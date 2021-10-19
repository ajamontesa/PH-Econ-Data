library(tidyverse)
library(httr)
library(rvest)
library(writexl)
library(lubridate)


if (!dir.exists("Data")) {dir.create("Data")}
if (!dir.exists("Data/CPI and Inflation")) {dir.create("Data/CPI and Inflation")}



# BSP Consumer Price Index ------------------------------------------------
writeLines("Downloading CPI Data from the BSP website.")

download.file(url = "https://www.bsp.gov.ph/Statistics/Prices/prices2012.xls",
              destfile = "Data/CPI and Inflation/BSP-prices2012.xls", method = "curl")



# PSA Website Consumer Price Index ----------------------------------------
writeLines("Downloading CPI Data from the PSA Website.")

## Scrape a list of links from the latest (Base 2012) CPI release from the PSA site
cpi_links <- read_html("https://psa.gov.ph/price-indices/cpi-ir/downloads") %>%
    html_nodes("table") %>% html_nodes("td") %>% html_nodes("span") %>% html_nodes("a") %>%
    html_attr("href")

# Download CPI xlsx files from the scraped links
download.file(url = cpi_links %>% str_subset("Statistical") %>% .[1],
              destfile = "Data/CPI and Inflation/PSA-CPI.xlsx", method = "curl")

download.file(url = cpi_links %>% str_subset("CORE") %>% .[1],
              destfile = "Data/CPI and Inflation/PSA-CoreCPI.xlsx", method = "curl")

rm(list = ls())


# Openstat Consumer Price Index -------------------------------------------
writeLines("Downloading CPI Data from Openstat.")

## Download Base 2012 Commodity Weights
if (!file.exists("Data/CPI and Inflation/Openstat-cpiBase2012Weights.csv")) {
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/CPI/0012M4ACPI3.px",
         body = '{"query": [], "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8") %>%
        write_csv("Data/CPI and Inflation/Openstat-cpiBase2012Weights.csv") %>%
        suppressMessages() %>% suppressWarnings()
}

## Download CPI data from 1957 to 1993 (Base 2012)
if (!file.exists("Data/CPI and Inflation/Openstat-cpi1957to1993.csv")) {
    writeLines(paste0("Downloading CPI data for 1957 to 1993"))
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/CPI/0012M4ACPI5.px",
         body = '{"query": [], "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8") %>%
        write_csv("Data/CPI and Inflation/Openstat-cpi1957to1993.csv") %>%
        suppressMessages() %>% suppressWarnings()
}

## Download CPI data from 1994 to 2011 (Base 2012)
if (!file.exists("Data/CPI and Inflation/Openstat-cpi1994to2011.csv")) {
    codes <- tribble(~a, ~b, ~y, "a", "b", "y")
    queries1 <- c('0", "1", "2", "3", "4", "5', '6", "7", "8", "9", "10", "11', '12')
    for (y in 1994:2011 - 1994) {
        for(q in 1:3) {
            codes[y + 1, q] <-
                str_c('{"query": [{"code": "Year", "selection": {"filter": "item", "values": ["',
                      y, '"]}}, {"code": "Period", "selection": {"filter": "item", "values": ["',
                      queries1[q], '"]}}], "response": {"format": "csv"}}')
        }
    }
    
    for (y in 1994:2011 - 1994) {
        writeLines(paste0("Downloading CPI data for ", y + 1994))
        for(q in c("a", "b", "y")) {
            assign(paste0("cpi", y + 1994, q),
                   POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/CPI/0012M4ACPI4.px",
                        body = codes[[y + 1, q]]) %>%
                       content(encoding = "UTF-8")) %>%
                suppressMessages() %>% suppressWarnings()
            Sys.sleep(0.5)
        }
    }
    
    do.call(bind_cols, mget(ls()[str_detect(ls(), "cpi\\d{4}")])) %>%
        select(1:2, starts_with("1"), starts_with("2")) %>%
        rename(Geolocation = Geolocation...1,
               `Commodity Description` = `Commodity Description...2`) %>%
        write_csv("Data/CPI and Inflation/Openstat-cpi1994to2011.csv") %>%
        suppressMessages() %>% suppressWarnings()
    
    rm(list = ls())
}

## Download CPI data from 2012 Jan to latest month
{## Latest Data
    codes <- tribble(~a, ~b, ~y, "a", "b", "y")
    queries1 <- c('0", "1", "2", "3", "4", "5', '6", "7", "8", "9", "10", "11', '12')
    for (y in 2012:year(Sys.Date()) - 2012) {
        for(q in 1:3) {
            codes[y + 1, q] <-
                str_c('{"query": [{"code": "Year", "selection": {"filter": "item", "values": ["',
                      y, '"]}}, {"code": "Period", "selection": {"filter": "item", "values": ["',
                      queries1[q], '"]}}], "response": {"format": "csv"}}')
        }
    }
    
    for (y in 2012:year(Sys.Date()) - 2012) {
        writeLines(paste0("Downloading CPI data for ", y + 2012))
        for(q in c("a", "b", "y")) {
            assign(paste0("cpi", y + 2012, q),
                   POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/CPI/0012M4ACPI1.px",
                        body = codes[[y + 1, q]]) %>%
                       content(encoding = "UTF-8")) %>%
                suppressMessages() %>% suppressWarnings()
            Sys.sleep(0.5)
        }
    }
    
    do.call(bind_cols, mget(ls()[str_detect(ls(), "cpi\\d{4}")])) %>%
        select(1:2, starts_with("2")) %>%
        rename(Geolocation = Geolocation...1,
               `Commodity Description` = `Commodity Description...2`) %>%
        write_csv("Data/CPI and Inflation/Openstat-cpi2012.csv") %>%
        suppressMessages() %>% suppressWarnings()
    
    rm(list = ls())
}



# Openstat CPI for Bottom 30% Income Households ---------------------------

## Download Commodity Weights for BIH CPI
if (!file.exists("Data/CPI and Inflation/Openstat-cpiBIHWeights.csv")) {
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/BIH/0022M4AB303.px",
         body = '{"query": [], "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8") %>%
        write_csv("Data/CPI and Inflation/Openstat-cpiBIHWeights.csv") %>%
        suppressMessages() %>% suppressWarnings()
}

## Download BIH CPI from 2000 to 2011
if (!file.exists("Data/CPI and Inflation/Openstat-cpiBIH2000to2011.csv")) {
    writeLines(paste0("Downloading Bottom 30% CPI data for 2000 to 2011"))
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/BIH/0022M4AB304.px",
         body = '{"query": [], "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8") %>%
        write_csv("Data/CPI and Inflation/Openstat-cpiBIH2000to2011.csv") %>%
        suppressMessages() %>% suppressWarnings()
}

## Download BIH CPI from 2012 to latest
{# Latest Data
    codes <- tribble(~y, "y")
    for (y in 2012:year(Sys.Date()) - 2012) {
        codes[y + 1] <-
            str_c('{"query": [{"code": "Year", "selection": {"filter": "item", "values": ["',
                  y, '"]}}], "response": {"format": "csv"}}')
    }
    
    for (y in 2012:year(Sys.Date()) - 2012) {
        writeLines(paste0("Downloading Bottom 30% CPI data for ", y + 2012))
        assign(paste0("cpiBIH", y + 2012),
               POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/BIH/0022M4AB301.px",
                    body = codes[[y + 1]]) %>%
                   content(encoding = "UTF-8")) %>%
            suppressMessages() %>% suppressWarnings()
        Sys.sleep(0.5)
    }
    
    do.call(bind_cols, mget(ls()[str_detect(ls(), "cpiBIH\\d{4}")])) %>%
        select(1:2, starts_with("2")) %>%
        rename(Geolocation = Geolocation...1,
               `Commodity Description` = `Commodity Description...2`) %>%
        write_csv("Data/CPI and Inflation/Openstat-cpiBIH2012.csv") %>%
        suppressMessages() %>% suppressWarnings()
    
    rm(list = ls())
}
