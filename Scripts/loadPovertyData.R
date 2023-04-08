library(tidyverse)
library(readxl)
library(lubridate)



# Poverty -----------------------------------------------------------------
writeLines("Loading Poverty Data into R.")

poverty <- read_xlsx("Data/Poverty/Poverty.xlsx") %>%
    pivot_longer(cols = -(1:3), names_to = "Year", values_to = "Value") %>%
    mutate(Year = parse_date(Year, "%Y"))


poverty_sectors <- read_xlsx("Data/Poverty/Poverty.xlsx", sheet = "Basic Sectors") %>%
    pivot_longer(cols = -(Indicator:Series), names_to = "Year", values_to = "Value") %>%
    mutate(Year = parse_date(Year, "%Y"))

