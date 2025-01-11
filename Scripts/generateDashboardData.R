library(tidyverse)
library(readxl)
library(lubridate)
library(RcppRoll)

rm(list = ls())


# Load National Accounts Data ---------------------------------------------
snaColNames81 <- str_c(seq.Date(as.Date("1981-01-01"), Sys.Date()-weeks(16), by = "quarter"))
snaColNames00 <- str_c(seq.Date(as.Date("2000-01-01"), Sys.Date()-weeks(16), by = "quarter"))


## Load Quarterly SNA data from 2000 Q1 to latest quarter
SNA2000_Quarterly_Exp <- bind_rows(
    read_xlsx("Data/National Accounts/PSA-01Summary_2018PSNA_Qrt.xlsx",
              skip = 49, n_max = 23, col_names = c("Expenditure", snaColNames00)) %>%
        filter(!is.na(Expenditure)) %>%
        pivot_longer(cols = -Expenditure, names_to = "Quarter", values_to = "MillionPesos") %>%
        mutate(Quarter = as.Date(Quarter), Valuation = "Constant 2018 Prices"),
    read_xlsx("Data/National Accounts/PSA-01Summary_2018PSNA_Qrt.xlsx",
              skip = 11, n_max = 23, col_names = c("Expenditure", snaColNames00)) %>%
        filter(!is.na(Expenditure)) %>%
        pivot_longer(cols = -Expenditure, names_to = "Quarter", values_to = "MillionPesos") %>%
        mutate(Quarter = as.Date(Quarter), Valuation = "Current Prices")
)  %>%
    group_by(Valuation, Expenditure) %>%
    mutate(GrowthRate = (MillionPesos/lag(MillionPesos, 4) - 1)) %>%
    ungroup() %>%
    filter(!str_detect(Expenditure, "discrepancy")) %>%
    mutate(Expenditure = as_factor(str_remove_all(Expenditure, "Less : "))) %>%
    suppressMessages() %>% suppressWarnings()

SNA2000_Quarterly_Exp <- bind_rows(
    read_xlsx("Data/National Accounts/PSA-01Summary_2018PSNA_Qrt.xlsx",
              skip = 49, n_max = 23, col_names = c("Expenditure", snaColNames00)) %>%
        filter(!is.na(Expenditure)) %>%
        pivot_longer(cols = -Expenditure, names_to = "Quarter", values_to = "MillionPesos") %>%
        mutate(Quarter = as.Date(Quarter), Valuation = "Constant 2018 Prices"),
    read_xlsx("Data/National Accounts/PSA-01Summary_2018PSNA_Qrt.xlsx",
              skip = 11, n_max = 23, col_names = c("Expenditure", snaColNames00)) %>%
        filter(!is.na(Expenditure)) %>%
        pivot_longer(cols = -Expenditure, names_to = "Quarter", values_to = "MillionPesos") %>%
        mutate(Quarter = as.Date(Quarter), Valuation = "Current Prices")
)  %>%
    group_by(Valuation, Expenditure) %>%
    mutate(GrowthRate = (MillionPesos/lag(MillionPesos, 4) - 1)) %>%
    ungroup() %>%
    filter(!str_detect(Expenditure, "discrepancy")) %>%
    mutate(Expenditure = as_factor(str_remove_all(Expenditure, "Less : "))) %>%
    suppressMessages() %>% suppressWarnings()

SNA2000_Quarterly_Ind <- bind_rows(
    read_xlsx("Data/National Accounts/PSA-01Summary_2018PSNA_Qrt.xlsx",
              skip = 315, n_max = 24, col_names = c("Industry", snaColNames00)) %>%
        filter(!is.na(Industry)) %>%
        pivot_longer(cols = -Industry, names_to = "Quarter", values_to = "MillionPesos") %>%
        mutate(Quarter = as.Date(Quarter), Valuation = "Constant 2018 Prices"),
    read_xlsx("Data/National Accounts/PSA-01Summary_2018PSNA_Qrt.xlsx",
              skip = 276, n_max = 24, col_names = c("Industry", snaColNames00)) %>%
        filter(!is.na(Industry)) %>%
        pivot_longer(cols = -Industry, names_to = "Quarter", values_to = "MillionPesos") %>%
        mutate(Quarter = as.Date(Quarter), Valuation = "Current Prices")
)  %>%
    group_by(Valuation, Industry) %>%
    mutate(GrowthRate = (MillionPesos/lag(MillionPesos, 4) - 1)) %>%
    ungroup() %>%
    mutate(Industry = str_squish(Industry),
           Industry = as_factor(str_remove_all(Industry, ",.+"))) %>%
    suppressMessages() %>% suppressWarnings()

SNA2000_Quarterly_PC <- read_csv("Data/National Accounts/Openstat-SNA-Quarterly-PC.csv") %>%
    filter(str_detect(Industry, "Gross")) %>%
    mutate(across(.cols = -1, .fns = as.double)) %>%
    pivot_longer(cols = -1) %>%
    mutate(Quarter = yq(str_extract(name, "\\d{4} Q\\d")) + months(0),
           Valuation = str_to_title(str_remove(Industry, "Per.+at\\s")),
           Industry = str_remove(str_extract(Industry, "Per.+at"), " at")) %>%
    select(Industry, Quarter, Valuation, Pesos = value) %>%
    group_by(Industry, Valuation) %>%
    mutate(GrowthRate = Pesos/lag(Pesos, 4) - 1) %>%
    ungroup() %>%
    suppressWarnings() %>% suppressMessages()



# Load CPI and Inflation Data ---------------------------------------------
inflation_large <- read_csv("Data/CPI and Inflation/Base 2018/Openstat-cpi1994to2005.csv", na = "..") %>%
    full_join(read_csv("Data/CPI and Inflation/Base 2018/Openstat-cpi2006to2017.csv", na = "..")) %>%
    full_join(read_csv("Data/CPI and Inflation/Base 2018/Openstat-cpi2018.csv", na = "..") %>%
                  mutate(Geolocation = str_remove(Geolocation, "Bansamoro "))) %>%
    select(1:(2 + (year(Sys.Date()) - 2006)*13 + (month(Sys.Date()) - 3))) %>%
    rename(Commodity = `Commodity Description`) %>%
    pivot_longer(cols = -(Geolocation:Commodity), names_to = "Month",
                 values_to = "CPI", values_transform = list(CPI = as.double)) %>%
    filter(!str_detect(Month, "Ave")) %>%
    mutate(Month = parse_date(Month, "%Y %b")) %>%
    group_by(Geolocation, Commodity) %>%
    mutate(Inflation = (CPI/lag(CPI, 12) - 1)) %>%
    ungroup() %>%
    suppressMessages() %>% suppressWarnings()

inflation_core <- read_xlsx("Data/CPI and Inflation/Base 2018/PSA-CoreCPI.xlsx", skip = 4) %>%
    select(Month = 2, Core = 5) %>%
    filter(!is.na(Month)) %>%
    mutate(Year = case_when(str_detect(Month, "\\d") ~ Month),
           Month = case_when(str_detect(Month, "\\d") ~ "Ave",
                             TRUE ~ Month)) %>%
    fill(Year, .direction = "down") %>%
    mutate(Period = str_c(Year, " ", str_sub(Month, 1, 3))) %>%
    filter(!str_detect(Period, "Ave")) %>%
    mutate(Month = parse_date(Period, "%Y %b"),
           Inflation = (Core/lag(Core, 12)) - 1,
           Geolocation = "PHILIPPINES", Commodity = "CORE", CPI = Core) %>%
    select(Geolocation, Commodity, Month, CPI, Inflation) %>%
    suppressMessages() %>% suppressWarnings()

inflation_small <- bind_rows(
    filter(mutate(inflation_large, Commodity = str_remove(Commodity, "^.+\\-\\s")),
           Geolocation == "PHILIPPINES",
           Commodity %in% c("ALL ITEMS", "FOOD AND NON-ALCOHOLIC BEVERAGES", "NON-FOOD")),
    inflation_core
) %>%
    mutate(Commodity = recode(Commodity, "ALL ITEMS" = "Headline", "FOOD AND NON-ALCOHOLIC BEVERAGES" = "Food", "NON-FOOD" = "Non-Food", "CORE" = "Core"),
           Commodity = factor(Commodity, levels = c("Headline", "Core", "Food", "Non-Food"))) %>%
    suppressMessages() %>% suppressWarnings()

main_commodities <- c(
    "ALL ITEMS", "FOOD AND NON-ALCOHOLIC BEVERAGES",
    "ALCOHOLIC BEVERAGES, TOBACCO AND OTHER VEGETABLE-BASED TOBACCO PRODUCTS",
    "NON-FOOD", "CLOTHING AND FOOTWEAR",
    "HOUSING, WATER, ELECTRICITY, GAS AND OTHER FUELS",
    "FURNISHINGS, HOUSEHOLD EQUIPMENT AND ROUTINE HOUSEHOLD MAINTENANCE",
    "HEALTH", "TRANSPORT", "COMMUNICATION", "RECREATION AND CULTURE", "EDUCATION",
    "RESTAURANTS AND MISCELLANEOUS GOODS AND SERVICES"
)

inflation_main <- inflation_large %>%
    mutate(Commodity = str_remove(Commodity, "^.+\\-\\s")) %>%
    filter(!str_starts(Geolocation, "\\.{4}"),
           Commodity %in% main_commodities)

rm(inflation_large)



# Load Employment Data ----------------------------------------------------
labor <- read_xlsx("Data/Labor and Employment/Labor and Employment.xlsx") %>%
    filter(Round != "Annual") %>%
    mutate(Period = case_when(str_detect(`LFS Round`, "Q") ~ yq(`LFS Round`),
                              TRUE ~ parse_date(`LFS Round`, "%Y %b"))) %>%
    rename_with(~ str_remove_all(., "\\s|\\+")) %>%
    select(LFSRound:Round, Period, everything())



# Load Fiscal Data --------------------------------------------------------

ngcor <- left_join(
    read_xlsx("Data/Fiscal Data/ngcor.xlsx") %>%
        pivot_longer(cols = -Particulars, names_to = "Month", values_to = "MillionPesos") %>%
        mutate(Particulars = as_factor(str_remove_all(Particulars, "\\s|-|/|\\(|\\)")),
               Month = parse_date(Month, "%B %Y"),
               Quarter = yq(str_c(str_sub(Month, 1, 4), "Q", quarter(Month)))) %>%
        group_by(Particulars, Quarter) %>%
        summarize(MillionPesos = sum(MillionPesos, na.rm = TRUE)) %>%
        ungroup() %>%
        pivot_wider(names_from = Particulars, values_from = MillionPesos),
    read_xlsx("Data/National Accounts/PSA-Quarter-Q1-1981-to-latest.xlsx",
              skip = 18, n_max = 1, col_names = c("Expenditure", snaColNames81)) %>%
        pivot_longer(cols = -Expenditure, names_to = "Quarter", values_to = "NominalGDP") %>%
        mutate(Quarter = as.Date(Quarter)) %>%
        select(Quarter, NominalGDP)
) %>% mutate(across(.cols = -Quarter, .fns = ~roll_meanr(.x, 4), .names = "{.col}4Q")) %>%
    suppressMessages() %>% suppressWarnings()


ngdebt <- left_join(
    read_xlsx("Data/Fiscal Data/ngdebt.xlsx") %>%
        pivot_longer(cols = -Particulars, names_to = "Month", values_to = "MillionPesos") %>%
        filter(Particulars %in% c("Actual Obligations", "Domestic Debt", "External Debt"),
               str_detect(Month, "Mar|Jun|Sep|Dec")) %>%
        mutate(Particulars = as_factor(str_remove_all(Particulars, "\\s|-|/|\\(|\\)")),
               Month = parse_date(Month, "%B %Y"),
               Quarter = yq(str_c(str_sub(Month, 1, 4), "Q", quarter(Month)))) %>%
        pivot_wider(names_from = Particulars, values_from = MillionPesos) %>%
        filter(year(Quarter) >= 1993),
    read_xlsx("Data/National Accounts/PSA-Quarter-Q1-1981-to-latest.xlsx",
              skip = 18, n_max = 1, col_names = c("Expenditure", snaColNames81)) %>%
        pivot_longer(cols = -Expenditure, names_to = "Quarter", values_to = "NominalGDP") %>%
        mutate(Quarter = as.Date(Quarter)) %>%
        select(Quarter, NominalGDP)
) %>% mutate(NominalGDP4Q = roll_sumr(NominalGDP, 4)) %>%
    suppressMessages() %>% suppressWarnings()


tax_types <- left_join(
    read_xlsx("Data/Fiscal Data/BIR-Tax-Statistics.xlsx") %>%
        rename(TaxType = `Tax Classification`) %>%
        pivot_longer(cols = -TaxType, names_to = "Particular", values_to = "Thousands") %>%
        mutate(Year = str_extract(Particular, "\\d{4}"),
               Particular = str_remove(Particular, "\\d{4}\\s"),
               Year = as.Date(str_c(Year, "-10-01"))) %>%
        pivot_wider(names_from = "Particular", values_from = "Thousands") %>%
        mutate(Quarter = Year),
    ngcor %>%
        filter(quarter(Quarter) == 4) %>%
        select(Quarter, BIRRevenues4Q, NominalGDP4Q)
) %>%
    mutate(Effort = Collection/(NominalGDP4Q*4),
           Share = Collection/(BIRRevenues4Q*4))


save.image("Data/dashboardData.RData")

