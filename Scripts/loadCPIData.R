library(tidyverse)
library(readxl)
library(lubridate)
library(RcppRoll)


# Download Data -----------------------------------------------------------
# Optional: Download latest data from various sources.
# source("Scripts/downloadCPIData.R")



# CPI and Inflation -------------------------------------------------------
writeLines("Loading CPI and Inflation Data into R.")

inflation_large <- full_join(read_csv("Data/CPI and Inflation/Base 2018/Openstat-cpi1994to2017.csv", na = ".."),
          read_csv("Data/CPI and Inflation/Base 2018/Openstat-cpi2018.csv", na = "..") %>%
              mutate(Geolocation = str_remove(Geolocation, "Bansamoro "))) %>%
    select(1:(2 + (year(Sys.Date()) - 1994)*13 + (month(Sys.Date() - days(5)) - 1))) %>%
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

inflation_small <- bind_rows(filter(inflation_large,
                                    Geolocation == "PHILIPPINES",
                                    Commodity %in% c("0 - ALL ITEMS",
                                                     "01 - FOOD AND NON-ALCOHOLIC BEVERAGES",
                                                     "02.900 - NON-FOOD")),
                             inflation_core) %>%
    mutate(Commodity = recode(Commodity,
                              "0 - ALL ITEMS" = "Headline",
                              "01 - FOOD AND NON-ALCOHOLIC BEVERAGES" = "Food",
                              "02.900 - NON-FOOD" = "Non-Food",
                              "CORE" = "Core"),
           Commodity = factor(Commodity, levels = c("Headline", "Core", "Food", "Non-Food"))) %>%
    suppressMessages() %>% suppressWarnings()
