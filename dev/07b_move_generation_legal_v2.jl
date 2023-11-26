#======================================================================
    This script generates the legal moves in a given position
    using the simplest technique pseudolegal+validation

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 11/11/2023
======================================================================#
include("05b_king_ischecked_v3.jl");



"""
EMPTYSQUARE removes a piece from a square
    emptysquare!(bitboard,square)
INPUT:
    bitboard: vector of size >=12*64 representing a chess board
    square: int number between 1 and 64
"""
function emptysquare!(currentbitboard,square)
    if 1<=square<=64
        #pieces = ['P','N','B','R','Q','K','p','n','b','r','q','k'];
        for i=0:11
            currentbitboard[i*64+square] = 0;
        end
    end
end



"""
PRINTSQUARE prints a square in human notation to stdout
    s = printsquare(sq)
INPUT:
    sq: integer between 1 and 64
OUTPUT:
    s: string containing the square name
"""
function printsquare(sq)
    columns = ['a','b','c','d','e','f','g','h'];
    return string(columns[1+(sq-1)%8])*string(8-floor(Int,(sq-0.1)/8));
end



"""
PSEUDOLEGALMOVES generates all pseudo-legal moves given a board position
    moves = pseudolegalmoves(bitboard,player)
INPUT:
    bitboard: vector of size >=12*64 representing a chess board
OPTIONAL INPUT:
    player: color of the moving player [default: 1 (white)]
OUTPUT:
    moves: vector of vectors of size 2 (initial square and final square)
    childrenboard: vector of bitboards representing the boards after each possible move
"""
function pseudolegalmoves(currentbitboard,player=1)
    #pieces = ['P','N','B','R','Q','K','p','n','b','r','q','k'];
    #moves = [];
    #childrenboards = [];
    moves = Vector{Vector{Int}}(undef,0);
    childrenboards = Vector{BitVector}(undef,0);
    if player==1
        #white pawns
        for i=1+8:64-8
            #one square forward
            if currentbitboard[i]==1 && isempty(currentbitboard,i-8)==0
                push!(moves,[i,i-8]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 0;                         #set moving player
                childbitboard[i] = 0;                           #move piece
                if 9<=i<=16
                    #promotion to queen
                    childbitboard[4*64+i-8] = 1;
                else
                    #simple one square forward
                    childbitboard[i-8] = 1;
                end
                push!(childrenboards,childbitboard);
            end
            #capture on the right
            if currentbitboard[i]==1 && (i-1)%8<=6 && isempty(currentbitboard,i-8+1)==-1
                push!(moves,[i,i-8+1]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 0;                         #set moving player
                childbitboard[i] = 0;                           #move piece
                emptysquare!(childbitboard,i-8+1);
                childbitboard[i-8+1] = 1;
                push!(childrenboards,childbitboard);
            end
            #capture on the left
            if currentbitboard[i]==1 && (i-1)%8>=1 && isempty(currentbitboard,i-8-1)==-1
                push!(moves,[i,i-8-1]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 0;                         #set moving player
                childbitboard[i] = 0;                           #move piece
                emptysquare!(childbitboard,i-8-1);
                childbitboard[i-8-1] = 1;
                push!(childrenboards,childbitboard);
            end
        end
        for i=49:56
            #two squares forward
            if currentbitboard[i]==1 && isempty(currentbitboard,i-8)==0 && isempty(currentbitboard,i-16)==0
                push!(moves,[i,i-16]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 0;                         #set moving player
                childbitboard[i] = 0;                           #move piece
                childbitboard[i-16] = 1;
                childbitboard[775+(i-48)] = 1;                  #set en-passant flag
                push!(childrenboards,childbitboard);
            end
        end
        for i=25+1:32
            #en-passant capture on the left
            if currentbitboard[i]==1 && currentbitboard[775+(i-24)-1]==1 && isempty(currentbitboard,i-1)==-1
                push!(moves,[i,i-8-1]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 0;                         #set moving player
                childbitboard[i] = 0;                           #move piece
                emptysquare!(childbitboard,i-1);
                childbitboard[i-8-1] = 1;
                push!(childrenboards,childbitboard);
            end
        end
        for i=25:32-1
            #en-passant capture on the right
            if currentbitboard[i]==1 && currentbitboard[775+(i-24)+1]==1 && isempty(currentbitboard,i+1)==-1
                push!(moves,[i,i-8+1]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 0;                         #set moving player
                childbitboard[i] = 0;                           #move piece
                emptysquare!(childbitboard,i+1);
                childbitboard[i-8+1] = 1;
                push!(childrenboards,childbitboard);
            end
        end


        #white knight
        for i=1:64
            if currentbitboard[64+i]==1
                if i>16 && (i-1)%8>=1 && isempty(currentbitboard,i-16-1)!=1
                    push!(moves,[i,i-16-1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[64+i] = 0;                        #move piece
                    emptysquare!(childbitboard,i-16-1);
                    childbitboard[64+i-16-1] = 1;
                    push!(childrenboards,childbitboard);
                end
                if i>16 && (i-1)%8<=6 && isempty(currentbitboard,i-16+1)!=1
                    push!(moves,[i,i-16+1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[64+i] = 0;                        #move piece
                    emptysquare!(childbitboard,i-16+1);
                    childbitboard[64+i-16+1] = 1;
                    push!(childrenboards,childbitboard);
                end
                if i>8 && (i-1)%8>=2 && isempty(currentbitboard,i-8-2)!=1
                    push!(moves,[i,i-8-2]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[64+i] = 0;                        #move piece
                    emptysquare!(childbitboard,i-8-2);
                    childbitboard[64+i-8-2] = 1;
                    push!(childrenboards,childbitboard);
                end
                if i>8 && (i-1)%8<=5 && isempty(currentbitboard,i-8+2)!=1
                    push!(moves,[i,i-8+2]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[64+i] = 0;                        #move piece
                    emptysquare!(childbitboard,i-8+2);
                    childbitboard[64+i-8+2] = 1;
                    push!(childrenboards,childbitboard);
                end
                if i<=48 && (i-1)%8>=1 && isempty(currentbitboard,i+16-1)!=1
                    push!(moves,[i,i+16-1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[64+i] = 0;                        #move piece
                    emptysquare!(childbitboard,i+16-1);
                    childbitboard[64+i+16-1] = 1;
                    push!(childrenboards,childbitboard);
                end
                if i<=48 && (i-1)%8<=6 && isempty(currentbitboard,i+16+1)!=1
                    push!(moves,[i,i+16+1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[64+i] = 0;                        #move piece
                    emptysquare!(childbitboard,i+16+1);
                    childbitboard[64+i+16+1] = 1;
                    push!(childrenboards,childbitboard);
                end
                if i<=56 && (i-1)%8>=2 && isempty(currentbitboard,i+8-2)!=1
                    push!(moves,[i,i+8-2]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[64+i] = 0;                        #move piece
                    emptysquare!(childbitboard,i+8-2);
                    childbitboard[64+i+8-2] = 1;
                    push!(childrenboards,childbitboard);
                end
                if i<=56 && (i-1)%8<=5 && isempty(currentbitboard,i+8+2)!=1
                    push!(moves,[i,i+8+2]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[64+i] = 0;                        #move piece
                    emptysquare!(childbitboard,i+8+2);
                    childbitboard[64+i+8+2] = 1;
                    push!(childrenboards,childbitboard);
                end
            end
        end


        #white bishop (and queen by diagonal)
        for i=1:64
            if currentbitboard[2*64+i]==1 || currentbitboard[4*64+i]==1
                #upper-left diagonal
                jmax = min((i-1)%8, floor(Int,(i-0.1)/8));
                for j=1:jmax
                    if isempty(currentbitboard,i-8*j-j)!=1
                        push!(moves,[i,i-8*j-j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 0;                         #set moving player
                        emptysquare!(childbitboard,i-8*j-j);            #move piece
                        childbitboard[2*64+i-8*j-j] = childbitboard[2*64+i];
                        childbitboard[4*64+i-8*j-j] = childbitboard[4*64+i];
                        childbitboard[2*64+i] = 0;
                        childbitboard[4*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i-8*j-j)!=0
                        break;
                    end
                end
                #upper-right diagonal
                jmax = min(7-(i-1)%8, floor(Int,(i-0.1)/8));
                for j=1:jmax
                    if isempty(currentbitboard,i-8*j+j)!=1
                        push!(moves,[i,i-8*j+j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 0;                         #set moving player
                        emptysquare!(childbitboard,i-8*j+j);            #move piece
                        childbitboard[2*64+i-8*j+j] = childbitboard[2*64+i];
                        childbitboard[4*64+i-8*j+j] = childbitboard[4*64+i];
                        childbitboard[2*64+i] = 0;
                        childbitboard[4*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i-8*j+j)!=0
                        break;
                    end
                end
                #lower-left diagonal
                jmax = min((i-1)%8, 7-floor(Int,(i-0.1)/8));
                for j=1:jmax
                    if isempty(currentbitboard,i+8*j-j)!=1
                        push!(moves,[i,i+8*j-j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 0;                         #set moving player
                        emptysquare!(childbitboard,i+8*j-j);            #move piece
                        childbitboard[2*64+i+8*j-j] = childbitboard[2*64+i];
                        childbitboard[4*64+i+8*j-j] = childbitboard[4*64+i];
                        childbitboard[2*64+i] = 0;
                        childbitboard[4*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i+8*j-j)!=0
                        break;
                    end
                end
                #lower-right diagonal
                jmax = min(7-(i-1)%8, 7-floor(Int,(i-0.1)/8));
                for j=1:jmax
                    if isempty(currentbitboard,i+8*j+j)!=1
                        push!(moves,[i,i+8*j+j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 0;                         #set moving player
                        emptysquare!(childbitboard,i+8*j+j);            #move piece
                        childbitboard[2*64+i+8*j+j] = childbitboard[2*64+i];
                        childbitboard[4*64+i+8*j+j] = childbitboard[4*64+i];
                        childbitboard[2*64+i] = 0;
                        childbitboard[4*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i+8*j+j)!=0
                        break;
                    end
                end
            end
        end


        #white rock (and queen by row/column)
        for i=1:64
            if currentbitboard[3*64+i]==1 || currentbitboard[4*64+i]==1
                #west direction
                for j=1:(i-1)%8
                    if isempty(currentbitboard,i-j)!=1
                        push!(moves,[i,i-j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 0;                         #set moving player
                        if i==64 && childbitboard[770]==1 && currentbitboard[3*64+i]==1
                            childbitboard[770] = 0;                     #clear kingside castling flag
                        end
                        if i==57 && childbitboard[771]==1 && currentbitboard[3*64+i]==1
                            childbitboard[771] = 0;                     #clear queenside castling flag
                        end
                        emptysquare!(childbitboard,i-j);                #move piece
                        childbitboard[3*64+i-j] = childbitboard[3*64+i];
                        childbitboard[4*64+i-j] = childbitboard[4*64+i];
                        childbitboard[3*64+i] = 0;
                        childbitboard[4*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i-j)!=0
                        break;
                    end
                end
                #east direction
                for j=1:7-(i-1)%8
                    if isempty(currentbitboard,i+j)!=1
                        push!(moves,[i,i+j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 0;                         #set moving player
                        if i==64 && childbitboard[770]==1 && currentbitboard[3*64+i]==1
                            childbitboard[770] = 0;                     #clear kingside castling flag
                        end
                        if i==57 && childbitboard[771]==1 && currentbitboard[3*64+i]==1
                            childbitboard[771] = 0;                     #clear queenside castling flag
                        end
                        emptysquare!(childbitboard,i+j);                #move piece
                        childbitboard[3*64+i+j] = childbitboard[3*64+i];
                        childbitboard[4*64+i+j] = childbitboard[4*64+i];
                        childbitboard[3*64+i] = 0;
                        childbitboard[4*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i+j)!=0
                        break;
                    end
                end
                #north direction
                for j=1:floor(Int,(i-0.1)/8)
                    if isempty(currentbitboard,i-8*j)!=1
                        push!(moves,[i,i-8*j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 0;                         #set moving player
                        if i==64 && childbitboard[770]==1 && currentbitboard[3*64+i]==1
                            childbitboard[770] = 0;                     #clear kingside castling flag
                        end
                        if i==57 && childbitboard[771]==1 && currentbitboard[3*64+i]==1
                            childbitboard[771] = 0;                     #clear queenside castling flag
                        end
                        emptysquare!(childbitboard,i-8*j);              #move piece
                        childbitboard[3*64+i-8*j] = childbitboard[3*64+i];
                        childbitboard[4*64+i-8*j] = childbitboard[4*64+i];
                        childbitboard[3*64+i] = 0;
                        childbitboard[4*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i-8*j)!=0
                        break;
                    end
                end
                #south direction
                for j=1:7-floor(Int,(i-0.1)/8)
                    if isempty(currentbitboard,i+8*j)!=1
                        push!(moves,[i,i+8*j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 0;                         #set moving player
                        if i==64 && childbitboard[770]==1 && currentbitboard[3*64+i]==1
                            childbitboard[770] = 0;                     #clear kingside castling flag
                        end
                        if i==57 && childbitboard[771]==1 && currentbitboard[3*64+i]==1
                            childbitboard[771] = 0;                     #clear queenside castling flag
                        end
                        emptysquare!(childbitboard,i+8*j);              #move piece
                        childbitboard[3*64+i+8*j] = childbitboard[3*64+i];
                        childbitboard[4*64+i+8*j] = childbitboard[4*64+i];
                        childbitboard[3*64+i] = 0;
                        childbitboard[4*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i+8*j)!=0
                        break;
                    end
                end
            end
        end

        
        #white king
        for i=1:64
            if currentbitboard[5*64+i]==1
                if i>8 && (i-1)%8>=1 && isempty(currentbitboard,i-8-1)!=1
                    push!(moves,[i,i-8-1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[5*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i-8-1);
                    childbitboard[5*64+i-8-1] = 1;
                    childbitboard[770] = 0;                         #clear castling flags
                    childbitboard[771] = 0;
                    push!(childrenboards,childbitboard);
                end
                if i>8 && isempty(currentbitboard,i-8)!=1
                    push!(moves,[i,i-8]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[5*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i-8);
                    childbitboard[5*64+i-8] = 1;
                    childbitboard[770] = 0;                         #clear castling flags
                    childbitboard[771] = 0;
                    push!(childrenboards,childbitboard);
                end
                if i>8 && (i-1)%8<=6 && isempty(currentbitboard,i-8+1)!=1
                    push!(moves,[i,i-8+1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[5*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i-8+1);
                    childbitboard[5*64+i-8+1] = 1;
                    childbitboard[770] = 0;                         #clear castling flags
                    childbitboard[771] = 0;
                    push!(childrenboards,childbitboard);
                end
                if (i-1)%8>=1 && isempty(currentbitboard,i-1)!=1
                    push!(moves,[i,i-1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[5*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i-1);
                    childbitboard[5*64+i-1] = 1;
                    childbitboard[770] = 0;                         #clear castling flags
                    childbitboard[771] = 0;
                    push!(childrenboards,childbitboard);
                end
                if (i-1)%8<=6 && isempty(currentbitboard,i+1)!=1
                    push!(moves,[i,i+1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[5*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i+1);
                    childbitboard[5*64+i+1] = 1;
                    childbitboard[770] = 0;                         #clear castling flags
                    childbitboard[771] = 0;
                    push!(childrenboards,childbitboard);
                end
                if i<=56 && (i-1)%8>=1 && isempty(currentbitboard,i+8-1)!=1
                    push!(moves,[i,i+8-1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[5*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i+8-1);
                    childbitboard[5*64+i+8-1] = 1;
                    childbitboard[770] = 0;                         #clear castling flags
                    childbitboard[771] = 0;
                    push!(childrenboards,childbitboard);
                end
                if i<=56 && isempty(currentbitboard,i+8)!=1
                    push!(moves,[i,i+8]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[5*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i+8);
                    childbitboard[5*64+i+8] = 1;
                    childbitboard[770] = 0;                         #clear castling flags
                    childbitboard[771] = 0;
                    push!(childrenboards,childbitboard);
                end
                if i<=56 && (i-1)%8<=6 && isempty(currentbitboard,i+8+1)!=1
                    push!(moves,[i,i+8+1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 0;                         #set moving player
                    childbitboard[5*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i+8+1);
                    childbitboard[5*64+i+8+1] = 1;
                    childbitboard[770] = 0;                         #clear castling flags
                    childbitboard[771] = 0;
                    push!(childrenboards,childbitboard);
                end
                break;
            end
        end
        if currentbitboard[770]==1 && currentbitboard[5*64+61]==1 && isempty(currentbitboard,62)==0 && isempty(currentbitboard,63)==0 && currentbitboard[3*64+64]==1
            #kingside castling
            if !ischecked(currentbitboard,1) && !ischecked(currentbitboard,1,62) && !ischecked(currentbitboard,1,63)
                push!(moves,[61,63]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 0;                         #set moving player
                emptysquare!(childbitboard,61);                 #move pieces
                emptysquare!(childbitboard,62);
                emptysquare!(childbitboard,63);
                emptysquare!(childbitboard,64);
                childbitboard[5*64+63] = 1;
                childbitboard[3*64+62] = 1;
                childbitboard[770] = 0;                         #clear castling flags
                childbitboard[771] = 0;
                push!(childrenboards,childbitboard);
            end
        end
        if currentbitboard[771]==1 && currentbitboard[5*64+61]==1 && isempty(currentbitboard,60)==0 && isempty(currentbitboard,59)==0 && isempty(currentbitboard,58)==0 && currentbitboard[3*64+57]==1
            #queenside castling
            if !ischecked(currentbitboard,1) && !ischecked(currentbitboard,1,60) && !ischecked(currentbitboard,1,59)
                push!(moves,[61,59]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 0;                         #set moving player
                emptysquare!(childbitboard,61);                 #move pieces
                emptysquare!(childbitboard,60);
                emptysquare!(childbitboard,59);
                emptysquare!(childbitboard,58);
                emptysquare!(childbitboard,57);
                childbitboard[5*64+59] = 1;
                childbitboard[3*64+60] = 1;
                childbitboard[770] = 0;                         #clear castling flags
                childbitboard[771] = 0;
                push!(childrenboards,childbitboard);
            end
        end

    else
        #black to move
        #pieces = ['P','N','B','R','Q','K','p','n','b','r','q','k'];


        #black pawns
        for i=1+8:64-8
            #one square forward
            if currentbitboard[6*64+i]==1 && isempty(currentbitboard,i+8)==0
                push!(moves,[i,i+8]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 1;                         #set moving player
                childbitboard[6*64+i] = 0;                      #move piece
                if 49<=i<=56
                    #promotion to queen
                    childbitboard[10*64+i-8] = 1;
                else
                    #simple one square forward
                    childbitboard[6*64+i-8] = 1;
                end
                #childbitboard[6*64+i+8] = 1;
                push!(childrenboards,childbitboard);
            end
            #capture on the right
            if currentbitboard[6*64+i]==1 && (i-1)%8<=6 && isempty(currentbitboard,i+8+1)==1
                push!(moves,[i,i+8+1]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 1;                         #set moving player
                childbitboard[6*64+i] = 0;                      #move piece
                emptysquare!(childbitboard,i+8+1);
                childbitboard[6*64+i+8+1] = 1;
                push!(childrenboards,childbitboard);
            end
            #capture on the left
            if currentbitboard[6*64+i]==1 && (i-1)%8>=1 && isempty(currentbitboard,i+8-1)==1
                push!(moves,[i,i+8-1]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 1;                         #set moving player
                childbitboard[6*64+i] = 0;                      #move piece
                emptysquare!(childbitboard,i+8-1);
                childbitboard[6*64+i+8-1] = 1;
                push!(childrenboards,childbitboard);
            end
        end
        for i=9:16
            #two squares forward
            if currentbitboard[6*64+i]==1 && isempty(currentbitboard,i+8)==0 && isempty(currentbitboard,i+16)==0
                push!(moves,[i,i+16]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 1;                         #set moving player
                childbitboard[6*64+i] = 0;                      #move piece
                childbitboard[6*64+i+16] = 1;
                childbitboard[775+(i-8)] = 1;                   #set en-passant flag
                push!(childrenboards,childbitboard);
            end
        end
        for i=33+1:40
            #en-passant capture on the left
            if currentbitboard[6*64+i]==1 && currentbitboard[775+(i-32)-1]==1 && isempty(currentbitboard,i-1)==1
                push!(moves,[i,i+8-1]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 1;                         #set moving player
                childbitboard[6*64+i] = 0;                      #move piece
                emptysquare!(childbitboard,i-1);
                childbitboard[6*64+i+8-1] = 1;
                push!(childrenboards,childbitboard);
            end
        end
        for i=33:40-1
            #en-passant capture on the right
            if currentbitboard[6*64+i]==1 && currentbitboard[775+(i-32)+1]==1 && isempty(currentbitboard,i+1)==1
                push!(moves,[i,i+8+1]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 1;                         #set moving player
                childbitboard[6*64+i] = 0;                      #move piece
                emptysquare!(childbitboard,i+1);
                childbitboard[6*64+i+8+1] = 1;
                push!(childrenboards,childbitboard);
            end
        end


        #black knight
        for i=1:64
            if currentbitboard[7*64+i]==1
                if i>16 && (i-1)%8>=1 && isempty(currentbitboard,i-16-1)!=-1
                    push!(moves,[i,i-16-1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[7*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i-16-1);
                    childbitboard[7*64+i-16-1] = 1;
                    push!(childrenboards,childbitboard);
                end
                if i>16 && (i-1)%8<=6 && isempty(currentbitboard,i-16+1)!=-1
                    push!(moves,[i,i-16+1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[7*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i-16+1);
                    childbitboard[7*64+i-16+1] = 1;
                    push!(childrenboards,childbitboard);
                end
                if i>8 && (i-1)%8>=2 && isempty(currentbitboard,i-8-2)!=-1
                    push!(moves,[i,i-8-2]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[7*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i-8-2);
                    childbitboard[7*64+i-8-2] = 1;
                    push!(childrenboards,childbitboard);
                end
                if i>8 && (i-1)%8<=5 && isempty(currentbitboard,i-8+2)!=-1
                    push!(moves,[i,i-8+2]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[7*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i-8+2);
                    childbitboard[7*64+i-8+2] = 1;
                    push!(childrenboards,childbitboard);
                end
                if i<=48 && (i-1)%8>=1 && isempty(currentbitboard,i+16-1)!=-1
                    push!(moves,[i,i+16-1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[7*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i+16-1);
                    childbitboard[7*64+i+16-1] = 1;
                    push!(childrenboards,childbitboard);
                end
                if i<=48 && (i-1)%8<=6 && isempty(currentbitboard,i+16+1)!=-1
                    push!(moves,[i,i+16+1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[7*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i+16+1);
                    childbitboard[7*64+i+16+1] = 1;
                    push!(childrenboards,childbitboard);
                end
                if i<=56 && (i-1)%8>=2 && isempty(currentbitboard,i+8-2)!=-1
                    push!(moves,[i,i+8-2]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[7*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i+8-2);
                    childbitboard[7*64+i+8-2] = 1;
                    push!(childrenboards,childbitboard);
                end
                if i<=56 && (i-1)%8<=5 && isempty(currentbitboard,i+8+2)!=-1
                    push!(moves,[i,i+8+2]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[7*64+i] = 0;                      #move piece
                    emptysquare!(childbitboard,i+8+2);
                    childbitboard[7*64+i+8+2] = 1;
                    push!(childrenboards,childbitboard);
                end
            end
        end


        #black bishop (and queen by diagonal)
        for i=1:64
            if currentbitboard[8*64+i]==1 || currentbitboard[10*64+i]==1
                #upper-left diagonal
                jmax = min((i-1)%8, floor(Int,(i-0.1)/8));
                for j=1:jmax
                    if isempty(currentbitboard,i-8*j-j)!=-1
                        push!(moves,[i,i-8*j-j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 1;                         #set moving player
                        emptysquare!(childbitboard,i-8*j-j);            #move piece
                        childbitboard[8*64+i-8*j-j] = childbitboard[8*64+i];
                        childbitboard[10*64+i-8*j-j] = childbitboard[10*64+i];
                        childbitboard[8*64+i] = 0;
                        childbitboard[10*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i-8*j-j)!=0
                        break;
                    end
                end
                #upper-right diagonal
                jmax = min(7-(i-1)%8, floor(Int,(i-0.1)/8));
                for j=1:jmax
                    if isempty(currentbitboard,i-8*j+j)!=-1
                        push!(moves,[i,i-8*j+j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 1;                         #set moving player
                        emptysquare!(childbitboard,i-8*j+j);            #move piece
                        childbitboard[8*64+i-8*j+j] = childbitboard[8*64+i];
                        childbitboard[10*64+i-8*j+j] = childbitboard[10*64+i];
                        childbitboard[8*64+i] = 0;
                        childbitboard[10*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i-8*j+j)!=0
                        break;
                    end
                end
                #lower-left diagonal
                jmax = min((i-1)%8, 7-floor(Int,(i-0.1)/8));
                for j=1:jmax
                    if isempty(currentbitboard,i+8*j-j)!=-1
                        push!(moves,[i,i+8*j-j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 1;                         #set moving player
                        emptysquare!(childbitboard,i+8*j-j);            #move piece
                        childbitboard[8*64+i+8*j-j] = childbitboard[8*64+i];
                        childbitboard[10*64+i+8*j-j] = childbitboard[10*64+i];
                        childbitboard[8*64+i] = 0;
                        childbitboard[10*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i+8*j-j)!=0
                        break;
                    end
                end
                #lower-right diagonal
                jmax = min(7-(i-1)%8, 7-floor(Int,(i-0.1)/8));
                for j=1:jmax
                    if isempty(currentbitboard,i+8*j+j)!=-1
                        push!(moves,[i,i+8*j+j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 1;                         #set moving player
                        emptysquare!(childbitboard,i+8*j+j);            #move piece
                        childbitboard[8*64+i+8*j+j] = childbitboard[8*64+i];
                        childbitboard[10*64+i+8*j+j] = childbitboard[10*64+i];
                        childbitboard[8*64+i] = 0;
                        childbitboard[10*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i+8*j+j)!=0
                        break;
                    end
                end
            end
        end


        #black rock (and queen by row/column)
        for i=1:64
            if currentbitboard[9*64+i]==1 || currentbitboard[10*64+i]==1
                #west direction
                for j=1:(i-1)%8
                    if isempty(currentbitboard,i-j)!=-1
                        push!(moves,[i,i-j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 1;                         #set moving player
                        if i==8 && childbitboard[772]==1 && currentbitboard[9*64+i]==1
                            childbitboard[772] = 0;                     #clear kingside castling flag
                        end
                        if i==1 && childbitboard[773]==1 && currentbitboard[9*64+i]==1
                            childbitboard[773] = 0;                     #clear queenside castling flag
                        end
                        emptysquare!(childbitboard,i-j);                #move piece
                        childbitboard[9*64+i-j] = childbitboard[9*64+i];
                        childbitboard[10*64+i-j] = childbitboard[10*64+i];
                        childbitboard[9*64+i] = 0;
                        childbitboard[10*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i-j)!=0
                        break;
                    end
                end
                #east direction
                for j=1:7-(i-1)%8
                    if isempty(currentbitboard,i+j)!=-1
                        push!(moves,[i,i+j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 1;                         #set moving player
                        if i==8 && childbitboard[772]==1 && currentbitboard[9*64+i]==1
                            childbitboard[772] = 0;                     #clear kingside castling flag
                        end
                        if i==1 && childbitboard[773]==1 && currentbitboard[9*64+i]==1
                            childbitboard[773] = 0;                     #clear queenside castling flag
                        end
                        emptysquare!(childbitboard,i+j);                #move piece
                        childbitboard[9*64+i+j] = childbitboard[9*64+i];
                        childbitboard[10*64+i+j] = childbitboard[10*64+i];
                        childbitboard[9*64+i] = 0;
                        childbitboard[10*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i+j)!=0
                        break;
                    end
                end
                #north direction
                for j=1:floor(Int,(i-0.1)/8)
                    if isempty(currentbitboard,i-8*j)!=-1
                        push!(moves,[i,i-8*j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 1;                         #set moving player
                        if i==8 && childbitboard[772]==1 && currentbitboard[9*64+i]==1
                            childbitboard[772] = 0;                     #clear kingside castling flag
                        end
                        if i==1 && childbitboard[773]==1 && currentbitboard[9*64+i]==1
                            childbitboard[773] = 0;                     #clear queenside castling flag
                        end
                        emptysquare!(childbitboard,i-8*j);              #move piece
                        childbitboard[9*64+i-8*j] = childbitboard[9*64+i];
                        childbitboard[10*64+i-8*j] = childbitboard[10*64+i];
                        childbitboard[9*64+i] = 0;
                        childbitboard[10*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i-8*j)!=0
                        break;
                    end
                end
                #south direction
                for j=1:7-floor(Int,(i-0.1)/8)
                    if isempty(currentbitboard,i+8*j)!=-1
                        push!(moves,[i,i+8*j]);
                        childbitboard = copy(currentbitboard);
                        childbitboard[776:783] .= 0;                    #clear en-passant flags
                        childbitboard[769] = 1;                         #set moving player
                        if i==8 && childbitboard[772]==1 && currentbitboard[9*64+i]==1
                            childbitboard[772] = 0;                     #clear kingside castling flag
                        end
                        if i==1 && childbitboard[773]==1 && currentbitboard[9*64+i]==1
                            childbitboard[773] = 0;                     #clear queenside castling flag
                        end
                        emptysquare!(childbitboard,i+8*j);              #move piece
                        childbitboard[9*64+i+8*j] = childbitboard[9*64+i];
                        childbitboard[10*64+i+8*j] = childbitboard[10*64+i];
                        childbitboard[9*64+i] = 0;
                        childbitboard[10*64+i] = 0;
                        push!(childrenboards,childbitboard);
                    end
                    if isempty(currentbitboard,i+8*j)!=0
                        break;
                    end
                end
            end
        end

        
        #black king
        for i=1:64
            if currentbitboard[11*64+i]==1
                if i>8 && (i-1)%8>=1 && isempty(currentbitboard,i-8-1)!=-1
                    #north-west square
                    push!(moves,[i,i-8-1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[11*64+i] = 0;                     #move piece
                    emptysquare!(childbitboard,i-8-1);
                    childbitboard[11*64+i-8-1] = 1;
                    childbitboard[772] = 0;                         #clear castling flags
                    childbitboard[773] = 0;
                    push!(childrenboards,childbitboard);
                end
                if i>8 && isempty(currentbitboard,i-8)!=-1
                    #north square
                    push!(moves,[i,i-8]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[11*64+i] = 0;                     #move piece
                    emptysquare!(childbitboard,i-8);
                    childbitboard[11*64+i-8] = 1;
                    childbitboard[772] = 0;                         #clear castling flags
                    childbitboard[773] = 0;
                    push!(childrenboards,childbitboard);
                end
                if i>8 && (i-1)%8<=6 && isempty(currentbitboard,i-8+1)!=-1
                    #north-east square
                    push!(moves,[i,i-8+1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[11*64+i] = 0;                     #move piece
                    emptysquare!(childbitboard,i-8+1);
                    childbitboard[11*64+i-8+1] = 1;
                    childbitboard[772] = 0;                         #clear castling flags
                    childbitboard[773] = 0;
                    push!(childrenboards,childbitboard);
                end
                if (i-1)%8>=1 && isempty(currentbitboard,i-1)!=-1
                    #west square
                    push!(moves,[i,i-1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[11*64+i] = 0;                     #move piece
                    emptysquare!(childbitboard,i-1);
                    childbitboard[11*64+i-1] = 1;
                    childbitboard[772] = 0;                         #clear castling flags
                    childbitboard[773] = 0;
                    push!(childrenboards,childbitboard);
                end
                if (i-1)%8<=6 && isempty(currentbitboard,i+1)!=-1
                    #east square
                    push!(moves,[i,i+1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[11*64+i] = 0;                     #move piece
                    emptysquare!(childbitboard,i+1);
                    childbitboard[11*64+i+1] = 1;
                    childbitboard[772] = 0;                         #clear castling flags
                    childbitboard[773] = 0;
                    push!(childrenboards,childbitboard);
                end
                if i<=56 && (i-1)%8>=1 && isempty(currentbitboard,i+8-1)!=-1
                    #south-east square
                    push!(moves,[i,i+8-1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[11*64+i] = 0;                     #move piece
                    emptysquare!(childbitboard,i+8-1);
                    childbitboard[11*64+i+8-1] = 1;
                    childbitboard[772] = 0;                         #clear castling flags
                    childbitboard[773] = 0;
                    push!(childrenboards,childbitboard);
                end
                if i<=56 && isempty(currentbitboard,i+8)!=-1
                    #south square
                    push!(moves,[i,i+8]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[11*64+i] = 0;                     #move piece
                    emptysquare!(childbitboard,i+8);
                    childbitboard[11*64+i+8] = 1;
                    childbitboard[772] = 0;                         #clear castling flags
                    childbitboard[773] = 0;
                    push!(childrenboards,childbitboard);
                end
                if i<=56 && (i-1)%8<=6 && isempty(currentbitboard,i+8+1)!=-1
                    #south-west square
                    push!(moves,[i,i+8+1]);
                    childbitboard = copy(currentbitboard);
                    childbitboard[776:783] .= 0;                    #clear en-passant flags
                    childbitboard[769] = 1;                         #set moving player
                    childbitboard[11*64+i] = 0;                     #move piece
                    emptysquare!(childbitboard,i+8+1);
                    childbitboard[11*64+i+8+1] = 1;
                    childbitboard[772] = 0;                         #clear castling flags
                    childbitboard[773] = 0;
                    push!(childrenboards,childbitboard);
                end
                break;
            end
        end
        if currentbitboard[772]==1 && currentbitboard[11*64+5]==1 && isempty(currentbitboard,6)==0 && isempty(currentbitboard,7)==0 && currentbitboard[9*64+8]==1
            #kingside castling
            if !ischecked(currentbitboard,-1) && !ischecked(currentbitboard,-1,6) && !ischecked(currentbitboard,-1,7)
                push!(moves,[5,7]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 1;                         #set moving player
                emptysquare!(childbitboard,5);                  #move pieces
                emptysquare!(childbitboard,6);
                emptysquare!(childbitboard,7);
                emptysquare!(childbitboard,8);
                childbitboard[11*64+7] = 1;
                childbitboard[9*64+6] = 1;
                childbitboard[772] = 0;                         #clear castling flags
                childbitboard[773] = 0;
                push!(childrenboards,childbitboard);
            end
        end
        if currentbitboard[773]==1 && currentbitboard[11*64+5]==1 && isempty(currentbitboard,4)==0 && isempty(currentbitboard,3)==0 && isempty(currentbitboard,2)==0 && currentbitboard[9*64+1]==1
            #queenside castling
            if !ischecked(currentbitboard,-1) && !ischecked(currentbitboard,-1,4) && !ischecked(currentbitboard,-1,3)
                push!(moves,[5,3]);
                childbitboard = copy(currentbitboard);
                childbitboard[776:783] .= 0;                    #clear en-passant flags
                childbitboard[769] = 1;                         #set moving player
                emptysquare!(childbitboard,5);                  #move pieces
                emptysquare!(childbitboard,4);
                emptysquare!(childbitboard,3);
                emptysquare!(childbitboard,2);
                emptysquare!(childbitboard,1);
                childbitboard[11*64+3] = 1;
                childbitboard[9*64+4] = 1;
                childbitboard[772] = 0;                         #clear castling flags
                childbitboard[773] = 0;
                push!(childrenboards,childbitboard);
            end
        end

    end

    for childbitboard in childrenboards
        #set checked flag
        childbitboard[774] = 0;
        childbitboard[775] = 0;
        if ischecked(childbitboard,1)
            childbitboard[774] = 1;
        end
        if ischecked(childbitboard,-1)
            childbitboard[775] = 1;
        end
    end
    return (moves,childrenboards);
end



"""
LEGALMOVES generates all legal moves given a board position
    moves = legalmoves(bitboard,player)
INPUT:
    bitboard: vector of size >=12*64 representing a chess board
OPTIONAL INPUT:
    player: color of the moving player [default: 1 (white)]
OUTPUT:
    moves: vector of vectors of size 2 (initial square and final square)
    childrenboard: vector of bitboards representing the boards after each legal move
"""
function legalmoves(currentbitboard,player=1)
    (candidatemoves,candidateboards) = pseudolegalmoves(currentbitboard,player);
    moves = Vector{Vector{Int}}(undef,0);
    childrenboards = BitMatrix(undef,(783,0));
    childrenboards .= 0;
    for i=1:lastindex(candidatemoves)
        if (player==1 && candidateboards[i][774]==0) || (player!=1 && candidateboards[i][775]==0)
            push!(moves,candidatemoves[i]);
            childrenboards = hcat(childrenboards,candidateboards[i]);
        end
    end
    return (moves,childrenboards);
end



"""
PERFT is a debugging function that counts all the legal moves at a certain depth
    n = perft(bitboard,depth,player)
INPUT:
    bitboard: vector of size >=12*64 representing a chess board
OPTIONAL INPUT:
    depth: integer at which stopping the count [default: 0]
    player: color of the moving player [default: 1 (white)]
OUTPUT:
    n: number of legal moves
"""
function perft(currentbitboard,depth=0,player=1,showdepth=-1)
    (candidatemoves,candidateboards) = legalmoves(currentbitboard,player);
    nmoves = length(candidatemoves);
    if depth>0
        nmoves = 0;
        for i=1:lastindex(candidatemoves)
            nmoves += perft(candidateboards[:,i],depth-1,-1*player);
            if depth==showdepth     #for debugging
                println("Found: [",printsquare(candidatemoves[i][1]),",",printsquare(candidatemoves[i][2]),"] ",perft(candidateboards[:,i],depth-1,-1*player));
            end
        end
    end
    return nmoves;
end
