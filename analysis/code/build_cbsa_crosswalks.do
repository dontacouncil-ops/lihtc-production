*==============================================================================*
* build_cbsa_crosswalks.do
*
* Rebuilds the two CBSA crosswalks used by this package DIRECTLY from the
* original OMB delineation file, so their provenance is fully public and
* verifiable. You do not need to run this to reproduce Update 1 (the finished
* CSVs already ship); it exists so the crosswalks can be audited or refreshed.
*
* PRIMARY SOURCE (public, fixed):
*   OMB / U.S. Census Bureau, March 2020 delineation file, list1_2020.xls.
*   Authority: OMB Bulletin No. 20-01 (March 6, 2020).
*   URL: https://www2.census.gov/programs-surveys/metro-micro/geographies/
*        reference-files/2020/delineation-files/list1_2020.xls
*   Shipped here as: data/list1_2020_OMB_March2020.xls
*
* WHAT IT PRODUCES (both are deterministic transforms of the file above):
*   data/cbsa_march2020.csv         fips, pt                     (county -> type)
*   data/cbsa_titles_march2020.csv  fips, cbsa, cbsa_title, pt   (adds code+title)
*
* TRANSFORM (no modeling, no external data):
*   1. Read list1_2020.xls (the table starts on the third row).
*   2. Build the 5-digit county FIPS = FIPS State Code + FIPS County Code.
*   3. pt = "metro" if the area is a Metropolitan Statistical Area, else "micro".
*   4. Keep county FIPS, CBSA code, CBSA title, and pt. One row per county.
*   Counties in neither list are non-CBSA (rural); they simply do not appear here.
*==============================================================================*
clear all
set more off
local data "`c(pwd)'/data"

import excel using "`data'/list1_2020_OMB_March2020.xls", cellrange(A3) firstrow clear

* Standardize the column names we need (Stata may import them with spaces stripped).
* Expected: CBSACode, CBSATitle, MetropolitanMicropolitanStati (status), FIPSStateCode, FIPSCountyCode.
capture confirm variable CBSACode
if _rc {
    di as error "Column names differ from expected; open the file and adjust names."
    exit 111
}
gen str5 fips = FIPSStateCode + FIPSCountyCode
gen str5 cbsa = CBSACode
rename CBSATitle cbsa_title
gen str5 pt = "micro"
* The status column name is long; grab it positionally if needed.
capture confirm variable MetropolitanMicropolitanStati
if !_rc replace pt = "metro" if strpos(MetropolitanMicropolitanStati,"Metropolitan")>0
drop if missing(fips)

* Titled crosswalk (superset).
preserve
    keep fips cbsa cbsa_title pt
    order fips cbsa cbsa_title pt
    export delimited using "`data'/cbsa_titles_march2020.csv", replace
    di as res "Wrote cbsa_titles_march2020.csv (`=_N' county rows)."
restore

* County -> type crosswalk (the smaller file the geography figures use).
preserve
    keep fips pt
    order fips pt
    export delimited using "`data'/cbsa_march2020.csv", replace
    di as res "Wrote cbsa_march2020.csv (`=_N' county rows)."
restore

di as res "Both crosswalks rebuilt from list1_2020_OMB_March2020.xls."
