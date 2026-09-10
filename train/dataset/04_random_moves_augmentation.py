#!/usr/bin/env python3
"""
Augment a FEN dataset by generating child positions via random legal moves.

Usage:
    python 04_augment_random_moves.py \
        --input dataset1.csv dataset2.csv \
        --target 50000 \
        --output randomdataset.csv

Dependencies:
    pip install python-chess tqdm
"""
import argparse
import csv
import os
import sys
import time
import random
from pathlib import Path
from tqdm import tqdm
import chess
import chess.engine

# ─── Defaults ─────────────────────────────────────────────────────────────────
STOCKFISH_BIN = "/home/andrea/Downloads/stockfish-ubuntu-x86-64-avx2/stockfish/stockfish-ubuntu-x86-64-avx2"


# ─── Sampling ─────────────────────────────────────────────────────────────────

def count_data_rows(paths: list[Path]) -> int:
    """Count total data rows (excluding headers) across all input files."""
    total = 0
    for p in paths:
        with open(p, "rb") as f:
            total += sum(1 for _ in f) - 1
    return total

def iter_rows(paths: list[Path]):
    """Yield (file_index, row_index, fen) for every data row across *paths*."""
    for fi, path in enumerate(paths):
        with open(path, "r", newline="", encoding="utf-8", errors="replace") as f:
            reader = csv.reader(f)
            next(reader)
            for ri, row in enumerate(reader):
                if row:
                    yield fi, ri, row[0]

def sample_source_fens(paths: list[Path], k: int, rng: random.Random, max_passes: int = 10,) -> list[str]:
    """
    Pick k non-terminal FENs from the concatenated input files.
    On each pass, accept each not-yet-seen row with probability (k - collected) / rows_remaining.
    Game-over rows are rejected; repeat up to *max_passes* to compensate.
    """
    n_rows = count_data_rows(paths)
    print(f"  Total source rows: {n_rows:,}")

    sample: list[str] = []
    seen: set[tuple[int, int]] = set()

    for pass_no in range(1, max_passes + 1):
        remaining = n_rows - len(seen)
        if remaining <= 0:
            break

        #p = (k - len(sample)) / remaining
        p = k / n_rows

        for fi, ri, fen in tqdm(
            iter_rows(paths),
            total=n_rows,
            desc=f"  Pass {pass_no}",
            unit="row",
            mininterval=1.0,
        ):
            if (fi, ri) in seen:
                continue
            if len(sample) >= k:
                break
            if rng.random() < p:
                seen.add((fi, ri))
                try:
                    board = chess.Board(fen)
                except ValueError:
                    continue
                if not board.is_game_over():
                    sample.append(fen)

        print(f"  Pass {pass_no}: {len(sample):,}/{k:,} collected.")
        if len(sample) >= k:
            break

    if len(sample) < k:
        print(
            f"WARNING: only {len(sample):,} non-terminal FENs after "
            f"{max_passes} passes (requested {k:,}). Continuing.",
            file=sys.stderr,
        )

    return sample


# ─── Output helpers ─────────────────────────────────────────────────────────────

def write_header(path: Path) -> None:
    """Create the output file with a header row."""
    with open(path, "w", newline="", encoding="utf-8") as f:
        csv.writer(f).writerow(["fen", "centipawn", "mate"])

def append_rows(path: Path, rows: list[list[str]]) -> None:
    """Open *path* in append mode, write *rows*, close immediately."""
    with open(path, "a", newline="", encoding="utf-8") as f:
        csv.writer(f).writerows(rows)


# ─── Evaluation helpers ─────────────────────────────────────────────────────────

def score_to_fields(score: chess.engine.Score) -> tuple[str, str]:
    """Return (centipawn, mate) strings for a chess.engine.Score."""
    if score.is_mate():
        return "NULL", str(score.white())
    return str(score.white()), "NULL"

def game_over_fields(board: chess.Board) -> tuple[str, str]:
    """Return (centipawn, mate) for a terminal position without engine."""
    result = board.result()
    if result == "1-0":
        return "NULL", "1"
    if result == "0-1":
        return "NULL", "-1"
    return "0", "NULL"


# ─── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    ap = argparse.ArgumentParser(
        description=(
            "Generate child positions via random moves and evaluate them "
            "with Stockfish, writing results to CSV in batches."
        )
    )
    ap.add_argument(
        "-i", "--input", nargs="+", required=True,
        help="One or more input CSV files (FEN in column 0)",
    )
    ap.add_argument(
        "-o", "--output", default="augmented_fen.csv",
        help="Output CSV path (default: augmented_fen.csv)",
    )
    ap.add_argument(
        "--target", type=int, default=100_000,
        help="Target number of child positions (default 100 000)",
    )
    ap.add_argument(
        "--seed", type=int, default=42,
        help="Random seed (default 42)",
    )
    ap.add_argument(
        "--depth", type=int, default=12,
        help="Stockfish search depth (default 12)",
    )
    ap.add_argument(
        "--time-limit", type=float, default=10.0,
        help="Max seconds per position (default 10.0)",
    )
    ap.add_argument(
        "--threads", type=int, default=16,
        help="Stockfish threads (default 16)",
    )
    ap.add_argument(
        "--hash", type=int, default=16384,
        help="Stockfish hash in MB (default 16384)",
    )
    ap.add_argument(
        "--save-every", type=int, default=10_000,
        help="Batch size: open/append/close the file every N rows (default 10 000)",
    )
    ap.add_argument(
        "--stockfish", default=STOCKFISH_BIN,
        help=f"Path to Stockfish binary (default: {STOCKFISH_BIN})",
    )
    args = ap.parse_args()

    # ── Validate inputs ────────────────────────────────────────────────────
    if not os.path.isfile(args.stockfish):
        sys.exit(f"ERROR: Stockfish binary not found at {args.stockfish}")

    paths: list[Path] = []
    for inp in args.input:
        p = Path(inp)
        if not p.is_file():
            sys.exit(f"ERROR: input file not found: {p}")
        paths.append(p)

    rng = random.Random(args.seed)

    # ── Sample source positions ────────────────────────────────────────────
    print(f"Sampling from {len(paths)} file(s) ...")
    source_fens = sample_source_fens(paths, args.target, rng)
    print(f"Sampled {len(source_fens):,} source positions.\n")

    if not source_fens:
        sys.exit("ERROR: no valid source positions found.")

    # ── Create output file with header ─────────────────────────────────────
    output_path = Path(args.output)
    write_header(output_path)

    # ── Launch Stockfish ───────────────────────────────────────────────────
    engine: chess.engine.SimpleEngine | None = None
    limit = chess.engine.Limit(depth=args.depth, time=args.time_limit)

    try:
        engine = chess.engine.SimpleEngine.popen_uci(args.stockfish)
        engine.configure({"Threads": args.threads, "Hash": args.hash})
        print(f"Stockfish: {args.threads} threads, {args.hash} MB hash")
        print(f"Depth {args.depth}, time limit {args.time_limit:.1f}s/pos\n")

        # Warmup
        print("Warming up engine ...")
        t0 = time.perf_counter()
        engine.analyse(chess.Board(), chess.engine.Limit(depth=1))
        print(f"  Warmup: {time.perf_counter() - t0:.2f}s\n")

    except Exception as exc:
        sys.exit(f"ERROR: could not start Stockfish: {exc}")

    # ── Generate + evaluate + batch-write ──────────────────────────────────
    buffer: list[list[str]] = []
    written = 0
    skipped_invalid = 0
    skipped_time = 0
    game_over_count = 0
    t_start = time.perf_counter()

    pbar = tqdm(
        source_fens,
        total=len(source_fens),
        desc="Generating",
        unit="pos",
        mininterval=1.0,
    )

    try:
        for src_fen in pbar:
            # ── Generate random child ──────────────────────────────────────
            try:
                board = chess.Board(src_fen)
            except ValueError:
                skipped_invalid += 1
                continue

            legal = list(board.legal_moves)
            if not legal:
                skipped_invalid += 1
                continue

            board.push(rng.choice(legal))
            child_fen = board.fen()

            # ── Evaluate ───────────────────────────────────────────────────
            if board.is_game_over():
                cp, mate = game_over_fields(board)
                game_over_count += 1
            else:
                t0 = time.perf_counter()
                analysis = engine.analyse(board, limit)
                wall = time.perf_counter() - t0

                if not analysis:
                    skipped_invalid += 1
                    continue

                if wall > 0.9 * args.time_limit:
                    skipped_time += 1
                    continue

                cp, mate = score_to_fields(analysis["score"])

            # ── Buffer the row ─────────────────────────────────────────────
            buffer.append([child_fen, cp, mate])
            written += 1

            # ── Flush batch to disk (open → append → close) ───────────────
            if len(buffer) >= args.save_every:
                append_rows(output_path, buffer)
                buffer.clear()

    except KeyboardInterrupt:
        print("\n\nInterrupted - flushing remaining buffer ...")

    except Exception as exc:
        print(f"\n[ERROR] {exc}", file=sys.stderr)

    finally:
        pbar.close()

        # Flush any remaining rows
        if buffer:
            append_rows(output_path, buffer)
            buffer.clear()

        if engine is not None:
            try:
                engine.quit()
            except (chess.engine.EngineTerminatedError,
                    chess.engine.EngineError, OSError):
                pass

    # ── Summary ────────────────────────────────────────────────────────────
    elapsed = time.perf_counter() - t_start
    print(f"\n{'=' * 54}")
    print(f"  Source positions sampled:   {len(source_fens):>12,}")
    print(f"  Child positions written:    {written:>12,}")
    print(f"    of which game-over:       {game_over_count:>12,}")
    print(f"  Invalid / no legal move:    {skipped_invalid:>12,}")
    print(f"  Skipped (time limit):       {skipped_time:>12,}")
    print(f"{'=' * 54}")
    print(f"  Output: {output_path}")
    print(f"  Time:   {elapsed:.1f}s ({elapsed / 60:.1f} min)")

if __name__ == "__main__":
    main()
