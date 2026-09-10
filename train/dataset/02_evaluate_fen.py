#!/usr/bin/env python3
"""
Evaluate chess positions from a CSV database using Stockfish.

Reads a CSV with columns: fen, occurrences, centipawn, mate, top5_moves.
Finds the first row with NULL,NULL,NULL in the last three columns and
evaluates from there, updating the CSV in-place (periodic saves for safety).

Also writes a companion CSV (fen, centipawn, mate) with the score for
each of the top-5 moves.

Usage:
    python 02_evaluate_fen.py --input input.csv --moves-output output.csv --threads 8

Dependencies:
    pip install python-chess tqdm
"""
import csv
import os
import sys
import time
import argparse
import tempfile

import chess
import chess.engine
from tqdm import tqdm

# ─── Defaults ───────────────────────────────────────────────────────────────────
STOCKFISH_BIN = "/home/andrea/Downloads/stockfish-ubuntu-x86-64-avx2/stockfish/stockfish-ubuntu-x86-64-avx2"


# ─── Helpers ────────────────────────────────────────────────────────────────────
def score_to_fields(score: chess.engine.Score) -> tuple[str, str]:
    """Return (centipawn_str, mate_str) for a chess.engine.Score."""
    if score.is_mate():
        return "NULL", str(score.white().mate())
    return str(score.white()), "NULL"

def uci_moves(analysis: list) -> list[str]:
    """Extract the first move (UCI) from each AnalysisInfo in the list."""
    moves = []
    for info in analysis:
        if info["pv"]:
            moves.append(info["pv"][0].uci())
        else:
            moves.append("0000")  # fallback if PV is empty
    return moves

def save_csv(path: str, header: list[str], rows: list[list[str]]):
    """Write header + rows to *path* atomically (write to temp, then rename)."""
    dir_name = os.path.dirname(os.path.abspath(path)) or "."
    fd, tmp_path = tempfile.mkstemp(dir=dir_name, suffix=".csv")
    try:
        with os.fdopen(fd, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(header)
            writer.writerows(rows)
        os.replace(tmp_path, path)
    except BaseException:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise


# ─── Main ───────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Evaluate FEN positions with Stockfish.")
    parser.add_argument("-i","--input", required=True, help="Input CSV to update in place")
    parser.add_argument("--moves-output", default="dataset_fen_top5_moves.csv",
                        help="Companion CSV for top-5 moves")
    parser.add_argument("--depth", type=int, default=8)
    parser.add_argument("--time-limit", type=float, default=10.0)
    parser.add_argument("--multipv", type=int, default=5)
    parser.add_argument("--threads", type=int, default=1)
    parser.add_argument("--hash", type=int, default=8192)
    parser.add_argument("--save-every", type=int, default=10000)
    args = parser.parse_args()

    if not os.path.isfile(STOCKFISH_BIN):
        sys.exit(f"ERROR: Stockfish binary not found at {STOCKFISH_BIN}")
    if not os.path.isfile(args.input):
        sys.exit(f"ERROR: Input CSV not found at {args.input}")

    # ── Load CSV ───────────────────────────────────────────────────────────────
    print(f"Reading {args.input} ...")
    with open(args.input, "r", newline="") as f:
        reader = csv.reader(f)
        header = next(reader)          # fen,occurrences,centipawn,mate,top5_moves
        rows = list(reader)

    total = len(rows)
    print(f"Total rows: {total:,}")

    # ── Find first un-evaluated row ────────────────────────────────────────────
    start = 0
    for i, row in enumerate(rows):
        if len(row) >= 5 and row[2] == "NULL" and row[3] == "NULL" and row[4] == "NULL":
            start = i
            break
    else:
        start = total  # no un-evaluated rows found
    print(f"Starting row: {start}")

    if start == total:
        print("All rows already evaluated. Nothing to do.")
        return
    
    # ── Open companion moves CSV (append mode) ─────────────────────────────────
    moves_new = not os.path.isfile(args.moves_output)
    moves_fh = open(args.moves_output, "a", newline="")
    moves_writer = csv.writer(moves_fh)
    if moves_new:
        moves_writer.writerow(["fen", "centipawn", "mate"])

    # ── Launch Stockfish ───────────────────────────────────────────────────────
    engine = None
    limit = chess.engine.Limit(depth=args.depth, time=args.time_limit)
    try:
        engine = chess.engine.SimpleEngine.popen_uci(STOCKFISH_BIN)
        engine.configure({
            "Threads": args.threads,
            "Hash": args.hash
        })
        print(f"Stockfish: {args.threads} threads, {args.hash} MB hash, "
              f"MultiPV={args.multipv}")
        print(f"Time limit: {args.time_limit:.1f}s per position\n")
    except Exception as exc:
        sys.exit(f"ERROR: could not start Stockfish: {exc}")

    # ── Warmup ──────────────────────────────────────────────────────────
    print("Warming up engine (initialization round) ...")
    warmup_t0 = time.perf_counter()
    engine.analyse(chess.Board(), chess.engine.Limit(depth=1))
    warmup_wall = time.perf_counter() - warmup_t0
    print(f"  Warmup took {warmup_wall:.2f}s.\n")

    # ── Dataset Generation ──────────────────────────────────────────────
    processed = 0
    try:
        for i in tqdm(range(start, total), desc="Evaluating", unit="pos",
                      total=total, initial=start):
            row = rows[i]
            if len(row) < 5:
                continue
            fen = row[0]

            # Skip rows that already have data (for resumption)
            if row[2] != "NULL" or row[3] != "NULL" or row[4] != "NULL":
                continue

            # Parse board
            try:
                board = chess.Board(fen)
            except ValueError:
                print(f"\n[WARN] Invalid FEN at row {i}: {fen[:60]}…", file=sys.stderr)
                continue

            # Game-over positions: record result, skip engine query
            if board.is_game_over():
                if board.result() == "1-0":
                    row[2], row[3] = "NULL", "1"
                elif board.result() == "0-1":
                    row[2], row[3] = "NULL", "-1"
                else:
                    row[2], row[3] = "0", "NULL"
                row[4] = "NULL"
                processed += 1
                continue

            # Engine analysis
            t0 = time.perf_counter()
            analysis = engine.analyse(board, limit, multipv=args.multipv)
            wall = time.perf_counter() - t0
            if not analysis:
                # Shouldn't happen, but guard against it
                row[2] = row[3] = row[4] = "NULL"
                continue

            # Discard analysis if it has used all the time budget
            if wall > 0.9*args.time_limit:
                row[2] = row[3] = row[4] = "NULL"
                continue
            
            # ── Fill the main row (best line) ─────────────────────────────────
            best_score = analysis[0]["score"]
            row[2], row[3] = score_to_fields(best_score)
            top_moves = uci_moves(analysis)
            row[4] = ";".join(top_moves)

            # ── Write each top-N move's score to the companion CSV ────────────
            for info in analysis:
                cp, mate = score_to_fields(info["score"])
                if info["pv"]:
                    board.push(info["pv"][0])
                    childboard_fen = board.fen()
                    board.pop()
                else:
                    childboard_fen = fen
                moves_writer.writerow([childboard_fen, cp, mate])
            processed += 1

            # ── Periodic save ─────────────────────────────────────────────────
            if processed % args.save_every == 0:
                save_csv(args.input, header, rows)
                moves_fh.flush()

    except KeyboardInterrupt:
        print("\n\nInterrupted by user - saving progress ...")
        # Give the engine a grace period so it doesn't half-write a UCI reply
        try:
            engine.quit()
        except (chess.engine.EngineTerminatedError,
                chess.engine.EngineError,
                OSError):
            pass
        engine = None  # mark as dead so finally skips it

    except Exception as exc:
        print(f"\n[ERROR] {exc}", file=sys.stderr)

    finally:
        # Final save
        save_csv(args.input, header, rows)
        moves_fh.close()
        if engine is not None:
            try:
                engine.quit()
            except (chess.engine.EngineTerminatedError,
                    chess.engine.EngineError,
                    OSError):
                pass  # engine already dead (e.g. Ctrl-C killed the subprocess)


    print(f"\nDone. Processed {processed:,} positions "
          f"(from row {start} to row {start+processed} of {total:,}).")
    print(f"Main CSV  : {args.input}")
    print(f"Moves CSV : {args.moves_output}")

if __name__ == "__main__":
    main()
