# =============================================================================
# downloadTradeData.R
# -----------------------------------------------------------------------------
# Downloads the International Merchandise Trade Statistics (IMTS) annual-value
# domain from the PSA OpenStat PXWeb API and writes one raw CSV per year per
# direction into Data/Trade/<Exports|Imports>/imts_<direction>_<year>.csv.
#
# Sibling of downloadAgriData.R; same helpers, conventions, and CSV pattern.
#
# Design notes:
#  * Each YEAR is a separate .px table in the AVE (export) / AVI (import) nodes.
#    The script reads each node's table list, pulls the year from each title, and
#    loops them, so "all years" needs no hard-coded IDs and self-extends.
#  * Response format is CSV. PSA's PXWeb json-stat2/json-stat export is broken on
#    this instance - it returns the dimension skeleton but a stub `value` ([1.0])
#    regardless of selection - whereas CSV returns real data (and is the format
#    the agri downloader already uses successfully).
#  * OpenStat caps a query at 100,000 cells. The big dimension (Commodity Code)
#    is a large valueset PXWeb omits from metadata, so it can't be enumerated to
#    chunk on. Instead we item-select COUNTRY in batches and let commodity/year/
#    value default to "all" by omission. The commodity count varies sharply by
#    vintage (imports from 2007 are detailed enough that 4 countries would exceed
#    the cap, which the origin rejects with an IIS 403), so the batch is sized
#    PER TABLE: probe one country (rows = commodity count) and set the batch so
#    commodities x countries x measures stays under the cap.
#  * Responses are read as ALL CHARACTER and saved raw. Typing, the PSCC parse
#    (the real 11-digit code is the commodity label that CSV emits), country
#    harmonization, and reshaping are deferred to loadTradeData.R.
#  * Every request is paced and retries on HTTP 429 via px_req(). Output is one
#    CSV per year per direction and the loop SKIPS files that already exist, so
#    an interrupted run resumes.
#  * Browser-realistic headers clear PSA's User-Agent 403 block.
# =============================================================================

library(tidyverse)
library(httr)
library(jsonlite)

set_config(config(ssl_verifypeer = 0))   # OpenStat's SSL certificate is flaky

# ---- Config -----------------------------------------------------------------

trade_dir  <- "Data/Trade"
directions <- list(exports = "2L/IMT/AVE",   # Annual Value of Export  by commodity x country
                   imports = "2L/IMT/AVI")   # Annual Value of Import  by commodity x country
years_filter  <- NULL          # NULL = all available years; else e.g. 2010:2024
CELL_CAP <- 100000L            # PXWeb per-query cell limit
SAFETY   <- 0.9                # stay comfortably under it

ua <- paste0("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ",
             "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
px_headers <- add_headers(`User-Agent` = ua, Referer = "https://openstat.psa.gov.ph/")

`%||%` <- function(a, b) if (is.null(a)) b else a

dir.create(trade_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Helper functions -------------------------------------------------------

base_url    <- "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/"
px_url      <- function(node, id) str_c(base_url, node, "/", id)
px_node_url <- function(node)     str_c(base_url, node)

# GET/POST with a polite pace, retrying on transient network errors and
# retryable HTTP statuses. A 403 here is the ORIGIN (IIS) IP throttle - a
# "403 Forbidden: Access is denied" page, NOT a Cloudflare challenge - which
# trips after sustained POST volume. Hammering it RESETS the block window, so a
# 403 gets a long cooldown and few retries; a persistent 403 stops cleanly so
# you can wait the block out and resume (completed years are skipped).
px_req <- function(method, url, body = NULL, pause = 0.6, tries = 5) {
    for (attempt in seq_len(tries)) {
        r <- tryCatch(
            if (method == "GET")
                GET(url, px_headers, timeout(120))
            else
                POST(url, body = body, encode = "raw",
                     content_type_json(), px_headers, timeout(120)),
            error = function(e) e
        )
        if (inherits(r, "error")) {                      # connection reset, DNS, timeout
            wait <- 2 ^ attempt
            message("  network error (", conditionMessage(r), "); retry ",
                    attempt, "/", tries, " in ", wait, "s")
            Sys.sleep(wait); next
        }
        sc <- status_code(r)
        if (sc == 403L) {                                # IIS origin IP throttle
            message("  403 origin throttle; cooling down 60s (attempt ",
                    attempt, "/", tries, ")")
            Sys.sleep(60); next
        }
        if (sc %in% c(408L, 429L, 500L, 502L, 503L, 504L)) {
            wait <- suppressWarnings(as.numeric(headers(r)[["retry-after"]]))
            if (is.na(wait)) wait <- 2 ^ attempt
            message("  HTTP ", sc, "; backing off ", wait, "s (attempt ",
                    attempt, "/", tries, ")")
            Sys.sleep(wait); next
        }
        Sys.sleep(pause); return(r)
    }
    stop("Persistent error after ", tries, " attempts: ", url,
         "\n  A repeating 403 is PSA's origin IP throttle (IIS 'Access is denied').",
         "\n  Stop ALL requests for 20-30 min to let the block clear, then re-run -",
         "\n  completed years are skipped. Raising `pause` further also helps.")
}

# Parse a response as JSON (used for metadata + table listings only).
px_json <- function(r) {
    if (status_code(r) != 200)
        stop("HTTP ", status_code(r), " - ",
             substr(content(r, "text", encoding = "UTF-8"), 1, 200))
    fromJSON(content(r, "text", encoding = "UTF-8"), simplifyVector = FALSE)
}

px_meta      <- function(node, id) px_json(px_req("GET", px_url(node, id)))
px_tablelist <- function(node)     px_json(px_req("GET", px_node_url(node)))

find_var <- function(meta, needle) {
    for (v in meta$variables) {
        hay <- tolower(paste(v$code %||% "", v$text %||% ""))
        if (grepl(needle, hay, fixed = TRUE)) return(v)
    }
    stop("no variable matching '", needle, "'")
}

# POST a CSV query; read the body as an all-character tibble (no typing here).
px_fetch_csv <- function(node, id, body) {
    r <- px_req("POST", px_url(node, id), body = body)
    if (status_code(r) != 200)
        stop("HTTP ", status_code(r), " from ", id, " - ",
             substr(content(r, "text", encoding = "UTF-8"), 1, 160))
    read_csv(I(content(r, "text", encoding = "UTF-8")),
             col_types = cols(.default = col_character()), show_col_types = FALSE)
}

# A CSV query item-selecting one batch of countries (commodity/year/value = all).
country_query <- function(country_var, country_values) {
    paste0('{"query":[{"code":"', country_var,
           '","selection":{"filter":"item","values":[',
           paste0('"', country_values, '"', collapse = ","),
           ']}}],"response":{"format":"csv"}}')
}

# Pull one year-table in full. The cell cap is commodities x countries x measures
# and the commodity count varies a lot by vintage (imports from 2007 carry enough
# codes that even 4 countries blows the 100k cap and the origin 403s). Commodity
# count isn't in metadata, so probe ONE country (rows = n commodities), then size
# the country batch from that so every request stays under the cap.
px_year_table <- function(node, id) {
    meta <- px_meta(node, id)
    nvar <- find_var(meta, "country")
    vvar <- find_var(meta, "value")
    countries <- unlist(nvar$values)
    n_value   <- length(vvar$values)
    if (length(countries) == 0) stop("no country codes in metadata for ", id)

    probe  <- px_fetch_csv(node, id, country_query(nvar$code, countries[1]))
    n_comm <- nrow(probe)
    batch  <- max(1L, as.integer((CELL_CAP * SAFETY) %/% (n_comm * n_value)))
    message(sprintf("    %s commodities x %d measures = %s cells/country -> batch=%d countries",
                    format(n_comm, big.mark = ","), n_value,
                    format(n_comm * n_value, big.mark = ","), batch))

    rest  <- countries[-1]
    grps  <- if (length(rest)) split(rest, ceiling(seq_along(rest) / batch)) else list()
    parts <- vector("list", length(grps) + 1L)
    parts[[1]] <- probe                                  # reuse the probe (country 1)
    for (i in seq_along(grps)) {
        g   <- grps[[i]]
        out <- px_fetch_csv(node, id, country_query(nvar$code, g))
        parts[[i + 1L]] <- out
        message(sprintf("    chunk %d/%d (%d countries): %s rows",
                        i, length(grps), length(g), format(nrow(out), big.mark = ",")))
    }
    bind_rows(parts)
}

# ---- Main -------------------------------------------------------------------

for (dir_name in names(directions)) {
    node   <- directions[[dir_name]]
    outdir <- file.path(trade_dir, str_to_title(dir_name))
    dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

    tabs <- map_dfr(px_tablelist(node), function(t)
                tibble(id = t$id %||% NA, type = t$type %||% "t",
                       text = t$text %||% "")) %>%
            filter(type == "t", !is.na(id)) %>%
            mutate(year = str_extract(text, "\\d{4}")) %>%
            filter(!is.na(year)) %>%
            arrange(year)

    if (!is.null(years_filter))
        tabs <- filter(tabs, as.integer(year) %in% years_filter)

    message(sprintf("[%s] %d year-tables: %s",
                    dir_name, nrow(tabs), str_c(tabs$year, collapse = ", ")))

    for (k in seq_len(nrow(tabs))) {
        yr  <- tabs$year[k]
        id  <- tabs$id[k]
        out <- file.path(outdir, sprintf("imts_%s_%s.csv", dir_name, yr))
        if (file.exists(out)) { message("  skip ", basename(out), " (exists)"); next }

        message(sprintf("  pull %s %s  [%s]", dir_name, yr, id))
        df <- px_year_table(node, id)
        write_csv(df, out)
        message(sprintf("  -> %s: %s rows\n", basename(out),
                        format(nrow(df), big.mark = ",")))
    }
}

message("Done. Per-year CSVs are under ", trade_dir, "/Exports and ", trade_dir, "/Imports.")
