#!/usr/bin/env python3
"""
Generate a deduplicated FEN test set from a PGN file.

Reads games from a PGN file, picks one random position from each game
(deduplicated across games), evaluates every position with Stockfish,
and writes the results to a CSV.  The loop continues until exactly
*--size* unique positions have been collected (skipped games do not
count toward the target).

CSV columns: fen, centipawn, mate, top5_moves

Usage:
    python 01_generate_test_set.py --input input.pgn --output test_set.csv

Dependencies:
    pip install python-chess tqdm
"""
import argparse
import csv
import random
import sys
import time
from pathlib import Path
import chess
import chess.engine
import chess.pgn
from tqdm import tqdm

# ─── Defaults ───────────────────────────────────────────────────────────────────
STOCKFISH_BIN = "/home/andrea/Downloads/stockfish-ubuntu-x86-64-avx2/stockfish/stockfish-ubuntu-x86-64-avx2"


# ─── Helpers ────────────────────────────────────────────────────────────────────

def get_mainline_fens(game: chess.pgn.Game) -> list[str]:
    """Return every FEN along the game's mainline (initial position + after each move)."""
    board = game.board()
    fens = [board.fen()]
    for node in game.mainline():
        board.push(node.move)
        fens.append(board.fen())
    return fens

def pick_random_fen(fens: list[str], taken: set[str]) -> str | None:
    """
    Pick one random FEN from *fens* that is not already in *taken*.
    Returns None when every FEN in the game is a duplicate.
    """
    candidates = [f for f in fens if f not in taken]
    if not candidates:
        return None
    return random.choice(candidates)

def score_to_fields(score: chess.engine.Score) -> tuple[str, str]:
    """Return (centipawn, mate) strings for a chess.engine.Score."""
    if score.is_mate():
        return "NULL", str(score.white().mate())
    return str(score.white()), "NULL"


# ─── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Generate a deduplicated FEN test set from a PGN file."
    )
    parser.add_argument("-i", "--input", required=True,
                        help="Input PGN file")
    parser.add_argument("-o", "--output", required=True,
                        help="Output CSV file")
    parser.add_argument("--size", type=int, default=10000,
                        help="Exact number of unique positions to collect (default: 10000)")
    parser.add_argument("--depth", type=int, default=6,
                        help="Stockfish search depth (default: 6)")
    parser.add_argument("--multipv", type=int, default=5,
                        help="Number of lines to request (default: 5)")
    parser.add_argument("--threads", type=int, default=1,
                        help="Stockfish threads (default: 1)")
    parser.add_argument("--hash", type=int, default=1024,
                        help="Stockfish hash in MB (default: 1024)")
    parser.add_argument("--seed", type=int, default=None,
                        help="Random seed for reproducibility")
    parser.add_argument("--stockfish", default=STOCKFISH_BIN,
                        help=f"Path to Stockfish binary (default: {STOCKFISH_BIN})")
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.is_file():
        sys.exit(f"Error: PGN file not found: {input_path}")
    if not Path(args.stockfish).is_file():
        sys.exit(f"Error: Stockfish binary not found: {args.stockfish}")

    print(f"Input PGN  : {input_path}")
    print(f"Output CSV : {output_path}")
    print(f"Target size: {args.size:,} unique positions")
    print(f"Engine     : depth {args.depth}, MultiPV {args.multipv}, "
          f"{args.threads} thread(s), {args.hash} MB hash\n")

    # ═══════════════════════════════════════════════════════════════════════════
    # Phase 1 – read games until we have exactly `size` unique FENs
    # ═══════════════════════════════════════════════════════════════════════════
    print("Reading games and selecting positions...")
    taken: set[str] = set()
    selected_fens: list[str] = []
    games_read = 0
    games_skipped = 0  # every position in the game was a duplicate

    with open(input_path, "r", encoding="utf-8", errors="replace") as f:
        while len(selected_fens) < args.size:
            try:
                game = chess.pgn.read_game(f)
            except (ValueError, StopIteration, EOFError):
                break
            if game is None:
                break

            games_read += 1
            fens = get_mainline_fens(game)
            fen = pick_random_fen(fens, taken)

            if fen is None:
                games_skipped += 1          # skip: don't count toward target
            else:
                taken.add(fen)
                selected_fens.append(fen)

    print(f"  Games read       : {games_read:,}")
    print(f"  Positions picked : {len(selected_fens):,}")
    if games_skipped:
        print(f"  Games skipped    : {games_skipped:,} (all positions already seen)")
    print()

    if len(selected_fens) < args.size:
        print(f"[WARN] PGN exhausted: collected {len(selected_fens):,} "
              f"positions (target was {args.size:,}).")

    if not selected_fens:
        sys.exit("No positions selected – nothing to evaluate.")

    # ═══════════════════════════════════════════════════════════════════════════
    # Phase 2 – evaluate every FEN with Stockfish
    # ═══════════════════════════════════════════════════════════════════════════
    print(f"Launching Stockfish ({args.stockfish})...")
    limit = chess.engine.Limit(depth=args.depth)

    engine: chess.engine.SimpleEngine | None = None
    try:
        engine = chess.engine.SimpleEngine.popen_uci(args.stockfish)
        engine.configure({"Threads": args.threads, "Hash": args.hash})
        print(f"Stockfish ready: {args.threads} thread(s), {args.hash} MB hash")

        # Warm-up so the first real analysis isn't slowed by JIT / lazy init
        t0 = time.perf_counter()
        engine.analyse(chess.Board(), chess.engine.Limit(depth=1))
        print(f"Warm-up: {time.perf_counter() - t0:.2f}s\n")

        results: list[list[str]] = []

        for fen in tqdm(selected_fens, desc="Evaluating", unit="pos"):
            try:
                board = chess.Board(fen)
            except ValueError:
                tqdm.write(f"\n[WARN] Invalid FEN, skipping: {fen[:60]}...")
                continue

            # ── Terminal positions: record the result, skip the engine ──
            if board.is_game_over():
                if board.result() == "1-0":
                    cp, mate = "NULL", "1"
                elif board.result() == "0-1":
                    cp, mate = "NULL", "-1"
                else:                       # draw
                    cp, mate = "0", "NULL"
                top5 = "NULL"
            else:
                analysis = engine.analyse(board, limit, multipv=args.multipv)

                if not analysis:
                    cp = mate = top5 = "NULL"
                else:
                    best_score = analysis[0]["score"]
                    cp, mate = score_to_fields(best_score)

                    # First move of each PV line
                    moves = []
                    for info in analysis:
                        if info["pv"]:
                            moves.append(info["pv"][0].uci())
                        else:
                            moves.append("0000")
                    top5 = ";".join(moves)

            results.append([fen, cp, mate, top5])

    except KeyboardInterrupt:
        print("\n\nInterrupted by user.")
    finally:
        if engine is not None:
            try:
                engine.quit()
            except (chess.engine.EngineTerminatedError,
                    chess.engine.EngineError,
                    OSError):
                pass  # engine already dead (e.g. Ctrl-C killed the subprocess)

    if not results:
        sys.exit("No positions were successfully evaluated.")

    # ═══════════════════════════════════════════════════════════════════════════
    # Phase 3 – write CSV
    # ═══════════════════════════════════════════════════════════════════════════
    header = ["fen", "centipawn", "mate", "top5_moves"]
    print(f"\nWriting {len(results):,} rows to {output_path}...")
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(results)

    print("Done.")

if __name__ == "__main__":
    main()
