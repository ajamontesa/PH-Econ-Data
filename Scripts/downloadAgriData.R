# =============================================================================
# downloadAgriData.R
# -----------------------------------------------------------------------------
# Downloads the Agriculture & Food domain from the PSA OpenStat PXWeb API and
# writes tidy-ready CSVs into Data/Agriculture and Food/<subfolder>/.
#
# Design notes:
#  * OpenStat enforces a 100,000-cell limit per query. px_csv() reads each
#    table's metadata, computes the cell count, and automatically splits an
#    oversized pull into Geolocation batches that stay under the limit, then
#    stitches the pieces back together.
#  * Every request is paced (~0.4s) and retries with exponential backoff on
#    HTTP 429 (rate limit) via px_req(), so a long run self-heals instead of
#    aborting. Bump the px_req() `pause` default if 429s persist on the sweep.
#  * All responses are read as CHARACTER. Typing/parsing is deferred to
#    loadAgriData.R, so PXWeb missing-value markers ("..", "-", ":") survive
#    and per-chunk type guessing can't break bind_rows().
#  * Prices (farmgate / wholesale / retail) are swept node-by-node via
#    px_sweep(): every table in a node is pulled, named descriptively from the
#    table's own title, and the New / Old / base-year variants are kept in
#    separate folders for posterity.
#  * Removed vs. the old script: the Cloudflare-blocked PSA-website GVA scrape,
#    and the discontinued 2000-2017 livestock/poultry volume tables.
#
# NOTE: outputs are organized into subfolders. Delete any old flat CSVs / .xlsx
#       directly under "Data/Agriculture and Food/" so nothing is orphaned.
# =============================================================================

library(tidyverse)
library(httr)
library(jsonlite)

set_config(config(ssl_verifypeer = 0))   # OpenStat's SSL certificate is flaky

agri_dir   <- "Data/Agriculture and Food"
subfolders <- c("Agricultural Accounts", "Crops", "Livestock and Poultry",
                "Fisheries", "Census")
for (d in c("Data", agri_dir, file.path(agri_dir, subfolders)))
    if (!dir.exists(d)) dir.create(d, recursive = TRUE)


# ---- Helper functions -------------------------------------------------------

base_url    <- "https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/"
px_url      <- function(node, id) str_c(base_url, node, "/", id)
px_node_url <- function(node)     str_c(base_url, node)

# GET/POST with a pause + automatic backoff on 429 (rate limit).
px_req <- function(method, url, body = NULL, pause = 0.4, tries = 5) {
    for (attempt in seq_len(tries)) {
        r <- if (method == "GET") GET(url) else POST(url, body = body)
        if (status_code(r) != 429) { Sys.sleep(pause); return(r) }
        wait <- suppressWarnings(as.numeric(headers(r)[["retry-after"]]))
        if (is.na(wait)) wait <- 2 ^ attempt          # 2, 4, 8, 16 s backoff
        message("  429 rate-limited; waiting ", wait, "s (attempt ", attempt, "/", tries, ")")
        Sys.sleep(wait)
    }
    stop("Still rate-limited after ", tries, " attempts: ", url)
}

# POST one query; return an all-character tibble. Fails loudly on non-200.
px_fetch <- function(node, id, body) {
    r <- px_req("POST", px_url(node, id), body = body)
    if (status_code(r) != 200)
        stop("HTTP ", status_code(r), " from ", id, " - ",
             substr(content(r, "text", encoding = "UTF-8"), 1, 160))
    read_csv(I(content(r, "text", encoding = "UTF-8")),
             col_types = cols(.default = col_character()), show_col_types = FALSE)
}

# Pull a whole table to CSV, auto-chunking under the cell limit when needed.
px_csv <- function(node, id, dest, limit = 1e5, chunk_var = "Geolocation") {
    dest <- file.path(agri_dir, dest)
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)

    mr  <- px_req("GET", px_url(node, id))
    txt <- content(mr, "text", encoding = "UTF-8")
    if (status_code(mr) != 200 || !startsWith(str_trim(txt), "{"))
        stop(id, ": metadata did not return JSON (HTTP ", status_code(mr),
             "). If 429 it was rate-limited; otherwise the table likely moved - ",
             "re-check with px_walk(\"", node, "\").")

    vars  <- fromJSON(txt, simplifyVector = FALSE)$variables
    sizes <- setNames(map_int(vars, ~ length(.x$values)), map_chr(vars, ~ .x$code))
    total <- prod(sizes)

    if (total <= limit) {
        px_fetch(node, id, '{"query":[],"response":{"format":"csv"}}') %>% write_csv(dest)
        message("saved ", basename(dest), "  (", format(total, big.mark = ","), " cells, 1 request)")
        return(invisible())
    }

    if (!chunk_var %in% names(sizes)) chunk_var <- names(which.max(sizes))
    others <- prod(sizes[names(sizes) != chunk_var])
    if (others > limit)
        stop(basename(dest), ": one ", chunk_var, " slice = ", others,
             " cells (> ", limit, "). Needs a second chunk dimension.")
    vals  <- map_chr(vars[[match(chunk_var, names(sizes))]]$values, as.character)
    batch <- max(1L, limit %/% others)
    grps  <- split(vals, ceiling(seq_along(vals) / batch))
    message("chunking ", basename(dest), " on ", chunk_var, ": ",
            length(vals), " values -> ", length(grps), " requests")

    map(grps, function(g) {
        q <- str_c('{"query":[{"code":"', chunk_var,
                   '","selection":{"filter":"item","values":[',
                   str_c('"', g, '"', collapse = ","), ']}}],"response":{"format":"csv"}}')
        px_fetch(node, id, q)
    }) %>% bind_rows() %>% write_csv(dest)
    message("saved ", basename(dest), "  (", format(total, big.mark = ","),
            " cells, ", length(grps), " requests)")
}

# Turn a table title into a clean commodity slug, e.g.
#   "Cereals: Farmgate Prices by Geolocation, ..." -> "Cereals"
#   "Livestock and Poultry (Household): Farmgate Prices ..." -> "Livestock-and-Poultry-Household"
make_slug <- function(text) {
    s <- str_split(text, regex("(farmgate|wholesale|retail)", ignore_case = TRUE), n = 2)[[1]][1]
    s <- str_split(s, regex("\\bby\\b", ignore_case = TRUE), n = 2)[[1]][1]
    s <- str_squish(str_replace_all(s, "[():,/]", " "))
    str_replace_all(s, "\\s+", "-")
}

# Sweep an entire node: pull every table into <folder>, named descriptively as
# Openstat-<label>-<commodity>.csv. Recurses into any sub-levels.
px_sweep <- function(node, folder, label) {
    dir.create(file.path(agri_dir, folder), recursive = TRUE, showWarnings = FALSE)
    items <- tryCatch(
        px_req("GET", px_node_url(node)) %>% content("text", encoding = "UTF-8") %>%
            fromJSON(simplifyVector = TRUE) %>% as_tibble(),
        error = function(e) tibble())
    if (!nrow(items)) { warning("No listing for ", node, " - skipped."); return(invisible()) }

    for (sub in items$id[items$type == "l"])          # recurse into sub-levels
        px_sweep(str_c(node, "/", sub), folder, label)

    tabs <- items[items$type == "t", , drop = FALSE]
    if (!nrow(tabs)) return(invisible())
    slugs <- make.unique(vapply(tabs$text, make_slug, character(1)), sep = "-")  # collision-safe
    message("-- sweeping ", node, " (", nrow(tabs), " tables) -> ", folder)
    for (k in seq_len(nrow(tabs)))
        px_csv(node, tabs$id[k],
               file.path(folder, str_c("Openstat-", label, "-", slugs[k], ".csv")))
}


# ---- 1. Agricultural Accounts ----------------------------------------------
writeLines("Downloading Agricultural Accounts ...")

# Value of Production (moved to .../VP/NA)
px_csv("2B/AA/VP/NA", "0012B5FVOP1.px", "Agricultural Accounts/Openstat-Value-of-Production-Agri.csv")

# Supply Utilization Accounts (10 commodity groups)
sua_items <- c("Cereals", "Rootcrops", "Vegetables", "Nuts", "Fruits",
               "Commercial-Crops", "NonFood", "Livestock", "Poultry", "Fishery")
for (i in 0:9)
    px_csv("2B/AA/SU", str_c("0012B5FSUA", i, ".px"),
           str_c("Agricultural Accounts/Openstat-SU-Accounts-", sua_items[i + 1], ".csv"))

# Import Dependency, Self-Sufficiency, Farm-to-Retail gap (moved to .../AFIS, new IDs)
px_csv("2B/AA/AFIS", "0032E5FIDR0.px", "Agricultural Accounts/Openstat-Import-Dependency-Agri.csv")
px_csv("2B/AA/AFIS", "0022E5FSSR0.px", "Agricultural Accounts/Openstat-Self-Sufficiency-Agri.csv")
px_csv("2B/AA/AFIS", "0012B5FAIS1.px", "Agricultural Accounts/Openstat-Farm-to-Retail-Price-Gap.csv")

# Costs & Returns - crop / aquaculture groups (Rootcrops ... Milkfish-Tilapia)
cr_items <- c("Rootcrops", "Legumes", "Vegetables", "Fruits",
              "Commercial-Crops", "Nuts", "Milkfish-Tilapia")
for (i in 1:7)
    px_csv("2B/AA/CR", str_c("0012B5FCOP", i, ".px"),
           str_c("Agricultural Accounts/Openstat-Production-Cost-Returns-", cr_items[i], ".csv"))

# Costs & Returns - Palay & Corn (combined table APC1, pulled whole)
px_csv("2B/AA/CR", "0012B5FAPC1.px",
       "Agricultural Accounts/Openstat-Production-Cost-Returns-Palay-Corn.csv")


# ---- 2. Crops --------------------------------------------------------------
writeLines("Downloading Crops ...")

px_csv("2E/CS", "0012E4EVCP0.px", "Crops/Openstat-Volume-of-Production-Palay-Corn.csv")
px_csv("2E/CS", "0022E4EAHC0.px", "Crops/Openstat-Area-Harvested-Palay-Corn.csv")
px_csv("2E/CS", "0142E4EVCP1.px", "Crops/Openstat-Volume-of-Production-Major-Crops.csv")
px_csv("2E/CS", "0152E4EAHM0.px", "Crops/Openstat-Area-Harvested-Major-Crops.csv")
px_csv("2E/CS", "0032E4ECNV0.px", "Crops/Openstat-Stocks-Rice-Corn.csv")


# ---- 3. Livestock & Poultry ------------------------------------------------
writeLines("Downloading Livestock & Poultry ...")

px_csv("2E/LP/PDN",     "0012E4FLPO0.px", "Livestock and Poultry/Openstat-Volume-of-Production-Livestock-Poultry.csv")
px_csv("2E/LP/INV/NEW", "0012E4FILP0.px", "Livestock and Poultry/Openstat-Inventory-Livestock-Poultry.csv")


# ---- 4. Fisheries ----------------------------------------------------------
writeLines("Downloading Fisheries ...")

px_csv("2E/FS", "0132E4GVFP1.px", "Fisheries/Openstat-Volume-of-Production-Fisheries-Subsector.csv")
px_csv("2E/FS", "0142E4GCFP1.px", "Fisheries/Openstat-Value-of-Production-Fisheries-Subsector.csv")
px_csv("2E/FS", "0112E4GVFP0.px", "Fisheries/Openstat-Volume-of-Production-Fisheries-Species.csv")


# ---- 5. Census of Agriculture & Fisheries (structural, 1960-2012) ----------
writeLines("Downloading Census of Agriculture & Fisheries ...")

px_csv("2E/AFC", "0472E6CNAF0.px", "Census/Openstat-CAF-Farms-Number-Area-Region.csv")
px_csv("2E/AFC", "0462E6CSOF0.px", "Census/Openstat-CAF-Farms-Size-of-Parcel.csv")
px_csv("2E/AFC", "0432E6CTSF0.px", "Census/Openstat-CAF-Parcels-Tenure.csv")
px_csv("2E/AFC", "0422E6CIRR0.px", "Census/Openstat-CAF-Farms-Irrigated.csv")


# ---- 6. Prices: Farmgate / Wholesale / Retail (New & Old, swept whole) ------
writeLines("Downloading Prices (farmgate / wholesale / retail) ...")

price_nodes <- tribble(
    ~node,        ~folder,                                       ~label,
    "2M/NFG",     "Farmgate Prices/New Series",                  "Farmgate-Prices",
    "2M/FG",      "Farmgate Prices/Old Series",                  "Farmgate-Prices",
    "2M/NWSNEW",  "Wholesale Prices/New Series (New Geo Code)",  "Wholesale-Prices",
    "2M/NWS",     "Wholesale Prices/New Series (Old Geo Code)",  "Wholesale-Prices",
    "2M/WS",      "Wholesale Prices/Old Series",                 "Wholesale-Prices",
    "2M/2018NEW", "Retail Prices/2018-based (New Geo Code)",     "Retail-Prices",
    "2M/2018",    "Retail Prices/2018-based (Old Geo Code)",     "Retail-Prices",
    "2M/NRP",     "Retail Prices/2012-based",                    "Retail-Prices",
    "2M/RP",      "Retail Prices/Old Series",                    "Retail-Prices"
)
pwalk(price_nodes, px_sweep)

writeLines("Done. Agriculture & Food data downloaded into Data/Agriculture and Food/.")

rm(list = ls())

