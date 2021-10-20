# **Philippine Economic Data**
This is a repository for **compiling and consolidating Philippine economic data sets** of interest. Many of the data sets here are already publicly accessible on the internet, but are scattered and unconsolidated. The goal of this repository is to make it easier to conduct economic research and analysis through the use of these data sets.

The repository contains mostly **macroeconomic data** rather than microdata derived from surveys such as the FIES or LFS. While microdata are also important in conducting economic research, they are too large and cumbersome to be consolidated into this particular repo. Access to survey microdata also requires a request to be submitted to the PSA.

The **R programming language** is used to scrape most of the data sets. For data scraping that cannot be automated, data extraction and compilation is done manually. The repository will be updated at least quarterly.
  
  
## **Overview of Folders and Scripts**

-  Datasets are stored inside the `Data/` folder. Domain-related data sets are separated into respective subfolders.  
-  All R scripts are stored inside the `Scripts/` folder.  
-  Generated plots are stored inside the `Plots/` folder.  
  

### **Data**
| Data Sub-Folder | Description |
| --------------- | ----------- |
| `Agriculture and Food/` | Contains data on agriculture and food scraped/downloaded from OpenStat and the PSA website. |
| `CPI and Inflation/` | Contains Consumer Price Index data sets scraped/downloaded from OpenStat and the PSA website. |
| `Fiscal Data/` | Contains fiscal data extracted and compiled from various government websites. |
| `Labor and Employment/` | Contains Labor and Employment data sets manually extracted and compiled from the PSA website. |
| `National Accounts/` | Contains National Accounts data sets scraped/downloaded from PSA, OpenStat, and BSP. |

  

### **Scripts**
| Script | Description |
| ------ | ----------- |
| `downloadAgriData.R` | Scrapes/downloads agriculture and food data from various sources. |
| `downloadCPIData.R` | Scrapes/downloads Consumer Price Index data from various sources. |
| `downloadSNAData.R` | Scrapes/downloads National Accounts data from various sources. |
| `loadCPIData.R` | Loads CPI and inflation data into R. |
| `loadFiscalData.R` | Loads fiscal data into R. |
| `loadLaborData.R` | Loads labor and employment data into R. |
| `loadSNAData.R` | Loads National Accounts data into R. |

  

## **Data Sources**
Data in this repository are downloaded from publicly accessible sources:  

*  [Philippine Statistics Authority (PSA)](https://psa.gov.ph)
*  [PSA's OpenStat platform](https://openstat.psa.gov.ph/)
*  [Bangko Sentral ng Pilipinas (BSP)](https://www.bsp.gov.ph/SitePages/Statistics/Statistics.aspx)
*  [Bureau of Treasury (BTr)](https://www.treasury.gov.ph/)
  
In particular, data sets were compiled from the following links:  

*  [National Income Accounts (Base Year 2018)](https://psa.gov.ph/national-accounts/base-2018/data-series)
*  [Consumer Price Index and Inflation (Base Year 2012)](https://psa.gov.ph/price-indices/cpi-ir/downloads)
*  [Labor and Employment](https://psa.gov.ph/statistics/survey/labor-and-employment/labor-force-survey/table)
*  [National Government Cash Operations](https://www.treasury.gov.ph/?page_id=4221)
*  [National Government Debt](https://www.treasury.gov.ph/?page_id=12407)
*  [Agriculture Data](https://openstat.psa.gov.ph/Database/Agriculture-Forestry-Fisheries)
  
  
### **National Accounts**
The Philippine System of National Accounts (PSNA) generates macroeconomic indicator on Gross Domestic Product (GDP). The GDP represents the monetary value of all final goods and services produced within the economy in a given period of time.  

 The System of National Accounts (SNA) helps economists to measure the level of economic development and the rate of economic growth, the change in consumption, saving, consumption, investment, debt and wealth of the economy. From the data of SNA, economists can either forecast the future growth of the economy or study impacts on the economy and the institutional sectors of identified government policies and programs. ([*Source*](https://psa.gov.ph/national-accounts/frequently-asked-questions))
  
The latest base year for the SNA is 2018.  
  
National Accounts data can be downloaded from the [PSA website](https://psa.gov.ph/national-accounts), [OpenStat platform](https://openstat.psa.gov.ph/Database/Economic-Accounts/National-Accounts-of-the-Philippines), or [BSP website](https://www.bsp.gov.ph/SitePages/Statistics/RealSectorAccounts.aspx).  
  
  
### **Consumer Price Index and Inflation**
The Consumer Price Index is an indicator of the change in the average prices of a fixed basket of goods and services commonly purchased by households relative to a base year. The Inflation Rate is the annual rate of change or the year-on-year change in the Consumer Price Index.
  
The latest base year for the CPI is 2012.  
  
CPI and Inflation data can be downloaded from [OpenStat](https://openstat.psa.gov.ph/Database/Prices/Price-Indices), [PSA](https://psa.gov.ph/price-indices/cpi-ir/downloads), or [BSP](https://www.bsp.gov.ph/SitePages/Statistics/Prices.aspx?TabId=1).
  
  
### **Labor and Employment**
Labor and Employment statistics are generated from the Labor Force Survey (LFS), a nationwide survey of households conducted quarterly to gather data on the demographic and socio-economic characteristics of the population. The LFS is designed to provide statistics on levels and trends of employment, unemployment and underemployment of the country, as a whole, and for each of the administrative regions. ([*Source*](https://psa.gov.ph/statistics/survey/labor-and-employment/labor-force-survey/tech-notes))
  
Labor and employment data can be downloaded from the [PSA](https://psa.gov.ph/statistics/survey/labor-and-employment/labor-force-survey/table).
  
  
###  **Fiscal Data**
Fiscal data includes various data on the national government's revenue and expenditure accounts, national debt, local governments' fiscal accounts, as well as data extracted from public budget documents such as the *Budget of Expenditure and Sources of Financing* and *General Appropriations Act*.

[National cash operations data](https://www.treasury.gov.ph/?page_id=4221) and [national debt data](https://www.treasury.gov.ph/?page_id=12407) can be downloaded the Bureau of Treasury. Local government fiscal data can be downloaded from the [Bureau of Local Government Finance](https://blgf.gov.ph/lgu-fiscal-data/). Budget documents can be found on the [Department of Budget and Management website](https://dbm.gov.ph/).
  
  
### **Agricultural and Food Data**
A number of agriculture data sets are available in this repository:
*  value of production
*  supply utilization accounts
*  prices, costs, and returns


The OpenStat platform is the best publicly available source for [agricultural data](https://openstat.psa.gov.ph/Database/Agriculture-Forestry-Fisheries), [agricultural accounts](https://openstat.psa.gov.ph/Database/Agriculture-Forestry-Fisheries/Agricultural-Accounts), and [price data](https://openstat.psa.gov.ph/Database/Prices).