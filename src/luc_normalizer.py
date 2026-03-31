#!/usr/bin/env python3
"""
luc_normalizer.py

Append normalized luminescence data computed from a multi-sheet XLSX into ONE long CSV.

Usage pattern:
- Provide a single --csv path (default: Data/lum_long.csv).
- If --csv exists: read it and append new rows.
- If --csv does not exist: create it with the computed rows.

Computed per (Experiment, Replicate):
- VpA      = Volume / Area
- baseline = 5% quantile of VpA within the group
- VpA_base = VpA - baseline
- VpA_norm = VpA_base / mean(VpA_base of ref_sample rows in the same group)

Ref sample is specified as "NLuc-CLuc" via --ref-sample and is stored in column Ref_sample.

Expected XLSX columns per sheet:
  NLuc, CLuc, Replicate, Volume, Area
Experiment is taken from the sheet name.

New flag:
--deduplicate  Drops duplicates after append based on:
               (NLuc, CLuc, Experiment, Replicate, Ref_sample), keeping first.
"""

from __future__ import annotations

import argparse
import sys
import warnings
from pathlib import Path

import numpy as np
import pandas as pd


OUT_COLS = [
    "NLuc", "CLuc", "Experiment", "Replicate",
    "Volume", "Area", "VpA", "VpA_base", "VpA_norm", "Ref_sample"
]

DEDUP_KEYS = ["NLuc", "CLuc", "Experiment", "Replicate", "Ref_sample"]


def normalize_whitespace(x) -> str:
    if pd.isna(x):
        return np.nan
    return " ".join(str(x).strip().split())


def make_pair_id(nluc, cluc) -> str:
    if pd.isna(nluc) or pd.isna(cluc):
        return np.nan
    return f"{nluc}-{cluc}"


def process_sheet(df: pd.DataFrame, experiment: str, ref_sample: str, q: float) -> pd.DataFrame:
    required = ["NLuc", "CLuc", "Replicate", "Volume", "Area"]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise ValueError(f"Sheet '{experiment}' missing required columns: {missing}")

    df = df.copy().dropna(how="all")

    df["NLuc"] = df["NLuc"].map(normalize_whitespace)
    df["CLuc"] = df["CLuc"].map(normalize_whitespace)

    # Replicate can be numeric or string; keep as-is but normalize whitespace
    df["Replicate"] = df["Replicate"].map(normalize_whitespace)
    rep_num = pd.to_numeric(df["Replicate"], errors="coerce")
    if rep_num.notna().any():
        df["Replicate"] = rep_num.where(rep_num.notna(), df["Replicate"])

    # Empty cells -> NaN (kept!)
    df["Volume"] = pd.to_numeric(df["Volume"], errors="coerce")
    df["Area"] = pd.to_numeric(df["Area"], errors="coerce")

    df["Experiment"] = normalize_whitespace(experiment)
    df["Ref_sample"] = ref_sample

    df["VpA"] = df["Volume"] / df["Area"]
    df["_pair_id"] = df.apply(lambda r: make_pair_id(r["NLuc"], r["CLuc"]), axis=1)

    def qfun(series: pd.Series) -> float:
        return series.quantile(q, interpolation="linear")

    df["VpA_q"] = df.groupby(["Experiment", "Replicate"])["VpA"].transform(qfun)
    df["VpA_base"] = df["VpA"] - df["VpA_q"]

    # Reference mean per (Experiment, Replicate)
    ref_rows = df[df["_pair_id"] == ref_sample].copy()
    ref_map = (
        ref_rows.groupby(["Experiment", "Replicate"])["VpA_base"]
        .mean()
        .to_dict()
    )

    def compute_norm(row):
        key = (row["Experiment"], row["Replicate"])
        ref_v = ref_map.get(key, np.nan)
        if pd.isna(ref_v):
            return np.nan
        return row["VpA_base"] / ref_v

    df["VpA_norm"] = df.apply(compute_norm, axis=1)

    # Warn if ref missing in some groups
    groups = df[["Experiment", "Replicate"]].drop_duplicates()
    missing_ref = []
    for _, g in groups.iterrows():
        key = (g["Experiment"], g["Replicate"])
        if key not in ref_map or pd.isna(ref_map.get(key, np.nan)):
            missing_ref.append(key)
    if missing_ref:
        warnings.warn(
            f"Ref sample '{ref_sample}' missing/NA in: "
            + ", ".join([f"{e}:{r}" for e, r in missing_ref]),
            RuntimeWarning,
        )

    out = df[OUT_COLS].copy()
    out = out.dropna(subset=["NLuc", "CLuc", "Replicate"], how="any")
    return out


def main() -> int:
    p = argparse.ArgumentParser(
        description="Append VpA baseline (5% quantile) + ref normalization from multi-sheet XLSX into a single long CSV (creates it if missing)."
    )
    p.add_argument("--xlsx", required=True, help="Input Excel workbook (.xlsx) with multiple sheets.")
    p.add_argument(
        "--csv",
        default=str(Path("Data") / "lum_long.csv"),
        help="Long CSV path to read/append/write (default: Data/lum_long.csv).",
    )
    p.add_argument(
        "--ref-sample",
        required=True,
        help='Reference sample identifier as "NLuc-CLuc", e.g. "AtMLO1-AtCAM2".',
    )
    p.add_argument(
        "--quantile",
        type=float,
        default=0.01,
        help="Quantile used for baseline correction per (Experiment, Replicate). Default 0.01.",
    )
    p.add_argument(
        "--deduplicate",
        action="store_true",
        help="Drop duplicates after append using keys: NLuc, CLuc, Experiment, Replicate, Ref_sample (keep first).",
    )

    args = p.parse_args()
    q = float(args.quantile)
    if not (0.0 < q < 1.0):
        raise ValueError("--quantile must be between 0 and 1 (exclusive).")

    ref_sample = normalize_whitespace(args.ref_sample)
    csv_path = Path(args.csv)
    csv_path.parent.mkdir(parents=True, exist_ok=True)

    # Load existing long CSV if it exists, else start empty
    if csv_path.exists():
        long_df = pd.read_csv(csv_path)
        for c in OUT_COLS:
            if c not in long_df.columns:
                long_df[c] = np.nan
    else:
        long_df = pd.DataFrame(columns=OUT_COLS)

    # Process XLSX
    xl = pd.ExcelFile(args.xlsx)
    new_parts = []
    for sheet in xl.sheet_names:
        sheet_df = pd.read_excel(args.xlsx, sheet_name=sheet, engine="openpyxl")
        new_parts.append(process_sheet(sheet_df, experiment=sheet, ref_sample=ref_sample, q=q))

    new_df = pd.concat(new_parts, ignore_index=True) if new_parts else pd.DataFrame(columns=OUT_COLS)

    # Preserve any extra columns that may exist in long_df
    extras = [c for c in long_df.columns if c not in OUT_COLS]
    long_df = long_df[OUT_COLS + extras]
    for c in extras:
        if c not in new_df.columns:
            new_df[c] = np.nan
    new_df = new_df[OUT_COLS + extras]

    combined = pd.concat([long_df, new_df], ignore_index=True)

    removed = 0
    if args.deduplicate and not combined.empty:
        before = len(combined)
        # Only dedup on keys that actually exist
        keys = [k for k in DEDUP_KEYS if k in combined.columns]
        combined = combined.drop_duplicates(subset=keys, keep="first")
        removed = before - len(combined)

    combined.to_csv(csv_path, index=False, na_rep="")
    print(
        f"Wrote {len(new_df):,} new rows. "
        f"{'Removed ' + str(removed) + ' duplicates. ' if args.deduplicate else ''}"
        f"Long CSV now has {len(combined):,} rows at: {csv_path}"
    )
    return 0


if __name__ == "__main__":
    with warnings.catch_warnings():
        warnings.simplefilter("default", category=RuntimeWarning)
        sys.exit(main())