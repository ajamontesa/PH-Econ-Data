library(tidyverse)
library(readxl)
library(lubridate)
library(RcppRoll)


# Download Data -----------------------------------------------------------
# Optional: Download latest data from various sources.
# source("Scripts/downloadSNAData.R")



# National Accounts -------------------------------------------------------
writeLines("Loading National Accounts Data into R.")

snaColNames81 <- str_c(seq.Date(as.Date("1981-01-01"), Sys.Date()-weeks(19), by = "quarter"))
snaColNames00 <- str_c(seq.Date(as.Date("2000-01-01"), Sys.Date()-weeks(19), by = "quarter"))

## Load Quarterly SNA data from 1981 Q1 to latest quarter
SNA1981_Quarterly_Exp <- bind_rows(
    read_xlsx("Data/National Accounts/PSA-Quarter-Q1-1981-to-latest.xlsx", skip = 38, n_max = 8,
              col_names = c("Expenditure", snaColNames81)) %>%
        filter(!is.na(Expenditure)) %>%
        pivot_longer(cols = -Expenditure, names_to = "Quarter", values_to = "MillionPesos") %>%
        mutate(Quarter = as.Date(Quarter), Valuation = "Constant 2018 Prices"),
    read_xlsx("Data/National Accounts/PSA-Quarter-Q1-1981-to-latest.xlsx", skip = 11, n_max = 8,
              col_names = c("Expenditure", snaColNames81)) %>%
        filter(!is.na(Expenditure)) %>%
        pivot_longer(cols = -Expenditure, names_to = "Quarter", values_to = "MillionPesos") %>%
        mutate(Quarter = as.Date(Quarter), Valuation = "Current Prices")
) %>%
    group_by(Valuation, Expenditure) %>%
    mutate(GrowthRate = (MillionPesos/lag(MillionPesos, 4) - 1)) %>%
    ungroup() %>%
    mutate(Expenditure = as_factor(str_remove_all(Expenditure, "Less : "))) %>%
    suppressMessages() %>% suppressWarnings()

SNA1981_Quarterly_Ind <- bind_rows(
    read_xlsx("Data/National Accounts/PSA-Quarter-Q1-1981-to-latest.xlsx", skip = 197, n_max = 8,
              col_names = c("Industry", snaColNames81)) %>%
        filter(!is.na(Industry)) %>%
        pivot_longer(cols = -Industry, names_to = "Quarter", values_to = "MillionPesos") %>%
        mutate(Quarter = as.Date(Quarter), Valuation = "Constant 2018 Prices"),
    read_xlsx("Data/National Accounts/PSA-Quarter-Q1-1981-to-latest.xlsx", skip = 173, n_max = 8,
              col_names = c("Industry", snaColNames81)) %>%
        filter(!is.na(Industry)) %>%
        pivot_longer(cols = -Industry, names_to = "Quarter", values_to = "MillionPesos") %>%
        mutate(Quarter = as.Date(Quarter), Valuation = "Current Prices")
) %>%
    group_by(Valuation, Industry) %>%
    mutate(GrowthRate = (MillionPesos/lag(MillionPesos, 4) - 1)) %>%
    ungroup() %>%
    mutate(Industry = as_factor(str_remove_all(Industry, ",.+"))) %>%
    suppressMessages() %>% suppressWarnings()

## Load Annual SNA data from 1946 to latest year
SNA1946_Annual_Ind <- bind_rows(
    read_xlsx("Data/National Accounts/PSA-Annual-1946-to-latest.xlsx", sheet = "Current_2018based", skip = 9, n_max = 5,
              col_names = c("Industry", 1946:year(Sys.Date() - months(15)))) %>%
        filter(!is.na(Industry)) %>%
        pivot_longer(cols = -Industry, names_to = "Year", values_to = "MillionPesos") %>%
        mutate(Year = parse_date(Year, "%Y"), Valuation = "Current Prices"),
    read_xlsx("Data/National Accounts/PSA-Annual-1946-to-latest.xlsx", sheet = "Constant_2018based", skip = 9, n_max = 5,
              col_names = c("Industry", 1946:year(Sys.Date() - months(15)))) %>%
        filter(!is.na(Industry)) %>%
        pivot_longer(cols = -Industry, names_to = "Year", values_to = "MillionPesos") %>%
        mutate(Year = parse_date(Year, "%Y"), Valuation = "Constant 2018 Prices")
) %>%
    group_by(Valuation, Industry) %>%
    mutate(GrowthRate = (MillionPesos/lag(MillionPesos, 1) - 1)) %>%
    ungroup() %>%
    mutate(Industry = as_factor(str_remove_all(Industry, ",.+"))) %>%
    suppressMessages() %>% suppressWarnings()

## Load Quarterly SNA data from 2000 Q1 to latest quarter
SNA2000_Quarter_Exp <- bind_rows(
    read_xlsx("Data/National Accounts/PSA-01Summary_2018PSNA_Qrt.xlsx", skip = 49, n_max = 23,
              col_names = c("Expenditure", snaColNames00)) %>%
        filter(!is.na(Expenditure)) %>%
        pivot_longer(cols = -Expenditure, names_to = "Quarter", values_to = "MillionPesos") %>%
        mutate(Quarter = as.Date(Quarter), Valuation = "Constant 2018 Prices"),
    read_xlsx("Data/National Accounts/PSA-01Summary_2018PSNA_Qrt.xlsx", skip = 11, n_max = 23,
              col_names = c("Expenditure", snaColNames00)) %>%
        filter(!is.na(Expenditure)) %>%
        pivot_longer(cols = -Expenditure, names_to = "Quarter", values_to = "MillionPesos") %>%
        mutate(Quarter = as.Date(Quarter), Valuation = "Current Prices")
)  %>%
    group_by(Valuation, Expenditure) %>%
    mutate(GrowthRate = (MillionPesos/lag(MillionPesos, 4) - 1)) %>%
    ungroup() %>%
    mutate(Expenditure = as_factor(str_remove_all(Expenditure, "Less : "))) %>%
    suppressMessages() %>% suppressWarnings()

SNA2000_Quarter_Ind <- bind_rows(
    read_xlsx("Data/National Accounts/PSA-01Summary_2018PSNA_Qrt.xlsx", skip = 315, n_max = 24,
              col_names = c("Industry", snaColNames00)) %>%
        filter(!is.na(Industry)) %>%
        pivot_longer(cols = -Industry, names_to = "Quarter", values_to = "MillionPesos") %>%
        mutate(Quarter = as.Date(Quarter), Valuation = "Constant 2018 Prices"),
    read_xlsx("Data/National Accounts/PSA-01Summary_2018PSNA_Qrt.xlsx", skip = 276, n_max = 24,
              col_names = c("Industry", snaColNames00)) %>%
        filter(!is.na(Industry)) %>%
        pivot_longer(cols = -Industry, names_to = "Quarter", values_to = "MillionPesos") %>%
        mutate(Quarter = as.Date(Quarter), Valuation = "Current Prices")
)  %>%
    group_by(Valuation, Industry) %>%
    mutate(Growth = (MillionPesos/lag(MillionPesos, 4) - 1)) %>%
    ungroup() %>%
    mutate(Industry = as_factor(str_remove_all(Industry, ",.+"))) %>%
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
    mutate(Growth = Pesos/lag(Pesos, 4) - 1) %>%
    ungroup() %>%
    suppressWarnings() %>% suppressMessages()
