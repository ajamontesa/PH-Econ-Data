library(tidyverse)
library(readxl)
library(lubridate)
library(RcppRoll)



# Fiscal Data -------------------------------------------------------------
writeLines("Loading Fiscal Data into R.")

snaColNames81 <- str_c(seq.Date(as.Date("1981-01-01"), Sys.Date()-weeks(16), by = "quarter"))

ngcor <- left_join(
    read_xlsx("Data/Fiscal Data/ngcor.xlsx") %>%
        pivot_longer(cols = -Particulars, names_to = "Month", values_to = "MillionPesos") %>%
        mutate(Particulars = as_factor(str_remove_all(Particulars, "\\s|-|/|\\(|\\)")),
               Month = parse_date(Month, "%B %Y"),
               Quarter = yq(str_c(str_sub(Month, 1, 4), "Q", quarter(Month)))) %>%
        group_by(Particulars, Quarter) %>%
        summarize(MillionPesos = sum(MillionPesos, na.rm = TRUE)) %>%
        ungroup() %>%
        pivot_wider(names_from = Particulars, values_from = MillionPesos),
    read_xlsx("Data/National Accounts/PSA-Quarter-Q1-1981-to-latest.xlsx", skip = 18, n_max = 1,
              col_names = c("Expenditure", snaColNames81)) %>%
        pivot_longer(cols = -Expenditure, names_to = "Quarter", values_to = "NominalGDP") %>%
        mutate(Quarter = as.Date(Quarter)) %>%
        select(Quarter, NominalGDP)
) %>% mutate(across(.cols = -Quarter, .fns = ~roll_sumr(.x, 4), .names = "{.col}4Q")) %>%
    suppressMessages() %>% suppressWarnings()


left_join(
    read_xlsx("Data/Fiscal Data/ngdebt.xlsx") %>%
        pivot_longer(cols = -Particulars, names_to = "Month", values_to = "MillionPesos") %>%
        filter(Particulars %in% c("Actual Obligations", "Domestic Debt", "External Debt"),
               str_detect(Month, "Mar|Jun|Sep|Dec")) %>%
        mutate(Particulars = as_factor(str_remove_all(Particulars, "\\s|-|/|\\(|\\)")),
               Month = parse_date(Month, "%B %Y"),
               Quarter = yq(str_c(str_sub(Month, 1, 4), "Q", quarter(Month)))) %>%
        pivot_wider(names_from = Particulars, values_from = MillionPesos) %>%
        filter(year(Quarter) >= 1993),
    read_xlsx("Data/National Accounts/PSA-Quarter-Q1-1981-to-latest.xlsx", skip = 18, n_max = 1,
              col_names = c("Expenditure", snaColNames81)) %>%
        pivot_longer(cols = -Expenditure, names_to = "Quarter", values_to = "NominalGDP") %>%
        mutate(Quarter = as.Date(Quarter)) %>%
        select(Quarter, NominalGDP)
) %>% mutate(NominalGDP4Q = roll_sumr(NominalGDP, 4)) %>%
    suppressMessages() %>% suppressWarnings()

rm(snaColNames81)
