library(tidyverse)
library(httr)
library(rvest)
library(writexl)
library(lubridate)

if (!dir.exists("Data")) {dir.create("Data")}
if (!dir.exists("Data/National Accounts")) {dir.create("Data/National Accounts")}


# BSP National Accounts ---------------------------------------------------
writeLines("Downloading National Accounts Data from the BSP website.")

# Current Prices, By Expenditure and By Industry
download.file(url = "https://www.bsp.gov.ph/Statistics/Real%20Sector%20Accounts/gnicurrent_exp.xls",
              destfile = "Data/National Accounts/BSP-gnicurrent_exp.xls", method = "curl")

download.file(url = "https://www.bsp.gov.ph/Statistics/Real%20Sector%20Accounts/gnicurrent_ind.xls",
              destfile = "Data/National Accounts/BSP-gnicurrent_ind.xls", method = "curl")

# Constant Prices, By Expenditure and By Industry
download.file(url = "https://www.bsp.gov.ph/Statistics/Real%20Sector%20Accounts/gnicon2018_exp.xls",
              destfile = "Data/National Accounts/BSP-gnicon2018_exp.xls", method = "curl")

download.file(url = "https://www.bsp.gov.ph/Statistics/Real%20Sector%20Accounts/gnicon2018_ind.xls",
              destfile = "Data/National Accounts/BSP-gnicon2018_ind.xls", method = "curl")



# PSA Website National Accounts -------------------------------------------
writeLines("Downloading National Accounts Data from the PSA website.")

# Scrape a list of links from the latest SNA release from the PSA site
psafiles <- read_html("https://psa.gov.ph/national-accounts/base-2018/data-series") %>% 
    html_nodes(xpath = '//*[@id="content"]/div/div[1]/div/section/div/div/div/div/table/tbody/tr/td[2]/table/tr/td[1]/div/div/ul/li/span/a') %>% 
    html_attr("href")

# Download the latest Quarterly and Annual SNA data
download.file(url = psafiles[1], method = "curl",
              destfile = "Data/National Accounts/PSA-01Summary_2018PSNA_Qrt.xlsx")
download.file(url = psafiles[2], method = "curl",
              destfile = "Data/National Accounts/PSA-01Summary_2018PSNA_Ann.xlsx")

# Download the Quarterly and Annual Long Time Series SNA data
download.file(url = psafiles[43], method = "curl",
              destfile = "Data/National Accounts/PSA-Quarter-Q1-1981-to-latest.xlsx")
download.file(url = psafiles[44], method = "curl",
              destfile = "Data/National Accounts/PSA-Annual-1946-to-latest.xlsx")

rm(psafiles)



# Openstat National Accounts ----------------------------------------------
writeLines("Downloading National Accounts Data from the Openstat API.")

# Download Annual Data; By Expenditure, By Industry, Per Capita
POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/NA/AN/1SUM/0012B5CEXA1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Openstat-SNA-Annual-Exp.csv") %>%
    suppressMessages() %>% suppressWarnings()

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/NA/AN/1SUM/0052B5CPRA1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Openstat-SNA-Annual-Ind.csv") %>%
    suppressMessages() %>% suppressWarnings()

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/NA/AN/1SUM/0122B5CPCA1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Openstat-SNA-Annual-PC.csv") %>%
    suppressMessages() %>% suppressWarnings()

# Download Quarterly Data; By Expenditure, By Industry, Per Capita
POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/NA/QT/1SUM/0012B5CEXQ1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Openstat-SNA-Quarterly-Exp.csv") %>%
    suppressMessages() %>% suppressWarnings()

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/NA/QT/1SUM/0052B5CPRQ1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Openstat-SNA-Quarterly-Ind.csv") %>%
    suppressMessages() %>% suppressWarnings()

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/NA/QT/1SUM/0122B5CPCQ1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Openstat-SNA-Quarterly-PC.csv") %>%
    suppressMessages() %>% suppressWarnings()
