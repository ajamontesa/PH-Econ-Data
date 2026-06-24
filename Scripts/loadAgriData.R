# =============================================================================
# loadAgriData.R
# -----------------------------------------------------------------------------
# Loads the Agriculture & Food CSVs (from downloadAgriData.R) into tidy tables,
# kept as complete and granular as possible (all geographic levels, all years,
# all commodities/series) and split by periodicity.
#
# Column conventions follow generateDashboardData.R for interoperability:
#   * time column named by frequency and typed as Date:
#       Quarter (quarter-start) / Month (month-start) / Year (Jan-1).
#   * GrowthRate = year-on-year change (lag 4 quarterly, 1 annual, 12 monthly).
#   * peso values as MillionPesos / Pesos; categories as_factor where small.
#   * long format; missing read as NA; suppressMessages()/suppressWarnings().
#
# Objects (drop straight in beside SNA2000_Quarterly_Exp etc.):
#   crops_annual / crops_quarterly      Commodity, Geolocation -> Volume, Area, Yield (+growth)
#   prices_monthly / prices_annual      PriceType, Series, Commodity, Geolocation -> Pesos
#   livestock_quarterly / _annual       Item, Indicator -> Value (production; +inventory annual)
#   fisheries_quarterly / _annual       Subsector, Geolocation, Indicator -> Value
#   value_production_quarterly          Valuation, Subsector -> MillionPesos (+GrowthRate)
#   self_sufficiency_annual             Commodity, Indicator -> Ratio
# =============================================================================

library(tidyverse)
library(lubridate)

agri_dir <- "Data/Agriculture and Food"
na_marks <- c("..", "-", ":", "...", " ", "")


# ---- Generic helpers --------------------------------------------------------

# Read an OpenStat CSV and pivot the wide period columns long. A column is a
# "period" if a 4-digit year appears ANYWHERE in its name (handles both
# "1990 January" and "January 1990"); the year is then stripped wherever it
# sits. Returns an empty tibble (with a warning) if no period columns exist,
# so a swept table with an odd layout names itself instead of crashing.
load_openstat <- function(path, value = "Value") {
    df <- read_csv(path, na = na_marks,
                   col_types = cols(.default = col_character()), show_col_types = FALSE)
    period_cols <- names(df)[str_detect(names(df), "\\d{4}")]
    if (length(period_cols) == 0L) {
        warning("No period columns in ", basename(path), " - skipped.", call. = FALSE)
        return(tibble())
    }
    df %>%
        pivot_longer(all_of(period_cols), names_to = "PeriodRaw", values_to = value) %>%
        mutate("{value}" := parse_number(.data[[value]]),
               Yr = as.integer(str_extract(PeriodRaw, "\\d{4}")),
               PeriodLabel = str_squish(str_remove(PeriodRaw, "\\s*\\d{4}\\s*")))
}

# Parse Yr + PeriodLabel into a Date + PeriodType (Date = period start), then
# drop all scratch columns so only the categories, value, PeriodType and Date
# remain -- this prevents a stale "Year" (or PeriodRaw) ever colliding when a
# table later renames Date -> Year / Quarter / Month.
add_date <- function(df) {
    df %>%
        mutate(
            PeriodType = case_when(
                str_detect(PeriodLabel, "^Quarter|^Q\\d")               ~ "Quarter",
                str_detect(PeriodLabel, "^Semester")                    ~ "Semester",
                str_detect(PeriodLabel, "to ")                          ~ "Cumulative",
                str_detect(PeriodLabel, str_c(month.name, collapse="|"))~ "Month",
                PeriodLabel %in% c("", "Annual")                        ~ "Annual",
                TRUE                                                    ~ "Other"),
            Mn = case_when(
                PeriodType == "Quarter"  ~ (as.integer(str_extract(PeriodLabel, "\\d")) - 1L) * 3L + 1L,
                PeriodType == "Semester" ~ (as.integer(str_extract(PeriodLabel, "\\d")) - 1L) * 6L + 1L,
                PeriodType == "Month"    ~ match(str_extract(PeriodLabel, str_c(month.name, collapse="|")), month.name),
                PeriodType == "Annual"   ~ 1L,
                TRUE                     ~ NA_integer_),
            Date = make_date(Yr, coalesce(Mn, 1L), 1L)) %>%
        select(-any_of(c("Yr", "Mn", "PeriodRaw", "PeriodLabel")))
}

# Split a dot-prefixed geography column into a clean name + a Level (all kept).
clean_geo <- function(df, col = "Geolocation") {
    df %>% mutate(
        Level = case_when(
            str_detect(.data[[col]], "^\\.{4,}") ~ "Province",
            str_detect(.data[[col]], "^\\.{2,}") ~ "Region",
            TRUE                                 ~ "National"),
        "{col}" := str_squish(str_remove_all(.data[[col]], "^\\.+")))
}


# ---- crops: major crops + palay/corn (ecosystem), volume + area + yield -----
writeLines("Loading Crops (volume, area, yield) into R.")

crop_paths <- list(
    vol  = file.path(agri_dir, c("Crops/Openstat-Volume-of-Production-Major-Crops.csv",
                                 "Crops/Openstat-Volume-of-Production-Palay-Corn.csv")),
    area = file.path(agri_dir, c("Crops/Openstat-Area-Harvested-Major-Crops.csv",
                                 "Crops/Openstat-Area-Harvested-Palay-Corn.csv")))

crop_stack <- function(paths, value)
    map_dfr(paths, ~ load_openstat(.x, value) %>% rename(Commodity = 1, Geolocation = 2)) %>%
        add_date()

build_crops <- function(freq, lag_n, timecol) {
    v <- crop_stack(crop_paths$vol,  "Volume") %>% filter(PeriodType == freq)
    a <- crop_stack(crop_paths$area, "Area")   %>% filter(PeriodType == freq)
    full_join(select(v, Commodity, Geolocation, Date, Volume),
              select(a, Commodity, Geolocation, Date, Area)) %>%
        clean_geo() %>%
        mutate(Yield = Volume / Area) %>%
        group_by(Commodity, Geolocation) %>% arrange(Date, .by_group = TRUE) %>%
        mutate(across(c(Volume, Area, Yield), ~ .x / lag(.x, lag_n) - 1, .names = "{.col}Growth")) %>%
        ungroup() %>%
        rename("{timecol}" := Date) %>%
        select(Commodity, Geolocation, Level, all_of(timecol),
               Volume, Area, Yield, ends_with("Growth")) %>%
        arrange(Commodity, Geolocation, .data[[timecol]]) %>%
        suppressMessages() %>% suppressWarnings()
}

crops_annual    <- build_crops("Annual",  1, "Year")
crops_quarterly <- build_crops("Quarter", 4, "Quarter")


# ---- prices: farmgate / wholesale / retail, all series, all geo levels ------
writeLines("Loading Agriculture price data into R.")

price_dirs  <- file.path(agri_dir, c("Farmgate Prices", "Wholesale Prices", "Retail Prices"))
price_files <- list.files(price_dirs, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)

prices_all <- map_dfr(price_files, function(f) {
    parts <- str_split(str_remove(f, fixed(str_c(agri_dir, "/"))), "/")[[1]]
    d <- load_openstat(f, "Pesos")
    if (nrow(d) == 0) return(tibble())                       # skipped (no period cols)
    cat_cols <- setdiff(names(d), c("Pesos", "Yr", "PeriodRaw", "PeriodLabel"))
    if (length(cat_cols) < 2) {                              # unexpected layout
        warning("Layout has <2 category columns: ", basename(f), call. = FALSE)
        return(tibble())
    }
    d %>% rename(Geolocation = 1, Commodity = 2) %>%
        mutate(PriceType = str_remove(parts[1], " Prices"), Series = parts[2])
}) %>%
    add_date() %>% clean_geo() %>%
    suppressMessages() %>% suppressWarnings()

prices_monthly <- prices_all %>% filter(PeriodType == "Month",  !is.na(Pesos)) %>%
    rename(Month = Date) %>%
    select(PriceType, Series, Commodity, Geolocation, Level, Month, Pesos) %>%
    arrange(PriceType, Series, Commodity, Geolocation, Month)
prices_annual  <- prices_all %>% filter(PeriodType == "Annual", !is.na(Pesos)) %>%
    rename(Year = Date) %>%
    select(PriceType, Series, Commodity, Geolocation, Level, Year, Pesos) %>%
    arrange(PriceType, Series, Commodity, Geolocation, Year)


# ---- value_production: by subsector & valuation (quarterly) -----------------
writeLines("Loading Value of Production into R.")

value_production_quarterly <- load_openstat(
        file.path(agri_dir, "Agricultural Accounts/Openstat-Value-of-Production-Agri.csv"), "MillionPesos") %>%
    rename(Valuation = 1, Subsector = 2) %>%
    add_date() %>% filter(PeriodType == "Quarter") %>%
    rename(Quarter = Date) %>%
    mutate(Subsector = as_factor(str_remove_all(Subsector, "^\\.+"))) %>%
    group_by(Valuation, Subsector) %>% arrange(Quarter, .by_group = TRUE) %>%
    mutate(GrowthRate = MillionPesos / lag(MillionPesos, 4) - 1) %>% ungroup() %>%
    select(Valuation, Subsector, Quarter, MillionPesos, GrowthRate) %>%
    suppressMessages() %>% suppressWarnings()


# ---- self_sufficiency: SSR + IDR (annual) -----------------------------------
writeLines("Loading Self-Sufficiency & Import-Dependency into R.")

self_sufficiency_annual <- bind_rows(
    load_openstat(file.path(agri_dir, "Agricultural Accounts/Openstat-Self-Sufficiency-Agri.csv"), "Ratio") %>%
        mutate(Indicator = "Self-Sufficiency Ratio"),
    load_openstat(file.path(agri_dir, "Agricultural Accounts/Openstat-Import-Dependency-Agri.csv"), "Ratio") %>%
        mutate(Indicator = "Import Dependency Ratio")) %>%
    rename(Commodity = 1) %>% add_date() %>% rename(Year = Date) %>%
    select(Commodity, Indicator, Year, Ratio) %>%
    arrange(Commodity, Indicator, Year) %>%
    suppressMessages() %>% suppressWarnings()


# ---- livestock: production (quarterly/annual) + inventory (annual) ----------
writeLines("Loading Livestock & Poultry into R.")

lvstk_prod <- load_openstat(
        file.path(agri_dir, "Livestock and Poultry/Openstat-Volume-of-Production-Livestock-Poultry.csv"), "Value") %>%
    rename(ItemRaw = 1) %>%
    mutate(Depth = str_length(str_extract(ItemRaw, "^\\.*")),
           Item  = str_squish(str_remove_all(ItemRaw, "^\\.+")),
           Indicator = "Production (MT)") %>%
    add_date()

lvstk_inv <- read_csv(
        file.path(agri_dir, "Livestock and Poultry/Openstat-Inventory-Livestock-Poultry.csv"),
        na = na_marks, col_types = cols(.default = col_character()), show_col_types = FALSE) %>%
    pivot_longer(-Year, names_to = "Item", values_to = "Value") %>%
    mutate(Value = parse_number(Value), InvYear = as.integer(Year),
           Depth = 0L, Indicator = "Inventory (head)", Date = make_date(InvYear, 1L, 1L)) %>%
    select(Item, Depth, Indicator, Date, Value)

livestock_quarterly <- lvstk_prod %>% filter(PeriodType == "Quarter") %>%
    rename(Quarter = Date) %>%
    select(Item, Depth, Indicator, Quarter, Value) %>%
    arrange(Item, Quarter) %>% suppressWarnings()

livestock_annual <- bind_rows(
        lvstk_prod %>% filter(PeriodType == "Annual") %>% select(Item, Depth, Indicator, Date, Value),
        lvstk_inv) %>%
    rename(Year = Date) %>%
    arrange(Indicator, Item, Year) %>% suppressWarnings()
# NOTE: production ("Hog") and inventory ("Swine") labels may differ; recode to
#       align if filtering a single animal across both indicators.


# ---- fisheries: subsector volume + value (quarterly/annual) -----------------
writeLines("Loading Fisheries into R.")

fish_all <- bind_rows(
    load_openstat(file.path(agri_dir, "Fisheries/Openstat-Volume-of-Production-Fisheries-Subsector.csv"), "Value") %>%
        mutate(Indicator = "Volume (MT)"),
    load_openstat(file.path(agri_dir, "Fisheries/Openstat-Value-of-Production-Fisheries-Subsector.csv"), "Value") %>%
        mutate(Indicator = "Value (PhP000)")) %>%
    rename(Geolocation = 1, Subsector = 2) %>%
    add_date() %>% clean_geo() %>%
    mutate(Subsector = as_factor(str_remove_all(Subsector, "^\\.+"))) %>%
    suppressMessages() %>% suppressWarnings()

fisheries_quarterly <- fish_all %>% filter(PeriodType == "Quarter", !is.na(Value)) %>%
    rename(Quarter = Date) %>%
    select(Subsector, Geolocation, Level, Indicator, Quarter, Value) %>%
    arrange(Subsector, Geolocation, Indicator, Quarter)
fisheries_annual <- fish_all %>% filter(PeriodType == "Annual", !is.na(Value)) %>%
    rename(Year = Date) %>%
    select(Subsector, Geolocation, Level, Indicator, Year, Value) %>%
    arrange(Subsector, Geolocation, Indicator, Year)

writeLines("Done loading Agriculture & Food data.")
