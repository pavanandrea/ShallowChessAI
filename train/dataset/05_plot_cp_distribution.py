#!/usr/bin/env python3
"""
Plot the centipawn distribution across the full training dataset.

Usage:
    python plot_centipawn_distribution.py \
        --input dataset1.csv dataset2.csv \
        --output plot.png

Dependencies:
    pip install numpy matplotlib
"""
import argparse
import csv
import sys
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use("Agg")   # headless-safe; remove if you want an interactive window
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter


# ─── Column layout ────────────────────────────────────────────────────────────
# dataset_fen_1301.csv            → fen, occurrences, centipawn, mate, top5_moves
# *_top5_moves_deduplicated.csv   → fen, centipawn, mate
# *_random_moves_deduplicated.csv → fen, centipawn, mate
#
# We detect the layout by checking the header row.

def centipawn_column_index(header: list[str]) -> int:
    """Return the 0-based column index of 'centipawn' in the header."""
    for i, col in enumerate(header):
        if col.strip().lower() == "centipawn":
            return i
    raise ValueError(f"'centipawn' not found in header: {header}")

def read_centipawns(path: Path) -> tuple[np.ndarray, int]:
    """
    Stream a CSV and return (array_of_centipawn_floats, count_of_null_skipped).
    Memory-friendly: collects into a Python list of floats, converts once at the end.
    """
    values: list[float] = []
    n_null = 0
    n_rows = 0

    with open(path, "r", newline="", encoding="utf-8", errors="replace") as f:
        reader = csv.reader(f)
        header = next(reader)
        ci = centipawn_column_index(header)

        for row in reader:
            n_rows += 1
            if len(row) <= ci:
                continue
            raw = row[ci].strip()
            if raw in ("NULL", "", "N/A"):
                n_null += 1
                continue
            try:
                values.append(float(raw))
            except ValueError:
                n_null += 1

    arr = np.array(values, dtype=np.float32)
    print(f"  {path.name}: {n_rows:,} rows → {arr.size:,} centipawn values "
          f"({n_null:,} NULL skipped)")
    return arr, n_null


# ─── Stats ────────────────────────────────────────────────────────────────────

def print_stats(label: str, arr: np.ndarray) -> None:
    """Print min, max, mean, % within ±100 cp, and % with |cp| > 1500 for a centipawn array."""
    if arr.size == 0:
        return
    mn = float(arr.min())
    mx = float(arr.max())
    mu = float(arr.mean())
    pct_100 = float(np.mean(np.abs(arr) <= 100)) * 100.0
    n_1500 = int(np.sum(np.abs(arr) > 1500))
    pct_1500 = n_1500 / arr.size * 100.0

    print(f"  [{label}]")
    print(f"    min(cp)      = {mn:+,.1f}")
    print(f"    max(cp)      = {mx:+,.1f}")
    print(f"    mean(cp)     = {mu:+,.2f}")
    print(f"    |cp| ≤ 100   = {pct_100:.2f}%  ({int(np.sum(np.abs(arr) <= 100)):,} / {arr.size:,})")
    print(f"    |cp| > 1500  = {pct_1500:.2f}%  ({n_1500:,} / {arr.size:,})")


# ─── Plotting ─────────────────────────────────────────────────────────────────

def make_plot(datasets: list[tuple[str, np.ndarray]], clip: int, bins: int, out_path: Path) -> None:
    fig, axes = plt.subplots(2, 1, figsize=(12, 9),
                             gridspec_kw={"height_ratios": [3, 1]})
    ax_main, ax_zoom = axes

    # ── Shared bin edges & counts ─────────────────────────────────────────
    edges = np.linspace(-clip, clip, bins + 1)
    centers = 0.5 * (edges[:-1] + edges[1:])
    bin_w = edges[1] - edges[0]

    count_sets = []
    for label, arr in datasets:
        clipped = arr[np.abs(arr) <= clip]
        counts, _ = np.histogram(clipped, bins=edges)
        count_sets.append(counts)

    # ── Main panel: stacked bars ──────────────────────────────────────────
    bottom = np.zeros(bins, dtype=np.float64)
    for i, (label, arr) in enumerate(datasets):
        ax_main.bar(
            centers,
            count_sets[i],
            width=bin_w,
            bottom=bottom,
            label=f"{label}  (n={arr.size:,})",
        )
        bottom += count_sets[i]

    ax_main.set_xlabel("Centipawn (from White's perspective)")
    ax_main.set_ylabel("Count")
    ax_main.set_title("Centipawn Distribution – Full Dataset")
    ax_main.yaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{x:,.0f}"))
    ax_main.legend(loc="upper right", fontsize=9)
    ax_main.axvline(0, color="k", lw=0.6, ls="--", alpha=0.5)

    # ── Zoom panel: stacked bars over ±300 ────────────────────────────────
    zoom_range = 300
    z_edges = np.linspace(-zoom_range, zoom_range, bins + 1)
    z_centers = 0.5 * (z_edges[:-1] + z_edges[1:])
    z_bin_w = z_edges[1] - z_edges[0]

    z_bottom = np.zeros(bins, dtype=np.float64)
    for i, (label, arr) in enumerate(datasets):
        clipped = arr[np.abs(arr) <= zoom_range]
        z_counts, _ = np.histogram(clipped, bins=z_edges)
        ax_zoom.bar(
            z_centers,
            z_counts,
            width=z_bin_w,
            bottom=z_bottom,
        )
        z_bottom += z_counts

    ax_zoom.set_xlabel("Centipawn")
    ax_zoom.set_ylabel("Count")
    ax_zoom.set_title(f"Zoom: ±{zoom_range} cp")
    ax_zoom.yaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{x:,.0f}"))
    ax_zoom.axvline(0, color="k", lw=0.6, ls="--", alpha=0.5)

    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    print(f"\nPlot saved → {out_path}")
    plt.close(fig)


# ─── Main ─────────────────────────────────────────────────────────────────────

def main() -> None:
    ap = argparse.ArgumentParser(
        description="Plot centipawn distribution across dataset CSV files."
    )
    ap.add_argument(
        "-i", "--input", nargs="+", required=True,
        help="Path(s) to the dataset CSV file(s).",
    )
    ap.add_argument(
        "--clip", type=int, default=1500,
        help="Clip histogram to ±N centipawns (default 1500).",
    )
    ap.add_argument(
        "--bins", type=int, default=50,
        help="Number of histogram bins (default 50).",
    )
    ap.add_argument(
        "-o", "--output", default="centipawn_distribution.png",
        help="Output image path (default: centipawn_distribution.png).",
    )
    args = ap.parse_args()

    # Import data
    datasets: list[tuple[str, np.ndarray]] = []
    for fp in args.input:
        p = Path(fp)
        if not p.is_file():
            sys.exit(f"ERROR: file not found: {p}")
        print(f"Reading {p.name} ...")
        arr, _ = read_centipawns(p)
        if arr.size == 0:
            print(f"  WARNING: no usable centipawn values in {p.name}, skipping.")
            continue
        # Use a short label derived from the filename
        label = p.stem.replace("dataset_fen_1301", "").strip("_") or p.name
        datasets.append((label, arr))

    if not datasets:
        sys.exit("ERROR: no data to plot.")

    # Combined stats
    print(f"\n{'='*50}")
    print("Combined (all inputs):")
    all_cp = np.concatenate([arr for _, arr in datasets])
    print_stats("ALL", all_cp)
    print(f"{'='*50}\n")

    # Plot data
    make_plot(
        datasets,
        clip=args.clip,
        bins=args.bins,
        out_path=Path(args.output),
    )

if __name__ == "__main__":
    main()
