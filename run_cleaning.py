"""
Run SQL cleaning files and save results to data/processed
Run: python run_cleaning.py
"""
import duckdb
from pathlib import Path

con = duckdb.connect()

# Map of SQL file -> output Parquet
PIPELINE = [
    ("sql/01_clean_311.sql",           "data/processed/311_pothole_clean.parquet"),
    ("sql/02_clean_dot_repairs.sql",   "data/processed/dot_pothole_repairs_clean.parquet")
]

for sql_path, output_path in PIPELINE:
    sql = Path(sql_path).read_text()
    df  = con.sql(sql).df()
    df.to_parquet(output_path, index=False)
    print(f"{sql_path} -> {output_path}: {len(df):,} rows")