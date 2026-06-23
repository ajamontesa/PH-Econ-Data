# =============================================================================
# getPSALinks.R  -- helper sourced by downloadSNAData.R
# -----------------------------------------------------------------------------
# Scrapes the PSA National Accounts "data-series" page and leaves a character
# vector `psafiles` (absolute .xlsx URLs) in the environment, plus a reusable
# `psa_get()` for authenticated requests (also used by the download step).
#
# PSA sits behind a Cloudflare "managed challenge", so headless scraping fails.
# This instead reuses a `cf_clearance` cookie + matching User-Agent copied from
# a real browser that has already passed the challenge.
#
# REFRESH CREDENTIALS BEFORE EACH RUN (clearance lasts ~30-60 min):
#   1. Open the page in your normal browser and clear the "verify you are
#      human" check:
#        https://psa.gov.ph/statistics/national-accounts/data-series
#   2. Open DevTools (F12):
#        * Console tab  ->  type  navigator.userAgent   -> copy the string
#        * Storage tab  ->  Cookies -> https://psa.gov.ph
#                       ->  copy the VALUE of the `cf_clearance` cookie
#   3. Paste both into Scripts/psa_secrets.R (gitignored):
#        UA     <- "Mozilla/5.0 ( ... ) Firefox/128.0"
#        CFCOOK <- "xxxxxxxx..."
# =============================================================================

#library(httr)
#library(rvest)
#library(stringr)

# --- credentials -------------------------------------------------------------
# Use UA / CFCOOK already in the session; otherwise load the gitignored secrets.
if (!exists("UA") || !exists("CFCOOK")) {
    secrets <- "Scripts/psa_secrets.R"
    if (file.exists(secrets)) {
        source(secrets)
    } else {
        stop("PSA credentials not found. Set `UA` and `CFCOOK` in your session, ",
             "or create ", secrets, " (see the header of getPSALinks.R).")
    }
}

# --- authenticated GET against psa.gov.ph -----------------------------------
# Shared by the scrape below and the download step in downloadSNAData.R.
psa_get <- function(url, dest = NULL) {
    h <- add_headers(`User-Agent` = UA,
                     Cookie = paste0("cf_clearance=", CFCOOK))
    if (is.null(dest)) GET(url, h) else GET(url, h, write_disk(dest, overwrite = TRUE))
}

# --- scrape every .xlsx link from a PSA page --------------------------------
psa_xlsx_links <- function(url) {
    resp <- psa_get(url)
    if (status_code(resp) != 200)
        stop("PSA returned HTTP ", status_code(resp), " for ", url,
             " - cf_clearance cookie has likely expired; refresh it.")
    
    links <- read_html(resp) %>%
        html_elements("a[href$='.xlsx']") %>%
        html_attr("href") %>%
        unique()
    links <- ifelse(startsWith(links, "http"), links,
                    str_c("https://psa.gov.ph", links))
    
    # An expired cookie returns a Cloudflare challenge page WITH status 200 and
    # no .xlsx links, so treat an empty result as a credential/structure failure.
    if (length(links) == 0)
        stop("No .xlsx links found at ", url, " - either the page structure ",
             "changed, or the Cloudflare challenge re-triggered (refresh ",
             "your cf_clearance cookie).")
    links
}

# --- build the link vector ---------------------------------------------------
writeLines("Scraping PSA National Accounts data-series links ...")
psafiles <- psa_xlsx_links("https://psa.gov.ph/statistics/national-accounts/data-series")
writeLines(str_c("  ", length(psafiles), " .xlsx links found."))

# Regional accounts pages use the same mechanism; uncomment if you need them:
# psa_grdp_files <- psa_xlsx_links("https://psa.gov.ph/statistics/grdp/data-series")
# psa_grde_files <- psa_xlsx_links("https://psa.gov.ph/statistics/grde/data-series")