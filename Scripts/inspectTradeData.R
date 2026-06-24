# =============================================================================
# inspectTradeData.R
# -----------------------------------------------------------------------------
# Emits small structure summaries of the per-year IMTS CSVs so the layout can be
# verified without uploading the (70MB+) year files themselves. Produces:
#   trade_column_signatures.csv  - columns of every year file (header pattern, FOB/CIF)
#   trade_country_labels.txt     - every distinct Country label across all years
#   trade_code_summary.csv       - commodity-code length distribution per vintage
# Upload these three; they are a few KB each.
# =============================================================================

library(tidyverse)

trade_dir <- "Data/Trade"
files <- list.files(file.path(trade_dir, c("Exports", "Imports")),
                    pattern = "\\.csv$", full.names = TRUE)
stopifnot(length(files) > 0)

# 1. Column signature of each file (confirms "<year> <measure>" headers + FOB vs CIF)
sig <- map_dfr(files, function(f) {
    h <- read_csv(f, n_max = 0, show_col_types = FALSE)
    tibble(file = basename(f), ncol = ncol(h),
           columns = str_c(names(h), collapse = " | "))
})
write_csv(sig, "trade_column_signatures.csv")
message("wrote trade_column_signatures.csv (", nrow(sig), " files)")

# 2. Union of all Country labels across every file (for the country master)
countries <- files %>%
    map(~ read_csv(.x, col_select = "Country",
                   col_types = cols(.default = "c"), show_col_types = FALSE)[[1]]) %>%
    unlist() %>% unique() %>% sort()
writeLines(countries, "trade_country_labels.txt")
message("wrote trade_country_labels.txt (", length(countries), " distinct labels)")

# 3. Commodity-code shape for a spread of vintages (oldest, middle, newest of each
#    direction) - code length distribution + a few samples, to design the PSCC join
pick <- function(dir) {
    fs <- sort(files[str_detect(files, dir)])
    unique(fs[c(1, ceiling(length(fs) / 2), length(fs))])
}
sample_files <- unique(c(pick("Exports"), pick("Imports")))
code_summary <- map_dfr(sample_files, function(f) {
    cc <- read_csv(f, col_select = "Commodity Code",
                   col_types = cols(.default = "c"), show_col_types = FALSE)[[1]]
    u  <- unique(cc)
    lens <- table(nchar(u))
    tibble(file = basename(f),
           n_codes = length(u),
           length_dist = str_c(names(lens), as.integer(lens), sep = ":", collapse = ", "),
           samples = str_c(head(u, 6), collapse = ", "))
})
write_csv(code_summary, "trade_code_summary.csv")
message("wrote trade_code_summary.csv (", nrow(code_summary), " vintages)")
