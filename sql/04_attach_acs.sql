/*
================================================================================
File:        04_attach_acs.sql
Purpose:     Attach ACS demographic covariates to the (borocd, report_month)
             comparison table. Output is the modeling-ready analytical table
             (less road miles, which are added in 05_attach_road_miles.sql).
Inputs:      data/processed/joined_districts.parquet  (from 03_join_to_districts.sql)
             data/processed/acs_covariates.csv        (manually extracted from
                                                       NYC Population FactFinder
                                                       ACS 2019-2023; see
                                                       README.md)
Output:      One row per (borocd, report_month) with side-by-side report counts
             and static demographic covariates. ~1,416 rows.
Key outputs:
    - borocd, report_month: composite key
    - n_reports_311, n_repairs_dot: counts from the comparison table
    - total_population, median_age, median_household_income, pct_renters,
      rental_vacancy_rate, pct_with_college_degree, pct_foreign_born:
      ACS estimates, static across months for a given borocd
Notes:       ACS estimates carry margins of error that are not propagated here.
             See limitations in write-up.
Dependencies: DuckDB. Run from project root.
Author:      Jacob Edwards 6/12/2026
================================================================================
*/
WITH acs AS (
    SELECT
        CAST(
            CASE
                WHEN GeoID LIKE 'MN%' THEN '1'
                WHEN GeoID LIKE 'BX%' THEN '2'
                WHEN GeoID LIKE 'BK%' THEN '3'
                WHEN GeoID LIKE 'QN%' THEN '4'
                WHEN GeoID LIKE 'SI%' THEN '5'
            END || SUBSTRING(GeoID, 3, 2)
            AS INTEGER
        ) AS borocd,
        CAST(REPLACE(Pop_1E, ',', '') AS INTEGER) AS total_population,
        CAST(MdAgeE AS FLOAT) AS median_age,
        CAST(REPLACE(MdHHIncE, ',', '') AS INTEGER) AS median_household_income,
        CAST(ROcHU1P AS FLOAT) AS pct_renters,
        CAST(RntVacRtE AS FLOAT) AS rental_vacancy_rate,
        CAST(EA_BchDHP AS FLOAT) AS pct_with_college_degree,
        CAST(Fb1P AS FLOAT) AS pct_foreign_born
    FROM 'data/processed/acs_covariates.csv'
    WHERE CDTAType = 'CD'  -- exclude JIA rows from ACS upstream of join
)
SELECT
    comparison.borocd,
    comparison.report_month,
    comparison.n_reports_311,
    comparison.n_repairs_dot,
    acs.total_population,
    acs.median_age,
    acs.median_household_income,
    acs.pct_renters,
    acs.rental_vacancy_rate,
    acs.pct_with_college_degree,
    acs.pct_foreign_born
FROM 'data/processed/joined_districts.parquet' AS comparison
LEFT JOIN acs
    USING (borocd)
ORDER BY borocd, report_month;