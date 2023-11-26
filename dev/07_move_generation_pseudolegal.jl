#======================================================================
    This script generates the pseudo-legal moves in a given position

    Warnings:
    - promotion to knight/bishop/rock not allowed
    - when making a move remember to enable/disable enpassant/castlings
    - on every pawn move, remember to set the bits 776-783


    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 21/10/2023
======================================================================#


"""
ISEMPTY checks whether or not a square is empty
    isempty(bitboard,square)
INPUT:
    bitboard: vector of size >=12*64 representing a chess board
    square: int number between 1 and 64
OUTPUT:
    isempty: true if the square has no piece on it
"""
function isempty(currentbitboard,square)
    if 1<=square<=64
        #pieces = ['P','N','B','R','Q','K','p','n','b','r','q','k'];
        for i=0:5
            if currentbitboard[i*64+square]!=0
                return 1;
            end
        end
        for i=6:11
            if currentbitboard[i*64+square]!=0
                return -1;
            end
        end
    end
    return 0;
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
"""
function pseudolegalmoves(currentbitboard,player=1)
    #pieces = ['P','N','B','R','Q','K','p','n','b','r','q','k'];
    moves = [];
    if player==1
        #white pawns
        for i=1+8:64-8
            #one square forward
            if currentbitboard[i]==1 && isempty(currentbitboard,i-8)==0
                push!(moves,[i,i-8]);
            end
            #capture on the right
            if currentbitboard[i]==1 && (i-1)%8<=6 && isempty(currentbitboard,i-8+1)==-1
                push!(moves,[i,i-8+1]);
            end
            #capture on the left
            if currentbitboard[i]==1 && (i-1)%8>=1 && isempty(currentbitboard,i-8-1)==-1
                push!(moves,[i,i-8-1]);
            end
        end
        for i=49:56
            #two squares forward
            if currentbitboard[i]==1 && isempty(currentbitboard,i-8)==0 && isempty(currentbitboard,i-16)==0
                push!(moves,[i,i-16]);
            end
        end
        for i=25+1:32
            #en-passant capture on the left
            if currentbitboard[i]==1 && currentbitboard[775+(i-24)-1]==1 && isempty(currentbitboard,i-1)==-1
                push!(moves,[i,i-8-1]);
            end
        end
        for i=25:32-1
            #en-passant capture on the right
            if currentbitboard[i]==1 && currentbitboard[775+(i-24)+1]==1 && isempty(currentbitboard,i+1)==-1
                push!(moves,[i,i-8+1]);
            end
        end


        #white knight
        for i=1:64
            if currentbitboard[64+i]==1
                if i>16 && (i-1)%8>=1 && isempty(currentbitboard,i-16-1)!=1
                    push!(moves,[i,i-16-1]);
                end
                if i>16 && (i-1)%8<=6 && isempty(currentbitboard,i-16+1)!=1
                    push!(moves,[i,i-16+1]);
                end
                if i>8 && (i-1)%8>=2 && isempty(currentbitboard,i-8-2)!=1
                    push!(moves,[i,i-8-2]);
                end
                if i>8 && (i-1)%8<=5 && isempty(currentbitboard,i-8+2)!=1
                    push!(moves,[i,i-8+2]);
                end
                if i<=48 && (i-1)%8>=1 && isempty(currentbitboard,i+16-1)!=1
                    push!(moves,[i,i+16-1]);
                end
                if i<=48 && (i-1)%8<=6 && isempty(currentbitboard,i+16+1)!=1
                    push!(moves,[i,i+16+1]);
                end
                if i<=56 && (i-1)%8>=2 && isempty(currentbitboard,i+8-2)!=1
                    push!(moves,[i,i+8-2]);
                end
                if i<=56 && (i-1)%8<=5 && isempty(currentbitboard,i+8+2)!=1
                    push!(moves,[i,i+8+2]);
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
                    end
                    if isempty(currentbitboard,i-j)!=0
                        break;
                    end
                end
                #east direction
                for j=1:7-(i-1)%8
                    if isempty(currentbitboard,i+j)!=1
                        push!(moves,[i,i+j]);
                    end
                    if isempty(currentbitboard,i+j)!=0
                        break;
                    end
                end
                #north direction
                for j=1:floor(Int,(i-0.1)/8)
                    if isempty(currentbitboard,i-8*j)!=1
                        push!(moves,[i,i-8*j]);
                    end
                    if isempty(currentbitboard,i-8*j)!=0
                        break;
                    end
                end
                #south direction
                for j=1:7-floor(Int,(i-0.1)/8)
                    if isempty(currentbitboard,i+8*j)!=1
                        push!(moves,[i,i+8*j]);
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
                end
                if i>8 && isempty(currentbitboard,i-8)!=1
                    push!(moves,[i,i-8]);
                end
                if i>8 && (i-1)%8<=6 && isempty(currentbitboard,i-8+1)!=1
                    push!(moves,[i,i-8+1]);
                end
                if (i-1)%8>=1 && isempty(currentbitboard,i-1)!=1
                    push!(moves,[i,i-1]);
                end
                if (i-1)%8<=6 && isempty(currentbitboard,i+1)!=1
                    push!(moves,[i,i+1]);
                end
                if i<=56 && (i-1)%8>=1 && isempty(currentbitboard,i+8-1)!=1
                    push!(moves,[i,i+8-1]);
                end
                if i<=56 && isempty(currentbitboard,i+8)!=1
                    push!(moves,[i,i+8]);
                end
                if i<=56 && (i-1)%8<=6 && isempty(currentbitboard,i+8+1)!=1
                    push!(moves,[i,i+8+1]);
                end
                break;
            end
        end
        if currentbitboard[770]==1 && currentbitboard[5*64+61]==1 && isempty(currentbitboard,62)==0 && isempty(currentbitboard,63)==0 && currentbitboard[3*64+64]==1
            #kingside castling
            if !ischecked(currentbitboard,1) && !ischecked(currentbitboard,1,62) && !ischecked(currentbitboard,1,63)
                push!(moves,[61,63]);
            end
        end
        if currentbitboard[771]==1 && currentbitboard[5*64+61]==1 && isempty(currentbitboard,60)==0 && isempty(currentbitboard,59)==0 && isempty(currentbitboard,58)==0 && currentbitboard[3*64+57]==1
            #queenside castling
            if !ischecked(currentbitboard,1) && !ischecked(currentbitboard,1,60) && !ischecked(currentbitboard,1,59)
                push!(moves,[61,59]);
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
            end
            #capture on the right
            if currentbitboard[6*64+i]==1 && (i-1)%8<=6 && isempty(currentbitboard,i+8+1)==1
                push!(moves,[i,i+8+1]);
            end
            #capture on the left
            if currentbitboard[6*64+i]==1 && (i-1)%8>=1 && isempty(currentbitboard,i+8-1)==1
                push!(moves,[i,i+8-1]);
            end
        end
        for i=9:16
            #two squares forward
            if currentbitboard[6*64+i]==1 && isempty(currentbitboard,i+8)==0 && isempty(currentbitboard,i+16)==0
                push!(moves,[i,i+16]);
            end
        end
        for i=33+1:40
            #en-passant capture on the left
            if currentbitboard[6*64+i]==1 && currentbitboard[775+(i-32)-1]==1 && isempty(currentbitboard,i-1)==1
                push!(moves,[i,i+8-1]);
            end
        end
        for i=33:40-1
            #en-passant capture on the right
            if currentbitboard[6*64+i]==1 && currentbitboard[775+(i-32)+1]==1 && isempty(currentbitboard,i+1)==1
                push!(moves,[i,i+8+1]);
            end
        end


        #black knight
        for i=1:64
            if currentbitboard[7*64+i]==1
                if i>16 && (i-1)%8>=1 && isempty(currentbitboard,i-16-1)!=-1
                    push!(moves,[i,i-16-1]);
                end
                if i>16 && (i-1)%8<=6 && isempty(currentbitboard,i-16+1)!=-1
                    push!(moves,[i,i-16+1]);
                end
                if i>8 && (i-1)%8>=2 && isempty(currentbitboard,i-8-2)!=-1
                    push!(moves,[i,i-8-2]);
                end
                if i>8 && (i-1)%8<=5 && isempty(currentbitboard,i-8+2)!=-1
                    push!(moves,[i,i-8+2]);
                end
                if i<=48 && (i-1)%8>=1 && isempty(currentbitboard,i+16-1)!=-1
                    push!(moves,[i,i+16-1]);
                end
                if i<=48 && (i-1)%8<=6 && isempty(currentbitboard,i+16+1)!=-1
                    push!(moves,[i,i+16+1]);
                end
                if i<=56 && (i-1)%8>=2 && isempty(currentbitboard,i+8-2)!=-1
                    push!(moves,[i,i+8-2]);
                end
                if i<=56 && (i-1)%8<=5 && isempty(currentbitboard,i+8+2)!=-1
                    push!(moves,[i,i+8+2]);
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
                    end
                    if isempty(currentbitboard,i-j)!=0
                        break;
                    end
                end
                #east direction
                for j=1:7-(i-1)%8
                    if isempty(currentbitboard,i+j)!=-1
                        push!(moves,[i,i+j]);
                    end
                    if isempty(currentbitboard,i+j)!=0
                        break;
                    end
                end
                #north direction
                for j=1:floor(Int,(i-0.1)/8)
                    if isempty(currentbitboard,i-8*j)!=-1
                        push!(moves,[i,i-8*j]);
                    end
                    if isempty(currentbitboard,i-8*j)!=0
                        break;
                    end
                end
                #south direction
                for j=1:7-floor(Int,(i-0.1)/8)
                    if isempty(currentbitboard,i+8*j)!=-1
                        push!(moves,[i,i+8*j]);
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
                    push!(moves,[i,i-8-1]);
                end
                if i>8 && isempty(currentbitboard,i-8)!=-1
                    push!(moves,[i,i-8]);
                end
                if i>8 && (i-1)%8<=6 && isempty(currentbitboard,i-8+1)!=-1
                    push!(moves,[i,i-8+1]);
                end
                if (i-1)%8>=1 && isempty(currentbitboard,i-1)!=-1
                    push!(moves,[i,i-1]);
                end
                if (i-1)%8<=6 && isempty(currentbitboard,i+1)!=-1
                    push!(moves,[i,i+1]);
                end
                if i<=56 && (i-1)%8>=1 && isempty(currentbitboard,i+8-1)!=-1
                    push!(moves,[i,i+8-1]);
                end
                if i<=56 && isempty(currentbitboard,i+8)!=-1
                    push!(moves,[i,i+8]);
                end
                if i<=56 && (i-1)%8<=6 && isempty(currentbitboard,i+8+1)!=-1
                    push!(moves,[i,i+8+1]);
                end
                break;
            end
        end
        if currentbitboard[772]==1 && currentbitboard[11*64+5]==1 && isempty(currentbitboard,6)==0 && isempty(currentbitboard,7)==0 && currentbitboard[9*64+8]==1
            #kingside castling
            if !ischecked(currentbitboard,-1) && !ischecked(currentbitboard,-1,6) && !ischecked(currentbitboard,-1,7)
                push!(moves,[5,7]);
            end
        end
        if currentbitboard[773]==1 && currentbitboard[11*64+5]==1 && isempty(currentbitboard,4)==0 && isempty(currentbitboard,3)==0 && isempty(currentbitboard,2)==0 && currentbitboard[9*64+1]==1
            #queenside castling
            if !ischecked(currentbitboard,-1) && !ischecked(currentbitboard,-1,4) && !ischecked(currentbitboard,-1,3)
                push!(moves,[5,3]);
            end
        end

    end
    return moves;
end
