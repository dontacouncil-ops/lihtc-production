# LIHTC Production in the Southeast

Data, code, and write-up for **Partners Update 1, "Where Does Southeastern LIHTC Build, and What Does It Build?"**, part of the Federal Reserve Bank of Atlanta Community and Economic Development research on Low-Income Housing Tax Credit (LIHTC) capital flows in the Sixth District.

The Southeast here is the six Sixth District states: Alabama, Florida, Georgia, Louisiana, Mississippi, and Tennessee.

## What is in this repository

```
partners-update/   The write-up (Word). Update 1 is the opening section of
                   the Partners Update series document.
analysis/          A self-contained reproduction package for Update 1.
    code/          Stata do-files (reproduce_update1.do runs end to end).
    data/          Source files, unmodified as downloaded (all public).
    output/        Figure and table values written by the do-files (CSV).
    REPRODUCTION_README.txt   Full reproduction notes.
    DATA_SOURCES.txt          Provenance for every source file.
```

## What Update 1 covers

Where the LIHTC builds in the Southeast and what it builds: production by state and per resident, the split across metropolitan, micropolitan, and rural areas, per-capita production across metros and micropolitan areas, target population, income ceiling, construction type, and the Gulf Opportunity Zone cohort.

## Reproducing the analysis

The package is self-contained; every input is in `analysis/data/`. In Stata, from `analysis/`:

```stata
do code/reproduce_update1.do
```

It reads the source files, builds the place-type crosswalks, and writes the figure and table values to `analysis/output/`. `code/reproduce_update1_verbose.do` is the same with narration, and `code/check_one_at_a_time.do` steps through interactively. Run `code/build_cbsa_crosswalks.do` first only if rebuilding the crosswalks from the OMB source list.

## Data sources

All inputs are public:

- HUD National LIHTC Database, 1987 to 2024 (`LIHTCPUB.xlsx`), with the 2024 data dictionary.
- OMB Bulletin 20-01 (March 2020) metropolitan and micropolitan delineation (`list1_2020_OMB_March2020.xls`), used for the metro, micro, and rural place-type crosswalk.
- 2020 Census county and state population.
- American Community Survey 2016 to 2020 five-year renter-household estimates.
- FFIEC 2020 census-tract file for tract characteristics.

See `analysis/DATA_SOURCES.txt` for full provenance and `analysis/REPRODUCTION_README.txt` for the field-level notes.

## Source line

HUD National LIHTC Database, authors' calculations.
