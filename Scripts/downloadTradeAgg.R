# =============================================================================
# downloadTradeAgg.R
# -----------------------------------------------------------------------------
# Companion to downloadTradeData.R. Pulls the AGGREGATED IMTS tables and the
# PSCC reference workbooks - the small, high-value inputs for loadTradeData.R.
#
#   Data/Trade/Aggregated/   sum_total_trade.csv, sum_trade_by_country.csv,
#                            pcg_<...>.csv (by commodity group),
#                            pmg_<...>.csv (by major type of goods)
#   Data/Trade/Reference/    PSCC_Flat.xlsx, PSCC_Hierarchical.xlsx,
#                            Selected_Commodities_PSCC.xlsx
#
# These tables have no large-valueset dimension, so metadata carries every value
# and px_pull_table() can size cells exactly: one request when under the cap,
# otherwise chunk the largest dimension. CSV format (json-stat2 is broken here).
# =============================================================================

library(tidyverse)
library(httr)
library(jsonlite)

set_config(config(ssl_verifypeer = 0))
`%||%` <- function(a, b) if (is.null(a)) b else a

ua <- paste0("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ",
             "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
px_headers <- add_headers(`User-Agent` = ua, Referer = "https://openstat.psa.gov.ph/")

CELL_CAP <- 100000L
SAFETY   <- 0.9

agg_dir <- "Data/Trade/Aggregated"
ref_dir <- "Data/Trade/Reference"
dir.create(agg_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(ref_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Helpers (shared shape with downloadTradeData.R) ------------------------

base_url    <- "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/"
px_url      <- function(node, id) str_c(base_url, node, "/", id)
px_node_url <- function(node)     str_c(base_url, node)

px_req <- function(method, url, body = NULL, pause = 0.6, tries = 5) {
    for (attempt in seq_len(tries)) {
        r <- tryCatch(
            if (method == "GET") GET(url, px_headers, timeout(120))
            else POST(url, body = body, encode = "raw", content_type_json(), px_headers, timeout(120)),
            error = function(e) e)
        if (inherits(r, "error")) {
            wait <- 2 ^ attempt
            message("  network error (", conditionMessage(r), "); retry ", attempt, "/", tries, " in ", wait, "s")
            Sys.sleep(wait); next
        }
        sc <- status_code(r)
        if (sc == 403L) { message("  403 origin throttle; cooling down 60s (", attempt, "/", tries, ")")
                          Sys.sleep(60); next }
        if (sc %in% c(408L, 429L, 500L, 502L, 503L, 504L)) {
            wait <- suppressWarnings(as.numeric(headers(r)[["retry-after"]])); if (is.na(wait)) wait <- 2 ^ attempt
            message("  HTTP ", sc, "; backing off ", wait, "s"); Sys.sleep(wait); next
        }
        Sys.sleep(pause); return(r)
    }
    stop("Failed after ", tries, " attempts: ", url)
}

px_json      <- function(r) { if (status_code(r) != 200) stop("HTTP ", status_code(r))
                              fromJSON(content(r, "text", encoding = "UTF-8"), simplifyVector = FALSE) }
px_meta      <- function(node, id) px_json(px_req("GET", px_url(node, id)))
px_tablelist <- function(node)     px_json(px_req("GET", px_node_url(node)))

px_fetch_csv <- function(node, id, body) {
    r <- px_req("POST", px_url(node, id), body = body)
    if (status_code(r) != 200)
        stop("HTTP ", status_code(r), " from ", id, " - ",
             substr(content(r, "text", encoding = "UTF-8"), 1, 160))
    read_csv(I(content(r, "text", encoding = "UTF-8")),
             col_types = cols(.default = col_character()), show_col_types = FALSE)
}

# Pull a whole table: one request if under the cap, else chunk the largest dim.
px_pull_table <- function(node, id) {
    meta  <- px_meta(node, id)
    vars  <- meta$variables
    sizes <- vapply(vars, function(v) length(v$values), integer(1))
    total <- prod(sizes)
    if (total <= CELL_CAP * SAFETY)
        return(px_fetch_csv(node, id, '{"query":[],"response":{"format":"csv"}}'))

    big   <- which.max(sizes)
    bvar  <- vars[[big]]
    bvals <- unlist(bvar$values)
    per   <- total / sizes[big]
    batch <- max(1L, as.integer((CELL_CAP * SAFETY) %/% per))
    grps  <- split(bvals, ceiling(seq_along(bvals) / batch))
    message(sprintf("    %s cells -> chunk on '%s' (%d per request)",
                    format(total, big.mark = ","), bvar$code, batch))
    map(grps, function(g) {
        body <- paste0('{"query":[{"code":"', bvar$code,
                       '","selection":{"filter":"item","values":[',
                       paste0('"', g, '"', collapse = ","), ']}}],"response":{"format":"csv"}}')
        px_fetch_csv(node, id, body)
    }) %>% bind_rows()
}

safe_name <- function(x) x %>% str_replace_all("[^A-Za-z0-9]+", "_") %>%
                              str_replace_all("^_|_$", "") %>% str_to_lower()

# ---- 1. SUM single tables ---------------------------------------------------

sum_tables <- list(total_trade      = "0012L4DFTS0.px",
                   trade_by_country = "0012L4DFTS1.px")
for (nm in names(sum_tables)) {
    out <- file.path(agg_dir, paste0("sum_", nm, ".csv"))
    if (file.exists(out)) { message("skip ", basename(out)); next }
    message("pull SUM ", nm)
    write_csv(px_pull_table("2L/IMT/SUM", sum_tables[[nm]]), out)
    message("  -> ", basename(out))
}

# ---- 2. PCG / PMG tablelist nodes ------------------------------------------

agg_nodes <- list(pcg = "2L/IMT/PCG", pmg = "2L/IMT/PMG")
for (gname in names(agg_nodes)) {
    node <- agg_nodes[[gname]]
    tabs <- map_dfr(px_tablelist(node), function(t)
                tibble(id = t$id %||% NA, type = t$type %||% "t", text = t$text %||% "")) %>%
            filter(type == "t", !is.na(id))
    message(sprintf("[%s] %d tables", gname, nrow(tabs)))
    for (k in seq_len(nrow(tabs))) {
        tag <- str_extract(tabs$text[k], "\\d{4}") %||% safe_name(tabs$text[k])
        if (is.na(tag)) tag <- safe_name(tabs$id[k])
        out <- file.path(agg_dir, sprintf("%s_%s.csv", gname, tag))
        if (file.exists(out)) { message("  skip ", basename(out)); next }
        message("  pull ", gname, " ", tabs$id[k], " (", tabs$text[k], ")")
        write_csv(px_pull_table(node, tabs$id[k]), out)
        message("  -> ", basename(out))
    }
}

# ---- 3. PSCC reference workbooks -------------------------------------------

refs <- c(
  PSCC_Flat.xlsx                 = "https://openstat.psa.gov.ph/Portals/0/files/PSCC%20Commodity%20Code%20List_Flat.xlsx?ver=__sZXqJ0FyJtesDyVktHkQ%3d%3d",
  PSCC_Hierarchical.xlsx         = "https://openstat.psa.gov.ph/Portals/0/files/PSCC%20Commodity%20Code%20List_Hierarchical.xlsx?ver=2075KHTJoyKnZ1ij5xSW2w%3d%3d",
  Selected_Commodities_PSCC.xlsx = "https://openstat.psa.gov.ph/Portals/0/files/List%20of%20Selected%20Commodities%20with%20PSCC%20Commodity%20Codes_revised.xlsx?ver=ZgbmIHCXtlBJtBeCj7qYgg%3d%3d"
)
options(HTTPUserAgent = ua)            # download.file uses this as the User-Agent
for (nm in names(refs)) {
    dest <- file.path(ref_dir, nm)
    if (file.exists(dest)) { message("skip ", nm); next }
    message("download ", nm)
    # download.file passes the already percent-encoded URL through literally;
    # httr::GET re-encodes it and breaks the "?ver=...%3d%3d" token. mode="wb"
    # is essential so the binary xlsx is not mangled on Windows.
    download.file(refs[[nm]], dest, mode = "wb", quiet = TRUE)
    sig <- readBin(dest, "raw", 2)     # a valid xlsx is a zip -> starts with "PK"
    if (identical(sig, as.raw(c(0x50, 0x4B))))
        message("  -> ", nm, " (", file.info(dest)$size %/% 1024, " KB)")
    else
        message("  !! ", nm, " is not a valid xlsx (saved an error page?); ",
                "try the curl_download fallback")
}

message("Done. Aggregated CSVs in ", agg_dir, "; reference workbooks in ", ref_dir, ".")
