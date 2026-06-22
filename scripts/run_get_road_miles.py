"""
Script for calculating road miles per community board district by spatial
overlay of NYC street centerlines data (link in README.md) and CB geodata.

Reproject CRS to EPSG:2263 to calculate CB/centerline intersection in feet
Then convert to miles (feet / 5280)

Note that the type of road is in 'rw_type', represented as a string of the number:
    1 Street
    2 Highway
    3 Bridge
    4 Tunnel
    5 Boardwalk
    6 Path/Trail
    7 StepStreet
    8 Driveway
    9 Ramp
    10 Alley
    11 Unknown
    12 Non-Physical Street Segment
    13 U Turn
    14 Ferry Route

Output: dot_pothole_repairs_clean_borocd.parquet
Run: python run_get_road_miles.py
"""
import geopandas as gpd
import pandas as pd

# --- Paths for loading and saving
CB_GEODATA = "../data/raw/community_districts.geojson"
STREET_DATA = "../data/raw/centerlines.geojson"
OUTPUT = "../data/processed/road_miles_by_cd.parquet"

# --- Load streets centerlines data and community board polygons with some cleaning
streets = gpd.read_file(STREET_DATA)
cb = gpd.read_file(CB_GEODATA)
cb = (cb[['boro_cd', 'geometry']]
        .rename(columns={'boro_cd': 'borocd'})
        .astype({'borocd': 'int64'}))

# --- Filter to real road segments
KEEP_COLUMNS = ['geometry', 'rw_type']
KEEP_ROWS = ['1', '2', '3', '4', '9']
streets = streets[KEEP_COLUMNS].loc[streets['rw_type'].isin(KEEP_ROWS)]

# --- Re-project CRS
streets = streets.to_crs('EPSG:2263')
cb = cb.to_crs('EPSG:2263')

# --- Spatial overlay, calculate and aggregate road miles per CB
intersect = gpd.overlay(streets, cb, how='intersection')
intersect['miles'] = intersect.geometry.length / 5280
road_miles = (intersect
              .groupby('borocd')['miles']
              .sum()
              .reset_index()
              .rename(columns={'miles':'road_miles'}))
road_miles.to_parquet(OUTPUT, index=False)
print(f"Saved to {OUTPUT}")