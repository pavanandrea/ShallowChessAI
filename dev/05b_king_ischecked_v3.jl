#======================================================================
    This script checks whether one of the kings is in check
    (rewritten from scratch)

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 27/10/2023
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
ISCHECKED checks if the player's king is in check or not
    ischecked(bitboard,player,square)
INPUT:
    bitboard: vector of size >=12*64 representing a chess board
OPTIONAL INPUT:
    player: color of the king to check [default: 1 (white)]
    square: specify a square different than the king [default: 0 (no)]
OUTPUT:
    ischecked: true if the king is checked by the opponent
"""
function ischecked(currentbitboard,player=1,square=0)
    #pieces = ['P','N','B','R','Q','K','p','n','b','r','q','k'];
    if player==1
        #find king position
        i = findfirst(currentbitboard[5*64+1:6*64].==1);
        if isnothing(i)
            return false;
        end
        if square!=0
            i = square;
        end
        

        #check by black pawns
        if i>16 && (i-1)%8>=1 && currentbitboard[6*64+i-8-1]==1
            #check by pawn on the upper-left
            return true;
        end
        if i>16 && (i-1)%8<=6 && currentbitboard[6*64+i-8+1]==1
            #check by pawn on the upper-right
            return true;
        end


        #check by black knight
        if i>16 && (i-1)%8>=1 && currentbitboard[7*64+i-16-1]==1
            return true;
        end
        if i>16 && (i-1)%8<=6 && currentbitboard[7*64+i-16+1]==1
            return true;
        end
        if i>8 && (i-1)%8>=2 && currentbitboard[7*64+i-8-2]==1
            return true;
        end
        if i>8 && (i-1)%8<=5 && currentbitboard[7*64+i-8+2]==1
            return true;
        end
        if i<=56 && (i-1)%8>=2 && currentbitboard[7*64+i+8-2]==1
            return true;
        end
        if i<=56 && (i-1)%8<=5 && currentbitboard[7*64+i+8+2]==1
            return true;
        end
        if i<=48 && (i-1)%8>=1 && currentbitboard[7*64+i+16-1]==1
            return true;
        end
        if i<=48 && (i-1)%8<=6 && currentbitboard[7*64+i+16+1]==1
            return true;
        end


        #check by black bishop (and queen by diagonal)
        #upper-left diagonal
        jmax = min((i-1)%8, floor(Int,(i-0.1)/8));
        for j=1:jmax
            if currentbitboard[8*64+i-8*j-j]==1 || currentbitboard[10*64+i-8*j-j]==1
                return true;
            end
            if isempty(currentbitboard,i-8*j-j)!=0
                break;
            end
        end
        #upper-right diagonal
        jmax = min(7-(i-1)%8, floor(Int,(i-0.1)/8));
        for j=1:jmax
            if currentbitboard[8*64+i-8*j+j]==1 || currentbitboard[10*64+i-8*j+j]==1
                return true;
            end
            if isempty(currentbitboard,i-8*j+j)!=0
                break;
            end
        end
        #lower-left diagonal
        jmax = min((i-1)%8, 7-floor(Int,(i-0.1)/8));
        for j=1:jmax
            if currentbitboard[8*64+i+8*j-j]==1 || currentbitboard[10*64+i+8*j-j]==1
                return true;
            end
            if isempty(currentbitboard,i+8*j-j)!=0
                break;
            end
        end
        #lower-right diagonal
        jmax = min(7-(i-1)%8, 7-floor(Int,(i-0.1)/8));
        for j=1:jmax
            if currentbitboard[8*64+i+8*j+j]==1 || currentbitboard[10*64+i+8*j+j]==1
                return true;
            end
            if isempty(currentbitboard,i+8*j+j)!=0
                break;
            end
        end


        #check by black rock (and queen by row)
        #west direction
        for j=1:(i-1)%8
            if currentbitboard[9*64+i-j]==1 || currentbitboard[10*64+i-j]==1
                return true;
            end
            if isempty(currentbitboard,i-j)!=0
                break;
            end
        end
        #east direction
        for j=1:7-(i-1)%8
            if currentbitboard[9*64+i+j]==1 || currentbitboard[10*64+i+j]==1
                return true;
            end
            if isempty(currentbitboard,i+j)!=0
                break;
            end
        end
        #north direction
        for j=1:floor(Int,(i-0.1)/8)
            if currentbitboard[9*64+i-8*j]==1 || currentbitboard[10*64+i-8*j]==1
                return true;
            end
            if isempty(currentbitboard,i-8*j)!=0
                break;
            end
        end
        #south direction
        for j=1:7-floor(Int,(i-0.1)/8)
            if currentbitboard[9*64+i+8*j]==1 || currentbitboard[10*64+i+8*j]==1
                return true;
            end
            if isempty(currentbitboard,i+8*j)!=0
                break;
            end
        end


        #check by black king (useful to discard illegal moves)
        if i>8 && (i-1)%8>=1 && currentbitboard[11*64+i-8-1]==1
            return true;
        end
        if i>8 && currentbitboard[11*64+i-8]==1
            return true;
        end
        if i>8 && (i-1)%8<=6 && currentbitboard[11*64+i-8+1]==1
            return true;
        end
        if (i-1)%8>=1 && currentbitboard[11*64+i-1]==1
            return true;
        end
        if (i-1)%8<=6 && currentbitboard[11*64+i+1]==1
            return true;
        end
        if i<=56 && (i-1)%8>=1 && currentbitboard[11*64+i+8-1]==1
            return true;
        end
        if i<=56 && currentbitboard[11*64+i+8]==1
            return true;
        end
        if i<=56 && (i-1)%8<=6 && currentbitboard[11*64+i+8+1]==1
            return true;
        end


    else
        #find king position
        i = findfirst(currentbitboard[11*64+1:12*64].==1);
        if isnothing(i)
            return false;
        end
        if square!=0
            i = square;
        end

        #check by white pawns
        if i<=48 && (i-1)%8>=1 && currentbitboard[0*64+i+8-1]==1
            #check by pawn on the lower-left
            return true;
        end
        if i<=48 && (i-1)%8<=6 && currentbitboard[0*64+i+8+1]==1
            #check by pawn on the upper-right
            return true;
        end


        #check by white knight
        if i>16 && (i-1)%8>=1 && currentbitboard[1*64+i-16-1]==1
            return true;
        end
        if i>16 && (i-1)%8<=6 && currentbitboard[1*64+i-16+1]==1
            return true;
        end
        if i>8 && (i-1)%8>=2 && currentbitboard[1*64+i-8-2]==1
            return true;
        end
        if i>8 && (i-1)%8<=5 && currentbitboard[1*64+i-8+2]==1
            return true;
        end
        if i<=56 && (i-1)%8>=2 && currentbitboard[1*64+i+8-2]==1
            return true;
        end
        if i<=56 && (i-1)%8<=5 && currentbitboard[1*64+i+8+2]==1
            return true;
        end
        if i<=48 && (i-1)%8>=1 && currentbitboard[1*64+i+16-1]==1
            return true;
        end
        if i<=48 && (i-1)%8<=6 && currentbitboard[1*64+i+16+1]==1
            return true;
        end


        #check by white bishop (and queen by diagonal)
        #upper-left diagonal
        jmax = min((i-1)%8, floor(Int,(i-0.1)/8));
        for j=1:jmax
            if currentbitboard[2*64+i-8*j-j]==1 || currentbitboard[4*64+i-8*j-j]==1
                return true;
            end
            if isempty(currentbitboard,i-8*j-j)!=0
                break;
            end
        end
        #upper-right diagonal
        jmax = min(7-(i-1)%8, floor(Int,(i-0.1)/8));
        for j=1:jmax
            if currentbitboard[2*64+i-8*j+j]==1 || currentbitboard[4*64+i-8*j+j]==1
                return true;
            end
            if isempty(currentbitboard,i-8*j+j)!=0
                break;
            end
        end
        #lower-left diagonal
        jmax = min((i-1)%8, 7-floor(Int,(i-0.1)/8));
        for j=1:jmax
            if currentbitboard[2*64+i+8*j-j]==1 || currentbitboard[4*64+i+8*j-j]==1
                return true;
            end
            if isempty(currentbitboard,i+8*j-j)!=0
                break;
            end
        end
        #lower-right diagonal
        jmax = min(7-(i-1)%8, 7-floor(Int,(i-0.1)/8));
        for j=1:jmax
            if currentbitboard[2*64+i+8*j+j]==1 || currentbitboard[4*64+i+8*j+j]==1
                return true;
            end
            if isempty(currentbitboard,i+8*j+j)!=0
                break;
            end
        end


        #check by white rock (and queen by row)
        #west direction
        for j=1:(i-1)%8
            if currentbitboard[3*64+i-j]==1 || currentbitboard[4*64+i-j]==1
                return true;
            end
            if isempty(currentbitboard,i-j)!=0
                break;
            end
        end
        #east direction
        for j=1:7-(i-1)%8
            if currentbitboard[3*64+i+j]==1 || currentbitboard[4*64+i+j]==1
                return true;
            end
            if isempty(currentbitboard,i+j)!=0
                break;
            end
        end
        #north direction
        for j=1:floor(Int,(i-0.1)/8)
            if currentbitboard[3*64+i-8*j]==1 || currentbitboard[4*64+i-8*j]==1
                return true;
            end
            if isempty(currentbitboard,i-8*j)!=0
                break;
            end
        end
        #south direction
        for j=1:7-floor(Int,(i-0.1)/8)
            if currentbitboard[3*64+i+8*j]==1 || currentbitboard[4*64+i+8*j]==1
                return true;
            end
            if isempty(currentbitboard,i+8*j)!=0
                break;
            end
        end


        #check by white king (useful to discard illegal moves)
        if i>8 && (i-1)%8>=1 && currentbitboard[5*64+i-8-1]==1
            return true;
        end
        if i>8 && currentbitboard[5*64+i-8]==1
            return true;
        end
        if i>8 && (i-1)%8<=6 && currentbitboard[5*64+i-8+1]==1
            return true;
        end
        if (i-1)%8>=1 && currentbitboard[5*64+i-1]==1
            return true;
        end
        if (i-1)%8<=6 && currentbitboard[5*64+i+1]==1
            return true;
        end
        if i<=56 && (i-1)%8>=1 && currentbitboard[5*64+i+8-1]==1
            return true;
        end
        if i<=56 && currentbitboard[5*64+i+8]==1
            return true;
        end
        if i<=56 && (i-1)%8<=6 && currentbitboard[5*64+i+8+1]==1
            return true;
        end

    end
    return false;
end
