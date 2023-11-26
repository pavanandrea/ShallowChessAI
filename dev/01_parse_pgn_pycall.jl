#======================================================================
    This script reads a PGN file, extracts all the board positions of
    the game and evaluates them using Stockfish.

    NOTE: this script makes use of the Python package python-chess:
    pip install chess

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 03/10/2023
======================================================================#
using PyCall;
chess = pyimport("chess");
chesspgn = pyimport("chess.pgn");
chessengine = pyimport("chess.engine");


#read a PGN file containing a single game
fileio = open("dataset/example.pgn");
currentgame = chesspgn.read_game(fileio);
close(fileio);
moves = currentgame.mainline_moves();


#loop over the game moves and analyze each board with Stockfish
localengine = chessengine.SimpleEngine.popen_uci("stockfish/stockfish-ubuntu-x86-64-avx2");
currentboard = currentgame.board();
println("Analyzing game:");
@time for currentmove in currentgame.mainline_moves()
    currentboard.push(currentmove);
    #display(currentboard)
    #result = localengine.analyse(currentboard, chessengine.Limit(time=0.5));
    result = localengine.analyse(currentboard, chessengine.Limit(depth=10));
    currentscore = result["score"];
    println("\"",currentboard.fen(),"\" \t : \t Score = ",currentscore.white().score(mate_score=10000));
end
localengine.quit();
