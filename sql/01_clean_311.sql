/*
================================================================================
File:        01_clean_311.sql
Purpose:     Clean and enrich raw NYC 311 pothole reports for downstream 
             analysis.
Inputs:      data/raw/311_pothole.parquet (pulled via 00_fetch_data.py)
Output:      One row per de-duplicated pothole report, with derived geographic 
             identifiers and time fields. Should yield 72,640 rows.
Key outputs: 
    - borocd: 3-digit standard NYC community district code (NULL if unknown)
    - is_jia: TRUE for Joint Interest Areas (parks, airports, non-residential)
    - report_month: created_date truncated to month, for time-series aggregation
    - days_to_close: closed_date - created_date in days (NULL for pending)
Dependencies: DuckDB. Run from project root.
Author:      Jacob Edwards 6/7/2026
================================================================================
*/
WITH source AS (
    -- Pull data from raw parquet file, select columns
    SELECT 
        unique_key,
        created_date,
        closed_date,
        status,
        borough,            -- already uppercase in source
        community_board,    -- "NN BOROUGH" format, parse below
        incident_zip,
        address_type,       -- already uppercase in source
        latitude,
        longitude
    FROM 'data/raw/311_pothole.parquet'
), complaints_filtered AS (
    -- Enforce time window, key existence, some geospatial data
    SELECT *
    FROM source
    WHERE
        (created_date >= CAST('2023-01-01' AS TIMESTAMP) AND created_date < CAST('2025-01-01' AS TIMESTAMP))
        AND (unique_key IS NOT NULL)
        AND (
            (longitude IS NOT NULL AND latitude IS NOT NULL) 
            OR community_board NOT LIKE '0 %'
            )
), complaints_enriched AS (
    -- Transform community board string to BoroCD identifiers, flags for interesting locales
    SELECT *,
        -- BoroCD identifiers
        CASE 
            WHEN community_board LIKE '%Unspecified%'
                THEN NULL
            ELSE CAST(
                CASE
                    WHEN community_board LIKE '% MANHATTAN' THEN '1'
                    WHEN community_board LIKE '% BRONX' THEN '2'
                    WHEN community_board LIKE '% BROOKLYN' THEN '3'
                    WHEN community_board LIKE '% QUEENS' THEN '4'
                    WHEN community_board LIKE '% STATEN ISLAND' THEN '5'
                END || SPLIT_PART(community_board, ' ', 1)
                AS INTEGER 
            )
        END AS borocd,
        -- Joint Interest Area flag (JIA; parks etc)
        CASE
            WHEN community_board LIKE '%Unspecified%'
                THEN NULL
            ELSE CAST(
                SPLIT_PART(community_board, ' ', 1) 
                AS INTEGER
                ) >= 20
        END AS is_jia,
        -- Report month
        DATE_TRUNC('month', created_date) AS report_month,
        -- Time to close
        DATE_DIFF('day', created_date, closed_date) AS days_to_close
    FROM complaints_filtered
), complaints_ranked AS (
    SELECT *,
    CASE
        WHEN latitude IS NOT NULL
            THEN ROW_NUMBER() OVER (
                PARTITION BY latitude, longitude, DATE(created_date)
                ORDER BY created_date ASC
            )
        ELSE 1 -- no-coord rows cant be determined if duplicate; keep all
    END AS row_num
    FROM complaints_enriched
), complaints_deduped AS (
    SELECT *
    FROM complaints_ranked
    WHERE row_num = 1
) 
SELECT * EXCLUDE (row_num) 
FROM complaints_deduped;