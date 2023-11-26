#======================================================================
    Testing script for the move choice

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 11/11/2023
======================================================================#
using Flux;
using JLD2;
include("../dev/08b_bitboard_from_fen_v2.jl");
include("../dev/09_minimax_search.jl");


#initialize neural network and board position
myneuralnet = JLD2.load(joinpath(@__DIR__,"../models/myneuralnet_24k.jld2"),"myneuralnet");
gameboard = bitboardfromfen("3k4/8/8/8/8/8/3q1PPP/6K1 b - - 0 1");


#find legal moves
player = -1;
(availablemoves,childboards) = legalmoves(gameboard,player);
println("Legal moves:")
for i=1:lastindex(availablemoves)
    println("  ",printsquare(availablemoves[i][1]),printsquare(availablemoves[i][2])," (static evaluation: ",score(childboards[:,i])[1],")");
end


#minimax evaluation
maxdepth = 2;
(computermove,childboard,childmovescore) = minimax(gameboard,player,maxdepth,-1,1);
println("Computer move: ",printsquare(computermove[1]),printsquare(computermove[2])," (score: ",childmovescore,")");
