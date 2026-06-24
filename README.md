# **Philippine Economic Data**

This is a repository for **compiling and consolidating Philippine economic data sets** of interest. Many of the data sets here are already publicly accessible on the internet, but are scattered and unconsolidated. The goal of this repository is to make it easier to conduct economic research and analysis through the use of these data sets.

The repository contains mostly **macroeconomic data** rather than microdata derived from surveys such as the FIES or LFS. While microdata are also important in conducting economic research, they are too large and cumbersome to be consolidated into this particular repo. Access to survey microdata also requires a request to be submitted to the PSA.

The **R programming language** is used to scrape and wrangle most of the data sets. For data scraping that cannot be automated, data extraction and compilation is done manually. The repository is updated at least quarterly.


## **How the repository is organized**

Each domain follows the same three-stage pipeline:

1. **Download** — a `download<Domain>Data.R` script pulls the raw data, mostly from the PSA OpenStat PXWeb API (CSV responses, read as character to defer typing) or from agency websites and workbooks. Raw files land in the domain's `Data/` subfolder.
2. **Load / wrangle** — a `load<Domain>Data.R` script reshapes the raw files into tidy, analysis-ready tables (long format, typed dates, year-on-year growth where relevant, missing values handled, categories cleaned).
3. **Compile** — `generateDashboardData.R` builds the load tables and writes a curated subset of dashboard-ready tables to `Data/dashboardData.RData` (a single `.RData` file holding the tables most useful for a general dashboard or briefing).

- Datasets are stored inside the `Data/` folder, separated into domain subfolders.
- All R scripts are stored inside the `Scripts/` folder.


### **Data**

| Data Sub-Folder | Description |
| --------------- | ----------- |
| `Agriculture and Food/` | Agriculture, fisheries, and food data from OpenStat: value and volume of production, area harvested, livestock and poultry, supply utilization, self-sufficiency, and farmgate / wholesale / retail prices. Organized into themed subfolders (Crops, Livestock and Poultry, Fisheries, Agricultural Accounts, Census, and price folders split by New / Old series). |
| `CPI and Inflation/` | Consumer Price Index data (base years 2018 and 2012) from OpenStat and the PSA website. |
| `Fiscal Data/` | Fiscal data extracted and compiled from various government websites, including cash operations, national debt, and BIR tax statistics. |
| `Labor and Employment/` | Labor and Employment data manually extracted and compiled from the PSA website. |
| `National Accounts/` | National Accounts data from PSA, OpenStat, and BSP. |
| `Population/` | Population and related demographic series. |
| `Poverty/` | Poverty statistics from the PSA website. |
| `Trade/` | International Merchandise Trade Statistics (IMTS). The compact derived tables (`trade_*.csv`, `tradeData.rds`), aggregated tables, and PSCC reference workbooks are committed; the large raw per-year CSVs are **not** (see *Trade* below). |

The compiled `Data/dashboardData.RData` sits at the top of the `Data/` folder.


### **Scripts**

| Script | Description |
| ------ | ----------- |
| `downloadAgriData.R` | Downloads agriculture, fisheries, and price data from the OpenStat API into themed subfolders. |
| `downloadCPIDataBase2018.R` | Downloads Consumer Price Index data (2018 base). |
| `downloadCPIDataBase2012.R` | Downloads Consumer Price Index data (2012 base). |
| `downloadSNAData.R` | Downloads National Accounts data. |
| `downloadTradeData.R` | Downloads the raw IMTS annual value tables (one CSV per year per direction) from OpenStat. |
| `downloadTradeAgg.R` | Downloads the aggregated IMTS tables and the PSCC commodity-code reference workbooks. |
| `getPSALinks.R` | Helper that authenticates to the Cloudflare-protected PSA website (used by some download scripts). |
| `loadAgriData.R` | Loads agriculture and food data into tidy, periodicity-split tables. |
| `loadCPIData.R` | Loads CPI and inflation data into R. |
| `loadFiscalData.R` | Loads fiscal data into R. |
| `loadLaborData.R` | Loads labor and employment data into R. |
| `loadPovertyData.R` | Loads poverty statistics data into R. |
| `loadSNAData.R` | Loads National Accounts data into R. |
| `loadTradeData.R` | Consolidates the raw IMTS CSVs into a small set of compact, general-purpose trade tables (`tradeData.rds` + CSVs + a data dictionary). |
| `inspectTradeData.R` | Diagnostics / spot-checks for the trade tables. |
| `generateDashboardData.R` | Compiles the curated dashboard tables across all domains into `Data/dashboardData.RData`. |


## **Data Sources**

Data in this repository are downloaded from publicly accessible sources:

- [Philippine Statistics Authority (PSA)](https://psa.gov.ph)
- [PSA's OpenStat platform](https://openstat.psa.gov.ph/)
- [Bangko Sentral ng Pilipinas (BSP)](https://www.bsp.gov.ph/SitePages/Statistics/Statistics.aspx)
- [Bureau of Treasury (BTr)](https://www.treasury.gov.ph/)

In particular, data sets were compiled from the following links:

- [National Income Accounts (Base Year 2018)](https://psa.gov.ph/national-accounts/base-2018/data-series)
- [Consumer Price Index and Inflation (Base Year 2018)](https://psa.gov.ph/price-indices/cpi-ir/downloads)
- [Labor and Employment](https://psa.gov.ph/statistics/survey/labor-and-employment/labor-force-survey/table)
- [National Government Cash Operations](https://www.treasury.gov.ph/?page_id=4221)
- [National Government Debt](https://www.treasury.gov.ph/?page_id=12407)
- [Agriculture Data](https://openstat.psa.gov.ph/Database/Agriculture-Forestry-Fisheries)
- [Prices (farmgate / wholesale / retail)](https://openstat.psa.gov.ph/Database/Prices)
- [International Merchandise Trade Statistics](https://openstat.psa.gov.ph/Database/Foreign-Trade)
- [Poverty Statistics](https://psa.gov.ph/poverty-press-releases/data)

Most of the OpenStat downloads use the platform's **PXWeb API**. Because OpenStat caps each query at 100,000 cells, the download scripts read each table's metadata and automatically split oversized pulls into batches (chunked on geography or country) that stay under the limit, then stitch the pieces back together. Requests are paced and retry with backoff on rate-limiting (HTTP 429). Some PSA website pages sit behind a Cloudflare challenge; `getPSALinks.R` handles authentication for those.


### **National Accounts**

The Philippine System of National Accounts (PSNA) generates the macroeconomic indicator on Gross Domestic Product (GDP). The GDP represents the monetary value of all final goods and services produced within the economy in a given period of time.

The System of National Accounts (SNA) helps economists measure the level of economic development and the rate of economic growth, and the change in consumption, saving, investment, debt, and wealth of the economy. From the data of the SNA, economists can forecast the future growth of the economy or study the impacts of identified government policies and programs. ([*Source*](https://psa.gov.ph/national-accounts/frequently-asked-questions))

The latest base year for the SNA is 2018. National Accounts data can be downloaded from the [PSA website](https://psa.gov.ph/national-accounts), [OpenStat platform](https://openstat.psa.gov.ph/Database/Economic-Accounts/National-Accounts-of-the-Philippines), or [BSP website](https://www.bsp.gov.ph/SitePages/Statistics/RealSectorAccounts.aspx).


### **Consumer Price Index and Inflation**

The Consumer Price Index is an indicator of the change in the average prices of a fixed basket of goods and services commonly purchased by households relative to a base year. The Inflation Rate is the year-on-year change in the Consumer Price Index.

The latest base year for the CPI is 2018; the 2012 base is also retained for longer series. CPI and Inflation data can be downloaded from [OpenStat](https://openstat.psa.gov.ph/Database/Prices/Price-Indices), [PSA](https://psa.gov.ph/price-indices/cpi-ir/downloads), or [BSP](https://www.bsp.gov.ph/SitePages/Statistics/Prices.aspx?TabId=1).


### **Labor and Employment**

Labor and Employment statistics are generated from the Labor Force Survey (LFS), a nationwide survey of households conducted quarterly to gather data on the demographic and socio-economic characteristics of the population. The LFS provides statistics on levels and trends of employment, unemployment, and underemployment for the country as a whole and for each administrative region. ([*Source*](https://psa.gov.ph/statistics/survey/labor-and-employment/labor-force-survey/tech-notes))

Labor and employment data can be downloaded from the [PSA](https://psa.gov.ph/statistics/survey/labor-and-employment/labor-force-survey/table).


### **Fiscal Data**

Fiscal data includes data on the national government's revenue and expenditure accounts, national debt, and data extracted from public budget documents such as the *Budget of Expenditures and Sources of Financing* and *General Appropriations Act*.

[National cash operations data](https://www.treasury.gov.ph/?page_id=4221) and [national debt data](https://www.treasury.gov.ph/?page_id=12407) can be downloaded from the Bureau of Treasury. Local government fiscal data can be downloaded from the [Bureau of Local Government Finance](https://blgf.gov.ph/lgu-fiscal-data/). Budget documents can be found on the [Department of Budget and Management website](https://dbm.gov.ph/).


### **Agriculture and Food Data**

The `Agriculture and Food/` domain has been substantially expanded and now draws entirely from the OpenStat API via `downloadAgriData.R`. It covers:

- value of production (agricultural accounts)
- volume of production and area harvested (major crops, plus palay and corn with irrigated / rainfed splits)
- livestock and poultry production and inventory
- fisheries production by subsector
- supply utilization, self-sufficiency, and import-dependency ratios
- production costs and returns
- farmgate, wholesale, and retail prices

`loadAgriData.R` reshapes these into tidy tables that are kept as complete and granular as possible (all geographic levels, all years) and **split by periodicity** so that annual, quarterly, and monthly data never share a frame. Related indicators for the same theme are collapsed into one table (for example, crop volume, area, and derived yield; or fisheries volume and value). Prices are levels in pesos, so the New and Old series are stacked into a single long table distinguished by a series flag rather than being rebased.

Prices in particular are downloaded in full: farmgate, wholesale, and retail, each with their New and Old (and base-year / geographic-code) variants kept in separate folders for posterity. The OpenStat platform is the best publicly available source for [agricultural data](https://openstat.psa.gov.ph/Database/Agriculture-Forestry-Fisheries), [agricultural accounts](https://openstat.psa.gov.ph/Database/Agriculture-Forestry-Fisheries/Agricultural-Accounts), and [price data](https://openstat.psa.gov.ph/Database/Prices).


### **Trade Data**

The `Trade/` domain holds the **International Merchandise Trade Statistics (IMTS)** — annual trade values by commodity and partner country, with exports valued FOB and imports CIF, in current US dollars.

The raw data are large: one CSV per year per direction, each a commodity-code by partner-country table, totaling roughly **2.8 GB**. These raw files (`Data/Trade/Exports/` and `Data/Trade/Imports/`) are therefore **gitignored and not committed**. They are fully reproducible — `downloadTradeData.R` pulls every year from the OpenStat API (it reads each node's table list and extracts the year from each title, so it self-extends as new years are released) and skips files that already exist, so an interrupted run resumes. `downloadTradeAgg.R` additionally pulls the smaller aggregated IMTS tables and the PSCC commodity-code reference workbooks (`Data/Trade/Aggregated/` and `Data/Trade/Reference/`), which **are** committed.

`loadTradeData.R` consolidates the raw per-year CSVs into a compact, general-purpose set of tables (a few MB) that **are** committed and can be uploaded, inspected, or folded into the dashboard:

| Table | Description |
| ----- | ----------- |
| `trade_annual` | Exports, imports, balance, and total trade by year. |
| `trade_by_partner` | Trade value by partner country and year (with region and bloc flags). |
| `trade_by_region` | Trade value by partner region / bloc. |
| `trade_by_commodity` | Trade value by commodity code, all years (HS subheadings for the harmonized era, whole PSCC codes before it). |
| `trade_by_partner_group` | Trade value by partner country and commodity group. |
| `trade_semiconductors` | Semiconductor trade (HS 8541 / 8542) by partner. |
| `trade_minerals` | Mineral and metal trade by partner and type. |

The load step canonicalizes country labels (so vintage-specific variants such as the differing "Japan" labels are unified), flags non-country residual aggregates so totals reconcile, and ends with a coverage audit. The tables are emitted both as individual CSVs and as a single named-list bundle, `tradeData.rds`, alongside a column-by-column data dictionary (`trade_tables_dictionary.md`).

To regenerate the trade data from scratch:

```r
source("Scripts/downloadTradeData.R")   # ~2.8 GB of raw per-year CSVs (gitignored)
source("Scripts/downloadTradeAgg.R")    # aggregated tables + PSCC reference workbooks
source("Scripts/loadTradeData.R")       # compact committed tables + tradeData.rds
```


### **Poverty Statistics**

Poverty statistics are generated from the Family Income and Expenditure Survey (FIES), a nationwide survey of households undertaken every three years. It is the main source of data on family income and expenditure, including levels of consumption by item of expenditure and sources of income in cash and in kind. ([*Source*](https://psa.gov.ph/income-expenditure/fies-technical-notes))

The [PSA's glossary of poverty statistics](https://psa.gov.ph/poverty-press-releases/glossary) describes measures such as the poverty threshold, poverty incidence, poverty severity, and poverty gap. Poverty data can be downloaded from the [PSA](https://psa.gov.ph/poverty-press-releases/data).


## **Compiled Dashboard Data**

`generateDashboardData.R` is the final step of the pipeline. It builds the domain load tables and writes a curated, dashboard-ready subset to `Data/dashboardData.RData` using an explicit `save()` (so only the relevant tables are stored, not scratch objects). The compiled file currently includes National Accounts (quarterly expenditure, industry, and per-capita series), CPI and inflation, GDP deflators, labor, fiscal (cash operations, debt, tax), agriculture (annual crops, livestock, fisheries, value of production, self-sufficiency, and national monthly prices), and trade (annual totals, partners, regions, commodities, and semiconductors). Finer-grained tables remain available from the individual load scripts for deeper analysis.
