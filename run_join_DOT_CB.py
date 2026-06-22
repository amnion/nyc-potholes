"""
Dept of Transportation data does not have Community Board data. Use the CB data
from NYC OpenData (link in README) and GeoPandas to join 3-digit comm board
code to latitude and longitude coordinates in DOT.

Note that both DOT and CB have CRS EPSG:4326 (latitude/longitude coordinates)
GeoPandas requires projected CRS to compute distances for nearest spatial join
Here I reproject the CRS to EPSG:2263 which is what CB lat/lon is derived from

Output: dot_pothole_repairs_clean_borocd.parquet
Run: python run_join_DOT_CB.py
"""
import geopandas as gpd
import pandas as pd

# --- Paths for loading and saving
DOT_INPUT = "data/processed/dot_pothole_repairs_clean.parquet"
CB_GEODATA = "data/raw/community_districts.geojson"
OUTPUT = "data/processed/dot_pothole_repairs_clean_borocd.parquet"

# --- Load cleaned DOT data and convert to GeoDataFrame
dot = pd.read_parquet(DOT_INPUT)
dot_gdf = gpd.GeoDataFrame(
    data=dot,
    geometry=gpd.points_from_xy(dot['centroid_lon'], dot['centroid_lat']),
    crs="EPSG:4326")

# --- Load community board polygons
cb = gpd.read_file(CB_GEODATA)

# --- Convert to a projected CRS because lat/lon gives wrong calculations
dot_gdf = dot_gdf.to_crs('EPSG:2263')
cb = cb.to_crs('EPSG:2263')

# --- Spatial join the two datasets
dot_cb_gdf = dot_gdf.sjoin_nearest(cb)

# --- Strip all CB columns except boro_cd and save to parquet
out = (dot_cb_gdf[list(dot.columns) + ['boro_cd']]
        .rename(columns={'boro_cd': 'borocd'})
        .astype({'borocd': 'int64'})
        .copy())
out['is_jia'] = (out['borocd'] % 100) >= 20 # flag for JIA
out.to_parquet(OUTPUT, index=False)
print(f"Saved to {OUTPUT}")