#======================================================================
    The centipawn score distribution of the extracted dataset is not
    optimal for training, since the vast majority of the boards have
    a score near zero (most chess positions are "drawish").
    A simple way to "fatten" the curve is to generate random moves
    starting from the dataset, as proposed by Maesumi.
    By having more data with high scores, the resulting model is
    expected to have a better understanding of the game and lower bias.

    NOTE: this script makes use of the Python package python-chess:
    pip install chess

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 05/10/2023
======================================================================#
using PyCall;
chess = pyimport("chess");
chesspgn = pyimport("chess.pgn");
chessengine = pyimport("chess.engine");


function expandcsvdataset(datasetfile,stockfishexecutable,Nentrieslimit)
    println("ShallowChessAI - Dataset augmentation with random moves");
    #datasetfile = joinpath(@__DIR__,"../dataset/dataset_20k_20deep.csv");
    #datasetfile = joinpath(@__DIR__,"../dataset/dataset_811k_10deep.csv");
    #outputfile = joinpath(@__DIR__,"../dataset/dataset_random.csv");
    outputfile = datasetfile;

    #initialize Stockfish
    localengine = chessengine.SimpleEngine.popen_uci(stockfishexecutable);

    #create an empty CSV file
    if !isfile(outputfile)
        csvfileio = open(outputfile,"w");
        write(csvfileio, "fen,score\n");
        close(csvfileio);
    end

    #import a dataset
    #rawdataset = readlines(datasetfile);               #expand the whole dataset
    #rawdataset = readlines(datasetfile)[2:100_001];    #expand only the first 100_000 entries
    rawdataset = readlines(datasetfile)[2:Nentrieslimit+1];
    for i=1:lastindex(rawdataset)
        currententry = split(rawdataset[i], ",");
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
            result = localengine.analyse(currentboard, chessengine.Limit(depth=10));
            currentscore = result["score"];
                    
            #save result to CSV
            global csvfileio = open(outputfile,"a");
            write(csvfileio, currentboard.fen()*","*string(currentscore.white().score(mate_score=10000))*"\n");
            close(csvfileio);
        end

        #show progress
        #if i%floor(Int,lastindex(rawdataset)/100)==0        #display at 1% steps
        if i%floor(Int,lastindex(rawdataset)/10)==0         #display at 10% steps
            println("  Parsing progress: ",i,"/",lastindex(rawdataset)," boards (",floor(Int,i/floor(Int,lastindex(rawdataset)/100)),"%)");
        end
    end
    localengine.quit();
    println("Completed");
end
#datasetfile = joinpath(@__DIR__,"../dataset/dataset_811k_10deep.csv");
#stockfishexecutable = joinpath(@__DIR__,"../stockfish/stockfish-ubuntu-x86-64-avx2");
#Nentrieslimit = 100_000;
#expandcsvdataset(datasetfile, stockfishexecutable,Nentrieslimit);
