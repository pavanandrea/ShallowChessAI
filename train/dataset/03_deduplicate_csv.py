#!/usr/bin/env python3
"""
Deduplicate a large FEN CSV file by FEN string.
Also removes FENs that already exist in other reference CSV files.

Usage:
    python 03_deduplicate_csv.py --input input.csv --output output.csv --extra-files ref1.csv ref2.csv

Dependencies:
    pip install tqdm
"""
import sys
import argparse
from tqdm import tqdm
from pathlib import Path

def count_lines(filepath: str) -> int:
    """Quickly count lines using binary read (fast, no decoding)."""
    with open(filepath, "rb") as f:
        return sum(1 for _ in f)

def load_fens(filepath: str) -> set[str]:
    """Load the first column (FEN) from a CSV into a set. Skips header."""
    fens: set[str] = set()
    with open(filepath, "r") as f:
        next(f)  # skip header
        for line in tqdm(f, desc=f"  Loading {Path(filepath).name}", unit="row"):
            line = line.rstrip("\n")
            if line:
                fens.add(line.split(",", 1)[0])
    return fens

def deduplicate(main_file: str, other_files: list[str], output_file: str,) -> None:
    # ── 1. Build the "already exists" set from reference files ──────────
    existing_fens: set[str] = set()
    if other_files:
        print(f"Loading FENs from {len(other_files)} reference file(s)...")
        for of in other_files:
            fens = load_fens(of)
            existing_fens.update(fens)
        print(f"  → {len(existing_fens):,} FENs to exclude.\n")

    # ── 2. Prepare progress total (subtract header) ────────────────────
    total_lines = count_lines(main_file) - 1
    print(f"Processing: {main_file}  ({total_lines:,} data rows)")
    print(f"Output:     {output_file}\n")

    # ── 3. Stream-process the main file ─────────────────────────────────
    seen_fens: set[str] = set()
    kept = 0
    skipped_dup = 0
    skipped_existing = 0

    with open(main_file, "r") as fin, open(output_file, "w") as fout:
        # Preserve the header
        header = fin.readline()
        fout.write(header)

        for line in tqdm(fin, total=total_lines, desc="Deduplicating", unit="row"):
            if not line or line == "\n":
                continue

            fen = line.split(",", 1)[0]

            if fen in existing_fens:
                skipped_existing += 1
            elif fen in seen_fens:
                skipped_dup += 1
            else:
                seen_fens.add(fen)
                fout.write(line)
                kept += 1

    # ── 4. Summary ──────────────────────────────────────────────────────
    print(f"\n{'=' * 52}")
    print(f"  Rows processed:          {total_lines:>12,}")
    print(f"  Rows kept:               {kept:>12,}")
    print(f"  Duplicates removed:      {skipped_dup:>12,}")
    print(f"  Already in ref files:    {skipped_existing:>12,}")
    print(f"  Unique FENs in output:   {kept:>12,}")
    print(f"{'=' * 52}")
    print(f"  Output written to: {output_file}")

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Deduplicate a FEN CSV and remove FENs already present in reference files."
    )
    parser.add_argument("-i","--input", required=True, help="CSV to deduplicate")
    parser.add_argument("-o","--output", default="deduplicated.csv", help="Output CSV")
    parser.add_argument("--extra-files", nargs="*", default=[],
                        help="Additional CSV files whose FENs should be excluded from the output")
    args = parser.parse_args()

    # Check input and extra files
    input_path = Path(args.input)
    if not input_path.is_file():
        sys.exit(f"Error: input file does not exist: {args.input}")
    for f in args.extra_files:
        p = Path(f)
        if not p.is_file():
            sys.exit(f"Error: extra file does not exist: {f}")
    
    deduplicate(args.input, args.extra_files, args.output)

if __name__ == "__main__":
    main()
