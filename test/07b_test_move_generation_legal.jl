#======================================================================
    Testing script for the move generation

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 25/10/2023
======================================================================#
include("../dev/07b_move_generation_legal_v2.jl");
include("../dev/08b_bitboard_from_fen_v2.jl");


println("Testing the legal move generation (debugging tests):");


#position #2 from https://www.chessprogramming.org/Perft_Results
fenstring = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t");
(moves,_) = legalmoves(currentbitboard,1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==48
    println("test passed :)");
else
    println("TEST FAILED :(");
end


#position #3 from https://www.chessprogramming.org/Perft_Results
fenstring = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t\t\t\t\t");
(moves,_) = legalmoves(currentbitboard,1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==14
    println("test passed :)");
else
    println("TEST FAILED :(");
end


#position #5 from https://www.chessprogramming.org/Perft_Results
fenstring = "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t\t");
(moves,_) = legalmoves(currentbitboard,1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==44
    println("test passed :)");
else
    if length(moves)==41
        println("test passed banning the promotion to knight/bishop/rock");
    else
        println("TEST FAILED :(");
    end
end


#position #6 from https://www.chessprogramming.org/Perft_Results
fenstring = "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - -";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t");
(moves,_) = legalmoves(currentbitboard,1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==46
    println("test passed :)");
else
    println("TEST FAILED :(");
end



#variant of position #3 from https://www.chessprogramming.org/Perft_Results
fenstring = "8/2p5/3p4/1P5r/KR3p1k/8/4P1P1/8 b - - 1 1";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t\t\t\t");
(moves,_) = legalmoves(currentbitboard,-1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==15
    println("test passed :)");
else
    println("TEST FAILED :(");
end



#mate position
fenstring = "3k4/8/8/8/8/8/5PPP/3q2K1 w - - 0 1";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t\t\t\t\t");
(moves,_) = legalmoves(currentbitboard,1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==0
    println("test passed :)");
else
    println("TEST FAILED :(");
end
