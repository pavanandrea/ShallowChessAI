#======================================================================
    This script converts a FEN string to a bitboard representation

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 06/10/2023
======================================================================#
include("05b_king_ischecked_v2.jl");


#read dataset and convert FEN to bitboard
rawdataset = readlines("dataset/dataset_20k_20deep.csv");
bitboard = [];
score = [];
for line in rawdataset[2:10]
    currententry = split(line, ",");
    push!(score, parse(Int,currententry[2]));

    #calculate bitboard
    #see: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation
    currentbitboard = zeros(775);
    #currentbitboard = [zeros(8,8), zeros(8,8), zeros(8,8), zeros(8,8), zeros(8,8), zeros(8,8), zeros(8,8), zeros(8,8), zeros(8,8), zeros(8,8), zeros(8,8), zeros(8,8)];
    fenstring = currententry[1];
    fenfields = split(fenstring, " ");
    #first field: piece placement
    pieces = ['P','N','B','R','Q','K','p','n','b','r','q','k'];
    currentsquare = 1;
    #i = 1;
    for c in fenfields[1]
        if c in "12345678"
            #skip empty squares
            currentsquare += parse(Int,c);
            #i += 12*parse(Int,c);
        elseif c != '/'
            currentpiece = findfirst(pieces.==c);
            #currentbitboard[i+currentpiece-1] = 1;
            #i += 12;
            currentbitboard[(currentpiece-1)*64+currentsquare] = 1;
            #currentbitboard[currentpiece][floor(Int,currentsquare/8+1),currentsquare%8+1] = 1;
            currentsquare += 1;
        end
    end
    #second field: moving player
    if fenfields[2]=="w"
        currentbitboard[end-6] = 1;
    end
    #third field: castling
    if 'K' in fenfields[3]
        currentbitboard[end-5] = 1;
    end
    if 'Q' in fenfields[3]
        currentbitboard[end-4] = 1;
    end
    if 'k' in fenfields[3]
        currentbitboard[end-3] = 1;
    end
    if 'q' in fenfields[3]
        currentbitboard[end-2] = 1;
    end
    #check if white king or black king are in check
    if ischecked(currentbitboard,1)
        currentbitboard[end-1] = 1;
    end
    if ischecked(currentbitboard,0);
        currentbitboard[end] = 1;
    end

    #save bitboard
    push!(bitboard, currentbitboard);
    println(fenstring);
    #println(Int.(currentbitboard));
    #println("Score = ",score[end],"\n");
end


#=
# -- early version for testing --
#see: https://lichess.org/analysis/standard/rn1qkb1r/pbpp1ppp/1p2p2B/8/3PP3/P1N5/1PP2PPP/R2QKBNR_b_KQkq_-_0_5
fenstring = "rn1qkb1r/pbpp1ppp/1p2p2B/8/3PP3/P1N5/1PP2PPP/R2QKBNR b KQkq - 0 5";
currentbitboard = zeros(775);
fenfields = split(fenstring, " ");
pieces = ['P','N','B','R','Q','K','p','n','b','r','q','k'];
currentsquare = 1;
for c in fenfields[1]
    if c in "12345678"
        #skip empty squares
        currentsquare += parse(Int,c);
    elseif c != '/'
        currentpiece = findfirst(pieces.==c);
        currentbitboard[(currentpiece-1)*64+currentsquare] = 1;
        currentsquare += 1;
    end
end
display(Int.(reshape(currentbitboard[1:64],(8,8)))');       #print the white pawn structure on the screen (should see the central pawns at positions 36-37 and the a3 pawn at postition 41)
=#
