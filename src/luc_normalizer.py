#!/usr/bin/env python3
import re
import argparse
import pandas as pd
from pandas.api.types import is_numeric_dtype


SHEET_RE = re.compile(r"^(?P<nluc>.+?)_Experiment_(?P<experiment>[0-9]+(?:\.[0-9]+)?)$")


def parse_sheet_name(sheet_name: str):
    """
    'AtMLO2_Experiment_1.1' -> (NLuc='AtMLO2', experiment='1')
    """
    m = SHEET_RE.match(sheet_name.strip())
    if not m:
        return sheet_name.strip(), sheet_name.strip()
    nluc = m.group("nluc").strip()
    exp_full = m.group("experiment").strip()
    exp_int = exp_full.split(".")[0]
    return nluc, exp_int


def parse_replicate_from_control(control_name: str):
    """
    'AtCAM2.3' -> (base='AtCAM2', rep=3)
    """
    control_name = str(control_name).strip()
    m = re.match(r"^(?P<base>.+?)(?:\.(?P<rep>\d+))?$", control_name)
    base = m.group("base")
    rep = m.group("rep")
    return base, (int(rep) if rep is not None else None)


def wrap_rep_1_to_4(rep: int) -> int:
    return ((int(rep) - 1) % 4) + 1


def require_numeric(df: pd.DataFrame, col: str, sheet_name: str):
    """
    Enforce that a column is numeric. If not, raise with a preview of offending values.
    """
    if is_numeric_dtype(df[col]):
        return

    # Try a strict conversion (no coercion): will raise if any non-numeric exists
    try:
        df[col] = pd.to_numeric(df[col], errors="raise")
    except Exception as e:
        # Show a small preview of values that look non-numeric
        preview = df[[col]].head(20).to_string(index=False)
        raise ValueError(
            f"Sheet '{sheet_name}': column '{col}' is not numeric (and strict conversion failed).\n"
            f"Top values preview:\n{preview}\n"
            f"Original error: {e}"
        )


def reshape_one_sheet(df: pd.DataFrame, sheet_name: str, control_prefix: str):
    nluc, experiment = parse_sheet_name(sheet_name)

    df = df.copy()
    df.columns = [str(c).strip() for c in df.columns]

    required = {"EXO70", "Volume", "Area"}
    if not required.issubset(df.columns):
        raise ValueError(
            f"Sheet '{sheet_name}' is missing required columns. "
            f"Found: {list(df.columns)}; need: {sorted(required)}"
        )

    df = df.dropna(subset=["EXO70"], how="all")
    df["EXO70"] = df["EXO70"].astype(str).str.strip()

    # ✅ strict numeric enforcement (no silent NaNs)
    require_numeric(df, "Volume", sheet_name)
    require_numeric(df, "Area", sheet_name)

    # Identify control rows (end of each replicate block)
    is_control = df["EXO70"].str.startswith(control_prefix)
    control_idx = df.index[is_control].tolist()
    if not control_idx:
        raise ValueError(f"Sheet '{sheet_name}': no control rows starting with '{control_prefix}' found.")

    out_blocks = []
    prev = df.index.min()

    for k, cidx in enumerate(control_idx):
        block = df.loc[prev:cidx].copy()
        control_row = df.loc[cidx]

        _, rep = parse_replicate_from_control(control_row["EXO70"])
        if rep is None:
            rep = k + 1
        rep = wrap_rep_1_to_4(rep)

        vol_norm = float(control_row["Volume"])
        area_norm = float(control_row["Area"])

        block["NLuc"] = nluc
        block["Experiment"] = experiment
        block["Replicate"] = rep
        block["CLuc"] = block["EXO70"].map(lambda x: parse_replicate_from_control(x)[0])
        block["Volume_norm"] = vol_norm
        block["Area_norm"] = area_norm

        out_blocks.append(
            block[["NLuc", "CLuc", "Experiment", "Replicate", "Volume", "Area", "Volume_norm", "Area_norm"]]
        )

        next_pos = df.index.get_loc(cidx) + 1
        if next_pos < len(df.index):
            prev = df.index[next_pos]

    return pd.concat(out_blocks, ignore_index=True)


def main():
    ap = argparse.ArgumentParser(description="Convert multi-sheet luciferase leaf assay XLSX into one long CSV.")
    ap.add_argument("--xlsx", required=True, help="Input Excel workbook (.xlsx)")
    ap.add_argument("--out", required=True, help="Output CSV path")
    ap.add_argument("--control-prefix", default="AtCAM2", help="Control row prefix (default: AtCAM2)")
    args = ap.parse_args()

    xls = pd.ExcelFile(args.xlsx, engine="openpyxl")
    all_long = []

    for sheet in xls.sheet_names:
        df = pd.read_excel(args.xlsx, sheet_name=sheet, engine="openpyxl")
        all_long.append(reshape_one_sheet(df, sheet, control_prefix=args.control_prefix))

    out = pd.concat(all_long, ignore_index=True)
    out.to_csv(args.out, index=False)
    print(f"Wrote {len(out)} rows to: {args.out}")


if __name__ == "__main__":
    main()
