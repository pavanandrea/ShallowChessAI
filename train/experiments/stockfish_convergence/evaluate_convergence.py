#!/usr/bin/env python3
"""
Evaluate N random FEN positions at multiple Stockfish depth levels.

Usage:
    python evaluate_convergence.py ../../dataset/dataset_fen_1301.csv \
        --output convergence_results.csv \
        --depths 1 2 3 4 5 6 8 10 12 15 20 25 30 \
        --ground-truth-depth 30 \
        --n-positions 500 \
        --time-limit 30 \
        --threads 16 --hash 8192 --seed 42
"""
import csv
import os
import sys
import random
import argparse
import time

import chess
import chess.engine
from tqdm import tqdm

STOCKFISH_BIN = "/home/andrea/Downloads/stockfish-ubuntu-x86-64-avx2/stockfish/stockfish-ubuntu-x86-64-avx2"
MULTIPV = 5

def sample_positions(path: str, k: int, rng: random.Random) -> list[str]:
    """
    Pick k non-terminal FENs from *path* (FEN in column 0).

    Strategy: scan the file, accept each row with probability
    (k - len(sample)) / rows_remaining.  Stop as soon as k are collected.
    If a full pass ends short (some accepted rows were terminal),
    repeat, skipping rows already seen.
    """
    with open(path, newline="") as f:
        n_rows = sum(1 for _ in f) - 1  # subtract header
    print(f"  {n_rows:,} rows in file.")

    sample: list[str] = []
    seen: set[int] = set()

    for pass_no in range(1, 10):
        remaining = n_rows - len(seen)
        if remaining <= 0:
            break

        p = (k - len(sample)) / remaining

        with open(path, newline="") as f:
            reader = csv.reader(f)
            next(reader)  # header
            for i, row in enumerate(tqdm(reader,
                                         desc=f"Pass {pass_no}",
                                         unit="row",
                                         total=n_rows)):
                if i in seen:
                    continue
                if len(sample) >= k:
                    break
                if rng.random() < p:
                    seen.add(i)
                    board = chess.Board(row[0])
                    if not board.is_game_over():
                        sample.append(row[0])

        print(f"  Pass {pass_no}: {len(sample)}/{k} collected.")
        if len(sample) >= k:
            break

    if len(sample) < k:
        sys.exit(f"ERROR: only {len(sample)} non-terminal FENs after "
                 f"multiple passes (need {k}).")

    return sample

def evaluate(board: chess.Board, engine: chess.engine.SimpleEngine,
             limit: chess.engine.Limit,
             time_limit: float) -> tuple[str, str, str, str, float]:
    """
    Return (centipawn, mate, best_move, second_best_move, wall_time_s).

    If wall time exceeds *time_limit*, all fields except wall_time_s
    are set to "NULL".
    """
    t0 = time.perf_counter()
    analysis = engine.analyse(board, limit, multipv=MULTIPV)
    wall = time.perf_counter() - t0

    if not analysis:
        return "NULL", "NULL", "NULL", "NULL", wall

    # Simple and unambiguous: if we used up the budget, discard.
    if wall > 0.9*time_limit:
        return "NULL", "NULL", "NULL", "NULL", wall

    score = analysis[0]["score"]
    if score.is_mate():
        cp, mate = "NULL", str(score.white())
    else:
        cp, mate = str(score.white()), "NULL"

    best = analysis[0]["pv"][0].uci() if analysis[0]["pv"] else "NULL"
    second = "NULL"
    if len(analysis) > 1 and analysis[1]["pv"]:
        second = analysis[1]["pv"][0].uci()

    return cp, mate, best, second, wall

def main():
    ap = argparse.ArgumentParser(
        description="Evaluate N random FENs at multiple Stockfish depth levels.")
    ap.add_argument("input",
                    help="CSV file with FENs in column 0")
    ap.add_argument("--output", default="convergence_results.csv",
                    help="Output CSV filename")
    ap.add_argument("--depths", type=int, nargs="+", required=True,
                    help="List of search depths to evaluate")
    ap.add_argument("--ground-truth-depth", type=int, required=True,
                    help="Depth used as the ground-truth reference")
    ap.add_argument("--n-positions", type=int, default=500,
                    help="Number of random FEN positions to sample (default 500)")
    ap.add_argument("--time-limit", type=float, default=30.0,
                    help="Max seconds per position per depth; exceeded → NULL (default 30)")
    ap.add_argument("--threads", type=int, default=16,
                    help="Number of Stockfish threads")
    ap.add_argument("--hash", type=int, default=8192,
                    help="Stockfish hash size in MB")
    ap.add_argument("--seed", type=int, default=42,
                    help="Random seed for position sampling")
    args = ap.parse_args()

    t_total_start = time.perf_counter()

    all_depths = sorted(args.depths + [args.ground_truth_depth])
    rng = random.Random(args.seed)

    if not os.path.isfile(STOCKFISH_BIN):
        sys.exit(f"ERROR: Stockfish not found at {STOCKFISH_BIN}")
    if not os.path.isfile(args.input):
        sys.exit(f"ERROR: Input CSV not found at {args.input}")

    # ── Sample ──────────────────────────────────────────────────────────────
    print(f"Scanning {args.input} ...")
    sample = sample_positions(args.input, args.n_positions, rng)
    print(f"Sampled {len(sample)} positions (seed={args.seed}).\n")

    # ── Evaluate ─────────────────────────────────────────────────────────────
    out_fh = open(args.output, "w", newline="")
    writer = csv.writer(out_fh)
    writer.writerow(["fen", "depth", "centipawn", "mate", "best_move",
                     "second_best_move", "wall_time_s"])

    engine = None
    n_nulls = 0
    try:
        engine = chess.engine.SimpleEngine.popen_uci(STOCKFISH_BIN)
        engine.configure({"Threads": args.threads, "Hash": args.hash})
        print(f"Stockfish: {args.threads} threads, {args.hash} MB hash, "
              f"MultiPV={MULTIPV}")
        print(f"Time limit: {args.time_limit:.1f}s per position\n")

        # ── Warmup ──────────────────────────────────────────────────────────
        print("Warming up engine (initialization round) ...")
        warmup_t0 = time.perf_counter()
        engine.analyse(chess.Board(), chess.engine.Limit(depth=1))
        warmup_wall = time.perf_counter() - warmup_t0
        print(f"  Warmup took {warmup_wall:.2f}s (excluded from results).\n")

        for d in all_depths:
            limit = chess.engine.Limit(depth=d, time=args.time_limit)
            tag = (f"d={d}"
                   + "  [GT]" if d == args.ground_truth_depth else f"d={d}")
            for fen in tqdm(sample, desc=tag, unit="pos"):
                cp, mate, best, second, wall = evaluate(
                    chess.Board(fen), engine, limit,
                    time_limit=args.time_limit)
                writer.writerow([fen, d, cp, mate, best, second,
                                 f"{wall:.3f}"])
            out_fh.flush()

    except KeyboardInterrupt:
        print("\nInterrupted - saving.")
    finally:
        out_fh.close()
        if engine is not None:
            try:
                engine.quit()
            except (chess.engine.EngineTerminatedError,
                    chess.engine.EngineError, OSError):
                pass

    t_total = time.perf_counter() - t_total_start
    total_cells = len(sample) * len(all_depths)
    print(f"\nDone. {len(sample)} positions × {len(all_depths)} depths "
          f"→ {args.output}")
    print(f"  NULL cells (time-limit): {n_nulls}/{total_cells} "
          f"({100 * n_nulls / total_cells:.1f}%)")
    print(f"Total runtime: {t_total:.1f}s ({t_total / 60:.1f} min)")


if __name__ == "__main__":
    main()

