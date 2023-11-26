#======================================================================
    This script finds the best move in a given board position using
    the Minimax search algorithm with alpha-beta pruning
    (converted from Vector{Float32} to BitVector for efficiency)

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 11/11/2023
======================================================================#
include("05b_king_ischecked_v3.jl");



"""
BITBOARDFROMFEN converts a FEN string to a bitboard representation
see: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation
    bitboard = bitboardfromfen(fenstring)
INPUT:
    fenstring: FEN string
OUTPUT:
    bitboard: vector of size 12*64 representing a chess board
"""
function bitboardfromfen(fenstring)
    bitboard = BitVector(undef, 783);
    bitboard .= 0;
    fenfields = split(fenstring, " ");
    #=
    example: "rnb1kbnr/ppp1pppp/8/8/8/2N2q2/PPPP1PPP/R1BQKBNR w KQkq - 0 1"
    becomes: fenfields = [
        "rnb1kbnr/ppp1pppp/8/8/8/2N2q2/PPPP1PPP/R1BQKBNR",
        "w",
        "KQkq",
        "-",
        "0",
        "1"
    ]
    =#

    #parse first field: piece placement
    pieces = ['P','N','B','R','Q','K','p','n','b','r','q','k'];
    i = 1;
    for c in fenfields[1]
        if c in "12345678"
            #skip empty squares
            i += parse(Int,c);
        elseif c != '/'
            currentpiece = findfirst(pieces.==c);
            bitboard[(currentpiece-1)*64+i] = 1;
            i += 1;
        end
    end

    #parse second field: moving player
    if fenfields[2]=="w"
        bitboard[769] = 1;
    end

    #parse third field: castling
    if 'K' in fenfields[3]
        bitboard[770] = 1;
    end
    if 'Q' in fenfields[3]
        bitboard[771] = 1;
    end
    if 'k' in fenfields[3]
        bitboard[772] = 1;
    end
    if 'q' in fenfields[3]
        bitboard[773] = 1;
    end

    #check if white king or black king are in check
    if ischecked(bitboard,1)
        bitboard[774] = 1;
    end
    if ischecked(bitboard,0);
        bitboard[775] = 1;
    end

    #parse fourth field: en-passant
    if fenfields[4]!="-"
        enpassantcolumn = findfirst(['a','b','c','d','e','f','g','h'].==fenfields[4][1]);
        if !isnothing(enpassantcolumn) && (fenfields[4][2]=='5' || fenfields[4][2]=='4')
            bitboard[775+enpassantcolumn] = 1;
        end
    end
    return bitboard;
end
