/*
================================================================================
File:        03_join_to_districts.sql
Purpose:     Produce the analytical comparison table: 311 reports vs DOT work
             orders, aggregated per community board per month.
             NOTE: is_jia is a flag for Joint-Interest-Area, excluded here
             but set to TRUE if you want to include.
Inputs:      data/processed/311_pothole_clean.parquet
             data/processed/dot_pothole_repairs_clean_borocd.parquet
Output:      One row per (borocd, report_month) with side-by-side counts.
             Should yield 1,416 rows. (3 rows with 311 and not DOT data)
Key outputs:
    - borocd: 3-digit community district code
    - report_month: month bucket
    - n_311_reports: count of 311 reports, zero where none occurred
    - n_dot_repairs: count of DOT work orders, zero where none occurred
    Dependencies: DuckDB. Run from project root.
Author:      Jacob Edwards 6/11/2026
================================================================================
*/
WITH reports_311_by_cb_month AS (
    SELECT borocd, report_month, COUNT(*) AS n_reports_311
    FROM 'data/processed/311_pothole_clean.parquet'
    WHERE is_jia IS FALSE
        AND borocd IS NOT NULL
    GROUP BY borocd, report_month
),
repairs_dot_by_cb_month AS (
    SELECT borocd, report_month, COUNT(*) AS n_repairs_dot
    FROM 'data/processed/dot_pothole_repairs_clean_borocd.parquet'
    WHERE is_jia IS FALSE
    GROUP BY borocd, report_month
),
joined AS (
    SELECT
        borocd,
        report_month,
        COALESCE(n_reports_311, 0) AS n_reports_311,
        COALESCE(n_repairs_dot, 0) AS n_repairs_dot
    FROM reports_311_by_cb_month
    FULL OUTER JOIN repairs_dot_by_cb_month
    USING(borocd, report_month)
)
SELECT * FROM joined
ORDER BY borocd, report_month;