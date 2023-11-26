#======================================================================
    This script reads a PGN file, extracts all the board positions of
    the game and evaluates them using Stockfish.

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 04/10/2023
======================================================================#
using Chess;
using Chess.PGN;
using Chess.UCI;


#read a PGN file containing a single game
pgnstring = read("dataset/example.pgn", String);
currentgame = gamefromstring(pgnstring);


#define a function that extracts the score from the engine output
localengine = runengine("stockfish/stockfish-ubuntu-x86-64-avx2");
player = 1;
score = 0;
function extractscorefunction(outline)
    searchinfo = parsesearchinfo(outline);
    if !isnothing(searchinfo.score)
        if !searchinfo.score.ismate
            global score = player*searchinfo.score.value;
        else
            #mate in N moves
            global score = (10000-abs(searchinfo.score.value))*player*sign(searchinfo.score.value);
            #println("score = ",score);
        end
    else
        global score = NaN;
    end
end


#loop over the game moves and analyze each board with Stockfish
println("Analyzing game:");
@time for currentboard in boards(currentgame)
    if ischeckmate(currentboard)
        println("\"",fen(currentboard),"\" \t : \t Score = ",-10000*player);
        break;
    end
    setboard(localengine, currentboard);
    search(localengine, "go depth 10", infoaction=extractscorefunction);
    println("\"",fen(currentboard),"\" \t : \t Score = ",score);
    global player *= -1;
end
