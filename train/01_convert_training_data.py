#!/usr/bin/env python3
"""
Convert chess dataset CSVs into NPY/NPZ data files ready for training.

Usage:
    python 01_convert_training_data.py \
             --input data1.csv data2.csv \
             --lib chess.so \
             --output-train train.npy \
             --output-validation val.npy

Dependencies:
    pip install numpy tqdm
"""
from __future__ import annotations
import argparse
import csv
import ctypes
import sys
import time
from pathlib import Path
import numpy as np
from tqdm import tqdm

# ── C struct (mirrors chess.h) ────────────────────────────────────────────────

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

# Numpy dtype matching the C layout (14 fields) + score
FIELD_DTYPE = np.dtype([
    (name, np.dtype(f).newbyteorder("<"))
    for name, f in BitBoard._fields_
] + [("score", np.float32)])

BOARD_NAMES = [f[0] for f in BitBoard._fields_]

def load_set_fen(lib_path: Path):
    """Load the C shared library, return set_position_from_fen."""
    lib = ctypes.CDLL(str(lib_path))
    lib.set_position_from_fen.argtypes = [ctypes.POINTER(BitBoard), ctypes.c_char_p]
    lib.set_position_from_fen.restype = None
    return lib.set_position_from_fen

def compute_score(cp: float | None, mate: int | None) -> float | None:
    """Map centipawn / mate-in-N to a target in [-2, 2].

    Returns None if neither value is available.
    """
    if mate:
        sign = 1.0 if mate > 0 else -1.0
        return sign * (2.0 + 1.0 / (abs(mate) ** (2.0 / 3.0)))
    if cp is not None:
        return float(2.0 * np.tanh(np.clip(cp, -1500.0, 1500.0) / 364.0))
    return None

def _col(header: list[str], name: str) -> int:
    lower = name.lower()
    for i, h in enumerate(header):
        if h.strip().lower() == lower:
            return i
    raise ValueError(f"Column '{name}' not found in header: {header}")

def count_data_lines(path: Path) -> int:
    """Fast line count (excludes header)."""
    n = 0
    with open(path, "rb") as f:
        for _ in f:
            n += 1
    return n - 1  # subtract header


# ── Streaming conversion ──────────────────────────────────────────────────────

def convert(input_files: list[Path], set_fen) -> np.ndarray:
    """
    Stream every CSV line-by-line, parse FENs via C, and fill a
    pre-allocated structured numpy array.  Returns the trimmed array.
    """
    total_lines = sum(count_data_lines(fp) for fp in input_files)
    print(f"  Buffer: {total_lines:,} max samples "
          f"({total_lines * FIELD_DTYPE.itemsize / 1e6:.0f} MB)")

    data = np.zeros(total_lines, dtype=FIELD_DTYPE)
    n = 0
    skipped = 0

    bb = BitBoard()
    bb_ref = ctypes.byref(bb)
    bb_size = ctypes.sizeof(BitBoard)

    for fp in input_files:
        n_lines = count_data_lines(fp)
        with open(fp, newline="", encoding="utf-8", errors="replace") as f:
            reader = csv.reader(f)
            header = next(reader)
            c_fen = _col(header, "fen")
            c_cp = _col(header, "centipawn")
            c_mate = _col(header, "mate")

            for row in tqdm(reader, total=n_lines, desc=fp.name,
                            unit="row", leave=True):
                # ── FEN validity ──
                if len(row) <= max(c_fen, c_cp, c_mate):
                    skipped += 1
                    continue
                fen = row[c_fen].strip()
                if not fen or fen.upper() == "NULL":
                    skipped += 1
                    continue

                # ── Parse centipawn ──
                cp: float | None = None
                raw_cp = row[c_cp].strip()
                if raw_cp and raw_cp.upper() not in ("NULL", "N/A"):
                    try:
                        cp = float(raw_cp)
                    except ValueError:
                        pass

                # ── Parse mate ──
                mate: int | None = None
                raw_mate = row[c_mate].strip()
                if raw_mate and raw_mate.upper() not in ("NULL", "N/A", "0"):
                    try:
                        mate = int(raw_mate)
                        if mate == 0:
                            mate = None
                    except ValueError:
                        pass

                # ── Need at least one of cp / mate ──
                score = compute_score(cp, mate)
                if score is None:
                    skipped += 1
                    continue

                # ── C parse ──
                ctypes.memset(bb_ref, 0, bb_size)
                try:
                    set_fen(bb_ref, fen.encode())
                except Exception:
                    skipped += 1
                    continue
                if bb.white_kings == 0 and bb.black_kings == 0:
                    skipped += 1
                    continue

                # ── Write into pre-allocated array ──
                rec = data[n]
                rec["white_pawns"]   = bb.white_pawns
                rec["white_knights"] = bb.white_knights
                rec["white_bishops"] = bb.white_bishops
                rec["white_rooks"]   = bb.white_rooks
                rec["white_queens"]  = bb.white_queens
                rec["white_kings"]   = bb.white_kings
                rec["black_pawns"]   = bb.black_pawns
                rec["black_knights"] = bb.black_knights
                rec["black_bishops"] = bb.black_bishops
                rec["black_rooks"]   = bb.black_rooks
                rec["black_queens"]  = bb.black_queens
                rec["black_kings"]   = bb.black_kings
                rec["metadata"]      = bb.metadata
                rec["enpassant"]     = bb.enpassant
                rec["score"]         = score
                n += 1

    data = data[:n]
    print(f"\n  {n:,} valid samples ({skipped:,} skipped)\n")
    return data


# ── Save helper ───────────────────────────────────────────────────────────────

def save_npz(path: Path, arr: np.ndarray) -> None:
    """Write each field as a named array inside a compressed .npz."""
    np.savez_compressed(path, **{name: arr[name] for name in arr.dtype.names})
    print(f"  {path.name}: {len(arr):,} samples, "
          f"{path.stat().st_size / 1e6:.1f} MB")

def save_npy(path: Path, arr: np.ndarray) -> None:
    """Write the structured array to a single .npy file (mmap-compatible)."""
    np.save(path, arr)
    print(f"  {path.name}: {len(arr):,} samples, "
          f"{path.stat().st_size / 1e6:.1f} MB")


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    ap = argparse.ArgumentParser(
        description="Convert chess CSVs → shuffled train/val .npz",
    )
    ap.add_argument("-i", "--input", nargs="+", required=True,
                    help="Input CSV file(s)")
    ap.add_argument("--lib", required=True,
                    help="Path to the C shared library")
    ap.add_argument("--output-train", default="train.npy",
                    help="Output NPY file for training data (default: train.npy)")
    ap.add_argument("--output-validation", default="val.npy",
                    help="Output NPY file for validation data (default: val.npy)")
    ap.add_argument("--validation-fraction", type=float, default=0.15,
                    help="Validation fraction (default: 0.15)")
    ap.add_argument("--seed", type=int, default=42,
                    help="RNG seed (default: 42)")
    args = ap.parse_args()

    # ── C library ──
    lib_path = Path(args.lib)
    if not lib_path.is_file():
        sys.exit(f"ERROR: library not found: {lib_path}")
    set_fen = load_set_fen(lib_path)

    # ── Validate inputs ──
    input_files = []
    for p in args.input:
        fp = Path(p)
        if not fp.is_file():
            sys.exit(f"ERROR: file not found: {fp}")
        input_files.append(fp)

    # ── Convert (streaming) ──
    print("== Converting ==")
    t_start = time.time()
    data = convert(input_files, set_fen)
    if len(data) == 0:
        sys.exit("ERROR: no valid samples produced.")

    # ── Shuffle in-place & split ──
    print("== Shuffle & split ==")
    rng = np.random.default_rng(args.seed)
    rng.shuffle(data)  # in-place – no extra allocation

    Nvalidation = int(len(data) * args.validation_fraction)
    val_data = data[:Nvalidation]
    train_data = data[Nvalidation:]

    # ── Write output files ──
    print("== Writing ==")
    save_npy(Path(args.output_train), train_data)
    save_npy(Path(args.output_validation), val_data)
    #save_npz(Path(args.output_train), train_data)
    #save_npz(Path(args.output_validation), val_data)
    print(f"\nDone in {time.time() - t_start:.1f}s.")

if __name__ == "__main__":
    main()
