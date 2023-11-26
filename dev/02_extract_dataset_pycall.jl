#======================================================================
    This script reads all the games in a large PGN database, extracts
    all the board positions and evaluates them using Stockfish.
    The output is then saved as a CSV file with the following columns:
    * board FEN string
    * Stockfish score in centipawns

    NOTE: this script makes use of the Python package python-chess:
    pip install chess

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 04/10/2023
======================================================================#
using PyCall;
chess = pyimport("chess");
chesspgn = pyimport("chess.pgn");
chessengine = pyimport("chess.engine");


#initialize Stockfish
localengine = chessengine.SimpleEngine.popen_uci("stockfish/stockfish-ubuntu-x86-64-avx2");


#create an empty CSV file
csvfileio = open("dataset/dataset_small.csv","w");
write(csvfileio, "fen,score\n");
close(csvfileio);


#count the number of games in the PGN database
Ngames = 0;
for line in eachline("dataset/lichess_db_standard_rated_2013-01.pgn")
    if startswith(line, "[Event")
        global Ngames += 1;
    end
end
println("Found ",Ngames, " games to parse");


#parse large PGN database
println("Parsing PGN database...");
pgnfileio = open("dataset/lichess_db_standard_rated_2013-01.pgn");
for i in 1:10
    currentgame = chesspgn.read_game(pgnfileio);
    
    #loop over the game moves and analyze each board with Stockfish
    currentboard = currentgame.board();
    for currentmove in currentgame.mainline_moves()
        #create board and analyize it
        currentboard.push(currentmove);
        result = localengine.analyse(currentboard, chessengine.Limit(time=0.5));
        #result = localengine.analyse(currentboard, chessengine.Limit(depth=20));
        currentscore = result["score"];
            
        #save result to CSV
        global csvfileio = open("dataset/dataset_small.csv","a");
        write(csvfileio, "\""*currentboard.fen()*"\","*string(currentscore.white().score(mate_score=10000))*"\n");
        close(csvfileio);
    end

    #show progress
    if i%floor(Int,Ngames/100)==0
        println("Parsing progress: ",floor(Int,i/floor(Int,Ngames/100)),"%");
    end
end
close(pgnfileio);
localengine.quit();
