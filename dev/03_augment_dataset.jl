#======================================================================
    The centipawn score distribution of the extracted dataset is not
    optimal for training, since the vast majority of the boards have
    a score near zero (most chess positions are "drawish").
    A simple way to "fatten" the curve is to generate random moves
    starting from the dataset, as proposed by Maesumi.
    By having more data with high scores, the resulting model is
    expected to have a better understanding of the game and lower bias.

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 05/10/2023
======================================================================#
using PyCall;
chess = pyimport("chess");
chessengine = pyimport("chess.engine");


#initialize Stockfish
localengine = chessengine.SimpleEngine.popen_uci("stockfish/stockfish-ubuntu-x86-64-avx2");


#create an empty CSV file
csvfileio = open("dataset/dataset_small_random.csv","w");
write(csvfileio, "fen,score\n");
close(csvfileio);


#import a dataset
rawdataset = readlines("dataset/dataset_20k_20deep.csv");
for line in rawdataset[2:end]
    currententry = split(line, ",");
    currentboard = chess.Board(currententry[1]);
    legalmoves = [];
    if abs(parse(Int,currententry[2]))<9999
        for move in currentboard.legal_moves
            push!(legalmoves,move);
        end
    end
    if length(legalmoves)>1
        #pick a random move
        currentboard.push(rand(legalmoves));

        #evaluate with Stockfish
        #result = localengine.analyse(currentboard, chessengine.Limit(time=0.5));
        result = localengine.analyse(currentboard, chessengine.Limit(depth=10));
        currentscore = result["score"];
                
        #save result to CSV
        global csvfileio = open("dataset/dataset_small_random.csv","a");
        write(csvfileio, "\""*currentboard.fen()*"\","*string(currentscore.white().score(mate_score=10000))*"\n");
        close(csvfileio);
    end
end
localengine.quit();
