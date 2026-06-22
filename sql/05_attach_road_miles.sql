/*
================================================================================
File:        05_attach_road_miles.sql
Purpose:     Attach road miles data from NYC street centerlines to analytical
             table
Inputs:      data/processed/analytical_table_no_roads.parquet
             data/processed/road_miles_by_cd.parquet
Output:      One row per (borocd, report_month) with side-by-side report counts,
             and static road mile and demographic covariates. ~1,416 rows.
Key outputs:
    - borocd: 3-digit community district code
    - report_month: month bucket
    - n_311_reports: count of 311 reports, zero where none occurred
    - n_dot_repairs: count of DOT work orders, zero where none occurred
    Dependencies: DuckDB. Run from project root.
Author:      Jacob Edwards 6/13/2026
================================================================================
*/
SELECT
    a.borocd,
    a.report_month,
    a.n_reports_311,
    a.n_repairs_dot,
    a.total_population,
    a.median_age,
    a.median_household_income,
    a.pct_renters,
    a.rental_vacancy_rate,
    a.pct_with_college_degree,
    a.pct_foreign_born,
    r.road_miles
FROM 'data/processed/analytical_table_no_roads.parquet' AS a
LEFT JOIN 'data/processed/road_miles_by_cd.parquet' AS r
    USING (borocd)
ORDER BY a.borocd, a.report_month;