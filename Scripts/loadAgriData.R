# =============================================================================
# loadAgriData.R
# -----------------------------------------------------------------------------
# Loads the Agriculture & Food CSVs (from downloadAgriData.R) into tidy,
# visualization-ready tables. Tables are split by PERIODICITY (annual /
# quarterly / monthly are never mixed in one frame) and related indicators are
# collapsed per theme. Each object is a flat, date-typed tibble ready to be
# save()'d from generateDashboardData.R.
#
#   crops_annual / crops_quarterly        volume + area + yield (+ YoY growth)
#   prices_monthly / prices_annual        farmgate/wholesale/retail, all series
#   livestock_quarterly / _annual         production (+ inventory, annual only)
#   fisheries_quarterly / _annual         subsector volume + value
#   value_production_quarterly            by subsector & valuation
#   self_sufficiency_annual               SSR + IDR
# =============================================================================

library(tidyverse)
library(lubridate)

agri_dir <- "Data/Agriculture and Food"
na_marks <- c("..", "-", ":", "...", " ", "")


# ---- Generic helpers --------------------------------------------------------

# Read an OpenStat CSV and pivot the wide "YYYY <Period>" columns long.
load_openstat <- function(path, value = "Value") {
    df <- read_csv(path, na = na_marks,
                   col_types = cols(.default = col_character()), show_col_types = FALSE)
    period_cols <- names(df)[str_detect(names(df), "^\\s*\\d{4}\\b")]
    df %>%
        pivot_longer(all_of(period_cols), names_to = "PeriodRaw", values_to = value) %>%
        mutate("{value}" := parse_number(.data[[value]]),
               Year = as.integer(str_extract(PeriodRaw, "\\d{4}")),
               PeriodLabel = str_squish(str_remove(PeriodRaw, "^\\s*\\d{4}")))
}

# Parse Year + PeriodLabel into a Date and a PeriodType.
add_date <- function(df) {
    df %>% mutate(
        PeriodType = case_when(
            str_detect(PeriodLabel, "^Quarter|^Q\\d")               ~ "Quarter",
            str_detect(PeriodLabel, "^Semester")                    ~ "Semester",
            str_detect(PeriodLabel, "to ")                          ~ "Cumulative",
            str_detect(PeriodLabel, str_c(month.name, collapse="|"))~ "Month",
            PeriodLabel %in% c("", "Annual")                        ~ "Annual",
            TRUE                                                    ~ "Other"),
        Month = case_when(
            PeriodType == "Quarter"  ~ (as.integer(str_extract(PeriodLabel, "\\d")) - 1L) * 3L + 1L,
            PeriodType == "Semester" ~ (as.integer(str_extract(PeriodLabel, "\\d")) - 1L) * 6L + 1L,
            PeriodType == "Month"    ~ match(str_extract(PeriodLabel, str_c(month.name, collapse="|")), month.name),
            PeriodType == "Annual"   ~ 1L,
            TRUE                     ~ NA_integer_),
        Date = make_date(Year, coalesce(Month, 1L), 1L))
}

# Split a dot-prefixed geography column into a clean name + a Level.
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

# Stack the two sources for one indicator (Major Crops has no palay/corn; the
# Palay-Corn table supplies palay, corn, and their irrigated/rainfed splits).
crop_stack <- function(paths, value)
    map_dfr(paths, ~ load_openstat(.x, value) %>% rename(Commodity = 1, Geolocation = 2)) %>%
        add_date()

build_crops <- function(freq, lag_n) {
    v <- crop_stack(crop_paths$vol,  "Volume") %>% filter(PeriodType == freq)
    a <- crop_stack(crop_paths$area, "Area")   %>% filter(PeriodType == freq)
    full_join(select(v, Commodity, Geolocation, Date, Volume),
              select(a, Commodity, Geolocation, Date, Area)) %>%
        clean_geo() %>%
        mutate(Yield = Volume / Area) %>%
        group_by(Commodity, Geolocation) %>% arrange(Date, .by_group = TRUE) %>%
        mutate(across(c(Volume, Area, Yield), ~ .x / lag(.x, lag_n) - 1, .names = "{.col}Growth")) %>%
        ungroup() %>%
        select(Commodity, Geolocation, Level, Date, Volume, Area, Yield, ends_with("Growth")) %>%
        suppressMessages() %>% suppressWarnings()
}

crops_annual    <- build_crops("Annual",  1)
crops_quarterly <- build_crops("Quarter", 4)


# ---- prices: farmgate / wholesale / retail, all series ----------------------
writeLines("Loading Agriculture price data into R.")

price_dirs  <- file.path(agri_dir, c("Farmgate Prices", "Wholesale Prices", "Retail Prices"))
price_files <- list.files(price_dirs, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)

prices_all <- map_dfr(price_files, function(f) {
    parts <- str_split(str_remove(f, fixed(str_c(agri_dir, "/"))), "/")[[1]]
    load_openstat(f, "Pesos") %>%
        rename(Geolocation = 1, Commodity = 2) %>%
        mutate(PriceType = str_remove(parts[1], " Prices"), Series = parts[2])
}) %>%
    add_date() %>% clean_geo() %>%
    suppressMessages() %>% suppressWarnings()

prices_monthly <- prices_all %>% filter(PeriodType == "Month",  !is.na(Pesos)) %>%
    select(PriceType, Series, Commodity, Geolocation, Level, Date, Pesos)
prices_annual  <- prices_all %>% filter(PeriodType == "Annual", !is.na(Pesos)) %>%
    select(PriceType, Series, Commodity, Geolocation, Level, Date, Pesos)


# ---- value_production: by subsector & valuation (quarterly) -----------------
writeLines("Loading Value of Production into R.")

value_production_quarterly <- load_openstat(
        file.path(agri_dir, "Agricultural Accounts/Openstat-Value-of-Production-Agri.csv"), "MillionPesos") %>%
    rename(Valuation = 1, Subsector = 2) %>%
    add_date() %>% filter(PeriodType == "Quarter") %>%
    mutate(Subsector = as_factor(str_remove_all(Subsector, "^\\.+"))) %>%
    group_by(Valuation, Subsector) %>% arrange(Date, .by_group = TRUE) %>%
    mutate(GrowthRate = MillionPesos / lag(MillionPesos, 4) - 1) %>% ungroup() %>%
    select(Valuation, Subsector, Date, MillionPesos, GrowthRate) %>%
    suppressMessages() %>% suppressWarnings()


# ---- self_sufficiency: SSR + IDR (annual) -----------------------------------
writeLines("Loading Self-Sufficiency & Import-Dependency into R.")

self_sufficiency_annual <- bind_rows(
    load_openstat(file.path(agri_dir, "Agricultural Accounts/Openstat-Self-Sufficiency-Agri.csv"), "Value") %>%
        mutate(Indicator = "Self-Sufficiency Ratio"),
    load_openstat(file.path(agri_dir, "Agricultural Accounts/Openstat-Import-Dependency-Agri.csv"), "Value") %>%
        mutate(Indicator = "Import Dependency Ratio")) %>%
    rename(Commodity = 1) %>% add_date() %>%
    select(Commodity, Indicator, Date, Value) %>%
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

# Inventory: animals are COLUMNS, Year is the row -> pivot animals long.
lvstk_inv <- read_csv(
        file.path(agri_dir, "Livestock and Poultry/Openstat-Inventory-Livestock-Poultry.csv"),
        na = na_marks, col_types = cols(.default = col_character()), show_col_types = FALSE) %>%
    pivot_longer(-Year, names_to = "Item", values_to = "Value") %>%
    mutate(Value = parse_number(Value), Year = as.integer(Year),
           Depth = 0L, Indicator = "Inventory (head)", Date = make_date(Year, 1L, 1L))

livestock_quarterly <- lvstk_prod %>% filter(PeriodType == "Quarter") %>%
    select(Item, Depth, Indicator, Date, Value) %>% suppressWarnings()
livestock_annual <- bind_rows(
    lvstk_prod %>% filter(PeriodType == "Annual") %>% select(Item, Depth, Indicator, Date, Value),
    lvstk_inv %>% select(Item, Depth, Indicator, Date, Value)) %>% suppressWarnings()
# NOTE: production labels (e.g. "Hog") and inventory labels ("Swine") may differ;
#       recode to align if you filter a single animal across both indicators.


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
    select(Subsector, Geolocation, Level, Indicator, Date, Value)
fisheries_annual <- fish_all %>% filter(PeriodType == "Annual", !is.na(Value)) %>%
    select(Subsector, Geolocation, Level, Indicator, Date, Value)

writeLines("Done loading Agriculture & Food data.")
