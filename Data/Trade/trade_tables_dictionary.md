# Trade data tables (PH-Econ-Data / IMTS)

Source: PSA OpenStat International Merchandise Trade Statistics, annual value
tables. Values are current US dollars; exports valued FOB, imports CIF. Generated
by `loadTradeData.R` from the raw per-year CSVs (which are not committed).

Shared columns: `year` (int), `direction` ('Exports' or 'Imports'),
`value_usd` (numeric, current USD). `country` is a canonicalised label.
Partner/region/annual tables span all years; partner_group, semiconductors and
minerals are HS-era only.

## trade_annual.csv
One row per year. Columns: year, Exports, Imports, balance, total_trade (all USD).

## trade_by_partner.csv  [WHO]
Trade value by partner country. Columns: year, direction, country, region,
is_europe, is_asean, is_resid, value_usd. Spans all years and all countries.
`region` is one of North America, East Asia, ASEAN, Europe, Middle East, South
Asia, Oceania, Rest of world. `is_resid = TRUE` marks non-country aggregates
(e.g. 'South and Southeast Asia, N.E.S.') -- exclude these for clean rankings.

## trade_by_region.csv  [WHO, blocs]
Trade value by partner region. Columns: year, direction, region, value_usd.
(Roll-up of trade_by_partner.)

## trade_by_commodity.csv  [WHAT]
Trade value by commodity code, spanning all years. Columns: year, direction,
classification, code, chapter, chapter_label, group, value_usd.
`classification` = 'HS' (2007 onward; `code` is the HS subheading truncated to
the configured 6 digits) or 'PSCC' (pre-2007; `code` is the whole
7-digit Philippine code). `chapter` (2-digit), `chapter_label` and the 14-way
`group` are populated for HS rows only; roll up to them for HS-era composition,
or filter `code` for any specific product. PSCC rows carry the raw pre-2007
codes (interpret with the PSCC reference); they are not mapped to HS groups
because the two classifications are not directly comparable.

## trade_by_partner_group.csv  [WHO x WHAT]
Trade value by partner country x commodity group. Columns: year, direction,
country, group, value_usd. HS era only. Use for 'what does PH trade with X'.

## trade_semiconductors.csv  [product x WHO]
Semiconductor trade (HS 8541 + 8542) by partner. Columns: year, direction,
country, value_usd. HS era only.

## trade_minerals.csv  [product x WHO]
Mineral / metal trade by partner and type. Columns: year, direction, country,
mineral_type, value_usd. HS era only. `mineral_type`: Metal ores & concentrates
(26), Copper (74), Nickel (75), Gold (7108), Mineral fuels (27), Salt, stone &
earths (25), Lead, zinc & tin (78-80).

Coverage: 1991-2025; commodity by HS classification from 2007 onward, PSCC before that.
