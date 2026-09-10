#!/usr/bin/env python3
"""
Evaluate the ONNX model on a test-set CSV and report centipawn-error MAE
with a distribution plot.

Usage:
    python 02_evaluate_onnx_2311.py \
             --model checkpoints/best.onnx \
             --set test_set_fen_1302.csv \
             --lib chess.so \
             --output plot.png

Dependencies:
    pip install numpy onnxruntime matplotlib tqdm
"""
from __future__ import annotations
import argparse
import csv
import ctypes
import math
import sys
import time
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import onnxruntime as ort
from tqdm import tqdm


# ══════════════════════════════════════════════════════════════════════════════
#  C struct & FEN parser
# ══════════════════════════════════════════════════════════════════════════════

class BitBoard(ctypes.Structure):
    _fields_ = [
        ("white_pawns",   ctypes.c_uint64),
        ("white_knights", ctypes.c_uint64),
        ("white_bishops", ctypes.c_uint64),
        ("white_rooks",   ctypes.c_uint64),
        ("white_queens",  ctypes.c_uint64),
        ("white_kings",   ctypes.c_uint64),
        ("black_pawns",   ctypes.c_uint64),
        ("black_knights", ctypes.c_uint64),
        ("black_bishops", ctypes.c_uint64),
        ("black_rooks",   ctypes.c_uint64),
        ("black_queens",  ctypes.c_uint64),
        ("black_kings",   ctypes.c_uint64),
        ("metadata",      ctypes.c_uint8),
        ("enpassant",     ctypes.c_uint8),
    ]

BOARD_FIELDS = [
    "white_pawns", "white_knights", "white_bishops",
    "white_rooks", "white_queens", "white_kings",
    "black_pawns", "black_knights", "black_bishops",
    "black_rooks", "black_queens", "black_kings",
]

_SHIFTS_64 = np.arange(64, dtype=np.uint64)

def _expand_bitboard(bb_val: int) -> np.ndarray:
    arr = np.array([bb_val], dtype=np.uint64)
    return ((arr[:, None] >> _SHIFTS_64[None, :]) & 1).astype(np.float32).ravel()

def _expand_byte(byte_val: int, nbits: int) -> np.ndarray:
    shifts = np.arange(nbits, dtype=np.uint64)
    arr = np.array([byte_val], dtype=np.uint64)
    return ((arr[:, None] >> shifts[None, :]) & 1).astype(np.float32).ravel()

def fen_to_feature_vector(bb: BitBoard) -> np.ndarray:
    """[768] board + [7] metadata + [8] enpassant → [783] float32."""
    boards = np.concatenate(
        [_expand_bitboard(getattr(bb, f)) for f in BOARD_FIELDS]
    )
    meta = _expand_byte(bb.metadata, 7)
    ep   = _expand_byte(bb.enpassant, 8)
    return np.concatenate([boards, meta, ep]).astype(np.float32)

def load_set_fen(lib_path: Path):
    lib = ctypes.CDLL(str(lib_path))
    lib.set_position_from_fen.argtypes = [ctypes.POINTER(BitBoard), ctypes.c_char_p]
    lib.set_position_from_fen.restype = None
    return lib.set_position_from_fen


# ══════════════════════════════════════════════════════════════════════════════
#  Score helpers (v2311: model output ∈ [-1, 1], cp = 1500 * output³)
# ══════════════════════════════════════════════════════════════════════════════

def compute_target_score(cp: float | None, mate: int | None) -> float | None:
    """Convert a ground-truth evaluation to the model's target space."""
    if mate is not None and mate != 0:
        sign = 1.0 if mate > 0 else -1.0
        return sign * (1.0 + 1.0 / (abs(mate) ** (2.0 / 3.0)))
    if cp is not None:
        cp_clipped = np.clip(cp, -1500.0, 1500.0)
        return float(np.cbrt(cp_clipped / 1500.0))
    return None

def score_to_cp(score: float) -> float:
    """Convert a model output (tanh, ∈ [-1, 1]) back to centipawns."""
    return 1500.0 * float(score) ** 3


# ══════════════════════════════════════════════════════════════════════════════
#  CSV column lookup
# ══════════════════════════════════════════════════════════════════════════════

def _col(header: list[str], name: str) -> int:
    lower = name.lower()
    for i, h in enumerate(header):
        if h.strip().lower() == lower:
            return i
    raise ValueError(f"Column '{name}' not found in header: {header}")


# ══════════════════════════════════════════════════════════════════════════════
#  Plotting
# ══════════════════════════════════════════════════════════════════════════════

def _plot_errors(cp_err:np.ndarray, out_path:Path, title:str):
    fig, ax = plt.subplots(figsize=(9, 5))

    if len(cp_err) > 0:
        display = cp_err[cp_err < 1000]
        if len(display) > 0:
            bins = np.linspace(0, display.max(), 50)
            ax.hist(display, bins=bins, color="steelblue", edgecolor="none", alpha=0.85)
            ax.axvline(display.mean(), color="crimson", linestyle="--", linewidth=1.5,
                       label=f"MAE = {cp_err.mean():.1f} cp")
            ax.set_xlabel("|centipawn error|")
            ax.set_ylabel("Number of positions")
            ax.legend(fontsize=9)
            ax.grid(axis="y", alpha=0.3)
    else:
        ax.text(0.5, 0.5, "No non-mate positions", ha="center", va="center")

    fig.suptitle(title, fontsize=11)
    fig.tight_layout()
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)


# ══════════════════════════════════════════════════════════════════════════════
#  Main
# ══════════════════════════════════════════════════════════════════════════════

def main() -> None:
    ap = argparse.ArgumentParser(
        description="Evaluate ONNX model on a test-set CSV (centipawn MAE + plot)"
    )
    ap.add_argument("--model", type=Path, required=True)
    ap.add_argument("--set",   type=Path, required=True)
    ap.add_argument("--lib",   type=Path, required=True)
    ap.add_argument("--output", type=str, default="plot.png")
    args = ap.parse_args()

    for label, p in [("ONNX model", args.model), ("CSV", args.set), ("C library", args.lib)]:
        if not p.is_file():
            sys.exit(f"ERROR: {label} not found: {p}")

    # ── Load C library ──
    set_fen = load_set_fen(args.lib)
    bb = BitBoard()
    bb_ref = ctypes.byref(bb)
    bb_size = ctypes.sizeof(BitBoard)

    # ── Load ONNX model ──
    print(f"Loading ONNX model: {args.model}", flush=True)
    sess = ort.InferenceSession(str(args.model), providers=["CPUExecutionProvider"])
    input_name = sess.get_inputs()[0].name
    output_name = sess.get_outputs()[0].name
    print(f"  input  : {input_name}  shape={sess.get_inputs()[0].shape}")
    print(f"  output : {output_name}  shape={sess.get_outputs()[0].shape}", flush=True)

    # ── Count lines ──
    with open(args.set, "rb") as f:
        total_lines = sum(1 for _ in f) - 1
    print(f"\nTest set: {args.set}  ({total_lines:,} positions)", flush=True)

    # ── Parse every row into a feature vector + target ──
    t0 = time.time()
    feats: list[np.ndarray] = []
    targets: list[float] = []
    is_mate: list[bool] = []
    n_skipped = 0

    with open(args.set, newline="", encoding="utf-8", errors="replace") as f:
        reader = csv.reader(f)
        header = next(reader)
        c_fen = _col(header, "fen")
        c_cp = _col(header, "centipawn")
        c_mate = _col(header, "mate")

        pbar = tqdm(total=total_lines, desc="Parsing", unit="pos",
                    bar_format="{l_bar}{bar:20}{r_bar}")
        for row in reader:
            pbar.update(1)
            if len(row) <= max(c_fen, c_cp, c_mate):
                n_skipped += 1
                continue

            fen = row[c_fen].strip()
            if not fen or fen.upper() == "NULL":
                n_skipped += 1
                continue

            # centipawn
            cp_val: float | None = None
            raw = row[c_cp].strip()
            if raw and raw.upper() not in ("NULL", "N/A"):
                try:
                    cp_val = float(raw)
                except ValueError:
                    pass

            # mate
            mate_val: int | None = None
            raw = row[c_mate].strip()
            if raw and raw.upper() not in ("NULL", "N/A", "0"):
                try:
                    mate_val = int(raw) or None
                except ValueError:
                    pass

            target = compute_target_score(cp_val, mate_val)
            if target is None:
                n_skipped += 1
                continue

            # FEN → bitboard → 783-dim vector
            ctypes.memset(bb_ref, 0, bb_size)
            try:
                set_fen(bb_ref, fen.encode())
            except Exception:
                n_skipped += 1
                continue
            if bb.white_kings == 0 and bb.black_kings == 0:
                n_skipped += 1
                continue

            feats.append(fen_to_feature_vector(bb))
            targets.append(target)
            is_mate.append(mate_val is not None)

        pbar.close()

    if not feats:
        sys.exit("ERROR: no valid positions found in the CSV.")

    n = len(feats)
    n_mate = sum(is_mate)
    n_cp = n - n_mate
    print(f"Parsed {n:,} positions ({n_skipped:,} skipped) in {time.time() - t0:.1f}s", flush=True)

    # ── Single inference call ──
    X = np.stack(feats).astype(np.float32)          # [N, 783]
    scores = sess.run([output_name], {input_name: X})[0].ravel()  # [N]
    t_infer = time.time() - t0

    # ── Errors ──
    tgt_arr = np.array(targets, dtype=np.float64)
    score_err_all = np.abs(scores - tgt_arr)
    mate_mask = np.array(is_mate, dtype=bool)
    tgt_cp  = np.array([score_to_cp(t) for t in tgt_arr[~mate_mask]])
    pred_cp = np.array([score_to_cp(s) for s in scores[~mate_mask]])
    cp_err_non_mate = np.abs(pred_cp - tgt_cp)
    score_err_mate = score_err_all[mate_mask]

    # ── Summary ──
    mae_score = float(score_err_all.mean())
    mae_cp = float(cp_err_non_mate.mean()) if len(cp_err_non_mate) else float("nan")
    mae_score_mate = float(score_err_mate.mean()) if len(score_err_mate) else float("nan")
    p95 = float(np.percentile(cp_err_non_mate, 95)) if len(cp_err_non_mate) else float("nan")
    p99 = float(np.percentile(cp_err_non_mate, 99)) if len(cp_err_non_mate) else float("nan")

    fracs = {}
    for thresh in (10, 20, 50):
        fracs[thresh] = (float(np.mean(cp_err_non_mate < thresh))
                         if len(cp_err_non_mate) else float("nan"))

    print(f"\n{'═' * 60}")
    print(f"  Evaluation  ({args.model.name}  on  {args.set.name})")
    print(f"{'═' * 60}")
    print(f"  Positions evaluated : {n:,}  ({n_skipped:,} skipped)")
    print(f"  Mate-in-N           : {n_mate:,}")
    print(f"  CP positions        : {n_cp:,}")
    print(f"{'─' * 60}")
    print(f"  MAE (score, all)    : {mae_score:.6f}")
    print(f"  MAE (cp, non-mate)  : {mae_cp:.2f} cp")
    print(f"  MAE (score, mate)   : {mae_score_mate:.6f}  [score units]")
    print(f"  P95 (cp, non-mate)  : {p95:.2f} cp")
    print(f"  P99 (cp, non-mate)  : {p99:.2f} cp")
    print(f"{'─' * 60}")
    print(f"  err < 10 cp         : {fracs[10] * 100:6.2f} %")
    print(f"  err < 20 cp         : {fracs[20] * 100:6.2f} %")
    print(f"  err < 50 cp         : {fracs[50] * 100:6.2f} %")
    print(f"{'─' * 60}")
    print(f"  Time                : {t_infer:.1f}s  ({n / max(t_infer, 1):.0f} pos/s)")
    print(f"{'═' * 60}\n", flush=True)

    # ── Plot ──
    out_png = Path(args.output)
    _plot_errors(cp_err_non_mate, out_png, title="Centipawn Error Distribution (non-mate)")
    print(f"Plot → {out_png}\nDone.\n", flush=True)

if __name__ == "__main__":
    main()
