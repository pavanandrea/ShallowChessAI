#======================================================================
    Evaluate all the moves from the initial position

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 30/10/2023
======================================================================#
using Flux;
using JLD2;
include("07b_move_generation_legal_v1.jl");
include("08b_bitboard_from_fen_v1.jl");


gameboard = bitboardfromfen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
myneuralnet = JLD2.load(joinpath(@__DIR__,"../train/results/myneuralnet_24k.jld2"),"myneuralnet");
(availablemoves,childboards) = legalmoves(gameboard,1);
println("Found ",length(availablemoves)," legal moves:");
ynn = myneuralnet(childboards);
for i=1:lastindex(availablemoves)
    println("  ",printsquare(availablemoves[i][1]),printsquare(availablemoves[i][2])," - score = ",floor(Int,1500*ynn[i].^3));
end
