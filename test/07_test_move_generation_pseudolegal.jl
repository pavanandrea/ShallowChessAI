#======================================================================
    Testing script for the move generation

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 21/10/2023
======================================================================#
include("../dev/07_move_generation_pseudolegal.jl");
include("../dev/08b_bitboard_from_fen_v2.jl");


println("Testing the pseudolegal move generation (debugging tests):");


#white pawns
fenstring = "8/8/8/5pP1/8/6n1/PP5P/8 w - f5 0 1";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t");
moves = pseudolegalmoves(currentbitboard,1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==9
    println("test passed :)");
else
    println("TEST FAILED :(");
end


#white bishops (and pawn)
fenstring = "8/2p5/8/4B3/3P4/8/8/7B w - - 0 1";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t");
moves = pseudolegalmoves(currentbitboard,1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==16
    println("test passed :)");
else
    println("TEST FAILED :(");
end


#white rocks and queen
fenstring = "7R/5n2/4Q3/8/4p3/4R3/8/8 w - - 0 1";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t");
moves = pseudolegalmoves(currentbitboard,1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==14+10+21
    println("test passed :)");
else
    println("TEST FAILED :(");
end


#white king
fenstring = "4b3/4P3/4Kn2/8/8/8/8/8 w - - 0 1";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t");
moves = pseudolegalmoves(currentbitboard,1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==7
    println("test passed :)");
else
    println("TEST FAILED :(");
end


#black pawns
fenstring = "8/1p6/7p/6N1/pP6/8/8/8 b - b4 0 1";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t");
moves = pseudolegalmoves(currentbitboard,-1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==6
    println("test passed :)");
else
    println("TEST FAILED :(");
end


#black knights (and pawn)
fenstring = "8/8/2p1P3/3p4/3n4/8/8/7n b - - 0 1";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t");
moves = pseudolegalmoves(currentbitboard,-1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==10
    println("test passed :)");
else
    println("TEST FAILED :(");
end


#black bishops
fenstring = "7b/8/6b1/8/4Q3/8/8/8 b - - 0 1";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t\t");
moves = pseudolegalmoves(currentbitboard,-1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==13
    println("test passed :)");
else
    println("TEST FAILED :(");
end


#black rocks and queen
fenstring = "8/8/5P2/8/3qN1r1/8/8/7r b - - 0 1";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t");
moves = pseudolegalmoves(currentbitboard,-1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==22+10+14
    println("test passed :)");
else
    println("TEST FAILED :(");
end


#black king
fenstring = "8/8/4p3/4k3/5P2/8/8/8 b - - 0 1";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t\t");
moves = pseudolegalmoves(currentbitboard,-1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==7
    println("test passed :)");
else
    println("TEST FAILED :(");
end


#castling not allowed
fenstring = "7r/8/8/5q2/8/8/P6P/R3K2R w KQh - 0 1";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t");
moves = pseudolegalmoves(currentbitboard,1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==15
    println("test passed :)");
else
    println("TEST FAILED :(");
end


println("\n","Testing the pseudolegal move generation (complex positions):");


#initial position
fenstring = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t\t");
moves = pseudolegalmoves(currentbitboard,-1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==20
    println("test passed :)");
else
    println("TEST FAILED :(");
end


#position #2 from https://www.chessprogramming.org/Perft_Results
fenstring = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t");
moves = pseudolegalmoves(currentbitboard,1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==48
    println("test passed :)");
else
    println("TEST FAILED :(");
end


#opening C88 Ruy-Lopez Closed variation
fenstring = "r1bqk2r/2ppbppp/p1n2n2/1p2p3/4P3/1B3N2/PPPP1PPP/RNBQR1K1 b kq - 0 1";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t");
moves = pseudolegalmoves(currentbitboard,-1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==8+10+6+4+0+2
    println("test passed :)");
else
    println("TEST FAILED :(");
end


#position #5 from https://www.chessprogramming.org/Perft_Results
fenstring = "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8";
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t\t");
moves = pseudolegalmoves(currentbitboard,1);
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
moves = pseudolegalmoves(currentbitboard,1);
print("found ",length(moves)," moves","\t\t");
if length(moves)==46
    println("test passed :)");
else
    println("TEST FAILED :(");
end
