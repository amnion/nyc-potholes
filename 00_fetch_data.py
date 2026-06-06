"""
Fetch NYC 311 pothole reports from Socrata API and save as Parquet.
Endpoint: https://data.cityofnewyork.us/resource/erm2-nwe9.json (311 Service Requests)
Run: python 00_fetch_data.py
"""
import os
import pandas as pd
from dotenv import load_dotenv
from sodapy import Socrata
from datetime import datetime

# Anonymous access works but is rate-limited; an app token raises the cap.
# Get a free token at https://data.cityofnewyork.us/profile/edit/developer_settings

load_dotenv()  # reads .env into os.environ

APP_TOKEN = os.environ.get("SOCRATA_APP_TOKEN")
if APP_TOKEN is None:
    raise RuntimeError("SOCRATA_APP_TOKEN not set. See README for setup.")

client = Socrata("data.cityofnewyork.us", APP_TOKEN, timeout=60)

# Socrata uses SoQL — a SQL-flavored query language. This is the entire query:
where_clause = (
    "complaint_type = 'Street Condition' "
    "AND descriptor IN ('Pothole', 'Pothole, Highway') "  # adjust after you've eyeballed descriptors
    "AND created_date >= '2023-01-01T00:00:00' "
    "AND created_date < '2025-01-01T00:00:00'"
)

results = client.get(
    "erm2-nwe9",
    where=where_clause,
    limit=100  # Socrata defaults to 1000
)

# Socrata returns everything as strings. Coerce explicitly.
df = pd.DataFrame.from_records(results)

# Datetime columns
date_cols = ['created_date', 'closed_date', 'due_date', 'resolution_action_updated_date']
for col in date_cols:
    if col in df.columns:
        df[col] = pd.to_datetime(df[col], errors='coerce')

# Numeric columns
numeric_cols = ['latitude', 'longitude', 'x_coordinate_state_plane', 'y_coordinate_state_plane']
for col in numeric_cols:
    if col in df.columns:
        df[col] = pd.to_numeric(df[col], errors='coerce')


# Save as CSV for human inspection and Parquet for the rest
print(f"Pulled {len(df):,} rows on {datetime.now().isoformat()}")

df.to_csv("data/raw/311_pothole.csv", index=False)
df.to_parquet("data/raw/311_pothole.parquet", index=False)

print("Saved to data/raw/311_pothole.{csv,parquet}")