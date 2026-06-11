"""
Fetch NYC OpenData files via Socrata API and save as CSV and Parquet.
Free app token at https://data.cityofnewyork.us/profile/edit/developer_settings
Endpoints:
- https://data.cityofnewyork.us/resource/erm2-nwe9.json (311 Service Requests)
- https://data.cityofnewyork.us/resource/x9wy-ing4.json (DOT Pothole Work Orders)
Run: python 00_fetch_data.py
"""
# =============================================================================
# Imports
# =============================================================================
import os
import pandas as pd
from dotenv import load_dotenv
from sodapy import Socrata
from datetime import datetime
from shapely.geometry import shape
# =============================================================================
# Configure datasets
# =============================================================================
DATASETS = [
    {
        'name':         '311_pothole',
        'endpoint':     'erm2-nwe9',
        'limit':        200_000,
        'where':        (
            "complaint_type = 'Street Condition' "
            "AND descriptor IN ('Pothole', 'Pothole - Highway', 'Pothole - Tunnel') "
            "AND created_date >= '2023-01-01T00:00:00' "
            "AND created_date < '2025-01-01T00:00:00' "
        ),
        'date_cols':    ['created_date', 'closed_date', 'due_date', 'resolution_action_updated_date'],
        'numeric_cols': ['latitude', 'longitude', 'x_coordinate_state_plane', 'y_coordinate_state_plane'],
        'geom_col':     ''
    },
    {
        'name':         'dot_pothole_repairs',
        'endpoint':     'x9wy-ing4',
        'limit':        200_000,
        'where':        (
            "rptdate >= '2023-01-01T00:00:00' "
            "AND rptdate < '2025-01-01T00:00:00' "
        ),
        'date_cols':    ['rptdate', 'rptclosed'],
        'numeric_cols': ['shape_leng'],
        'geom_col':     'the_geom'
    }
]
# =============================================================================
# Define functions
# =============================================================================
def polyline_centroid_shapely(geom_dict):
    """Calculate the latitude/longitude centroid of a GeoJSON shape"""
    if not geom_dict:
        return (None, None)
    centroid = shape(geom_dict).centroid
    return (centroid.y, centroid.x)

def fetch_dataset(client, config):
    """Pull one dataset, coerce types, save to CSV and Parquet"""
    
    # Call the API
    results = client.get(
        dataset_identifier=config['endpoint'],
        where=config['where'],
        limit=config['limit']
    )

    # Socrata returns everything as strings. Coerce explicitly.
    df = pd.DataFrame.from_records(results)

    # Handle datetime columns
    for col in config['date_cols']:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors='coerce')

    # Handle numeric columns
    for col in config['numeric_cols']:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce')

    # Handle GeoJSON columns (for now, convert to lat/lon centroid)
    if config['geom_col'] in df.columns:
        df[['centroid_lat', 'centroid_lon']] = df[config['geom_col']].apply(
            polyline_centroid_shapely
        ).apply(pd.Series)
        df = df.drop(columns=config['geom_col'])

    # Save as CSV for human inspection and Parquet for the rest
    print(f'Pulled {len(df):,} rows on {datetime.now().isoformat()}')

    df.to_csv(f"data/raw/{config['name']}.csv", index=False)
    df.to_parquet(f"data/raw/{config['name']}.parquet", index=False)

    print(f"Saved to data/raw/{config['name']}")

# =============================================================================
# Main
# =============================================================================
if __name__ == "__main__":

    load_dotenv()
    APP_TOKEN = os.environ.get("SOCRATA_APP_TOKEN")
    if APP_TOKEN is None:
        raise RuntimeError("SOCRATA_APP_TOKEN not set. See README for setup.")
    client = Socrata("data.cityofnewyork.us", APP_TOKEN, timeout=60)

    for config in DATASETS:
        fetch_dataset(client, config)