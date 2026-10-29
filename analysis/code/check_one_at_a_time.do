*==============================================================================*
* check_one_at_a_time.do  -  reproduce Partners Update 1, one step at a time.
* Run STEP 0 first each session (it saves output/clean.dta); then run any step.
* Each step reloads what it needs, so steps are independent and order-free.
* Set the working folder to this folder first, e.g.  cd "/path/to/Update1_reproduction".
*==============================================================================*

* Path globals (survive across single-step runs); each step also re-sets them.
global REPRO_DIR "`c(pwd)'"
if "${REPRO_DIR}"=="" global REPRO_DIR "."
global data "${REPRO_DIR}/data"
global out  "${REPRO_DIR}/output"
capture mkdir "${out}"
capture confirm file "${data}/cbsa_march2020.csv"
if _rc {
    di as error "Data files not found under ${data}."
    di as error "Set the working folder first, e.g.:"
    di as error `"  cd "/Users/you/Downloads/Update1_reproduction" "'
    exit 601
}

*==============================================================================*
* STEP 0 - SETUP: import HUD data, build keys and flags, save clean.dta and cw.dta.
* Key vars created: tot, li, se, terr, year, badyear, fips, placetype, has_type/has_ceil/has_targ, trgt_*_y.
* Calc: force numerics with real(string()), build 5-digit fips = st2020*1000+cnty2020, merge county to place type.
*==============================================================================*

global REPRO_DIR "`c(pwd)'"
if "${REPRO_DIR}"=="" global REPRO_DIR "."
global data "${REPRO_DIR}/data"
global out  "${REPRO_DIR}/output"
capture mkdir "${out}"
capture confirm file "${data}/cbsa_march2020.csv"
if _rc {
    di as error "Data files not found under ${data}. Set the folder first, e.g.:"
    di as error `"  cd "/Users/you/Downloads/Update1_reproduction" "'
    exit 601
}

* Load the county-to-place-type crosswalk and save it for later merges.
import delimited using "${data}/cbsa_march2020.csv", varnames(1) stringcols(1) clear
save "${out}/cw.dta", replace

* Load the raw HUD LIHTC database (all 55,345 project records).
import excel using "${data}/LIHTCPUB.xlsx", firstrow clear
di as res "Imported " _N " rows."

* Keep only the fields the analysis uses.
keep hud_id proj_st yr_pis yr_alloc st2020 cnty2020 ///
     n_unitsr li_unitr type credit inc_ceil dda ///
     trgt_fam trgt_eld trgt_dis trgt_hml trgt_oth non_prof

* Force each analysis field to numeric (Excel import can read some as text).
capture confirm numeric variable yr_pis
if _rc destring yr_pis, replace force
capture confirm numeric variable yr_alloc
if _rc destring yr_alloc, replace force
capture confirm numeric variable st2020
if _rc destring st2020, replace force
capture confirm numeric variable cnty2020
if _rc destring cnty2020, replace force
capture confirm numeric variable n_unitsr
if _rc destring n_unitsr, replace force
capture confirm numeric variable li_unitr
if _rc destring li_unitr, replace force
capture confirm numeric variable type
if _rc destring type, replace force
capture confirm numeric variable credit
if _rc destring credit, replace force
capture confirm numeric variable inc_ceil
if _rc destring inc_ceil, replace force
capture confirm numeric variable dda
if _rc destring dda, replace force
capture confirm numeric variable non_prof
if _rc destring non_prof, replace force
* Build clean 0/1 target-population indicators from the raw flags.
gen byte trgt_fam_y = (real(string(trgt_fam))==1)
gen byte trgt_eld_y = (real(string(trgt_eld))==1)
gen byte trgt_dis_y = (real(string(trgt_dis))==1)
gen byte trgt_hml_y = (real(string(trgt_hml))==1)
gen byte trgt_oth_y = (real(string(trgt_oth))==1)

* Total units (tot) drive production and geography; low-income units (li) drive composition.
gen double tot = real(string(n_unitsr))   // total units      (production/geography)
gen double li  = real(string(li_unitr))   // income-restricted (composition)
replace tot = 0 if missing(tot)
replace li  = 0 if missing(li)

* Flag the six Southeastern states and the excluded territories.
gen byte se   = inlist(proj_st,"AL","FL","GA","LA","MS","TN")
gen byte terr = inlist(proj_st,"PR","GU","VI","MP","AS")

* Placed-in-service year, and a flag for missing or sentinel years (8888/9999) to drop.
gen int year = yr_pis
gen byte badyear = missing(year) | year==8888 | year==9999 | year<1987 | year>2024

* Allocation year (kept for reference).
gen int ayear = yr_alloc

* Build the 5-digit county FIPS = state(2) + county(3), zero-padded, for the crosswalk merge.
gen double _st = real(string(st2020))
gen double _cn = real(string(cnty2020))
gen str5 fips = ""
replace fips = string(_st,"%02.0f") + string(_cn,"%03.0f") ///
    if !missing(_st) & !missing(_cn)
replace fips = "" if fips=="00000"
drop _st _cn

* Report how many non-territory records carry a sentinel year (these are excluded downstream).
count if (year==8888 | year==9999) & !terr
di as res "Records with sentinel yr_pis (8888/9999), non-territory: " r(N)

* Attach each project to its place type (metro / micro / rural) by county.
merge m:1 fips using "${out}/cw.dta", keep(master match) nogen

* Human-readable place-type label from the crosswalk code.
gen str12 placetype = ""
replace placetype = "Metro" if pt=="metro"
replace placetype = "Micropolitan" if pt=="micro"
replace placetype = "Rural" if missing(pt) & fips!=""
replace placetype = "Unclassified" if fips==""
drop pt

* Reporting-base flags: 1 if the development records construction type / ceiling / target.
gen byte has_type = inlist(type,1,2,3,4)
gen byte has_ceil = inlist(inc_ceil,1,2,3)
gen byte has_targ = (trgt_fam_y|trgt_eld_y|trgt_dis_y|trgt_hml_y|trgt_oth_y)

save "${out}/clean.dta", replace
di as res _n "STEP 0 done. clean.dta and cw.dta saved. You can now run any step below."

*==============================================================================*
* STEP 1 - TABLE 1: state production and units per 100,000 residents, 2008-2024.
* Key vars: tot (units), li (income-restricted), statepop (2020 Census); creates projects, units, liunits, lishare, per100k.
* Calc: collapse to one row per state, per100k = units/statepop*100000.
*==============================================================================*
capture noisily global REPRO_DIR "`c(pwd)'"
if "${REPRO_DIR}"=="" global REPRO_DIR "."
global data "${REPRO_DIR}/data"
global out  "${REPRO_DIR}/output"
capture mkdir "${out}"

capture confirm file "${out}/clean.dta"
if _rc {
    di as error "clean.dta not found. Run STEP 0 first (it saves output/clean.dta)."
    exit 601
}
use "${out}/clean.dta", clear
keep if se & !badyear & year>=2008 & year<=2024   // production window

gen double statepop = .
replace statepop = 5024279  if proj_st=="AL"
replace statepop = 21538187 if proj_st=="FL"
replace statepop = 10711908 if proj_st=="GA"
replace statepop = 4657757  if proj_st=="LA"
replace statepop = 2961279  if proj_st=="MS"
replace statepop = 6910840  if proj_st=="TN"

gen byte _one = 1
collapse (count) projects=_one (sum) units=tot liunits=li, by(proj_st statepop)
gen lishare  = liunits/units
gen per100k  = units/statepop*100000

list proj_st projects units liunits lishare per100k, ///
    noobs sep(0) abbrev(12)

assert reldif(units, 72237)<0.001 & reldif(liunits,69926)<0.001 if proj_st=="FL"
assert reldif(units, 66896)<0.001 & reldif(liunits,64353)<0.001 if proj_st=="GA"
assert reldif(units, 40149)<0.001 & reldif(liunits,39999)<0.001 if proj_st=="TN"
assert reldif(units, 30163)<0.001 & reldif(liunits,25944)<0.001 if proj_st=="LA"
assert reldif(units, 20684)<0.001 & reldif(liunits,20325)<0.001 if proj_st=="MS"
assert reldif(units, 10570)<0.001 & reldif(liunits,10527)<0.001 if proj_st=="AL"
assert abs(round(per100k)-335)<=1 if proj_st=="FL"
assert abs(round(per100k)-625)<=1 if proj_st=="GA"
assert abs(round(per100k)-698)<=1 if proj_st=="MS"
di as res "TABLE 1 reproduced."

export delimited using "${out}/table1_state.csv", replace

*==============================================================================*
* STEP 2 - FIGURES 1-2: units per 100,000 residents by place type (Metro/Micro/Rural), SE and US.
* Key vars: tot, placetype, county pop; creates units_se/us, pop_se/us, rate_se/us.
* Calc: numerator and denominator collapsed on the same county set, rate = units/pop*100000.
*==============================================================================*
capture noisily global REPRO_DIR "`c(pwd)'"
if "${REPRO_DIR}"=="" global REPRO_DIR "."
global data "${REPRO_DIR}/data"
global out  "${REPRO_DIR}/output"
capture mkdir "${out}"

import delimited using "${data}/county_pop_2020.csv", varnames(1) clear ///
    stringcols(1)
merge m:1 fips using "${out}/cw.dta", keep(master match) nogen
gen str12 placetype = "Rural"
replace placetype = "Metro" if pt=="metro"
replace placetype = "Micropolitan" if pt=="micro"
gen byte se_c = inlist(state_name,"Alabama","Florida","Georgia", ///
    "Louisiana","Mississippi","Tennessee")
save "${out}/_countybase.dta", replace
collapse (sum) pop_us=pop, by(placetype)
save "${out}/_popus.dta", replace
use "${out}/_countybase.dta", clear
keep if se_c
collapse (sum) pop_se=pop, by(placetype)
merge 1:1 placetype using "${out}/_popus.dta", nogen
save "${out}/_ptpop.dta", replace

capture confirm file "${out}/clean.dta"
if _rc {
    di as error "clean.dta not found. Run STEP 0 first (it saves output/clean.dta)."
    exit 601
}
use "${out}/clean.dta", clear
keep if !terr & !badyear & year>=2008 & year<=2024 & placetype!="Unclassified"
save "${out}/_numbase.dta", replace
collapse (sum) units_us=tot, by(placetype)
save "${out}/_numus.dta", replace
use "${out}/_numbase.dta", clear
keep if se
collapse (sum) units_se=tot, by(placetype)
merge 1:1 placetype using "${out}/_numus.dta", nogen
merge 1:1 placetype using "${out}/_ptpop.dta", nogen

* Rate = units / residents * 100,000, computed for each place type, SE and US.
gen rate_us = units_us/pop_us*100000
gen rate_se = units_se/pop_se*100000
order placetype units_us pop_us rate_us units_se pop_se rate_se
list, noobs sep(0) abbrev(12)

assert abs(round(rate_se)-457)<=2 if placetype=="Metro"
assert abs(round(rate_se)-479)<=2 if placetype=="Micropolitan"
assert abs(round(rate_se)-366)<=2 if placetype=="Rural"
assert abs(round(rate_us)-529)<=2 if placetype=="Metro"
assert abs(round(rate_us)-394)<=2 if placetype=="Micropolitan"
assert abs(round(rate_us)-241)<=2 if placetype=="Rural"
di as res "FIGURES 1-2 reproduced. SE: metro 457, micro 479, rural 366. US: metro 529, micro 394, rural 241."
di as txt "  Rural excludes records with no 2020 county geography (unclassified),"
di as txt "  consistent with the population denominator and with Figure 10. Earlier"
di as txt "  drafts placed those unclassified units in the rural numerator, which"
di as txt "  inflated rural to 564 (SE) and 439 (US); see the measurement audit."

export delimited using "${out}/fig1_2_placetype_rates.csv", replace

*==============================================================================*
* STEP 3 - FIGURES 1-2 and TABLE 1, renter-household denominator (ROBUSTNESS VARIANT, not printed).
* Key vars: tot, placetype, renter_households (ACS B25003); creates per-1,000-renter rates.
* Calc: same as Steps 1-2 but divides by renter households instead of residents.
*==============================================================================*
capture noisily global REPRO_DIR "`c(pwd)'"
if "${REPRO_DIR}"=="" global REPRO_DIR "."
global data "${REPRO_DIR}/data"
global out  "${REPRO_DIR}/output"
capture mkdir "${out}"

import delimited using "${data}/county_renter_hh_2020_acs5.csv", ///
    varnames(1) stringcols(1) clear
merge m:1 fips using "${out}/cw.dta", keep(master match) nogen
gen str12 placetype = "Rural"
replace placetype = "Metro" if pt=="metro"
replace placetype = "Micropolitan" if pt=="micro"
gen str2 stab = substr(fips,1,2)
gen byte se = inlist(stab,"01","12","13","22","28","47")
save "${out}/_renterbase.dta", replace
keep if se
* Renter-household denominator (ACS B25003) as a robustness variant of Figures 1-2 and Table 1.
collapse (sum) renter_pt=renter, by(placetype)
save "${out}/_rhpt.dta", replace
use "${out}/_renterbase.dta", clear
collapse (sum) renter_st=renter, by(stab)
gen proj_st = ""
replace proj_st = "AL" if stab=="01"
replace proj_st = "FL" if stab=="12"
replace proj_st = "GA" if stab=="13"
replace proj_st = "LA" if stab=="22"
replace proj_st = "MS" if stab=="28"
replace proj_st = "TN" if stab=="47"
keep if proj_st!=""
save "${out}/_rhst.dta", replace

capture confirm file "${out}/clean.dta"
if _rc {
    di as error "clean.dta not found. Run STEP 0 first (it saves output/clean.dta)."
    exit 601
}
use "${out}/clean.dta", clear
keep if se & !badyear & year>=2008 & year<=2024
collapse (sum) units=tot, by(proj_st)
merge 1:1 proj_st using "${out}/_rhst.dta", keep(match) nogen
gen per1000_renter = units/renter_st*1000
gsort -per1000_renter
list proj_st units renter_st per1000_renter, noobs sep(0) abbrev(16)
assert abs(per1000_renter-59.3)<0.3 if proj_st=="MS"
assert abs(per1000_renter-18.2)<0.3 if proj_st=="AL"
assert abs(per1000_renter-26.9)<0.3 if proj_st=="FL"
di as res "TABLE 1 (renter-household variant) reproduced."
di as txt "  ROBUSTNESS VARIANT of Table 1: units per 1,000 renter households."
di as txt "  Ranking MS>LA>GA>TN>FL>AL matches the per-100k-residents ranking."
di as txt "  This CSV is not a printed Table 1 column."
export delimited using "${out}/table1_state_per1000renter.csv", replace

capture confirm file "${out}/clean.dta"
if _rc {
    di as error "clean.dta not found. Run STEP 0 first (it saves output/clean.dta)."
    exit 601
}
use "${out}/clean.dta", clear
keep if se & !badyear & year>=2008 & year<=2024 & placetype!="Unclassified"
collapse (sum) units=tot, by(placetype)
merge 1:1 placetype using "${out}/_rhpt.dta", keep(match) nogen
gen per1000_renter = units/renter_pt*1000
list placetype units renter_pt per1000_renter, noobs sep(0) abbrev(16)
assert abs(per1000_renter-36.1)<0.3 if placetype=="Metro"
assert abs(per1000_renter-39.4)<0.3 if placetype=="Micropolitan"
assert abs(per1000_renter-35.5)<0.5 if placetype=="Rural"
di as res "FIGURES 1-2 (renter-household variant) reproduced. SE: metro 36.1, micro 39.4, rural 35.5."
di as txt "  Micropolitan is highest, matching the resident-denominator result."
di as txt "  Rural excludes unclassified records, consistent with the numerator."
di as txt "  ROBUSTNESS VARIANT of Figures 1-2: this CSV is not a printed figure."
export delimited using "${out}/fig1_2_placetype_per1000renter.csv", replace

*==============================================================================*
* STEP 4 - FIGURES 3a-3b: top metropolitan and micropolitan areas by renter households, with LIHTC units per 100,000 residents and per 1,000 renter households, 2008-2024.
* Key vars: tot, cbsa_title, cbsapop (residents), cbsarent (renter households); creates units, per100k, per1000rent by CBSA.
* Calc: collapse units, residents, and renter households to CBSA on one county set; rank by renter households; per100k = units/residents*100000, per1000rent = units/renters*1000. SE branch uses SE-state counties on both numerator and denominator (straddle-line CBSAs use only their SE-state counties); the national branch uses whole-CBSA denominators. Old top-by-units lists are retained as supporting output.
*==============================================================================*
capture noisily global REPRO_DIR "`c(pwd)'"
if "${REPRO_DIR}"=="" global REPRO_DIR "."
global data "${REPRO_DIR}/data"
global out  "${REPRO_DIR}/output"
capture mkdir "${out}"

capture confirm file "${out}/clean.dta"
if _rc {
    di as error "clean.dta not found. Run STEP 0 first (it saves output/clean.dta)."
    exit 601
}
import delimited using "${data}/cbsa_titles_march2020.csv", varnames(1) stringcols(1) clear
save "${out}/_cbsatitles.dta", replace
* Residents by CBSA
import delimited using "${data}/county_pop_2020.csv", varnames(1) stringcols(1) clear
merge m:1 fips using "${out}/_cbsatitles.dta", keep(master match) nogen
drop if missing(cbsa_title)
collapse (sum) cbsapop=pop, by(cbsa_title pt)
save "${out}/_cbsapop.dta", replace
* Renter households by CBSA
import delimited using "${data}/county_renter_hh_2020_acs5.csv", varnames(1) stringcols(1) clear
merge m:1 fips using "${out}/_cbsatitles.dta", keep(master match) nogen
drop if missing(cbsa_title)
collapse (sum) cbsarent=renter, by(cbsa_title pt)
save "${out}/_cbsarent.dta", replace
* SE-only CBSA denominators (SE-state counties only), for the SE branch so the
* numerator (SE-state units) and denominators (SE-state residents and renters)
* cover the same county set. Straddle-line CBSAs use only their SE-state counties.
import delimited using "${data}/county_pop_2020.csv", varnames(1) stringcols(1) clear
merge m:1 fips using "${out}/_cbsatitles.dta", keep(master match) nogen
drop if missing(cbsa_title)
keep if inlist(substr(fips,1,2),"01","12","13","22","28","47")
collapse (sum) cbsapop_se=pop, by(cbsa_title pt)
save "${out}/_cbsapopse.dta", replace
import delimited using "${data}/county_renter_hh_2020_acs5.csv", varnames(1) stringcols(1) clear
merge m:1 fips using "${out}/_cbsatitles.dta", keep(master match) nogen
drop if missing(cbsa_title)
keep if inlist(substr(fips,1,2),"01","12","13","22","28","47")
collapse (sum) cbsarent_se=renter, by(cbsa_title pt)
save "${out}/_cbsarentse.dta", replace
import delimited using "${data}/cbsa_titles_march2020.csv", varnames(1) stringcols(1) clear
save "${out}/_cbsatitles2.dta", replace
* US CBSA units
use "${out}/clean.dta", clear
keep if !terr & !badyear & year>=2008 & year<=2024
merge m:1 fips using "${out}/_cbsatitles2.dta", keep(master match) nogen
drop if missing(cbsa_title)
collapse (sum) units=tot, by(cbsa_title pt)
merge 1:1 cbsa_title pt using "${out}/_cbsapop.dta", keep(match) nogen
merge 1:1 cbsa_title pt using "${out}/_cbsarent.dta", keep(match) nogen
gen per100k = units/cbsapop*100000
gen per1000rent = units/cbsarent*1000
save "${out}/_cbsaus.dta", replace
* SE CBSA units
use "${out}/clean.dta", clear
keep if se & !badyear & year>=2008 & year<=2024
merge m:1 fips using "${out}/_cbsatitles2.dta", keep(master match) nogen
drop if missing(cbsa_title)
collapse (sum) units=tot, by(cbsa_title pt)
merge 1:1 cbsa_title pt using "${out}/_cbsapopse.dta", keep(match) nogen
merge 1:1 cbsa_title pt using "${out}/_cbsarentse.dta", keep(match) nogen
gen per100k = units/cbsapop_se*100000
gen per1000rent = units/cbsarent_se*1000
save "${out}/_cbsase.dta", replace
* Supporting output: national ranked-by-units lists (not printed figures)
use "${out}/_cbsaus.dta", clear
keep if pt=="metro"
gsort -units
export delimited using "${out}/metros_all_us.csv", replace
use "${out}/_cbsaus.dta", clear
keep if pt=="micro"
gsort -units
export delimited using "${out}/micros_all_us.csv", replace
* FIGURE 3a: SE metros ranked by renter households
use "${out}/_cbsase.dta", clear
keep if pt=="metro"
gsort -cbsarent
di as res "FIGURE 3a - Southeastern metros by renter households (top 10 shown):"
list cbsa_title cbsarent units per100k per1000rent in 1/10, noobs sep(0) abbrev(48)
export delimited using "${out}/fig3a_metros_renter_se.csv", replace
export delimited using "${out}/metros_all_se.csv", replace
assert abs(per100k-459)<=1 if cbsa_title=="Miami-Fort Lauderdale-Pompano Beach, FL"
assert abs(per1000rent-32.3)<0.2 if cbsa_title=="Miami-Fort Lauderdale-Pompano Beach, FL"
assert abs(per100k-549)<=1 if cbsa_title=="Atlanta-Sandy Springs-Alpharetta, GA"
assert abs(per1000rent-43.4)<0.2 if cbsa_title=="Atlanta-Sandy Springs-Alpharetta, GA"
assert abs(units-33444)<=2 if cbsa_title=="Atlanta-Sandy Springs-Alpharetta, GA"
* FIGURE 3b: SE micropolitans ranked by renter households
use "${out}/_cbsase.dta", clear
keep if pt=="micro"
gsort -cbsarent
di as res "FIGURE 3b - Southeastern micropolitans by renter households (top 10 shown):"
list cbsa_title cbsarent units per100k per1000rent in 1/10, noobs sep(0) abbrev(48)
export delimited using "${out}/fig3b_micros_renter_se.csv", replace
export delimited using "${out}/micros_all_se.csv", replace
assert abs(per100k-603)<=1 if cbsa_title=="Tupelo, MS"
assert abs(per1000rent-59.1)<0.2 if cbsa_title=="Tupelo, MS"
di as res "FIGURES 3a-3b reproduced (renter-household ranking; two per-capita denominators)."
di as res "  Supporting national lists: metros_all_us / micros_all_us (ranked by units)."

*==============================================================================*
* STEP 5 - FIGURE 4: Gulf Opportunity Zone designated vs other units by year, AL/LA/MS, 2000-2024.
* Key vars: tot, dda (GO Zone codes 3,4); creates gozone, total by year.
* Calc: sum designated (dda in 3,4) and total units per year, then merge the two series.
*==============================================================================*
capture noisily global REPRO_DIR "`c(pwd)'"
if "${REPRO_DIR}"=="" global REPRO_DIR "."
global data "${REPRO_DIR}/data"
global out  "${REPRO_DIR}/output"
capture mkdir "${out}"

capture confirm file "${out}/clean.dta"
if _rc {
    di as error "clean.dta not found. Run STEP 0 first (it saves output/clean.dta)."
    exit 601
}
use "${out}/clean.dta", clear
keep if inlist(proj_st,"AL","LA","MS") & !badyear & year>=2000 & year<=2024
* Gulf Opportunity Zone flag: HUD difficult-development-area codes 3 and 4.
gen byte goz = inlist(dda,3,4)

save "${out}/_gozbase.dta", replace
collapse (sum) gozone=tot if goz, by(year)
save "${out}/_gozone.dta", replace
use "${out}/_gozbase.dta", clear
collapse (sum) total=tot, by(year)
merge 1:1 year using "${out}/_gozone.dta", nogen
replace gozone = 0 if missing(gozone)
gen other = total - gozone
list year gozone other total, noobs sep(0)

quietly sum gozone
di as res "GO Zone designated total units (AL/LA/MS): " %9.0f r(sum)
assert abs(r(sum)-26118)<=5
quietly sum total if year==2008
local t2008 = r(sum)
quietly sum gozone if year==2008
di as res "2008 designated share: " %4.1f r(sum)/`t2008'*100 "%"
assert abs(r(sum)/`t2008'*100-78)<=1
di as res "FIGURE 4 reproduced."
export delimited using "${out}/fig4_gozone.csv", replace

capture confirm file "${out}/clean.dta"
if _rc {
    di as error "clean.dta not found. Run STEP 0 first (it saves output/clean.dta)."
    exit 601
}
use "${out}/clean.dta", clear
keep if proj_st=="FL" & inlist(dda,3,4)
quietly sum tot
di as res "Florida designated total units (Wilma zone, excluded from Fig 5): " %9.0f r(sum)
assert abs(r(sum)-9858)<=5

*==============================================================================*
* STEP 6 - FIGURES 5-6: target-population composition (Family/Elderly/Other), pooled and by cohort, SE and US.
* Key vars: li, tp (target category), coh (cohort); creates share.
* Calc: single target per development by priority, share = category li / cohort total li (den).
*==============================================================================*
capture noisily global REPRO_DIR "`c(pwd)'"
if "${REPRO_DIR}"=="" global REPRO_DIR "."
global data "${REPRO_DIR}/data"
global out  "${REPRO_DIR}/output"
capture mkdir "${out}"

capture confirm file "${out}/clean.dta"
if _rc {
    di as error "clean.dta not found. Run STEP 0 first (it saves output/clean.dta)."
    exit 601
}
use "${out}/clean.dta", clear
keep if !badyear & has_targ                       // reporting base

* Assign one target category per development by priority (Family, then Elderly, then Other).
gen str8 tp = ""
replace tp = "Family"  if trgt_fam_y
replace tp = "Elderly" if trgt_eld_y & tp==""
replace tp = "Other"   if (trgt_dis_y|trgt_hml_y|trgt_oth_y) & tp==""
drop if tp==""

* Group placed-in-service years into cohorts for the over-time panels.
gen str5 coh = ""
replace coh = "87-94" if year>=1987 & year<=1994
replace coh = "95-99" if year>=1995 & year<=1999
replace coh = "00-04" if year>=2000 & year<=2004
replace coh = "05-09" if year>=2005 & year<=2009
replace coh = "10-14" if year>=2010 & year<=2014
replace coh = "15-19" if year>=2015 & year<=2019
replace coh = "20-24" if year>=2020 & year<=2024

save "${out}/_prep6.dta", replace

foreach g in SE US {
    use "${out}/_prep6.dta", clear
    if "`g'"=="SE" keep if se
    quietly sum li
    local den = r(sum)
    foreach c in Family Elderly Other {
        quietly sum li if tp=="`c'"
        di as res "Fig6 `g' `c': " %4.1f r(sum)/`den'*100 "%"
    }
}

use "${out}/_prep6.dta", clear
keep if se
collapse (sum) li, by(coh tp)
bysort coh: egen cohtot = total(li)
gen share = li/cohtot*100
keep coh tp share
gen region = "SE"
save "${out}/_fig7_se.dta", replace
use "${out}/_prep6.dta", clear
keep if !terr
collapse (sum) li, by(coh tp)
bysort coh: egen cohtot = total(li)
gen share = li/cohtot*100
keep coh tp share
gen region = "US"
save "${out}/_fig7_us.dta", replace
use "${out}/_fig7_se.dta", clear
append using "${out}/_fig7_us.dta"
order region coh tp share
sort region coh tp
replace coh = char(61) + char(34) + coh + char(34)  // lock coh as text so Excel does not read 05-09 / 10-14 as dates
export delimited using "${out}/fig5_6_targetpop_cohort.csv", replace
use "${out}/_fig7_se.dta", clear
drop region
reshape wide share, i(coh) j(tp) string
list, noobs sep(0)
assert abs(shareFamily-56.0)<1 if coh=="20-24"
replace coh = char(61) + char(34) + coh + char(34)  // lock coh as text so Excel does not read 05-09 / 10-14 as dates
export delimited using "${out}/fig5_6_targetpop_cohort_se.csv", replace
use "${out}/_fig7_us.dta", clear
reshape wide share, i(coh) j(tp) string
assert abs(shareFamily-59.5)<1 if coh=="20-24"
di as res "FIGURES 5-6 reproduced (SE and US)."

*==============================================================================*
* STEP 7 - FIGURES 7-8: income-ceiling composition (50%/60%/income averaging), pooled and by cohort, SE and US.
* Key vars: li, ic (ceiling token), coh; creates share.
* Calc: share = ceiling-category li / cohort total li, using reshape-safe tokens c50/c60/IncAvg.
*==============================================================================*
capture noisily global REPRO_DIR "`c(pwd)'"
if "${REPRO_DIR}"=="" global REPRO_DIR "."
global data "${REPRO_DIR}/data"
global out  "${REPRO_DIR}/output"
capture mkdir "${out}"

capture confirm file "${out}/clean.dta"
if _rc {
    di as error "clean.dta not found. Run STEP 0 first (it saves output/clean.dta)."
    exit 601
}
use "${out}/clean.dta", clear
keep if !badyear & has_ceil                       // reporting base
* Income-ceiling label from inc_ceil (50% / 60% AMGI / income averaging).
gen str12 ic = ""
replace ic = "c50"  if inc_ceil==1
replace ic = "c60"  if inc_ceil==2
replace ic = "IncAvg" if inc_ceil==3
gen str5 coh = ""
replace coh = "87-94" if year>=1987 & year<=1994
replace coh = "95-99" if year>=1995 & year<=1999
replace coh = "00-04" if year>=2000 & year<=2004
replace coh = "05-09" if year>=2005 & year<=2009
replace coh = "10-14" if year>=2010 & year<=2014
replace coh = "15-19" if year>=2015 & year<=2019
replace coh = "20-24" if year>=2020 & year<=2024
save "${out}/_prep7.dta", replace

foreach g in SE US {
    use "${out}/_prep7.dta", clear
    if "`g'"=="SE" keep if se
    quietly sum li
    local den = r(sum)
    foreach c in "c50" "c60" "IncAvg" {
        local lbl "`c'"
        if "`c'"=="c50" local lbl "50% AMGI"
        if "`c'"=="c60" local lbl "60% AMGI"
        if "`c'"=="IncAvg" local lbl "Income averaging"
        quietly sum li if ic=="`c'"
        di as res "Fig8 `g' `lbl': " %4.1f r(sum)/`den'*100 "%"
    }
}
use "${out}/_prep7.dta", clear
keep if se
quietly sum li
local d=r(sum)
quietly sum li if ic=="c60"
assert abs(r(sum)/`d'*100-91.9)<0.3

use "${out}/_prep7.dta", clear
keep if se
collapse (sum) li, by(coh ic)
bysort coh: egen cohtot = total(li)
gen share = li/cohtot*100
keep coh ic share
gen region = "SE"
save "${out}/_fig9_se.dta", replace
use "${out}/_prep7.dta", clear
keep if !terr
collapse (sum) li, by(coh ic)
bysort coh: egen cohtot = total(li)
gen share = li/cohtot*100
keep coh ic share
gen region = "US"
save "${out}/_fig9_us.dta", replace
use "${out}/_fig9_se.dta", clear
append using "${out}/_fig9_us.dta"
order region coh ic share
sort region coh ic
replace coh = char(61) + char(34) + coh + char(34)  // lock coh as text so Excel does not read 05-09 / 10-14 as dates
export delimited using "${out}/fig7_8_ceiling_cohort.csv", replace
use "${out}/_fig9_se.dta", clear
drop region
reshape wide share, i(coh) j(ic) string
list, noobs sep(0) abbrev(20)
replace coh = char(61) + char(34) + coh + char(34)  // lock coh as text so Excel does not read 05-09 / 10-14 as dates
export delimited using "${out}/fig7_8_ceiling_cohort_se.csv", replace
di as res "FIGURES 7-8 reproduced (SE and US)."

*==============================================================================*
* STEP 8 - FIGURES 9-10: construction-type composition (New/Rehab/Both), by place type and by cohort.
* Key vars: li, ct (construction token), coh, placetype; creates share.
* Calc: share = construction-category li / group total li (by place type for Fig 10, by cohort for Fig 11).
*==============================================================================*
capture noisily global REPRO_DIR "`c(pwd)'"
if "${REPRO_DIR}"=="" global REPRO_DIR "."
global data "${REPRO_DIR}/data"
global out  "${REPRO_DIR}/output"
capture mkdir "${out}"

capture confirm file "${out}/clean.dta"
if _rc {
    di as error "clean.dta not found. Run STEP 0 first (it saves output/clean.dta)."
    exit 601
}
use "${out}/clean.dta", clear
keep if !badyear & has_type                       // reporting base
* Construction-type label from type (New / Acquisition and rehab / Both).
gen str12 ct = ""
replace ct = "New"   if type==1
replace ct = "Rehab" if type==2
replace ct = "Both"  if type==3
drop if ct==""

gen str5 coh = ""
replace coh = "87-94" if year>=1987 & year<=1994
replace coh = "95-99" if year>=1995 & year<=1999
replace coh = "00-04" if year>=2000 & year<=2004
replace coh = "05-09" if year>=2005 & year<=2009
replace coh = "10-14" if year>=2010 & year<=2014
replace coh = "15-19" if year>=2015 & year<=2019
replace coh = "20-24" if year>=2020 & year<=2024
save "${out}/_prep8.dta", replace

use "${out}/_prep8.dta", clear
keep if se & inlist(placetype,"Metro","Micropolitan","Rural")
collapse (sum) li, by(placetype ct)
bysort placetype: egen den = total(li)
gen share = li/den*100
keep placetype ct share
reshape wide share, i(placetype) j(ct) string
list, noobs sep(0) abbrev(24)
assert abs(shareNew-73.0)<0.6 if placetype=="Metro"
export delimited using "${out}/fig9_constr_placetype_se.csv", replace

use "${out}/_prep8.dta", clear
keep if se
collapse (sum) li, by(coh ct)
bysort coh: egen den = total(li)
gen share = li/den*100
keep coh ct share
gen region = "SE"
save "${out}/_fig11_se.dta", replace
use "${out}/_prep8.dta", clear
keep if !terr
collapse (sum) li, by(coh ct)
bysort coh: egen den = total(li)
gen share = li/den*100
keep coh ct share
gen region = "US"
save "${out}/_fig11_us.dta", replace
use "${out}/_fig11_se.dta", clear
append using "${out}/_fig11_us.dta"
order region coh ct share
sort region coh ct
replace coh = char(61) + char(34) + coh + char(34)  // lock coh as text so Excel does not read 05-09 / 10-14 as dates
export delimited using "${out}/fig10_constr_cohort.csv", replace
use "${out}/_fig11_se.dta", clear
drop region
reshape wide share, i(coh) j(ct) string
list, noobs sep(0) abbrev(24)
replace coh = char(61) + char(34) + coh + char(34)  // lock coh as text so Excel does not read 05-09 / 10-14 as dates
export delimited using "${out}/fig10_constr_cohort_se.csv", replace
di as res "FIGURES 9-10 reproduced (Figure 10: SE and US)."
