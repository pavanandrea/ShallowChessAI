#!/usr/bin/env python3
"""
Convert a large PGN file (e.g. Lichess dump) to a deduplicated FEN database.
Writes a CSV with columns: fen, occurrences, centipawn, mate, top5_moves.

Usage:
    python pgn_to_fen.py --input input.pgn --output output.csv

Dependencies:
    pip install python-chess tqdm
"""
import argparse
import sys
import csv
import time
from collections import Counter
from pathlib import Path
from tqdm import tqdm
import chess
import chess.pgn

def count_games(pgn_path: Path) -> int:
    """Quick pre-scan: count [Event lines to get the total game count."""
    count = 0
    with open(pgn_path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("[Event"):
                count += 1
    return count

def main():
    p = argparse.ArgumentParser(description="Convert a large PGN to a deduplicated FEN CSV")
    p.add_argument("-i","--input", required=True, help="Input PGN file")
    p.add_argument("-o","--output", required=True, help="Output CSV file")
    args = p.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)
    if not input_path.exists():
        print(f"Error: {input_path} not found.", file=sys.stderr)
        sys.exit(1)
    print(f"Input:  {input_path}")
    print(f"Output: {output_path}")

    # Pre-scan so tqdm knows the total (enables % and ETA)
    print("Counting games ...")
    total_games = count_games(input_path)
    print(f"  {total_games:,} games found\n")

    fen_counts: Counter = Counter()
    start_time = time.perf_counter()

    pbar = tqdm(total=total_games, desc="Extracting FENs", unit="games", mininterval=1, maxinterval=10)

    with open(input_path, "r", encoding="utf-8", errors="replace") as f:
        game = chess.pgn.read_game(f)
        while game is not None:
            board = game.board()
            fen_counts[board.fen()] += 1

            for node in game.mainline():
                board.push(node.move)
                fen_counts[board.fen()] += 1

            pbar.update(1)

            try:
                game = chess.pgn.read_game(f)
            except (ValueError, StopIteration, EOFError):
                break

    pbar.close()
    elapsed = time.perf_counter() - start_time

    print(f"\nDone in {elapsed:.1f}s.")
    print(f"  Games loaded:    {pbar.n:,}")
    print(f"  Positions total: {sum(fen_counts.values()):,}")
    print(f"  Unique FENs:     {len(fen_counts):,}")

    print(f"Writing CSV to {output_path} ...")
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["fen", "occurrences", "centipawn", "mate", "top5_moves"])
        for fen, count in fen_counts.most_common():
            writer.writerow([fen, count, "NULL", "NULL", "NULL"])

    print(f"Wrote {len(fen_counts):,} rows.")

if __name__ == "__main__":
    main()
