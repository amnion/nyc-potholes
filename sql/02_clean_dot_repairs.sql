/*
================================================================================
File:        02_clean_dot_repairs.sql
Purpose:     Clean and enrich raw NYC DOT pothole work orders for downstream
             analysis.
Inputs:      data/raw/dot_pothole_repairs.parquet (pulled via 00_fetch_data.py)
Output:      One row per deduplicated work order with spelled-out borough,
             derived time fields, and polyline centroid coordinates.
             Approximately 32,376 rows.
Key outputs:
    - borough: full name (matches 311 convention)
    - report_month: rptdate truncated to month, for time-series aggregation
    - days_to_close: rptclosed - rptdate in days
    - source: retained for limitations analysis (citizen vs DOT-internal mix)
    - centroid_lat / centroid_lon: polyline centroid; spatial join to community
      board happens in 03_join_to_districts.sql
Dependencies: DuckDB. Run from project root.
Author:      Jacob Edwards 6/7/2026
================================================================================
*/
WITH source AS (
    -- Column selection happens here; no separate type-handling required
    -- because fetch script coerces dates and numerics at pull time.
    SELECT
        onfacename,
        boro,
        source,
        rptdate,
        rptclosed,
        centroid_lat,
        centroid_lon
    FROM 'data/raw/dot_pothole_repairs.parquet'
), repairs_filtered AS (
    SELECT *
    FROM source
    WHERE
        (rptdate >= CAST('2023-01-01' AS TIMESTAMP) AND rptdate < CAST('2025-01-01' AS TIMESTAMP))
), repairs_enriched AS (
    SELECT *,
        -- Spell out borough to match 311 dataset conventions.
        CASE
            WHEN boro = 'M' THEN 'MANHATTAN'
            WHEN boro = 'X' THEN 'BRONX'
            WHEN boro = 'B' THEN 'BROOKLYN'
            WHEN boro = 'Q' THEN 'QUEENS'
            WHEN boro = 'S' THEN 'STATEN ISLAND'
        END AS borough,
        -- Bucket by report date (when DOT was notified), not closure date.
        -- Aligns temporally with 311 created_date for gap comparison.
        DATE_TRUNC('month', rptdate) AS report_month,
        -- Useful for secondary "time-to-closure by district" dashboard view.
        DATE_DIFF('day', rptdate, rptclosed) AS days_to_close
    FROM repairs_filtered
), repairs_ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY centroid_lat, centroid_lon, DATE(rptclosed)
            ORDER BY rptclosed ASC
        ) AS row_num
    FROM repairs_enriched
), repairs_deduped AS (
    SELECT *
    FROM repairs_ranked
    WHERE row_num = 1
)
SELECT * EXCLUDE (boro, row_num)
FROM repairs_deduped;