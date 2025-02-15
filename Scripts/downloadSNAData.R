library(tidyverse)
library(httr)
library(rvest)
library(writexl)
library(lubridate)

if (!dir.exists("Data")) {dir.create("Data")}
if (!dir.exists("Data/National Accounts")) {dir.create("Data/National Accounts")}


# Set ssl_verifypper=0 since OpenStat's SSL Certificate is problematic
set_config(config(ssl_verifypeer=0))

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

# Old PSA Website : https://psa.gov.ph/national-accounts/base-2018/data-series
#psafiles <- read_html("https://psa.gov.ph/national-accounts/base-2018/data-series") %>% 
#    html_nodes(xpath = '//*[@id="content"]/div/div[1]/div/section/div/div/div/div/table/tbody/tr/td[2]/table/tr/td[1]/div/div/ul/li/span/a') %>% 
#    html_attr("href")

# Download the latest Quarterly and Annual SNA data
#download.file(url = psafiles[1], method = "curl",
#              destfile = "Data/National Accounts/PSA-01Summary_2018PSNA_Qrt.xlsx")
#download.file(url = psafiles[2], method = "curl",
#              destfile = "Data/National Accounts/PSA-01Summary_2018PSNA_Ann.xlsx")

# Download the Quarterly and Annual Long Time Series SNA data
#download.file(url = psafiles[43], method = "curl",
#              destfile = "Data/National Accounts/PSA-Quarter-Q1-1981-to-latest.xlsx")
#download.file(url = psafiles[44], method = "curl",
#              destfile = "Data/National Accounts/PSA-Annual-1946-to-latest.xlsx")
# Download Other SNA files
#for (f in psafiles[c(3:42)]) {
#    download.file(url = f, method = "curl",
#                  destfile = str_c("Data/National Accounts/PSA-",
#                                   str_extract(str_remove(f, "^h.+/"), "\\d.+(Qrt|Ann)"),
#                                   ".xlsx"))
#}

# New PSA Website
psafiles <- read_html("https://psa.gov.ph/statistics/national-accounts/data-series") %>% 
    html_nodes(xpath = '//*[@id="content"]/div/div/div/div[1]/div/div/div/div/div/div/div/table/tbody/tr/td[2]/span/a') %>% 
    html_attr("href")

psafiles <- str_c("https://psa.gov.ph", psafiles)

# Download the latest Quarterly and Annual SNA data
download.file(url = psafiles[str_detect(psafiles, "Summary(.*)Qrt")], method = "curl",
              destfile = "Data/National Accounts/PSA-01Summary_2018PSNA_Qrt.xlsx")
download.file(url = psafiles[str_detect(psafiles, "Summary(.*)Ann")], method = "curl",
              destfile = "Data/National Accounts/PSA-01Summary_2018PSNA_Ann.xlsx")

# Download the Quarterly and Annual Long Time Series SNA data
download.file(url = psafiles[str_detect(psafiles, "1981")], method = "curl",
              destfile = "Data/National Accounts/PSA-Quarter-Q1-1981-to-latest.xlsx")
download.file(url = psafiles[str_detect(psafiles, "1946")], method = "curl",
              destfile = "Data/National Accounts/PSA-Annual-1946-to-latest.xlsx")

# Download Other SNA files
for (f in psafiles[str_detect(psafiles, "(HFCE|DEQ|EOG|EOS|IOG|IOS|AFF|MAQ|MFG|ESWW|CNS|TRD|TAS|AFSA|IAC|FIA|REOD|EDUC|HHSW|OS)")]) {
    download.file(url = f, method = "curl",
                  destfile = str_c("Data/National Accounts/PSA-",
                                   str_extract(str_remove(f, "^h.+/"), "\\d.+(Qrt|Ann)"),
                                   ".xlsx"))
}


rm(psafiles, f)



# PSA Website Regional Accounts -------------------------------------------
writeLines("Downloading Regional Accounts Data from the PSA website.")

# Scrape a list of links from the latest GRDP release from the PSA site

# Old PSA website
#psa_grdp_files <- read_html("https://psa.gov.ph/grdp/data-series") %>%
#    html_nodes(xpath = '//*[@id="content"]/div/div[1]/div/div/div[1]/div/div/div/table/tbody/tr/td[2]/table/tr/td[1]/div/div/ul/li/span/a') %>% 
#    html_attr("href")


# New PSA website
psa_grdp_files <- read_html("https://psa.gov.ph/statistics/grdp/data-series") %>%
    html_nodes(xpath = '//*[@id="content"]/div/div/div/div[1]/div/div/div/div/div/div/div/div/div/div[2]/span/div/table/tbody/tr[2]/td[2]/p/span/a') %>% 
    html_attr("href")

psa_grdp_files <- str_c("https://psa.gov.ph", psa_grdp_files)

# Download the Annual GRDP data
download.file(url = psa_grdp_files[1], method = "curl",
              destfile = "Data/National Accounts/PSA-GRDP-Ind-2018PSNA.xlsx")
download.file(url = psa_grdp_files[2], method = "curl",
              destfile = "Data/National Accounts/PSA-GRDP-Reg-2018PSNA.xlsx")


# Scrape a list of links from the latest GRDE release from the PSA site

# Old PSA website
#psa_grde_files <- read_html("https://psa.gov.ph/grde/data-series") %>%
#    html_nodes(xpath = '//*[@id="content"]/div/div[1]/div/div/div[1]/div/div/div/table/tbody/tr/td[2]/table/tr/td[1]/div/div/ul/li/span/a') %>% 
#    html_attr("href")

# New PSA website
psa_grde_files <- read_html("https://psa.gov.ph/statistics/grde/data-series") %>%
    html_nodes(xpath = '//*[@id="content"]/div/div/div/div[1]/div/div/div/div/div/div/div/div/div/div/span/div/table/tbody/tr[2]/td[2]/p/span/a') %>% 
    html_attr("href")

psa_grde_files <- str_c("https://psa.gov.ph", psa_grde_files)

# Download the Annual GRDE data
download.file(url = psa_grde_files[1], method = "curl",
              destfile = "Data/National Accounts/PSA-GRDE-Exp-2018PSNA.xlsx")
download.file(url = psa_grde_files[2], method = "curl",
              destfile = "Data/National Accounts/PSA-GRDE-Reg-2018PSNA.xlsx")

rm(psa_grdp_files, psa_grde_files)



# Openstat National Accounts ----------------------------------------------
writeLines("Downloading National Accounts Data from the Openstat API.")

# Download Annual Data; By Expenditure, By Industry, Per Capita
POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/NA/AN/1SUM/0012B5CEXA1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Openstat-SNA-Annual-Exp.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/NA/AN/1SUM/0052B5CPRA1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Openstat-SNA-Annual-Ind.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/NA/AN/1SUM/0122B5CPCA1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Openstat-SNA-Annual-PC.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

# Download Quarterly Data; By Expenditure, By Industry, Per Capita
POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/NA/QT/1SUM/0012B5CEXQ1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Openstat-SNA-Quarterly-Exp.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/NA/QT/1SUM/0052B5CPRQ1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Openstat-SNA-Quarterly-Ind.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/NA/QT/1SUM/0122B5CPCQ1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Openstat-SNA-Quarterly-PC.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)



# Openstat Gross Regional Domestic Product --------------------------------
writeLines("Downloading Gross Regional Domestic Product Data from the Openstat API.")

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/GP/RG/GRD/0012B5CPGD1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Regional Accounts/Openstat-GRDP.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/GP/RG/PCI/0772B5CPCP1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Regional Accounts/Openstat-GRDP-PC.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/GP/RG/AFF/0052B5CPAF1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Regional Accounts/Openstat-GRDP-Agriculture.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/GP/RG/IND/0092B5CPIN1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Regional Accounts/Openstat-GRDP-Industry.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/GP/RG/SER/0292B5CPSR1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Regional Accounts/Openstat-GRDP-Services.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)



# Openstat Gross Regional Domestic Expenditure ----------------------------
writeLines("Downloading Gross Regional Domestic Expenditure Data from the Openstat API.")

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/EA/BR/GR/0012B5CEGR1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Regional Accounts/Openstat-GRDE.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/EA/BR/GRC/1412B5CPCG1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Regional Accounts/Openstat-GRDE-PC.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/EA/BR/HF/0052B5CEHF1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Regional Accounts/Openstat-GRDE-01HFCE.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/EA/BR/PHF/0672B5CEPC1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Regional Accounts/Openstat-GRDE-01HFCE-PC.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/EA/BR/GF/0092B5CEGF1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Regional Accounts/Openstat-GRDE-02GFCE.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/EA/BR/GCF/0132B5CECF1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Regional Accounts/Openstat-GRDE-03GCF.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/EA/BR/EGS/0422B5CEXP1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Regional Accounts/Openstat-GRDE-04Exports.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2B/EA/BR/IGS/0542B5CEMP1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Regional Accounts/Openstat-GRDE-05Imports.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)



# Openstat Provincial Product Accounts ------------------------------------
writeLines("Downloading Provincial Product Accounts Data from the Openstat API.")

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2A/PPA/0012A5GPPA0.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Provincial Accounts/Openstat-PPA.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2A/PPA/0022A5GPPA1.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Provincial Accounts/Openstat-PPA-Industry.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)

POST(url = "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2A/PPA/0092A5GPPA8.px",
     body = '{"query": [], "response": {"format": "csv"}}') %>%
    content(encoding = "UTF-8") %>%
    write_csv("Data/National Accounts/Provincial Accounts/Openstat-PPA-PC.csv") %>%
    suppressMessages() %>% suppressWarnings()
Sys.sleep(1)