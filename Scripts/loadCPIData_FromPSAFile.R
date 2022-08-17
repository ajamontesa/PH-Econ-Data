library(tidyverse)
library(readxl)
library(writexl)
library(lubridate)


# Load Geolocation and Commodities from Weights
cpi_items <- read_csv("Data/CPI and Inflation/Base 2018/Openstat-cpiBase2018Weights.csv")


# Generate column headers for months Jan to Dec and Ave
months_length <- ((year(Sys.Date())-2018)*13) + month(Sys.Date())-1

cpi_months <- str_c(
    rep(2018:year(Sys.Date()), each = 13, length.out = months_length),
    rep_len(c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec", "Ave"),
            length.out = months_length)
)

cpi_colnames <- c("Geolocation", "Commodity Description", cpi_months)


# Load raw CPI data from xlsx file downloaded from PSA site (not Openstat)
cpi_raw <- read_xlsx("Data/CPI and Inflation/Base 2018/PSA-CPI.xlsx", skip = 5, col_names = cpi_colnames) %>%
    fill(Geolocation, .direction = "down")

cpi_all <- left_join(
    cpi_items %>% select(-Weights),
    cpi_raw
)


# Generate clean csv file
cpi_all %>% write_csv("Data/CPI and Inflation/Base 2018/PSA-cpi2018.csv")


# Cleanup
rm(list = ls())