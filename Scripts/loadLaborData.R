library(tidyverse)
library(readxl)
library(lubridate)
library(RcppRoll)


# Labor and Employment ----------------------------------------------------
writeLines("Loading Labor and Employment Data into R.")

labor <- read_xlsx("Data/Labor and Employment/Labor and Employment.xlsx") %>%
    filter(Round != "Annual") %>%
    mutate(Period = parse_date(`LFS Round`, "%Y %b")) %>%
    rename_with(~ str_remove_all(., "\\s|\\+")) %>%
    select(LFSRound:Round, Period, everything())
