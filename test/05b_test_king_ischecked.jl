#======================================================================
    Testing script for the ischecked function

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 07/10/2023
======================================================================#
include("../dev/08b_bitboard_from_fen_v2.jl");


println("Testing the function ischecked:");

#white king in check by black pawn
fenstring = "r3kb1r/pbpq2pp/np5B/5p2/3P4/P1N5/RPP2pPP/3QKBNR w Kkq - 0 14";
player = 1;
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t:\t");
if ischecked(currentbitboard,player)
    println("passed :)");
else
    println("FAILED :(");
end

#white king in check by black knight
fenstring = "r3kb1r/pbpp1p1p/1p2p3/7B/4P2q/PnN2Q2/1PP2PPP/2KRR3 w kq - 2 4";
player = 1;
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t:\t");
if ischecked(currentbitboard,player)
    println("passed :)");
else
    println("FAILED :(");
end

#white king in check by black bishop
fenstring = "rnbqk1nr/pppp1ppp/8/1B2p3/4P3/5N2/PPPb1PPP/RNBQK2R w KQkq - 0 4";
player = 1;
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t:\t");
if ischecked(currentbitboard,player)
    println("passed :)");
else
    println("FAILED :(");
end

#white king in check by black rock
fenstring = "rnb3k1/pppr1ppp/5n2/4p1N1/4P3/2N2Q2/PPPK1PPP/R1B4R w - - 0 9";
player = 1;
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t:\t");
if ischecked(currentbitboard,player)
    println("passed :)");
else
    println("FAILED :(");
end

#white king in check by black queen
fenstring = "rnb1k1nr/pppp1ppp/8/1B2p1q1/4P3/5N2/PPPK1PPP/RNBQ3R w kq - 1 5";
player = 1;
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t:\t");
if ischecked(currentbitboard,player)
    println("passed :)");
else
    println("FAILED :(");
end

#black king in check by white pawn
fenstring = "r2qkb1r/pbpP2pp/np2pp1B/8/3P4/P1N5/1PP2PPP/R2QKBNR b KQkq - 0 8";
player = 0;
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t:\t");
if ischecked(currentbitboard,player)
    println("passed :)");
else
    println("FAILED :(");
end

#black king in check by white knight
fenstring = "r3k2r/pbNp1p1p/1pn1p2b/7B/3PP2q/P4Q2/1PP2PPP/R3K2R b KQkq - 0 3";
player = 0;
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t:\t");
if ischecked(currentbitboard,player)
    println("passed :)");
else
    println("FAILED :(");
end

#black king in check by white bishop
fenstring = "r3kb1r/ppp1pppp/n3Qn2/1B6/8/8/NPPP1PPP/R1B1K1NR b KQkq - 2 7";
player = 0;
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t:\t");
if ischecked(currentbitboard,player)
    println("passed :)");
else
    println("FAILED :(");
end

#black king in check by white rock
fenstring = "r1bR2k1/ppp2ppp/5n2/4p1N1/1n2P3/2N1KQ2/PPP2PPP/R1B5 b - - 2 12";
player = 0;
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t:\t");
if ischecked(currentbitboard,player)
    println("passed :)");
else
    println("FAILED :(");
end

#black king in check by white queen
fenstring = "r1bRn1k1/ppp2Qpp/8/4p1N1/1n2P3/2N1K3/PPP2PPP/R1B5 b - - 0 13";
player = 0;
currentbitboard = bitboardfromfen(fenstring);
print(fenstring,"\t:\t");
if ischecked(currentbitboard,player)
    println("passed :)");
else
    println("FAILED :(");
end
