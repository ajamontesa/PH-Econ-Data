## loadTradeData.R ------------------------------------------------------------
## Consolidate the raw IMTS per-year CSVs (Data/Trade/Exports, Data/Trade/Imports)
## into a small set of clean, general-purpose tables that can be committed,
## uploaded, or folded into dashboardData.RData -- without the ~2.8 GB of raw data.
##
## The raw value tables are commodity x country x year records (gitignored;
## regenerate with downloadTradeData.R). This script keeps only trade VALUE in USD
## (exports FOB, imports CIF), canonicalises country labels, and emits several
## marginal tables that together answer most trade questions:
##
##   trade_annual            year x {Exports, Imports, balance, total_trade}
##   trade_by_partner        country x year x direction (+ region, flags)   [WHO]
##   trade_by_region         region  x year x direction                     [WHO, blocs]
##   trade_by_commodity      commodity code x year x direction (+ chapter,
##                           chapter_label, group); all years                [WHAT]
##   trade_by_partner_group  country x commodity group x year x direction   [WHO x WHAT]
##   trade_semiconductors    country x year x direction (HS 8541/8542)      [product x WHO]
##   trade_minerals          country x mineral_type x year x direction      [product x WHO]
##
## Outputs (Data/Trade/):
##   * one CSV per table (uploadable / inspectable)
##   * tradeData.rds  -- the same tables as a named list (for the dashboard)
##   * trade_tables_dictionary.md -- column-by-column data dictionary
##
## Completeness: every year on disk and every country are retained (label variants
## are merged, not dropped; residual aggregates are flagged, not removed, so totals
## reconcile). The HS/pre-HS split is detected by code length per row, not a fixed
## year. trade_by_commodity spans all years: HS subheadings (truncated to HS_DIGITS)
## for the harmonised era and whole PSCC codes before it (classification column);
## chapter/group are populated for HS rows only. The script ends with a coverage
## audit so you can verify nothing is silently lost.
## ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(tidyverse)
  library(data.table)
})

## ---- Config ----------------------------------------------------------------
EXP_DIR <- "Data/Trade/Exports"
IMP_DIR <- "Data/Trade/Imports"
OUT_DIR <- "Data/Trade"

# Commodity granularity. HS_DIGITS truncates HS codes to this many digits for the
# commodity table: 6 = international HS subheading (granular + compact); raise to
# 8 or 10 for national-line detail (larger files). INCLUDE_PRE_HS keeps the
# pre-2007 PSCC commodity codes too, so the commodity table spans 1991 onward
# (set FALSE for a smaller, HS-only commodity table).
HS_DIGITS          <- 6L
INCLUDE_PRE_HS     <- TRUE

SEMI_PREFIX <- c("8541", "8542")
MINERAL_P2  <- c("25", "26", "27", "74", "75", "78", "79", "80")
MINERAL_P4  <- c("7108")

EUROPE_RX <- paste0(
  "AUSTRIA|BELGIUM|BULGARIA|CROATIA|CYPRUS|CZECH|DENMARK|ESTONIA|FINLAND|",
  "FRANCE|GERMAN|GREECE|HUNGARY|ICELAND|IRELAND|ITALY|LATVIA|LIECHTENSTEIN|",
  "LITHUANIA|LUXEMBOURG|MALTA|NETHERLANDS|NORWAY|POLAND|PORTUGAL|ROMANIA|",
  "SLOVAK|SLOVENIA|SPAIN|SWEDEN|SWITZERLAND|UNITED KINGDOM|GREAT BRITAIN"
)
EUROPE_NOT_RX <- "ANTILLES|NEW CALEDONIA|GUIANA|POLYNESIA"

ASEAN_SET <- c("INDONESIA", "MALAYSIA", "THAILAND", "SINGAPORE", "VIETNAM",
               "BRUNEI DARUSSALAM", "CAMBODIA", "MYANMAR", "LAOS")

## ---- Helpers ---------------------------------------------------------------

# Canonical country labels. The Japan rule unifies "Japan" and "Japan (excludes
# Okinawa)" across vintages; without it Japan drops out of many years.
canon_country <- function(x) {
  y <- str_squish(toupper(x))
  y <- str_replace_all(y, "\\s*\\d+/\\s*$", "")
  y <- str_replace_all(y, "[.,]+$", "")
  y <- str_squish(y)
  dplyr::case_when(
    str_detect(y, "UNITED STATES|^USA$|^U\\.?S\\.?A?\\.?$") |
      y %in% c("ALASKA", "HAWAII", "PUERTO RICO", "GUAM", "AMERICAN SAMOA") ~ "UNITED STATES",
    str_detect(y, "HONG ?KONG")                                 ~ "HONG KONG",
    str_detect(y, "MACAU|MACAO")                                ~ "MACAU",
    str_detect(y, "TAIWAN|CHINESE TAIPEI|FORMOSA")              ~ "TAIWAN",
    str_detect(y, "JAPAN|OKINAWA|NANSEI")                       ~ "JAPAN",
    str_detect(y, "KOREA") &
      str_detect(y, "DPR|NORTH|DEMO\\.|DEMOCRATIC PEOPLE")      ~ "KOREA, DPR (NORTH)",
    str_detect(y, "KOREA")                                      ~ "KOREA, REP. (SOUTH)",
    str_detect(y, "^CHINA|MAINLAND CHINA|PEOPLE.?S REP.*CHINA|REPUBLIC OF CHINA$") &
      !str_detect(y, "TAIWAN")                                  ~ "CHINA",
    str_detect(y, "GERMAN") & !str_detect(y, "OPT\\. CTRY")     ~ "GERMANY",
    str_detect(y, "UNITED KINGDOM|GREAT BRITAIN|^U\\.?K\\.?$|^UK ") ~ "UNITED KINGDOM",
    str_detect(y, "RUSSIA|USSR|SOVIET")                         ~ "RUSSIA",
    str_detect(y, "NETHERLANDS") & !str_detect(y, "ANTILLES")   ~ "NETHERLANDS",
    str_detect(y, "CZECH")                                      ~ "CZECH REPUBLIC",
    str_detect(y, "SLOVAK")                                     ~ "SLOVAKIA",
    str_detect(y, "VIET ?NAM")                                  ~ "VIETNAM",
    str_detect(y, "BRUNEI")                                     ~ "BRUNEI DARUSSALAM",
    str_detect(y, "^LAO|LAO PEOPLE")                            ~ "LAOS",
    str_detect(y, "MYANMAR|BURMA")                              ~ "MYANMAR",
    str_detect(y, "CAMBODIA|KAMPUCHEA")                         ~ "CAMBODIA",
    str_detect(y, "INDONESIA")                                  ~ "INDONESIA",
    str_detect(y, "MALAYSIA|MALAYA|SABAH|SARAWAK")              ~ "MALAYSIA",
    str_detect(y, "ARAB EMIRATES|^U\\.?A\\.?E")                 ~ "UNITED ARAB EMIRATES",
    str_detect(y, "IRAN")                                       ~ "IRAN",
    TRUE                                                        ~ y
  )
}

is_residual_raw <- function(x) {
  y <- toupper(x)
  str_detect(y, paste0("N\\.E\\.S|NOT SPECIFIED|NEUTRAL ZONE|OPT\\. CTRY|",
                       "OTHER PACIFIC ISLANDS|U\\.S\\. OCEANIA|FRENCH OCEANIA|",
                       "SPANISH AFRICA|BRITISH PACIFIC ISLANDS|PACIFIC TRUST|",
                       "SOUTH AND SOUTHEAST ASIA")) &
    !str_detect(y, "ARAB EMIRATES")
}

is_europe_fun <- function(cc) str_detect(cc, EUROPE_RX) & !str_detect(cc, EUROPE_NOT_RX)

region_of <- function(cc) {
  dplyr::case_when(
    is_europe_fun(cc)                                                  ~ "Europe",
    cc %in% c("CHINA", "HONG KONG", "JAPAN", "TAIWAN", "MACAU",
              "KOREA, REP. (SOUTH)", "KOREA, DPR (NORTH)", "MONGOLIA") ~ "East Asia",
    cc %in% ASEAN_SET                                                  ~ "ASEAN",
    cc %in% c("UNITED STATES", "CANADA", "MEXICO")                     ~ "North America",
    cc %in% c("AUSTRALIA", "NEW ZEALAND", "PAPUA NEW GUINEA")          ~ "Oceania",
    str_detect(cc, "SAUDI|EMIRATES|QATAR|KUWAIT|BAHRAIN|OMAN|ISRAEL|IRAN|IRAQ|JORDAN|LEBANON|SYRIA|YEMEN|TURKEY") ~ "Middle East",
    str_detect(cc, "INDIA|PAKISTAN|BANGLADESH|SRI LANKA|NEPAL")        ~ "South Asia",
    TRUE                                                               ~ "Rest of world"
  )
}

group_from_chapter <- function(ch) {
  dplyr::case_when(
    ch %in% 1:5    ~ "Animal products",
    ch %in% 6:15   ~ "Vegetable products & oils",
    ch %in% 16:24  ~ "Prepared food, beverages & tobacco",
    ch %in% 25:27  ~ "Mineral products",
    ch %in% 28:38  ~ "Chemicals",
    ch %in% 39:40  ~ "Plastics & rubber",
    ch %in% 41:49  ~ "Hides, wood & paper",
    ch %in% 50:63  ~ "Textiles & apparel",
    ch %in% 64:67  ~ "Footwear & misc",
    ch %in% 68:71  ~ "Stone, glass & precious metals",
    ch %in% 72:83  ~ "Base metals",
    ch %in% 84:85  ~ "Machinery & electrical",
    ch %in% 86:89  ~ "Transport equipment",
    ch %in% 90:99  ~ "Instruments & misc manufactures",
    TRUE           ~ "Other / unclassified"
  )
}

mineral_type <- function(code) {
  p2 <- str_sub(code, 1, 2); p4 <- str_sub(code, 1, 4)
  dplyr::case_when(
    p4 == "7108"               ~ "Gold (7108)",
    p2 == "26"                 ~ "Metal ores & concentrates (26)",
    p2 == "74"                 ~ "Copper (74)",
    p2 == "75"                 ~ "Nickel (75)",
    p2 == "27"                 ~ "Mineral fuels (27)",
    p2 == "25"                 ~ "Salt, stone & earths (25)",
    p2 %in% c("78", "79", "80") ~ "Lead, zinc & tin (78-80)",
    TRUE                       ~ "Other minerals"
  )
}

HS_CH <- c(
  "01"="Live animals","02"="Meat","03"="Fish & seafood","04"="Dairy, eggs, honey",
  "05"="Other animal products","06"="Live trees & plants","07"="Vegetables",
  "08"="Edible fruit & nuts","09"="Coffee, tea & spices","10"="Cereals",
  "11"="Milling products","12"="Oil seeds & oleagins","13"="Gums & resins",
  "14"="Other vegetable materials","15"="Animal & vegetable fats/oils",
  "16"="Prepared meat & fish","17"="Sugars","18"="Cocoa","19"="Cereal/flour preparations",
  "20"="Prepared vegetables & fruit","21"="Misc edible preparations",
  "22"="Beverages & spirits","23"="Food residues & animal feed","24"="Tobacco",
  "25"="Salt, stone & cement","26"="Ores, slag & ash","27"="Mineral fuels & oils",
  "28"="Inorganic chemicals","29"="Organic chemicals","30"="Pharmaceuticals",
  "31"="Fertilisers","32"="Tanning & dyeing extracts","33"="Essential oils & cosmetics",
  "34"="Soaps & waxes","35"="Albuminoidal substances","36"="Explosives",
  "37"="Photographic goods","38"="Misc chemical products","39"="Plastics",
  "40"="Rubber","41"="Raw hides & leather","42"="Leather articles","43"="Furskins",
  "44"="Wood & wood articles","45"="Cork","46"="Straw & plaiting","47"="Wood pulp",
  "48"="Paper & paperboard","49"="Printed books","50"="Silk","51"="Wool",
  "52"="Cotton","53"="Other vegetable fibres","54"="Man-made filaments",
  "55"="Man-made staple fibres","56"="Wadding & nonwovens","57"="Carpets",
  "58"="Special woven fabrics","59"="Coated textiles","60"="Knitted fabrics",
  "61"="Knitted apparel","62"="Woven apparel","63"="Other textile articles",
  "64"="Footwear","65"="Headgear","66"="Umbrellas","67"="Feathers & art. flowers",
  "68"="Stone & cement articles","69"="Ceramics","70"="Glass",
  "71"="Pearls & precious metals","72"="Iron & steel","73"="Iron/steel articles",
  "74"="Copper","75"="Nickel","76"="Aluminium","78"="Lead","79"="Zinc","80"="Tin",
  "81"="Other base metals","82"="Tools & cutlery","83"="Misc base-metal articles",
  "84"="Machinery & mech. appliances","85"="Electrical machinery & electronics",
  "86"="Railway","87"="Vehicles","88"="Aircraft","89"="Ships & boats",
  "90"="Optical, medical & precision instr.","91"="Clocks & watches",
  "92"="Musical instruments","93"="Arms & ammunition","94"="Furniture & lighting",
  "95"="Toys, games & sports","96"="Misc manufactured articles","97"="Works of art",
  "98"="Special transactions (national)","99"="Special / other (national)"
)
hs_label <- function(ch) {
  k <- sprintf("%02d", as.integer(ch))
  unname(ifelse(k %in% names(HS_CH), HS_CH[k], paste("Chapter", k)))
}

## ---- Per-file processor ----------------------------------------------------
## Reads one year/direction CSV and returns that file's contribution to each
## aggregate, so the full leaf-level panel is never held in memory at once.
process_file <- function(path, direction) {
  message("  ", basename(path))
  dt <- data.table::fread(path, colClasses = "character",
                          na.strings = c("..", "", "NA"), showProgress = FALSE)
  nm <- names(dt)
  code_col <- nm[str_detect(nm, regex("commodity", ignore_case = TRUE))][1]
  ctry_col <- nm[str_detect(nm, regex("country",   ignore_case = TRUE))][1]
  val_col  <- nm[str_detect(nm, regex("FOB|CIF",   ignore_case = TRUE))]
  val_col  <- val_col[length(val_col)]
  yr <- as.integer(str_extract(val_col, "\\d{4}"))

  d <- tibble(
    code    = str_squish(dt[[code_col]]),
    country = dt[[ctry_col]],
    value   = suppressWarnings(as.numeric(dt[[val_col]]))
  ) %>%
    filter(!is.na(value), value > 0) %>%
    mutate(
      year      = yr,
      direction = direction,
      country_c = canon_country(country),
      region    = region_of(country_c),
      is_europe = is_europe_fun(country_c),
      is_asean  = country_c %in% ASEAN_SET,
      is_resid  = is_residual_raw(country),
      era       = if_else(nchar(code) >= 10, "HS", "pre-HS"),
      classification = if_else(era == "HS", "HS", "PSCC"),
      # HS codes truncated to HS_DIGITS (international subheading by default);
      # pre-HS PSCC codes kept whole (their digit hierarchy is not assumed).
      code_key  = if_else(era == "HS", str_sub(code, 1, HS_DIGITS), code),
      group     = if_else(era == "HS",
                          group_from_chapter(suppressWarnings(as.integer(str_sub(code, 1, 2)))),
                          NA_character_),
      is_semi    = era == "HS" & str_sub(code, 1, 4) %in% SEMI_PREFIX,
      is_mineral = era == "HS" & (str_sub(code, 1, 2) %in% MINERAL_P2 |
                                  str_sub(code, 1, 4) %in% MINERAL_P4)
    )

  d_comm <- if (INCLUDE_PRE_HS) filter(d, !is.na(code_key)) else filter(d, era == "HS")
  d_hs   <- filter(d, era == "HS", !is.na(group))

  list(
    partner = d %>%
      group_by(year, direction, country_c, region, is_europe, is_asean, is_resid) %>%
      summarise(value = sum(value), .groups = "drop"),
    commodity = d_comm %>%
      group_by(year, direction, classification, code_key) %>%
      summarise(value = sum(value), .groups = "drop"),
    partner_group = d_hs %>%
      group_by(year, direction, country_c, group) %>% summarise(value = sum(value), .groups = "drop"),
    semi = d %>% filter(is_semi) %>%
      group_by(year, direction, country_c) %>% summarise(value = sum(value), .groups = "drop"),
    mineral = d %>% filter(is_mineral) %>% mutate(mt = mineral_type(code)) %>%
      group_by(year, direction, country_c, mt) %>% summarise(value = sum(value), .groups = "drop")
  )
}

## ---- Run over all files ----------------------------------------------------
exp_files <- list.files(EXP_DIR, pattern = "\\.csv$", full.names = TRUE)
imp_files <- list.files(IMP_DIR, pattern = "\\.csv$", full.names = TRUE)
if (length(exp_files) == 0 || length(imp_files) == 0)
  stop("No CSVs found. Run downloadTradeData.R to populate ", EXP_DIR, " and ", IMP_DIR, ".")

message("Aggregating ", length(exp_files), " export + ", length(imp_files), " import files ...")
parts <- c(
  lapply(exp_files, process_file, direction = "Exports"),
  lapply(imp_files, process_file, direction = "Imports")
)
pull_part <- function(name) bind_rows(lapply(parts, `[[`, name))

# Round to whole USD and use clear, self-describing column names.
trade_by_partner <- pull_part("partner") %>%
  arrange(year, direction, desc(value)) %>%
  transmute(year, direction, country = country_c, region,
            is_europe, is_asean, is_resid, value_usd = round(value))

trade_by_commodity <- pull_part("commodity") %>%
  mutate(chapter       = if_else(classification == "HS", str_sub(code_key, 1, 2), NA_character_),
         chapter_label = if_else(classification == "HS", hs_label(chapter), NA_character_),
         group         = if_else(classification == "HS",
                                 group_from_chapter(suppressWarnings(as.integer(chapter))),
                                 NA_character_)) %>%
  arrange(year, direction, desc(value)) %>%
  transmute(year, direction, classification, code = code_key,
            chapter, chapter_label, group, value_usd = round(value))

trade_by_partner_group <- pull_part("partner_group") %>%
  arrange(year, direction, country_c, desc(value)) %>%
  transmute(year, direction, country = country_c, group, value_usd = round(value))

trade_semiconductors <- pull_part("semi") %>%
  arrange(year, direction, desc(value)) %>%
  transmute(year, direction, country = country_c, value_usd = round(value))

trade_minerals <- pull_part("mineral") %>%
  arrange(year, direction, desc(value)) %>%
  transmute(year, direction, country = country_c, mineral_type = mt, value_usd = round(value))

## ---- Derived convenience tables --------------------------------------------
trade_by_region <- trade_by_partner %>%
  group_by(year, direction, region) %>% summarise(value_usd = sum(value_usd), .groups = "drop")

trade_annual <- trade_by_partner %>%
  group_by(year, direction) %>% summarise(value_usd = sum(value_usd), .groups = "drop") %>%
  pivot_wider(names_from = direction, values_from = value_usd) %>%
  mutate(balance = Exports - Imports, total_trade = Exports + Imports) %>%
  arrange(year)

## ---- Write outputs ---------------------------------------------------------
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

tables <- list(
  trade_annual           = trade_annual,
  trade_by_partner       = trade_by_partner,
  trade_by_region        = trade_by_region,
  trade_by_commodity     = trade_by_commodity,
  trade_by_partner_group = trade_by_partner_group,
  trade_semiconductors   = trade_semiconductors,
  trade_minerals         = trade_minerals
)

# one CSV per table (uploadable / inspectable)
iwalk(tables, ~ write_csv(.x, file.path(OUT_DIR, paste0(.y, ".csv"))))

# named-list bundle for the dashboard
hs_first <- suppressWarnings(min(trade_by_commodity$year[trade_by_commodity$classification == "HS"]))
tradeData <- c(tables, list(meta = list(
  built          = Sys.time(),
  source         = "PSA OpenStat IMTS annual value tables (FOB exports / CIF imports), current USD",
  years          = sort(unique(trade_annual$year)),
  hs_digits      = HS_DIGITS,
  include_pre_hs = INCLUDE_PRE_HS,
  hs_era_from    = hs_first,
  semi_codes     = SEMI_PREFIX,
  mineral_codes  = c(MINERAL_P2, MINERAL_P4),
  europe         = "EU-27 + UK + EFTA (see EUROPE_RX in loadTradeData.R)",
  notes = paste(
    "value_usd is current USD. partner / region / annual span all years.",
    "trade_by_commodity spans all years too, with classification = 'HS' (codes",
    "truncated to", HS_DIGITS, "digits) for the harmonised era and 'PSCC' (whole",
    "7-digit codes) before it; chapter/group are populated for HS rows only.",
    "partner_group, semiconductors and minerals are HS-era only. Countries are",
    "canonicalised (incl. Japan); is_resid flags non-country aggregates."
  )
)))
saveRDS(tradeData, file.path(OUT_DIR, "tradeData.rds"), compress = "xz")

## ---- Data dictionary -------------------------------------------------------
dict <- c(
  "# Trade data tables (PH-Econ-Data / IMTS)",
  "",
  "Source: PSA OpenStat International Merchandise Trade Statistics, annual value",
  "tables. Values are current US dollars; exports valued FOB, imports CIF. Generated",
  "by `loadTradeData.R` from the raw per-year CSVs (which are not committed).",
  "",
  "Shared columns: `year` (int), `direction` ('Exports' or 'Imports'),",
  "`value_usd` (numeric, current USD). `country` is a canonicalised label.",
  "Partner/region/annual tables span all years; partner_group, semiconductors and",
  "minerals are HS-era only.",
  "",
  "## trade_annual.csv",
  "One row per year. Columns: year, Exports, Imports, balance, total_trade (all USD).",
  "",
  "## trade_by_partner.csv  [WHO]",
  "Trade value by partner country. Columns: year, direction, country, region,",
  "is_europe, is_asean, is_resid, value_usd. Spans all years and all countries.",
  "`region` is one of North America, East Asia, ASEAN, Europe, Middle East, South",
  "Asia, Oceania, Rest of world. `is_resid = TRUE` marks non-country aggregates",
  "(e.g. 'South and Southeast Asia, N.E.S.') -- exclude these for clean rankings.",
  "",
  "## trade_by_region.csv  [WHO, blocs]",
  "Trade value by partner region. Columns: year, direction, region, value_usd.",
  "(Roll-up of trade_by_partner.)",
  "",
  "## trade_by_commodity.csv  [WHAT]",
  "Trade value by commodity code, spanning all years. Columns: year, direction,",
  "classification, code, chapter, chapter_label, group, value_usd.",
  "`classification` = 'HS' (2007 onward; `code` is the HS subheading truncated to",
  paste0("the configured ", HS_DIGITS, " digits) or 'PSCC' (pre-2007; `code` is the whole"),
  "7-digit Philippine code). `chapter` (2-digit), `chapter_label` and the 14-way",
  "`group` are populated for HS rows only; roll up to them for HS-era composition,",
  "or filter `code` for any specific product. PSCC rows carry the raw pre-2007",
  "codes (interpret with the PSCC reference); they are not mapped to HS groups",
  "because the two classifications are not directly comparable.",
  "",
  "## trade_by_partner_group.csv  [WHO x WHAT]",
  "Trade value by partner country x commodity group. Columns: year, direction,",
  "country, group, value_usd. HS era only. Use for 'what does PH trade with X'.",
  "",
  "## trade_semiconductors.csv  [product x WHO]",
  "Semiconductor trade (HS 8541 + 8542) by partner. Columns: year, direction,",
  "country, value_usd. HS era only.",
  "",
  "## trade_minerals.csv  [product x WHO]",
  "Mineral / metal trade by partner and type. Columns: year, direction, country,",
  "mineral_type, value_usd. HS era only. `mineral_type`: Metal ores & concentrates",
  "(26), Copper (74), Nickel (75), Gold (7108), Mineral fuels (27), Salt, stone &",
  "earths (25), Lead, zinc & tin (78-80).",
  "",
  paste0("Coverage: ", min(trade_annual$year), "-", max(trade_annual$year),
         "; commodity by HS classification from ", hs_first, " onward",
         if (INCLUDE_PRE_HS) ", PSCC before that." else " (PSCC excluded).")
)
writeLines(dict, file.path(OUT_DIR, "trade_tables_dictionary.md"))

## ---- Completeness audit + report -------------------------------------------
message("\nWrote to ", OUT_DIR, ":")
sizes <- tibble(
  file = c(paste0(names(tables), ".csv"), "tradeData.rds", "trade_tables_dictionary.md"),
  rows = c(sapply(tables, nrow), NA, NA)
) %>%
  mutate(MB = round(file.info(file.path(OUT_DIR, file))$size / 1e6, 2))
print(sizes, n = nrow(sizes))

# Per-year coverage. commodity_cover = commodity value as a share of total trade;
# it should read ~100% wherever commodity data exists, confirming no value is
# lost across the commodity dimension.
cov <- trade_annual %>%
  transmute(year, exports_B = round(Exports / 1e9, 1), imports_B = round(Imports / 1e9, 1),
            partner_total = Exports + Imports) %>%
  left_join(trade_by_partner %>% group_by(year) %>%
              summarise(countries = n_distinct(country), .groups = "drop"), by = "year") %>%
  left_join(trade_by_commodity %>% group_by(year) %>%
              summarise(codes = n_distinct(code), commodity_total = sum(value_usd),
                        .groups = "drop"), by = "year") %>%
  mutate(commodity_cover = round(100 * commodity_total / partner_total, 1)) %>%
  select(year, exports_B, imports_B, countries, codes, commodity_cover)

cat("\nCoverage audit (commodity_cover ~100% => commodity tables capture all value):\n")
print(as.data.frame(cov), row.names = FALSE)

resid <- trade_by_partner %>% group_by(year) %>%
  summarise(r = sum(value_usd[is_resid]) / sum(value_usd), .groups = "drop")
cat(sprintf(
  "\nSpan: %d-%d (%d years) | distinct countries: %d | distinct commodity codes: %d\n",
  min(cov$year), max(cov$year), nrow(cov),
  n_distinct(trade_by_partner$country), n_distinct(trade_by_commodity$code)))
cat(sprintf(
  "Residual (non-country aggregate) share: max %.2f%% in %d; %.2f%% in %d (latest).\n",
  100 * max(resid$r), resid$year[which.max(resid$r)],
  100 * resid$r[resid$year == max(resid$year)], max(resid$year)))
cat("Reconcile vs PSA headline: 2024 exports ~73.3 B, 2025 exports ~84.5 B.\n")

## ---- Folding into dashboardData.RData (run when ready) ----------------------
##   load("Data/dashboardData.RData")
##   dashboardData$trade <- readRDS("Data/Trade/tradeData.rds")
##   save(dashboardData, file = "Data/dashboardData.RData")
## ---------------------------------------------------------------------------
