library(tidyverse)
library(httr)
library(rvest)
library(writexl)
library(lubridate)


if (!dir.exists("Data")) {dir.create("Data")}
if (!dir.exists("Data/CPI and Inflation")) {dir.create("Data/CPI and Inflation")}
if (!dir.exists("Data/CPI and Inflation/Base 2012")) {dir.create("Data/CPI and Inflation/Base 2012")}
if (!dir.exists("Data/CPI and Inflation/Base 2018")) {dir.create("Data/CPI and Inflation/Base 2018")}


# Set ssl_verifypper=0 since OpenStat's SSL Certificate is problematic
set_config(config(ssl_verifypeer=0))

# BSP Consumer Price Index ------------------------------------------------
writeLines("Downloading CPI Data from the BSP website.")

download.file(url = "https://www.bsp.gov.ph/Statistics/Prices/prices2018.xls",
              destfile = "Data/CPI and Inflation/Base 2018/BSP-prices2018.xls", method = "curl")



# PSA Website Consumer Price Index ----------------------------------------
writeLines("Downloading CPI Data from the PSA Website.")

## Scrape a list of links from the latest (Base 2018) CPI release from the PSA site

# Old PSA website
#cpi_links <- read_html("https://psa.gov.ph/price-indices/cpi-ir/downloads") %>%
#    html_nodes("table") %>% html_nodes("td") %>% html_nodes("span") %>% html_nodes("a") %>%
#    html_attr("href")

# New PSA website
cpi_links <- read_html("https://psa.gov.ph/price-indices/cpi-ir/stat-tables") %>%
    html_nodes("table") %>% html_nodes("td") %>% html_nodes("span") %>% html_nodes("a") %>%
    html_attr("href")


# Download CPI xlsx files from the scraped links
download.file(url = cpi_links %>% str_subset("Statistical") %>% .[1] %>% str_c("https://psa.gov.ph", .),
              destfile = "Data/CPI and Inflation/Base 2018/PSA-CPI-Tables.xlsx", method = "curl")

#download.file(url = cpi_links %>% str_subset("CORE") %>% .[1],
#              destfile = "Data/CPI and Inflation/Base 2018/PSA-CoreCPI.xlsx", method = "curl")

rm(list = ls())



# Openstat Consumer Price Index -------------------------------------------
writeLines("Downloading CPI Data from Openstat.")

## Download Base 2018 Commodity Weights
if (!file.exists("Data/CPI and Inflation/Base 2018/Openstat-cpiBase2018Weights.csv")) {
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/CPI/2018/0012M4ACP12.px",
         body = '{"query": [], "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8") %>%
        write_csv("Data/CPI and Inflation/Base 2018/Openstat-cpiBase2018Weights.csv") %>%
        suppressMessages() %>% suppressWarnings()
}

## Download CPI data from 1957 to 1993 (Base 2018)
if (!file.exists("Data/CPI and Inflation/Base 2018/Openstat-cpi1957to1993.csv")) {
    writeLines(paste0("Downloading CPI data for 1957 to 1993"))
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/CPI/2018/0012M4ACP13.px",
         body = '{"query": [], "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8") %>%
        write_csv("Data/CPI and Inflation/Base 2018/Openstat-cpi1957to1993.csv") %>%
        suppressMessages() %>% suppressWarnings()
}

## Download CPI data from 1994 to 2017 (Base 2018)
if (!file.exists("Data/CPI and Inflation/Base 2018/Openstat-cpi1994to2005.csv")) {
    codes <- str_c('{"query": [{"code": "Year", "selection": {"filter": "item", "values": ["',
                   rep(0:(2017-1994), each = 13),
                   '"]}}, {"code": "Period", "selection": {"filter": "item", "values": ["',
                   rep(0:12, times = length(0:(2017-1994))),
                   '"]}}], "response": {"format": "csv"}}')
    
    cpi1994 <- POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/CPI/2018/0012M4ACP15.px",
                    body = codes[1]) %>%
        content(encoding = "UTF-8") %>%
        select(1:2) %>%
        rename(`Commodity Description` = `Commodity Description`) %>%
        suppressMessages() %>% suppressWarnings()
    
    writeLines(paste0("Downloading CPI data for 1994 to 2017"))
    for (code in codes) {
        #print(str_extract_all(code, "\\d+"))
        
        cpi1994 <- bind_cols(
            cpi1994,
            POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/CPI/2018/0012M4ACP15.px",
                 body = code) %>%
                content(encoding = "UTF-8") %>%
                select(-(1:2)) %>%
                suppressMessages() %>% suppressWarnings()
        )
        Sys.sleep(1)
    }
    
    cpi1994 %>%
        select(1:2, `1994 Jan`:`2005 Ave`) %>%
        write_csv("Data/CPI and Inflation/Base 2018/Openstat-cpi1994to2005.csv") %>%
        suppressMessages() %>% suppressWarnings()
    
    cpi1994 %>%
        select(1:2, `2006 Jan`:`2017 Ave`) %>%
        write_csv("Data/CPI and Inflation/Base 2018/Openstat-cpi2006to2017.csv") %>%
        suppressMessages() %>% suppressWarnings()
    
    #cpi1994 %>%
    #    write_csv("Data/CPI and Inflation/Base 2018/Openstat-cpi1994to2017.csv") %>%
    #    suppressMessages() %>% suppressWarnings()
    
    rm(list = ls())
}

## Download CPI data from 2018 Jan to latest month
{## Latest Data
    codes <- str_c('{"query": [{"code": "Year", "selection": {"filter": "item", "values": ["',
                   rep(0:(year(Sys.Date()-months(1)) - 2018), each = 13),
                   '"]}}, {"code": "Period", "selection": {"filter": "item", "values": ["',
                   rep(0:12, times = length(0:(year(Sys.Date()-months(1)) - 2018))),
                   '"]}}], "response": {"format": "csv"}}')
    
    
    cpi2018 <- POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/CPI/2018/0012M4ACP09.px",
                    body = codes[1]) %>%
        content(encoding = "UTF-8") %>%
        select(1:2) %>%
        rename(`Commodity Description` = `Commodity Description`) %>%
        suppressMessages() %>% suppressWarnings()
    
    writeLines(paste0("Downloading CPI data for 2018 to present"))
    for (code in codes) {
        cpi2018 <- bind_cols(
            cpi2018,
            POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/CPI/2018/0012M4ACP09.px",
                 body = code) %>%
                content(encoding = "UTF-8") %>%
                select(-(1:2)) %>%
                suppressMessages() %>% suppressWarnings()
        )
        Sys.sleep(1)
    }
    
    cpi2018 %>%
        write_csv("Data/CPI and Inflation/Base 2018/Openstat-cpi2018.csv") %>%
        suppressMessages() %>% suppressWarnings()
    
    rm(list = ls())
}



# Download Core CPI data from 2018 Jan to latest month
{## Latest Data
    codes <- str_c('{"query": [{"code": "Year", "selection": {"filter": "item", "values": ["',
                   rep(0:(year(Sys.Date()-months(1)) - 2018), each = 13),
                   '"]}}, {"code": "Period", "selection": {"filter": "item", "values": ["',
                   rep(0:12, times = length(0:(year(Sys.Date()-months(1)) - 2018))),
                   '"]}}], "response": {"format": "csv"}}')
    
    
    corecpi2018 <- POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/CPI/2018/0012M4ACP17.px",
                        body = codes[1]) %>%
        content(encoding = "UTF-8") %>%
        select(1:2) %>%
        rename(`Commodity Description` = `Commodity Description`) %>%
        suppressMessages() %>% suppressWarnings()
    
    writeLines(paste0("Downloading Core CPI data for 2018 to present"))
    for (code in codes) {
        corecpi2018 <- bind_cols(
            corecpi2018,
            POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/CPI/2018/0012M4ACP17.px",
                 body = code) %>%
                content(encoding = "UTF-8") %>%
                select(-(1:2)) %>%
                suppressMessages() %>% suppressWarnings()
        )
        Sys.sleep(1)
    }
    
    corecpi2018 %>%
        write_csv("Data/CPI and Inflation/Base 2018/Openstat-corecpi2018.csv") %>%
        suppressMessages() %>% suppressWarnings()
    
    rm(list = ls())
}



# Openstat CPI for Bottom 30% Income Households ---------------------------

## Base 2012
## Download Commodity Weights for Base 2012 BIH CPI
if (!file.exists("Data/CPI and Inflation/Base 2012/Openstat-cpiBIHWeights.csv")) {
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/BIH/0022M4AB303.px",
         body = '{"query": [], "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8") %>%
        write_csv("Data/CPI and Inflation/Base 2012/Openstat-cpiBIHWeights.csv") %>%
        suppressMessages() %>% suppressWarnings()
}

## Download Base 2012 BIH CPI from 2000 to 2011
if (!file.exists("Data/CPI and Inflation/Base 2012/Openstat-cpiBIH2000to2011.csv")) {
    writeLines(paste0("Downloading Bottom 30% CPI data for 2000 to 2011"))
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/BIH/2012/0022M4AB304.px",
         body = '{"query": [], "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8") %>%
        write_csv("Data/CPI and Inflation/Base 2012/Openstat-cpiBIH2000to2011.csv") %>%
        suppressMessages() %>% suppressWarnings()
}

## Download Base 2012 BIH CPI from 2012 to latest
{# Latest Data
    codes <- str_c('{"query": [{"code": "Year", "selection": {"filter": "item", "values": ["',
                   rep(0:(year(Sys.Date()-months(1)) - 2012)),
                   '"]}}], "response": {"format": "csv"}}')
    
    cpibih2012 <- POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/BIH/2012/0022M4AB301.px",
                       body = codes[1]) %>%
        content(encoding = "UTF-8") %>%
        select(1:2) %>%
        suppressMessages() %>% suppressWarnings()
    
    writeLines(paste0("Downloading Bottom 30% CPI data for 2012 to present"))
    for (code in codes) {
        cpibih2012 <- bind_cols(
            cpibih2012,
            POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/BIH/0022M4AB301.px",
                 body = code) %>%
                content(encoding = "UTF-8") %>%
                select(-(1:2)) %>%
                suppressMessages() %>% suppressWarnings()
        )
        Sys.sleep(0.5)
    }
    
    cpibih2012 %>%
        write_csv("Data/CPI and Inflation/Base 2012/Openstat-cpiBIH2012.csv") %>%
        suppressMessages() %>% suppressWarnings()
    
    rm(list = ls())
}


## Base 2018
## Download Commodity Weights for Base 2018 BIH CPI
if (!file.exists("Data/CPI and Inflation/Base 2018/Openstat-cpiBIHWeights.csv")) {
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/BIH/2018/0022M4ABOT3.px",
         body = '{"query": [], "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8") %>%
        write_csv("Data/CPI and Inflation/Base 2018/Openstat-cpiBIHWeights.csv") %>%
        suppressMessages() %>% suppressWarnings()
}

## Download Base 2018 BIH CPI from 2000 to 2011
if (!file.exists("Data/CPI and Inflation/Base 2018/Openstat-cpiBIH2000to2011.csv")) {
    writeLines(paste0("Downloading Bottom 30% CPI data for 2000 to 2011"))
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/BIH/2018/0022M4ABOT5.px",
         body = '{"query": [], "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8") %>%
        write_csv("Data/CPI and Inflation/Base 2018/Openstat-cpiBIH2000to2011.csv") %>%
        suppressMessages() %>% suppressWarnings()
}

## Download Base 2018 BIH CPI from 2012 to 2017
if (!file.exists("Data/CPI and Inflation/Base 2018/Openstat-cpiBIH2012to2017.csv")) {
    codes <- str_c('{"query": [{"code": "Year", "selection": {"filter": "item", "values": ["',
                   rep(0:(2017-2012), each = 1),
                   #'"]}}, {"code": "Period", "selection": {"filter": "item", "values": ["',
                   #rep(0:12, times = length(0:(2017-2012))),
                   '"]}}], "response": {"format": "csv"}}')
    
    cpibih2012 <- POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/BIH/2018/0022M4ABOT4.px",
                       body = codes[1]) %>%
        content(encoding = "UTF-8") %>%
        select(1:2) %>%
        rename(`Commodity Description` = `Commodity Description`) %>%
        suppressMessages() %>% suppressWarnings()
    
    writeLines(paste0("Downloading Bottom 30% CPI data for 2012 to 2017"))
    for (code in codes) {
        #print(str_extract_all(code, "\\d+"))
        
        cpibih2012 <- bind_cols(
            cpibih2012,
            POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/BIH/2018/0022M4ABOT4.px",
                 body = code) %>%
                content(encoding = "UTF-8") %>%
                select(-(1:2)) %>%
                suppressMessages() %>% suppressWarnings()
        )
        Sys.sleep(1)
    }
    
    cpibih2012 %>%
        write_csv("Data/CPI and Inflation/Base 2018/Openstat-cpiBIH2012to2017.csv") %>%
        suppressMessages() %>% suppressWarnings()
    
    rm(list = ls())
}

## Download Base 2018 BIH CPI from 2018 to latest
{# Latest Data
    codes <- str_c('{"query": [{"code": "Year", "selection": {"filter": "item", "values": ["',
                   rep(0:(year(Sys.Date()-months(1)) - 2018), each = 13),
                   '"]}}, {"code": "Period", "selection": {"filter": "item", "values": ["',
                   rep(0:12, times = length(0:(year(Sys.Date()-months(1)) - 2018))),
                   '"]}}], "response": {"format": "csv"}}')
    
    cpibih2018 <- POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/BIH/2018/0022M4ABOT1.px",
                       body = codes[1]) %>%
        content(encoding = "UTF-8") %>%
        select(1:2) %>%
        suppressMessages() %>% suppressWarnings()
    
    writeLines(paste0("Downloading Bottom 30% CPI data for 2018 to present"))
    for (code in codes) {
        cpibih2018 <- bind_cols(
            cpibih2018,
            POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/PI/BIH/2018/0022M4ABOT1.px",
                 body = code) %>%
                content(encoding = "UTF-8") %>%
                select(-(1:2)) %>%
                suppressMessages() %>% suppressWarnings()
        )
        Sys.sleep(0.5)
    }
    
    cpibih2018 %>%
        write_csv("Data/CPI and Inflation/Base 2018/Openstat-cpiBIH2018.csv") %>%
        suppressMessages() %>% suppressWarnings()
    
    rm(list = ls())
}
