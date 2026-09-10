#!/usr/bin/env python3
"""
Compute convergence statistics from evaluate_convergence.py output and plot.

Reads a CSV with columns:
    fen, depth, centipawn, mate, best_move, second_best_move, wall_time_s

For every depth level it computes:
    • MAE / RMSE / max|Δcp| of centipawn score vs ground truth
    • Fraction of positions with |Δcp| ≤ 10, 20, 50
    • Fraction with the correct best / second-best move
    • Evaluation speed (positions / s)

It also plots the *distribution* of the residual Δcp = cp_d - cp_gt:
    • a log-scale histogram of Δcp for representative depths
    • the survival function  S(x) = Pr(|Δcp| > x)  on a log-x axis

Usage:
    python plot_convergence.py convergence_results.csv [--show]
"""
import csv
import sys
import argparse
import numpy as np
import matplotlib
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker


# ─── helpers ──────────────────────────────────────────────────────────────────

def is_null(val: str) -> bool:
    return val is None or val.strip() == "NULL"

def load_results(path: str):
    """Return (depths, data, gt_depth)."""
    rows = []
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            rows.append(r)

    depths = sorted({int(r["depth"]) for r in rows})
    gt_depth = depths[-1]

    data = {}
    for r in rows:
        key = (r["fen"], int(r["depth"]))
        data[key] = {
            "cp":     r["centipawn"],
            "mate":   r["mate"],
            "best":   r["best_move"],
            "second": r["second_best_move"],
            "wall":   float(r["wall_time_s"]),
        }
    return depths, data, gt_depth


# ─── statistics ───────────────────────────────────────────────────────────────

def compute_stats(depths, data, gt_depth):
    """
    Return a dict with one entry per evaluation depth:
        eval_depths, rmse, mae, mae_max,
        agree10, agree20, agree50,
        best, second, speed,
        residuals   (depth -> list of Δcp = cp_d - cp_gt)
    """
    fens = {fen for (fen, _) in data.keys()}
    eval_depths = [d for d in depths if d != gt_depth]

    rmse_l, mae_l, mae_max_l = [], [], []
    a10_l, a20_l, a50_l = [], [], []
    best_l, second_l, speed_l = [], [], []
    residuals = {}

    for d in eval_depths:
        diffs: list[float] = []
        agree10 = agree20 = agree50 = best_m = second_m = n = 0
        walls: list[float] = []

        for fen in fens:
            cur = data.get((fen, d))
            gt = data.get((fen, gt_depth))
            if cur is None or gt is None:
                continue

            walls.append(cur["wall"])

            if is_null(cur["cp"]) or is_null(gt["cp"]):
                continue
            if (is_null(cur["best"]) or is_null(cur["second"])
                    or is_null(gt["best"]) or is_null(gt["second"])):
                continue

            delta = float(cur["cp"]) - float(gt["cp"])
            diffs.append(delta)
            n += 1

            ad = abs(delta)
            if ad <= 10:
                agree10 += 1
            if ad <= 20:
                agree20 += 1
            if ad <= 50:
                agree50 += 1

            if cur["best"] == gt["best"]:
                best_m += 1
            if cur["second"] == gt["second"]:
                second_m += 1

        residuals[d] = diffs
        speed_l.append(1.0 / np.mean(walls) if walls else np.nan)

        if n == 0:
            for lst in (rmse_l, mae_l, mae_max_l,
                        a10_l, a20_l, a50_l,
                        best_l, second_l):
                lst.append(np.nan)
            continue

        d_arr = np.array(diffs)
        abs_arr = np.abs(d_arr)

        rmse_l.append(float(np.sqrt(np.mean(d_arr ** 2))))
        mae_l.append(float(np.mean(abs_arr)))
        mae_max_l.append(float(np.max(abs_arr)))

        a10_l.append(agree10 / n)
        a20_l.append(agree20 / n)
        a50_l.append(agree50 / n)
        best_l.append(best_m / n)
        second_l.append(second_m / n)

    return {
        "eval_depths": eval_depths,
        "rmse": rmse_l,
        "mae": mae_l, "mae_max": mae_max_l,
        "agree10": a10_l, "agree20": a20_l, "agree50": a50_l,
        "best": best_l, "second": second_l,
        "speed": speed_l,
        "residuals": residuals,
    }


# ─── plotting ─────────────────────────────────────────────────────────────────

def _style_ax(ax):
    for spine in ("top", "right"):
        ax.spines[spine].set_visible(False)
    ax.tick_params(axis="both", which="major", labelsize=9)
    ax.tick_params(axis="both", which="minor", length=3)
    ax.grid(True, which="major", alpha=0.25, linewidth=0.6)
    ax.grid(True, which="minor", alpha=0.12, linewidth=0.4)

def _setup_x(ax, x):
    """Linear depth axis with integer ticks at the actual search depths."""
    ax.set_xlim(min(x) - 0.5, max(x) + 0.5)
    ax.set_xticks(list(x))
    ax.set_xticklabels([str(int(t)) for t in x])
    minors = [v + 0.5 for v in x if v + 0.5 <= max(x)]
    ax.set_xticks(minors, minor=True)

def _pct_ax(ax):
    ax.yaxis.set_major_formatter(ticker.PercentFormatter(1.0))
    ax.set_ylim(-0.03, 1.08)
    ax.yaxis.set_minor_locator(ticker.MultipleLocator(0.1))

def _plain_num_ax(ax):
    """Force the y-axis to display plain numbers (no scientific notation)."""
    fmt = ticker.ScalarFormatter()
    fmt.set_scientific(False)
    fmt.set_useOffset(False)
    ax.yaxis.set_major_formatter(fmt)

def _tolerance_vlines(ax, xs=(-50, -20, -10, 10, 20, 50)):
    for v in xs:
        ax.axvline(v, color="0.7", linewidth=0.7, linestyle=":", alpha=0.8)

def plot(stats, gt_depth, out_path, show):
    x = np.array(stats["eval_depths"], dtype=float)

    fig, axes = plt.subplots(2, 2, figsize=(9.5, 8.0))
    fig.suptitle(
        f"Stockfish Evaluation Convergence  (reference: depth {gt_depth})",
        fontsize=12, fontweight="bold", y=0.98,
    )

    LINE_KW = dict(linewidth=1.8, markersize=5.5, markeredgewidth=0.8)

    # ── (a)  Score error ────────────────────────────────────────────────────
    ax = axes[0, 0]
    #ax.plot(x, stats["rmse"], "o-", color="#d62728", label="RMSE", **LINE_KW)
    ax.plot(x, stats["mae"], "s--", color="#ff7f0e", label="MAE", **LINE_KW)
    #ax.plot(x, stats["mae_max"], "^:", color="#8c564b", label="max|E|", **LINE_KW)
    ax.set_xlabel("Search depth (plies)")
    ax.set_ylabel("Score error (centipawns)")
    ax.set_title("(a)  Score accuracy")
    _setup_x(ax, x)
    ax.legend(fontsize=9, framealpha=0.9)
    _style_ax(ax)

    # ── (b)  Score agreement within tolerance ───────────────────────────────
    ax = axes[0, 1]
    ax.plot(x, stats["agree50"], "o-", color="#1f77b4", label="|Δ| ≤ 50 cp", **LINE_KW)
    ax.plot(x, stats["agree20"], "s--", color="#2ca02c", label="|Δ| ≤ 20 cp", **LINE_KW)
    ax.plot(x, stats["agree10"], "^-.", color="#c2185b", label="|Δ| ≤ 10 cp", **LINE_KW)
    ax.set_xlabel("Search depth (plies)")
    ax.set_ylabel("Fraction of positions")
    ax.set_title("(b)  Score agreement")
    _setup_x(ax, x)
    _pct_ax(ax)
    ax.legend(fontsize=9, framealpha=0.9, loc="lower right")
    _style_ax(ax)

    # ── (c)  Move correctness ───────────────────────────────────────────────
    ax = axes[1, 0]
    ax.plot(x, stats["best"], "o-", color="#1f77b4", label="Best move", **LINE_KW)
    ax.plot(x, stats["second"], "s--", color="#9467bd", label="2nd-best move", **LINE_KW)
    ax.set_xlabel("Search depth (plies)")
    ax.set_ylabel("Fraction of positions")
    ax.set_title("(c)  Move correctness")
    _setup_x(ax, x)
    _pct_ax(ax)
    ax.legend(fontsize=9, framealpha=0.9, loc="lower right")
    _style_ax(ax)

    # ── (d)  Throughput ─────────────────────────────────────────────────────
    ax = axes[1, 1]
    ax.plot(x, stats["speed"], "D-", color="#7f7f7f",
            label="Positions / s", **LINE_KW)
    ax.set_xlabel("Search depth (plies)")
    ax.set_ylabel("Evaluation speed (positions / s)")
    ax.set_title("(d)  Throughput")
    _setup_x(ax, x)
    ax.set_yscale("log")
    _plain_num_ax(ax)
    ax.legend(fontsize=9, framealpha=0.9)
    _style_ax(ax)

    fig.text(0.5, 0.012,
             "Convergence of Stockfish evaluations on sampled positions, "
             f"referenced against a depth-{gt_depth} search.",
             ha="center", va="bottom", fontsize=8, color="0.35")

    fig.tight_layout(rect=[0, 0.04, 1, 0.96])
    fig.savefig(out_path, dpi=300, bbox_inches="tight")
    print(f"\nPlot saved to {out_path}")
    if show:
        plt.show()
    plt.close(fig)


def plot_distributions(residuals, gt_depth, out_path, show):
    """
    Plot the *distribution* of the residual Δcp = cp_d - cp_gt.

    Left : log-scale histograms of Δcp for a few representative depths.
    Right: survival function  S(x) = Pr(|Δcp| > x)  on a log-x axis,
           one curve per depth (shows the heavy tail and how deeper
           search pulls it leftward).
    """
    all_d = sorted(residuals)
    # up to four evenly spaced representative depths for the histogram
    idx = [0, len(all_d)//3, 2*len(all_d)//3, len(all_d)-1]
    hist_depths = sorted({all_d[i] for i in idx})

    cmap = plt.get_cmap("viridis")
    n_hist = len(hist_depths)

    fig, (ax_h, ax_s) = plt.subplots(1, 2, figsize=(11.0, 4.6))
    fig.suptitle(
        f"Distribution of score residuals  Δcp = cp_d − cp_{gt_depth}  "
        f"(reference: depth {gt_depth})",
        fontsize=12, fontweight="bold", y=1.02,
    )

    # ── (e) histogram of Δcp ────────────────────────────────────────────────
    H_CLIP = 150.0  # truncate the few extreme outliers so the bulk is readable
    bins = np.linspace(-H_CLIP, H_CLIP, 61)
    for j, d in enumerate(hist_depths):
        vals = np.array(residuals[d], dtype=float)
        vals = vals[np.abs(vals) <= H_CLIP]   # drop the extreme tail (see note)
        if vals.size == 0:
            continue
        color = cmap(j / max(1, n_hist - 1))
        ax_h.hist(vals, bins=bins, histtype="step", linewidth=1.4,
                  color=color, label=f"d={d}", alpha=1.0)
    _tolerance_vlines(ax_h)
    ax_h.set_yscale("log")
    ax_h.set_xlim(-H_CLIP, H_CLIP)
    ax_h.set_xlabel("Δcp = cp_d − cp_gt  (centipawns)")
    ax_h.set_ylabel("Number of positions (log scale)")
    ax_h.set_title("(e)  Residual score distribution")
    ax_h.legend(fontsize=9, framealpha=0.9, title="depth",
                title_fontsize=9)
    _style_ax(ax_h)
    ax_h.text(0.98, 0.97,
              f"outliers |Δcp| > {H_CLIP:.0f} cp truncated",
              transform=ax_h.transAxes, ha="right", va="top",
              fontsize=7.5, color="0.4")

    # ── (f) survival function of |Δcp| ──────────────────────────────────────
    n_c = len(all_d)
    for j, d in enumerate(all_d):
        absd = np.abs(np.array(residuals[d], dtype=float))
        if absd.size == 0:
            continue
        order = np.sort(absd)
        n = order.size
        surv = (n - np.arange(n) - 1) / n          # Pr(|Δ| > x_i)
        m = surv > 0                                # drop the exact-zero tail end
        xx = np.clip(order[m], 1.0, None)           # avoid log(0)
        color = cmap(j / max(1, n_c - 1))
        ax_s.semilogx(xx, surv[m], color=color, linewidth=1.5,
                      label=f"d={d}")
    for v in (10, 20, 50):
        ax_s.axvline(v, color="0.7", linewidth=0.7, linestyle=":", alpha=0.8)
    ax_s.set_xlim(1, 700)
    ax_s.set_ylim(0, 1.02)
    ax_s.set_xlabel("|Δcp|  (centipawns, log scale)")
    ax_s.set_ylabel("Pr( |Δcp| > x )")
    ax_s.set_title("(f)  Tail of the error distribution")
    ax_s.yaxis.set_major_formatter(ticker.PercentFormatter(1.0))
    ax_s.legend(fontsize=7.5, framealpha=0.9, ncol=2, loc="lower left",
                title="depth", title_fontsize=8)
    _style_ax(ax_s)

    fig.text(0.5, -0.02,
             "The long, heavy right-hand tail (a small fraction of hard "
             "positions with errors of several pawns) is what drives the "
             "MAE/max|E| gap; it persists even at the deepest searched depth.",
             ha="center", va="top", fontsize=8, color="0.35")

    fig.tight_layout(rect=[0, 0.04, 1, 0.98])
    fig.savefig(out_path, dpi=300, bbox_inches="tight")
    print(f"Distribution plot saved to {out_path}")
    if show:
        plt.show()
    plt.close(fig)


# ─── CLI ──────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(
        description="Compute and plot Stockfish convergence statistics.")
    ap.add_argument("input", help="convergence_results.csv")
    ap.add_argument("--plot", default="convergence_plot.png",
                    help="Output plot filename")
    ap.add_argument("--dist-plot", default="convergence_distributions.png",
                    help="Output score-distribution plot filename")
    ap.add_argument("--show", action="store_true",
                    help="Open the plot interactively")
    args = ap.parse_args()

    depths, data, gt_depth = load_results(args.input)
    n_pos = len({fen for (fen, _) in data.keys()})
    print(f"Loaded {len(data)} records across {n_pos} positions  "
          f"(ground truth: depth {gt_depth})\n")

    s = compute_stats(depths, data, gt_depth)

    # ── console table ────────────────────────────────────────────────────────
    hdr = (f"{'depth':>6s}  {'MAE':>7s}  "
           f"{'max|E|':>8s}  "
           f"{'±50':>6s}  "
           f"{'best':>6s}  {'2nd':>6s}  {'pos/s':>8s}")
    print(hdr)
    print("─" * len(hdr))
    for i, d in enumerate(s["eval_depths"]):
        print(f"{d:>6d}  {s['mae'][i]:>7.2f}  "
              f"{s['mae_max'][i]:>8.1f}  "
              f"{s['agree50'][i]:>6.3f}  "
              f"{s['best'][i]:>6.3f}  {s['second'][i]:>6.3f}  "
              f"{s['speed'][i]:>8.1f}")

    plot(s, gt_depth, args.plot, args.show)
    plot_distributions(s["residuals"], gt_depth, args.dist_plot, args.show)

if __name__ == "__main__":
    main()

