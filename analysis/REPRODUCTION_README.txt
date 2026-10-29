PARTNERS UPDATE 1 REPRODUCTION PACKAGE
Where Does Southeastern LIHTC Build, and What Does It Build?
Federal Reserve Bank of Atlanta, Community and Economic Development

Source: HUD National LIHTC Database, authors' calculations.


-------------------------------------------------------------------------------
1. WHAT IS IN THIS FOLDER
-------------------------------------------------------------------------------

  /data     Source files, unmodified as downloaded.
              LIHTCPUB.xlsx                    HUD National LIHTC Database,
                                               55,345 records, 1987-2024
              LIHTC_Data_Dictionary_2024.pdf   HUD field definitions
              cbsa_march2020.csv               county FIPS to metro/micro
              cbsa_titles_march2020.csv        county FIPS to CBSA code and title
              list1_2020_OMB_March2020.xls     OMB Bulletin 20-01 source list
              county_pop_2020.csv              2020 Census county population
              state_pop_2020.csv               2020 Census state population
              county_renter_hh_2020_acs5.csv   ACS 2016-2020 renter households

  /code     Stata do-files.
              build_cbsa_crosswalks.do         builds the crosswalks from the
                                               OMB source list (run first only
                                               if rebuilding crosswalks)
              reproduce_update1.do             MAIN SCRIPT: runs end to end
              reproduce_update1_verbose.do     same, with narration
              check_one_at_a_time.do           step-by-step interactive version
              check_one_at_a_time_verbose.do   same, with narration

  /output   Calculation files produced by the code (also supplied separately).

  DATA_SOURCES.txt   Provenance, retrieval dates, and URLs for every input.


-------------------------------------------------------------------------------
2. HOW TO RUN
-------------------------------------------------------------------------------

  Stata 14.2 or later. No user-written packages required.

  1. Unzip this folder to a location with write access.
  2. Open Stata and set the working directory to the unzipped folder:
         cd "C:/path/to/Update1_reproduction"
  3. Run:
         do code/reproduce_update1.do

  The script sets its own paths from the working directory. A guard block at
  the top of each section stops the run with error 601 if the working directory
  is not the unzipped folder, rather than writing output to the wrong place.

  Output CSVs are written to /output. The script prints a confirmation line for
  each exhibit and stops on any assert that fails.


-------------------------------------------------------------------------------
3. VERIFICATION BUILT INTO THE CODE
-------------------------------------------------------------------------------

  The do-file contains 35 assert statements that check reproduced values
  against the printed figures. If a value drifts, the run halts at that point.
  Examples:

      assert reldif(units, 72237)<0.001 if proj_st=="FL"
      assert abs(round(per100k)-698)<=1 if proj_st=="MS"
      assert abs(round(rate_se)-457)<=2 if placetype=="Metro"

  A successful run to completion means every checked value reproduced.


-------------------------------------------------------------------------------
4. KNOWN GAP: THREE TABLE 1 COLUMNS ARE NOT PRODUCED BY THIS CODE
-------------------------------------------------------------------------------

  Read this before using Table 1.

  The Table 1 section of reproduce_update1.do collapses to:

      collapse (count) projects=_one (sum) units=tot liunits=li,
               by(proj_st statepop)
      gen lishare = liunits/units
      gen per100k = units/statepop*100000

  It therefore produces, and asserts, only these columns:

      Projects | Units | Low-income units | Avg. size | Units per 100k

  The printed Table 1 also carries three further columns:

      9% credit | New constr. | In QCT

  These are NOT generated or checked by this code. They were produced outside
  this package and their derivation is not documented here.

  Independent recomputation from LIHTCPUB (August 2026) reproduced every
  column this code does produce, exactly, for all six states and the regional
  total. It did not reproduce the 9% credit or New constr. columns under any
  of seven definitions tested: analysis windows 2008-2024 and 1987-2024;
  project-count, N_UNITSR-weighted, and LI_UNITR-weighted shares; CREDIT==2
  and CREDIT in (2,3); TYPE==1 and TYPE in (1,3); and a BOND-field proxy.
  The largest divergence is Mississippi, where the table prints 74 percent for
  9% credit against 43 to 47 percent on recomputation. The In QCT column is
  closely approximated by a project-weighted share of QCT==1.

  Action: confirm these three columns against the code that generated them, or
  recompute and update the table, before the figures are cited externally.


-------------------------------------------------------------------------------
5. METHODOLOGY THAT MUST BE PRESERVED
-------------------------------------------------------------------------------

  Four choices materially change the results. Each is implemented in the code
  and each is a common place to go wrong.

  (a) Unit weighting.
      Production and geography figures use N_UNITSR (total units), because they
      are set against unrestricted population denominators. Composition figures
      use LI_UNITR (income-restricted units), because the characteristics
      measured are properties of restricted units.

  (b) Place type and the unclassified records.
      County FIPS is built as st2020 zero-padded to 2 digits plus cnty2020
      zero-padded to 3 digits, then joined to the OMB March 2020 delineation.
      A county in an MSA is metropolitan, in a Micropolitan Statistical Area is
      micropolitan, and in neither is rural.

      Records with missing or invalid county geography (11.4 percent of
      regional income-restricted units) are dropped from BOTH the numerator and
      the denominator. A record with no county can be assigned neither a place
      type nor a population.

      If unmatched records are instead treated as rural, the Southeast rural
      rate inflates from 366 to 564 per 100,000. This is pure numerator
      inflation; the population denominator does not change.

  (c) Southeast-only denominators for the renter exhibit.
      Figures 3a and 3b restrict multi-state CBSAs to their Southeastern
      counties on BOTH sides. Memphis is the test case: 34.7 units per 1,000
      renter households when computed correctly, 33.3 if the whole CBSA
      denominator is used.

  (d) Reporting base for composition figures.
      Figures 5 through 10 divide by units in records that report the
      characteristic, not by all income-restricted units. Completeness differs
      by characteristic: in the region, 61 percent of income-restricted units
      report a target population, 51 percent an income ceiling, and 88 percent
      a construction type (58, 66, and 88 percent nationally).


-------------------------------------------------------------------------------
6. UNIVERSE AND EXCLUSIONS
-------------------------------------------------------------------------------

  Southeast          AL, FL, GA, LA, MS, TN
  Production window  placed in service 2008-2024 (Table 1, Figures 1-4)
  Composition window placed in service 1987-2024 (Figures 5-10)
  Cohorts            1987-1994, then five-year bands through 2020-2024

  Excluded from all year-based figures:
    Records coded 8888 or 9999 in YR_PIS: 2,765 records and 225,252 units
    nationally, of which only 254 records fall in the region.

  Excluded from national series:
    Puerto Rico, Guam, Virgin Islands, Northern Marianas, American Samoa,
    0.69 percent of national units, so that place-type numerators cover the
    same universe as the population denominators, which are drawn from the
    fifty states and the District of Columbia.


-------------------------------------------------------------------------------
7. KNOWN DATA ISSUES IN THE HUD FILE
-------------------------------------------------------------------------------

  Georgia credit coding. Post-2020 bond-financed deals in Georgia are coded as
  competitive 9 percent credit. This does not affect the figures printed in
  Update 1, but it distorts any credit-type time series and must be handled
  before interpreting one.

  NONPROG flag. The no-longer-monitored flag is one-sided, with roughly
  20 percent coverage. It cannot support nonprofit versus for-profit
  comparisons; that requires HFA sources-and-uses records.

  Excel date conversion. Cohort labels 05-09 and 10-14 are read as dates by
  Excel on import. The exports wrap these as text formulas, ="05-09", so that
  the CSVs open correctly. Do not strip the wrapper.


-------------------------------------------------------------------------------
8. INTERPRETATION LIMITS DISCLOSED IN THE UPDATE
-------------------------------------------------------------------------------

  Per-resident rates divide a 2008-2024 production flow by 2020 Census
  population, so states that grew quickly across the window are understated
  relative to states that grew slowly.

  Place type is assigned from the March 2020 delineation for every project
  regardless of when it was placed in service, so a county that gained
  metropolitan status during the period is treated as metropolitan throughout.
  HUD's own METRO field, measured at placed in service, will differ.

  Regional-to-national comparisons on a reporting base assume non-reporting is
  unrelated to the characteristic measured, which this file cannot test.


FULL-COVERAGE UPDATE: All Update 1 figures. fig1_2_placetype_rates.csv regenerated to match the do-file.
