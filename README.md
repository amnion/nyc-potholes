# NYC Potholes: Reporting Gap Analysis

Quantifying where citizen 311 pothole reports diverge from NYC Department of Transportation repair activity, across 59 NYC community districts, 2023-2024.

**Read the full write-up:** [Do 311 calls actually represent New Yorkers’ problems?](https://amnion.github.io/2026/06/22/nyc-potholes.html)  
**Interactive dashboard:** [Tableau Public](https://public.tableau.com/views/NYCPotholeReportingGapAnalysis/Dashboard?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

---

## TL;DR

Across 59 NYC community districts and two years of data, **not a single district shows a statistically significant reporting gap between citizens and the city** after correcting for demographics and road exposure. 311 reports and DOT work orders correlate at *r = 0.88* in their demographic-adjusted residuals. The 311 system, at least for potholes, tracks the city's own operational priorities closely.

---

## What's in this repo

A reproducible analytical pipeline that:
1. Fetches pothole reports (311) and repairs (DOT) from NYC OpenData
2. Spatially joins records to community district boundaries
3. Computes road-mile exposure per district from NYC street centerlines
4. Merges with ACS demographic covariates
5. Fits parallel negative binomial regression models in R
6. Bootstraps confidence intervals on per-district reporting gaps
7. Produces publication-quality figures for the write-up

**Stack:** Python (pandas, GeoPandas, matplotlib) · R (MASS, broom) · SQL (DuckDB) · Jupyter

---

## Pipeline

```text
NYC OpenData APIs
|
v   (00_fetch_data.py)
raw data (Parquet, GeoJSON)
|
v   (Python spatial joins: DOT centroids -> CDs; Centerlines -> road miles)
intermediate spatial outputs
|
v   (SQL cleaning files 01–05, run via run_cleaning.py)
data/final/analytical_table.parquet
|
v   (model_data.R)
model fits, residuals, bootstrap CIs
|
v   (FigureNotebook.ipynb)
publication figures
```

To reproduce:
```bash
# Set up environment
cp .env.example .env                # add your NYC OpenData app token

# Conda (recommended)
conda env create -f environment.yml
conda activate nyc-potholes
# Or, use pip
pip install -r requirements.txt

# Run the pipeline
python scripts/00_fetch_data.py     # see data table for manual downloads
python scripts/run_join_DOT_CB.py
python scripts/run_get_road_miles.py
python scripts/run_cleaning.py
Rscript scripts/model_data.R

# Build figures
jupyter notebook notebooks/FigureNotebook.ipynb
```

---

## Repository structure

```text
nyc-potholes/
├── data/
│   ├── raw/          # API pulls       (not included)
│   ├── processed/    # intermediate    (not included)
│   └── final/        # cleaned, processed for analysis
├── sql/              # 5 SQL files, run in order via run_cleaning.py
├── scripts/          # Python fetch/geospatial/orchestration, R modeling
└── figures/          # FigureNotebook.ipynb to make SVG and PNG figs
```

---

## Data sources

All sources are public. App token required for NYC OpenData API; everything else is direct download.

| Source | Description | Access |
|---|---|---|
| [311 Service Requests](https://data.cityofnewyork.us/Social-Services/311-Service-Requests-from-2010-to-Present/erm2-nwe9) | Citizen pothole reports | Socrata API |
| [Street Pothole Work Orders – Closed](https://data.cityofnewyork.us/Transportation/Street-Pothole-Work-Orders-Closed-Dataset-/x9wy-ing4) | DOT repair records | Socrata API |
| [Community Districts](https://data.cityofnewyork.us/City-Government/Community-Districts/5crt-au7u) | NYC's 59 sub-borough boundaries (v26b, May 2026) | GeoJSON download |
| [Street Centerlines](https://data.cityofnewyork.us/City-Government/Centerline/inkn-q76z) | NYC street network for road-mile calculation | GeoJSON download |
| [ACS 2019–2023 5-year](https://www.nyc.gov/content/planning/pages/resources/datasets/american-community-survey) | Demographic covariates at CD level | Excel workbooks |
| [NYC Community Boards](https://data.cityofnewyork.us/City-Government/NYC-Community-Boards/ruf7-3wgc/) | Community board metadata (for dashboard) | CSV |

**ACS extraction notes:** Demographic estimates were manually extracted from NYC Department of City Planning's Demographic, Economic, Housing, and Social ACS workbooks into `acs_covariates.csv`.

Variables retained: 
```text
Dem_1923_CDTA.xlsx      Pop_1E      ->  total_population
                        MdAgeE          median_age
Econ_1923_CDTA.xlsx     MdHHIncE        median_household_income
Hous_1923_CDTA.xlsx     ROcHU1P         pct_renters
                        RntVacRtE       rental_vacancy_rate
Soc_1923_CDTA.xlsx      EA_BchDHP       pct_with_college_degree
                        Fb1P        ->  pct_foreign_born
```
Variance and margin-of-error columns excluded.

---

## Method summary

**Unit of analysis:** 59 standard community districts (12 Joint Interest Areas incl. parks, airports were excluded).

**Model:** Negative binomial regression with `log(road_miles)` as exposure offset:

`n_reports_311 ~ log(total_population) + median_household_income + pct_renters + pct_foreign_born + offset(log(road_miles))`

`n_repairs_dot ~ ...`

**Gap measure:** Pearson residuals from each model; gap index = `resid_311 − resid_dot` per district.

**Inference:** Parametric bootstrap (2,000 iterations) for per-district CIs, with Benjamini-Hochberg correction across 59 simultaneous tests.

---

## Reproducibility notes

- **NYC OpenData app token** required: free at [data.cityofnewyork.us](https://data.cityofnewyork.us/profile/edit/developer_settings)
- **CRS:** All spatial work uses EPSG:2263 (NYC State Plane, feet). Length calculations are invalid in EPSG:4326.
- **R version:** Models tested on R 4.6.0 with `MASS`, `broom`, and base packages
- **Python version:** 3.13 with `pandas`, `geopandas`, `matplotlib`, `duckdb`, `python-dotenv`

---

## Author

Jacob Edwards (6/2026) · [portfolio](https://amnion.github.io) · [linkedin](https://www.linkedin.com/in/jacob-edwards-phd-740239124/) · [email](mailto:jacobedwards.jae@gmail.com)