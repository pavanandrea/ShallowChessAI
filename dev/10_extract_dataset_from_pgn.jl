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


function extractpgn(pgnfile,csvoutputfile,stockfishexecutable,Nsampleslimit=0)
    println("ShallowChessAI - Dataset extraction from a PGN database");
    #pgnfile = joinpath(@__DIR__,"../dataset/lichess_db_standard_rated_2013-01.pgn");
    #csvoutputfile = joinpath(@__DIR__,"../dataset/dataset.csv");
    #stockfishexecutable = joinpath(@__DIR__,"../stockfish/stockfish-ubuntu-x86-64-avx2");
    
    #initialize Stockfish
    localengine = chessengine.SimpleEngine.popen_uci(stockfishexecutable);

    #create an empty CSV file
    csvfileio = open(csvoutputfile,"w");
    write(csvfileio, "fen,score\n");
    close(csvfileio);

    #count the number of games in the PGN database
    Ngames = 0;
    for line in eachline(pgnfile)
        if startswith(line, "[Event")
            Ngames += 1;
        end
    end
    println("Found ",Ngames, " games");
    #=if Nsampleslimit > 0
        Ngames = min(Ngames,Nsampleslimit);
        println("Only the first ",Nsampleslimit," games will be used");
    end=#

    #parse large PGN database
    println("Parsing PGN database...");
    pgnfileio = open(pgnfile);
    Nsamples = 0;       #number of parsed boards
    for _ in 1:Ngames
        currentgame = chesspgn.read_game(pgnfileio);
        
        #loop over the game moves and analyze each board with Stockfish
        currentboard = currentgame.board();
        for currentmove in currentgame.mainline_moves()
            #create board and analyize it
            currentboard.push(currentmove);
            result = localengine.analyse(currentboard, chessengine.Limit(depth=10));
            currentscore = result["score"];
            Nsamples += 1;
            
            #save result to CSV
            csvfileio = open(csvoutputfile,"a");
            write(csvfileio, currentboard.fen()*","*string(currentscore.white().score(mate_score=10000))*"\n");
            close(csvfileio);

            #show progress based on number of samples
            #if Nsampleslimit>0 && Nsamples%floor(Int,Nsampleslimit/100)==0      #display at 1% steps
            if Nsampleslimit>0 && Nsamples%floor(Int,Nsampleslimit/10)==0      #display at 10% steps
                println("  Parsing progress: ",Nsamples,"/",Nsampleslimit," boards (",floor(Int,Nsamples/floor(Int,Nsampleslimit/100)),"%)");
            end
            if Nsampleslimit>0 && Nsamples==Nsampleslimit
                break;
            end
        end

        #show progress based on number of games if a limit on number of samples is not defined
        #if Nsampleslimit==0 && i%floor(Int,Ngames/100)==0      #display at 1% steps
        if Nsampleslimit==0 && i%floor(Int,Ngames/10)==0       #display at 10% steps
            println("  Parsing progress: ",i,"/",Ngames," games (",floor(Int,i/floor(Int,Ngames/100)),"%)");
        end
        if Nsampleslimit>0 && Nsamples==Nsampleslimit
            break;
        end
    end
    close(pgnfileio);
    localengine.quit();
    println("Completed");
end

#pgnfile = joinpath(@__DIR__,"../dataset/lichess_db_standard_rated_2013-01.pgn");
#csvoutputfile = joinpath(@__DIR__,"../dataset/dataset.csv");
#stockfishexecutable = joinpath(@__DIR__,"../stockfish/stockfish-ubuntu-x86-64-avx2");
#extractpgn(pgnfile,csvoutputfile,stockfishexecutable);
