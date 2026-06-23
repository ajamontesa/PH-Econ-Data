library(tidyverse)
library(httr)
library(rvest)
library(writexl)
library(lubridate)

if (!dir.exists("Data")) {dir.create("Data")}
if (!dir.exists("Data/Agriculture and Food")) {dir.create("Data/Agriculture and Food")}



# PSA Website National Accounts -------------------------------------------
writeLines("Downloading Agriculture Data from the PSA website.")

## Scrape a list of links from the latest SNA release from the PSA site
psafiles <- read_html("https://psa.gov.ph/national-accounts/base-2018/data-series") %>% 
    html_nodes(xpath = '//*[@id="content"]/div/div[1]/div/section/div/div/div/div/table/tbody/tr/td[2]/table/tr/td[1]/div/div/ul/li/span/a') %>% 
    html_attr("href")

## Download the latest Quarterly and Annual Gross Value Added in Agriculture data
download.file(url = psafiles[15], method = "curl",
              destfile = "Data/Agriculture and Food/PSA-08AFF_2018PSNA_Qrt.xlsx")
download.file(url = psafiles[16], method = "curl",
              destfile = "Data/Agriculture and Food/PSA-08AFF_2018PSNA_Ann.xlsx")

rm(psafiles)



# Openstat Agricultural Accounts ------------------------------------------
writeLines("Downloading Agricultural Accounts Data from the Openstat API.")

# Download Annual Value of Production Data
POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/AA/VP/0012B5FVOP1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/Agriculture and Food/Openstat-Value-of-Production-Agri.csv") %>%
    suppressMessages() %>% suppressWarnings()

# Download Supply Utilization Accounts
sua_items <- c("Cereals", "Rootcrops", "Vegetables", "Nuts", "Fruits",
               "Commercial-Crops", "NonFood", "Livestock", "Poultry", "Fishery")

for (i in 0:9) {
    POST(url = as.character(str_c("https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/AA/SU/0012B5FSUA", i, ".px")),
         body = '{"query": [], "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8") %>%
        write_csv(as.character(str_c("Data/Agriculture and Food/Openstat-SU-Accounts-", sua_items[i+1], ".csv"))) %>%
        suppressMessages() %>% suppressWarnings()
    Sys.sleep(0.5)
}

rm(sua_items, i)

# Download Import Dependency and Self-Sufficiency Ratios
POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/AA/SU/0012E5FIDR0.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/Agriculture and Food/Openstat-Import-Dependency-Agri.csv") %>%
    suppressMessages() %>% suppressWarnings()

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/AA/SU/0012E5FSSR0.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/Agriculture and Food/Openstat-Self-Sufficiency-Agri.csv") %>%
    suppressMessages() %>% suppressWarnings()

# Download Costs and Returns Data
## Crops Production Costs and Returns
costreturns_items <- c("Cereals", "Rootcrops", "Legumes", "Vegetables", "Fruits", "Commercial-Crops", "Nuts")

for (i in 1:6) {
    POST(url = as.character(str_c("https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/AA/CR/0012B5FCOP", i, ".px")),
         body = '{"query": [], "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8") %>%
        write_csv(as.character(str_c("Data/Agriculture and Food/Openstat-Production-Cost-Returns-", costreturns_items[i+1], ".csv"))) %>%
        suppressMessages() %>% suppressWarnings()
    Sys.sleep(0.5)
}

## Palay Production Costs and Returns
left_join(
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/AA/CR/0012B5FCOP0.px",
         body = '{"query": [{"code": "Type", "selection": {"filter": "item", "values": ["0", "1", "2"]}},
                 {"code": "Season", "selection": {"filter": "item", "values": ["0"]}}],
                 "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8"),
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/AA/CR/0012B5FCOP0.px",
         body = '{"query": [{"code": "Type", "selection": {"filter": "item", "values": ["0", "1", "2"]}},
                 {"code": "Season", "selection": {"filter": "item", "values": ["1"]}}],
                 "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8")
) %>% left_join(
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/AA/CR/0012B5FCOP0.px",
         body = '{"query": [{"code": "Type", "selection": {"filter": "item", "values": ["0", "1", "2"]}},
                 {"code": "Season", "selection": {"filter": "item", "values": ["2"]}}],
                 "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8")
) %>% write_csv("Data/Agriculture and Food/Openstat-Production-Cost-Returns-Palay.csv") %>%
    suppressMessages() %>% suppressWarnings()

## Corn Production Costs and Returns
left_join(
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/AA/CR/0012B5FCOP0.px",
         body = '{"query": [{"code": "Type", "selection": {"filter": "item", "values": ["3", "4", "5"]}},
                 {"code": "Season", "selection": {"filter": "item", "values": ["0"]}}],
                 "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8"),
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/AA/CR/0012B5FCOP0.px",
         body = '{"query": [{"code": "Type", "selection": {"filter": "item", "values": ["3", "4", "5"]}},
                 {"code": "Season", "selection": {"filter": "item", "values": ["1"]}}],
                 "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8")
) %>% left_join(
    POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/AA/CR/0012B5FCOP0.px",
         body = '{"query": [{"code": "Type", "selection": {"filter": "item", "values": ["3", "4", "5"]}},
                 {"code": "Season", "selection": {"filter": "item", "values": ["2"]}}],
                 "response": {"format": "csv"}}') %>%
        content(encoding = "UTF-8")
) %>% write_csv("Data/Agriculture and Food/Openstat-Production-Cost-Returns-Corn.csv") %>%
    suppressMessages() %>% suppressWarnings()

rm(costreturns_items, i)



# Openstat Volume of Production -------------------------------------------
writeLines("Downloading Volume of Production Data from the Openstat API.")

## Palay and Corn Volume of Production
POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2E/CS/0012E4EVCP0.px",
     body = '{"query": [{"code": "Ecosystem/Croptype", "selection": {"filter": "item", "values": ["0", "1", "2"]}}],
             "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/Agriculture and Food/Openstat-Volume-of-Production-Palay.csv") %>%
    suppressMessages() %>% suppressWarnings()

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2E/CS/0012E4EVCP0.px",
     body = '{"query": [{"code": "Ecosystem/Croptype", "selection": {"filter": "item", "values": ["3", "4", "5"]}}],
             "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/Agriculture and Food/Openstat-Volume-of-Production-Corn.csv") %>%
    suppressMessages() %>% suppressWarnings()

## Other Crops Volume of Production
OtherCropsVolume <- tibble()
for (i in 0:99) {
    OtherCropsVolume <- bind_rows(
        OtherCropsVolume,
        POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2E/CS/0062E4EVCP1.px",
             body = as.character(str_c('{"query": [{"code": "Geolocation", "selection": {"filter": "item", "values": ["',
                                       i, '"]}}], "response": {"format": "csv"}}'))) %>%
            content(encoding = "UTF-8") %>%
            suppressMessages() %>% suppressWarnings()
    )
    Sys.sleep(0.5)
}
OtherCropsVolume %>% write_csv("Data/Agriculture and Food/Openstat-Volume-of-Production-Other-Crops.csv")

## Livestock Volume of Production
POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2E/LP/0012E4FPLS0.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/Agriculture and Food/Openstat-Volume-of-Production-Livestock.csv") %>%
    suppressMessages() %>% suppressWarnings()

## Poultry Volume of Production
POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2E/LP/0022E4FPPE0.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/Agriculture and Food/Openstat-Volume-of-Production-Poultry.csv") %>%
    suppressMessages() %>% suppressWarnings()

## Fisheries Volume of Production
FisheriesVolume <- tibble()
for (i in str_c(str_pad(string = 0:65, width = 2, side = "left", pad = "0"))) {
    FisheriesVolume <- bind_rows(
        FisheriesVolume,
        POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2E/FS/0112E4GVFP0.px",
             body = as.character(str_c('{"query": [{"code": "Species", "selection": {"filter": "item", "values": ["',
                                       i, '"]}}], "response": {"format": "csv"}}'))) %>%
            content(encoding = "UTF-8") %>%
            mutate(across(.cols = everything(), .fns = as.character)) %>%
            suppressMessages() %>% suppressWarnings()
    )
    Sys.sleep(1)
}
FisheriesVolume %>% write_csv("Data/Agriculture and Food/Openstat-Volume-of-Production-Fisheries.csv")

rm(list = ls())



# Openstat Farmgate Prices ------------------------------------------------
writeLines("Downloading Farmgate Price Data from the Openstat API.")

## Palay Farmgate Prices
POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/NFG/0032M4AFN01.px",
     body = '{"query": [{"code": "Commodity", "selection": {"filter": "item", "values": ["0", "1"]}}],
             "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/Agriculture and Food/Openstat-Farmgate-Prices-Palay.csv") %>%
    suppressMessages() %>% suppressWarnings()

## Corn Farmgate Prices
POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/NFG/0032M4AFN01.px",
     body = '{"query": [{"code": "Commodity", "selection": {"filter": "item", "values": ["2", "3", "4", "5"]}}],
             "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/Agriculture and Food/Openstat-Farmgate-Prices-Corn.csv") %>%
    suppressMessages() %>% suppressWarnings()

## Rootcrops Farmgate Prices
FarmgateRootcrops <- tibble()
for (i in 0:13) {
    FarmgateRootcrops <- bind_rows(
        FarmgateRootcrops,
        POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/NFG/0032M4AFN02.px",
             body = as.character(str_c('{"query": [{"code": "Commodity", "selection": {"filter": "item", "values": ["',
                                       i, '"]}}], "response": {"format": "csv"}}'))) %>%
            content(encoding = "UTF-8") %>%
        suppressMessages() %>% suppressWarnings()
    )
    Sys.sleep(0.5)
}
FarmgateRootcrops %>% write_csv("Data/Agriculture and Food/Openstat-Farmgate-Prices-Rootcrops.csv")

## Beans and Legumes Farmgate Prices
FarmgateBeansLegumes <- tibble()
for (i in 0:17) {
    FarmgateBeansLegumes <- bind_rows(
        FarmgateBeansLegumes,
        POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/NFG/0032M4AFN03.px",
             body = as.character(str_c('{"query": [{"code": "Commodity", "selection": {"filter": "item", "values": ["',
                                       i, '"]}}], "response": {"format": "csv"}}'))) %>%
            content(encoding = "UTF-8") %>%
            suppressMessages() %>% suppressWarnings()
    )
    Sys.sleep(0.5)
}
FarmgateBeansLegumes %>% write_csv("Data/Agriculture and Food/Openstat-Farmgate-Prices-Beans-Legumes.csv")

## Condiments Farmgate Prices
FarmgateCondiments <- tibble()
for (i in 0:11) {
    FarmgateCondiments <- bind_rows(
        FarmgateCondiments,
        POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/NFG/0032M4AFN04.px",
             body = as.character(str_c('{"query": [{"code": "Commodity", "selection": {"filter": "item", "values": ["',
                                       i, '"]}}], "response": {"format": "csv"}}'))) %>%
            content(encoding = "UTF-8") %>%
            suppressMessages() %>% suppressWarnings()
    )
    Sys.sleep(0.5)
}
FarmgateCondiments %>% write_csv("Data/Agriculture and Food/Openstat-Farmgate-Prices-Condiments.csv")

## Fruit Vegetables Farmgate Prices
FarmgateVegetablesFruit <- tibble()
for (i in 0:14) {
    FarmgateVegetablesFruit <- bind_rows(
        FarmgateVegetablesFruit,
        POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/NFG/0032M4AFN05.px",
             body = as.character(str_c('{"query": [{"code": "Commodity", "selection": {"filter": "item", "values": ["',
                                       i, '"]}}], "response": {"format": "csv"}}'))) %>%
            content(encoding = "UTF-8") %>%
            suppressMessages() %>% suppressWarnings()
    )
    Sys.sleep(0.5)
}
FarmgateVegetablesFruit %>% write_csv("Data/Agriculture and Food/Openstat-Farmgate-Prices-Vegetables-Fruit.csv")

## Leafy Vegetables Farmgate Prices
FarmgateVegetablesLeafy <- tibble()
for (i in 0:19) {
    FarmgateVegetablesLeafy <- bind_rows(
        FarmgateVegetablesLeafy,
        POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/NFG/0032M4AFN06.px",
             body = as.character(str_c('{"query": [{"code": "Commodity", "selection": {"filter": "item", "values": ["',
                                       i, '"]}}], "response": {"format": "csv"}}'))) %>%
            content(encoding = "UTF-8") %>%
            suppressMessages() %>% suppressWarnings()
    )
    Sys.sleep(0.5)
}
FarmgateVegetablesLeafy %>% write_csv("Data/Agriculture and Food/Openstat-Farmgate-Prices-Vegetables-Leafy.csv")

## Fruits Farmgate Prices
FarmgateFruits <- tibble()
for (i in 0:46) {
    FarmgateFruits <- bind_rows(
        FarmgateFruits,
        POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/NFG/0032M4AFN07.px",
             body = as.character(str_c('{"query": [{"code": "Commodity", "selection": {"filter": "item", "values": ["',
                                       i, '"]}}], "response": {"format": "csv"}}'))) %>%
            content(encoding = "UTF-8") %>%
            suppressMessages() %>% suppressWarnings()
    )
    Sys.sleep(0.5)
}
FarmgateFruits %>% write_csv("Data/Agriculture and Food/Openstat-Farmgate-Prices-Fruits.csv")

## Commercial Crops Farmgate Prices
FarmgateCommercialCrops <- tibble()
for (i in 0:43) {
    FarmgateCommercialCrops <- bind_rows(
        FarmgateCommercialCrops,
        POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/NFG/0032M4AFN08.px",
             body = as.character(str_c('{"query": [{"code": "Commodity", "selection": {"filter": "item", "values": ["',
                                       i, '"]}}], "response": {"format": "csv"}}'))) %>%
            content(encoding = "UTF-8") %>%
            suppressMessages() %>% suppressWarnings()
    )
    Sys.sleep(0.5)
}
FarmgateCommercialCrops %>% write_csv("Data/Agriculture and Food/Openstat-Farmgate-Prices-Commercial-Crops.csv")

## Cutflowers Farmgate Prices
FarmgateCutflowers <- tibble()
for (i in 0:10) {
    FarmgateCutflowers <- bind_rows(
        FarmgateCutflowers,
        POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/NFG/0032M4AFN09.px",
             body = as.character(str_c('{"query": [{"code": "Commodity", "selection": {"filter": "item", "values": ["',
                                       i, '"]}}], "response": {"format": "csv"}}'))) %>%
            content(encoding = "UTF-8") %>%
            suppressMessages() %>% suppressWarnings()
    )
    Sys.sleep(0.5)
}
FarmgateCutflowers %>% write_csv("Data/Agriculture and Food/Openstat-Farmgate-Prices-Cutflowers.csv")

## Livestock and Poultry Backyard Farmgate Prices
FarmgateLivestockPoultryBackyard <- tibble()
for (i in 0:19) {
    FarmgateLivestockPoultryBackyard <- bind_rows(
        FarmgateLivestockPoultryBackyard,
        POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/NFG/0032M4AFN10.px",
             body = as.character(str_c('{"query": [{"code": "Commodity", "selection": {"filter": "item", "values": ["',
                                       i, '"]}}], "response": {"format": "csv"}}'))) %>%
            content(encoding = "UTF-8") %>%
            suppressMessages() %>% suppressWarnings()
    )
    Sys.sleep(0.5)
}
FarmgateLivestockPoultryBackyard %>% write_csv("Data/Agriculture and Food/Openstat-Farmgate-Prices-Livestock-Poultry-Backyard.csv")

## Livestock and Poultry Backyard Farmgate Prices
FarmgateLivestockPoultryCommercial <- tibble()
for (i in 0:10) {
    FarmgateLivestockPoultryCommercial <- bind_rows(
        FarmgateLivestockPoultryCommercial,
        POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/NFG/0032M4AFN11.px",
             body = as.character(str_c('{"query": [{"code": "Commodity", "selection": {"filter": "item", "values": ["',
                                       i, '"]}}], "response": {"format": "csv"}}'))) %>%
            content(encoding = "UTF-8") %>%
            suppressMessages() %>% suppressWarnings()
    )
    Sys.sleep(0.5)
}
FarmgateLivestockPoultryCommercial %>% write_csv("Data/Agriculture and Food/Openstat-Farmgate-Prices-Livestock-Poultry-Commercial.csv")

rm(list = ls())
