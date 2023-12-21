#======================================================================
    Run ShallowChessAI against a randomly playing opponent

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 06/12/2023
======================================================================#
using Flux;
using JLD2;
include("./08b_bitboard_from_fen_v2.jl");
include("./09_minimax_search.jl");


#initialization
myneuralnet = JLD2.load(joinpath(@__DIR__,"../models/myneuralnet_24k.jld2"),"myneuralnet");
squares = ["a8","b8","c8","d8","e8","f8","g8","h8",
            "a7","b7","c7","d7","e7","f7","g7","h7",
            "a6","b6","c6","d6","e6","f6","g6","h6",
            "a5","b5","c5","d5","e5","f5","g5","h5",
            "a4","b4","c4","d4","e4","f4","g4","h4",
            "a3","b3","c3","d3","e3","f3","g3","h3",
            "a2","b2","c2","d2","e2","f2","g2","h2",
            "a1","b1","c1","d1","e1","f1","g1","h1"];


#main function
function main()
    gameboard = bitboardfromfen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    maxdepth = 1;

    #gameplay
    turn = 1;
    while !isgameover(gameboard) && turn<=100
        #engine move (minimax algorithm with alpha-beta pruning)
        if isgameover(gameboard)
            break;
        end
        (computermove,childboard,_) = minimax(gameboard,1,maxdepth,-1,1);
        print("Turn ",turn,": ",printsquare(computermove[1]),printsquare(computermove[2]));
        gameboard = childboard;

        #random opponent move (minimax algorithm with alpha-beta pruning)
        if isgameover(gameboard)
            break;
        end
        (availablemoves,childboards) = legalmoves(gameboard,-1);
        if length(availablemoves)==0
            break;
        end
        i = rand(1:length(availablemoves));
        println(" - ",printsquare(availablemoves[i][1]),printsquare(availablemoves[i][2]));
        gameboard = childboards[:,i];
        turn += 1;
    end
    println("\n");

    #the game has ended
    finalscore = score(gameboard)[1];
    println("Game is over (static score: ",1500*finalscore^3,")");
end
main();
