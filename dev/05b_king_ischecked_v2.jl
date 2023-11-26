#======================================================================
    This script checks whether one of the kings is in check
    (solved the bug on column h of the v1)

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 07/10/2023
======================================================================#


"""
ISCHECKED checks if the player's king is in check or not
    ischecked(bitboard,player)
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
    kingposition = square;
    if player==1
        #find white king position
        if square==0
            kingposition = findfirst(currentbitboard[5*64+1:6*64].==1);
        end
        if isnothing(kingposition)
            return false;
        else
            kingposition -= 1;
        end

        #check by black pawn
        if (kingposition+1)>=16 && kingposition%8>=2 && currentbitboard[6*64+(kingposition+1)-8-1]==1
            return true;
        elseif (kingposition+1)>=16 && kingposition%8<=7 && currentbitboard[6*64+(kingposition+1)-8+1]==1
            return true;
        end

        #check by black knight
        if (kingposition+1)>=16 && kingposition%8>=2 && currentbitboard[7*64+(kingposition+1)-16-1]==1
            return true;
        elseif (kingposition+1)>=16 && kingposition%8<=7 && currentbitboard[7*64+(kingposition+1)-16+1]==1
            return true;
        elseif (kingposition+1)>=8 && kingposition%8>=3 && currentbitboard[7*64+(kingposition+1)-8-2]==1
            return true;
        elseif (kingposition+1)>=8 && kingposition%8<=6 && currentbitboard[7*64+(kingposition+1)-8+2]==1
            return true;
        elseif (kingposition+1)<=56 && kingposition%8>=3 && currentbitboard[7*64+(kingposition+1)+8-2]==1
            return true;
        elseif (kingposition+1)<=56 && kingposition%8<=6 && currentbitboard[7*64+(kingposition+1)+8+2]==1
            return true;
        elseif (kingposition+1)<=48 && kingposition%8>=2 && currentbitboard[7*64+(kingposition+1)+16-1]==1
            return true;
        elseif (kingposition+1)<=48 && kingposition%8<=7 && currentbitboard[7*64+(kingposition+1)+16+1]==1
            return true;
        end

        #check by black bishop (or queen by diagonal)
        if (kingposition+1)>=8 && kingposition%8>=1
            #upper-left diagonal
            imax = min(kingposition%8, floor(Int,((kingposition+1)-0.1)/8));
            for i=1:imax
                if currentbitboard[8*64+(kingposition+1)-8*i-i]==1 || currentbitboard[10*64+(kingposition+1)-8*i-i]==1
                    #bishop or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)-8*i-i]==1 || currentbitboard[1*64+(kingposition+1)-8*i-i]==1 || currentbitboard[2*64+(kingposition+1)-8*i-i]==1 || currentbitboard[3*64+(kingposition+1)-8*i-i]==1 || currentbitboard[4*64+(kingposition+1)-8*i-i]==1 || currentbitboard[5*64+(kingposition+1)-8*i-i]==1 || currentbitboard[6*64+(kingposition+1)-8*i-i]==1 || currentbitboard[7*64+(kingposition+1)-8*i-i]==1 || currentbitboard[9*64+(kingposition+1)-8*i-i]==1 || currentbitboard[11*64+(kingposition+1)-8*i-i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end
        if (kingposition+1)>=8 && kingposition%8<=6
            #upper-right diagonal
            imax = min(7-kingposition%8, floor(Int,((kingposition+1)-0.1)/8));
            for i=1:imax
                if currentbitboard[8*64+(kingposition+1)-8*i+i]==1 || currentbitboard[10*64+(kingposition+1)-8*i+i]==1
                    #bishop or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)-8*i+i]==1 || currentbitboard[1*64+(kingposition+1)-8*i+i]==1 || currentbitboard[2*64+(kingposition+1)-8*i+i]==1 || currentbitboard[3*64+(kingposition+1)-8*i+i]==1 || currentbitboard[4*64+(kingposition+1)-8*i+i]==1 || currentbitboard[5*64+(kingposition+1)-8*i+i]==1 || currentbitboard[6*64+(kingposition+1)-8*i+i]==1 || currentbitboard[7*64+(kingposition+1)-8*i+i]==1 || currentbitboard[9*64+(kingposition+1)-8*i+i]==1 || currentbitboard[11*64+(kingposition+1)-8*i+i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end
        if (kingposition+1)<=56 && kingposition%8>=1
            #lower-left diagonal
            imax = min(kingposition%8, 8-1-floor(Int,((kingposition+1)-0.1)/8));
            for i=1:imax
                if currentbitboard[8*64+(kingposition+1)+8*i-i]==1 || currentbitboard[10*64+(kingposition+1)+8*i-i]==1
                    #bishop or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)+8*i-i]==1 || currentbitboard[1*64+(kingposition+1)+8*i-i]==1 || currentbitboard[2*64+(kingposition+1)+8*i-i]==1 || currentbitboard[3*64+(kingposition+1)+8*i-i]==1 || currentbitboard[4*64+(kingposition+1)+8*i-i]==1 || currentbitboard[5*64+(kingposition+1)+8*i-i]==1 || currentbitboard[6*64+(kingposition+1)+8*i-i]==1 || currentbitboard[7*64+(kingposition+1)+8*i-i]==1 || currentbitboard[9*64+(kingposition+1)+8*i-i]==1 || currentbitboard[11*64+(kingposition+1)+8*i-i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end
        if (kingposition+1)<=56 && kingposition%8<=6
            #lower-right diagonal
            imax = min(7-kingposition%8, 8-1-floor(Int,((kingposition+1)-0.1)/8));
            for i=1:imax
                if currentbitboard[8*64+(kingposition+1)+8*i+i]==1 || currentbitboard[10*64+(kingposition+1)+8*i+i]==1
                    #bishop or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)+8*i+i]==1 || currentbitboard[1*64+(kingposition+1)+8*i+i]==1 || currentbitboard[2*64+(kingposition+1)+8*i+i]==1 || currentbitboard[3*64+(kingposition+1)+8*i+i]==1 || currentbitboard[4*64+(kingposition+1)+8*i+i]==1 || currentbitboard[5*64+(kingposition+1)+8*i+i]==1 || currentbitboard[6*64+(kingposition+1)+8*i+i]==1 || currentbitboard[7*64+(kingposition+1)+8*i+i]==1 || currentbitboard[9*64+(kingposition+1)+8*i+i]==1 || currentbitboard[11*64+(kingposition+1)+8*i+i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end

        #check by black rock (or queen by row)
        if kingposition%8>=1
            #west direction
            for i=1:kingposition%8
                if currentbitboard[9*64+(kingposition+1)-i]==1 || currentbitboard[10*64+(kingposition+1)-i]==1
                    #rock or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)-i]==1 || currentbitboard[1*64+(kingposition+1)-i]==1 || currentbitboard[2*64+(kingposition+1)-i]==1 || currentbitboard[3*64+(kingposition+1)-i]==1 || currentbitboard[4*64+(kingposition+1)-i]==1 || currentbitboard[5*64+(kingposition+1)-i]==1 || currentbitboard[6*64+(kingposition+1)-i]==1 || currentbitboard[7*64+(kingposition+1)-i]==1 || currentbitboard[8*64+(kingposition+1)-i]==1 || currentbitboard[11*64+(kingposition+1)-i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end
        if kingposition%8<=6
            #east direction
            for i=1:7-kingposition%8
                if currentbitboard[9*64+(kingposition+1)+i]==1 || currentbitboard[10*64+(kingposition+1)+i]==1
                    #rock or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)+i]==1 || currentbitboard[1*64+(kingposition+1)+i]==1 || currentbitboard[2*64+(kingposition+1)+i]==1 || currentbitboard[3*64+(kingposition+1)+i]==1 || currentbitboard[4*64+(kingposition+1)+i]==1 || currentbitboard[5*64+(kingposition+1)+i]==1 || currentbitboard[6*64+(kingposition+1)+i]==1 || currentbitboard[7*64+(kingposition+1)+i]==1 || currentbitboard[8*64+(kingposition+1)+i]==1 || currentbitboard[11*64+(kingposition+1)+i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end
        if (kingposition+1)>=8
            #north direction
            for i=1:floor(Int,((kingposition+1)-0.1)/8)
                if currentbitboard[9*64+(kingposition+1)-8*i]==1 || currentbitboard[10*64+(kingposition+1)-8*i]==1
                    #rock or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)-8*i]==1 || currentbitboard[1*64+(kingposition+1)-8*i]==1 || currentbitboard[2*64+(kingposition+1)-8*i]==1 || currentbitboard[3*64+(kingposition+1)-8*i]==1 || currentbitboard[4*64+(kingposition+1)-8*i]==1 || currentbitboard[5*64+(kingposition+1)-8*i]==1 || currentbitboard[6*64+(kingposition+1)-8*i]==1 || currentbitboard[7*64+(kingposition+1)-8*i]==1 || currentbitboard[8*64+(kingposition+1)-8*i]==1 || currentbitboard[11*64+(kingposition+1)-8*i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end
        if (kingposition+1)<=56
            #south direction
            for i=1:8-1-floor(Int,((kingposition+1)-0.1)/8)
                if currentbitboard[9*64+(kingposition+1)+8*i]==1 || currentbitboard[10*64+(kingposition+1)+8*i]==1
                    #rock or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)+8*i]==1 || currentbitboard[1*64+(kingposition+1)+8*i]==1 || currentbitboard[2*64+(kingposition+1)+8*i]==1 || currentbitboard[3*64+(kingposition+1)+8*i]==1 || currentbitboard[4*64+(kingposition+1)+8*i]==1 || currentbitboard[5*64+(kingposition+1)+8*i]==1 || currentbitboard[6*64+(kingposition+1)+8*i]==1 || currentbitboard[7*64+(kingposition+1)+8*i]==1 || currentbitboard[8*64+(kingposition+1)+8*i]==1 || currentbitboard[11*64+(kingposition+1)+8*i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end
        #check by black queen already analyzed


    else
        #find black king position
        if square==0
            kingposition = findfirst(currentbitboard[11*64+1:12*64].==1);
            if isnothing(kingposition)
                return false;
            else
                kingposition -= 1;
            end
        end

        #check by white pawn
        if (kingposition+1)<=48 && kingposition%8>=1 && currentbitboard[0*64+(kingposition+1)+8-1]==1
            return true;
        elseif (kingposition+1)<=48 && kingposition%8<=6 && currentbitboard[0*64+(kingposition+1)+8+1]==1
            return true;
        end

        #check by white knight
        if (kingposition+1)>=16 && kingposition%8>=1 && currentbitboard[1*64+(kingposition+1)-16-1]==1
            return true;
        elseif (kingposition+1)>=16 && kingposition%8<=6 && currentbitboard[1*64+(kingposition+1)-16+1]==1
            return true;
        elseif (kingposition+1)>=8 && kingposition%8>=2 && currentbitboard[1*64+(kingposition+1)-8-2]==1
            return true;
        elseif (kingposition+1)>=8 && kingposition%8<=5 && currentbitboard[1*64+(kingposition+1)-8+2]==1
            return true;
        elseif (kingposition+1)<=56 && kingposition%8>=2 && currentbitboard[1*64+(kingposition+1)+8-2]==1
            return true;
        elseif (kingposition+1)<=56 && kingposition%8<=5 && currentbitboard[1*64+(kingposition+1)+8+2]==1
            return true;
        elseif (kingposition+1)<=48 && kingposition%8>=1 && currentbitboard[1*64+(kingposition+1)+16-1]==1
            return true;
        elseif (kingposition+1)<=48 && kingposition%8<=6 && currentbitboard[1*64+(kingposition+1)+16+1]==1
            return true;
        end

        #check by white bishop (or queen by diagonal)
        if (kingposition+1)>=8 && kingposition%8>=1
            #upper-left diagonal
            imax = min(kingposition%8, floor(Int,((kingposition+1)-0.1)/8));
            for i=1:imax
                if currentbitboard[2*64+(kingposition+1)-8*i-i]==1 || currentbitboard[4*64+(kingposition+1)-8*i-i]==1
                    #bishop or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)-8*i-i]==1 || currentbitboard[1*64+(kingposition+1)-8*i-i]==1 || currentbitboard[3*64+(kingposition+1)-8*i-i]==1 || currentbitboard[5*64+(kingposition+1)-8*i-i]==1 || currentbitboard[6*64+(kingposition+1)-8*i-i]==1 || currentbitboard[7*64+(kingposition+1)-8*i-i]==1 || currentbitboard[8*64+(kingposition+1)-8*i-i]==1 || currentbitboard[9*64+(kingposition+1)-8*i-i]==1 || currentbitboard[10*64+(kingposition+1)-8*i-i]==1 || currentbitboard[11*64+(kingposition+1)-8*i-i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end
        if (kingposition+1)>=8 && kingposition%8<=6
            #upper-right diagonal
            imax = min(7-kingposition%8, floor(Int,((kingposition+1)-0.1)/8));
            for i=1:imax
                if currentbitboard[2*64+(kingposition+1)-8*i+i]==1 || currentbitboard[4*64+(kingposition+1)-8*i+i]==1
                    #bishop or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)-8*i+i]==1 || currentbitboard[1*64+(kingposition+1)-8*i+i]==1 || currentbitboard[3*64+(kingposition+1)-8*i+i]==1 || currentbitboard[5*64+(kingposition+1)-8*i+i]==1 || currentbitboard[6*64+(kingposition+1)-8*i+i]==1 || currentbitboard[7*64+(kingposition+1)-8*i+i]==1 || currentbitboard[8*64+(kingposition+1)-8*i+i]==1 || currentbitboard[9*64+(kingposition+1)-8*i+i]==1 || currentbitboard[10*64+(kingposition+1)-8*i+i]==1 || currentbitboard[11*64+(kingposition+1)-8*i+i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end
        if (kingposition+1)<=56 && kingposition%8>=1
            #lower-left diagonal
            imax = min(kingposition%8, 8-1-floor(Int,((kingposition+1)-0.1)/8));
            for i=1:imax
                if currentbitboard[2*64+(kingposition+1)+8*i-i]==1 || currentbitboard[4*64+(kingposition+1)+8*i-i]==1
                    #bishop or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)+8*i-i]==1 || currentbitboard[1*64+(kingposition+1)+8*i-i]==1 || currentbitboard[3*64+(kingposition+1)+8*i-i]==1 || currentbitboard[5*64+(kingposition+1)+8*i-i]==1 || currentbitboard[6*64+(kingposition+1)+8*i-i]==1 || currentbitboard[7*64+(kingposition+1)+8*i-i]==1 || currentbitboard[8*64+(kingposition+1)+8*i-i]==1 || currentbitboard[9*64+(kingposition+1)+8*i-i]==1 || currentbitboard[10*64+(kingposition+1)+8*i-i]==1 || currentbitboard[11*64+(kingposition+1)+8*i-i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end
        if (kingposition+1)<=56 && kingposition%8<=6
            #lower-right diagonal
            imax = min(7-kingposition%8, 8-1-floor(Int,((kingposition+1)-0.1)/8));
            for i=1:imax
                if currentbitboard[2*64+(kingposition+1)+8*i+i]==1 || currentbitboard[4*64+(kingposition+1)+8*i+i]==1
                    #bishop or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)+8*i+i]==1 || currentbitboard[1*64+(kingposition+1)+8*i+i]==1 || currentbitboard[3*64+(kingposition+1)+8*i+i]==1 || currentbitboard[5*64+(kingposition+1)+8*i+i]==1 || currentbitboard[6*64+(kingposition+1)+8*i+i]==1 || currentbitboard[7*64+(kingposition+1)+8*i+i]==1 || currentbitboard[8*64+(kingposition+1)+8*i+i]==1 || currentbitboard[9*64+(kingposition+1)+8*i+i]==1 || currentbitboard[10*64+(kingposition+1)+8*i+i]==1 || currentbitboard[11*64+(kingposition+1)+8*i+i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end

        #check by white rock (or queen by row)
        if kingposition%8>=1
            #west direction
            for i=1:kingposition%8
                if currentbitboard[3*64+(kingposition+1)-i]==1 || currentbitboard[4*64+(kingposition+1)-i]==1
                    #rock or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)-i]==1 || currentbitboard[1*64+(kingposition+1)-i]==1 || currentbitboard[2*64+(kingposition+1)-i]==1 || currentbitboard[5*64+(kingposition+1)-i]==1 || currentbitboard[6*64+(kingposition+1)-i]==1 || currentbitboard[7*64+(kingposition+1)-i]==1 || currentbitboard[8*64+(kingposition+1)-i]==1 || currentbitboard[9*64+(kingposition+1)-i]==1 || currentbitboard[10*64+(kingposition+1)-i]==1 || currentbitboard[11*64+(kingposition+1)-i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end
        if kingposition%8<=6
            #east direction
            for i=1:7-kingposition%8
                if currentbitboard[3*64+(kingposition+1)+i]==1 || currentbitboard[4*64+(kingposition+1)+i]==1
                    #rock or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)+i]==1 || currentbitboard[1*64+(kingposition+1)+i]==1 || currentbitboard[2*64+(kingposition+1)+i]==1 || currentbitboard[5*64+(kingposition+1)+i]==1 || currentbitboard[6*64+(kingposition+1)+i]==1 || currentbitboard[7*64+(kingposition+1)+i]==1 || currentbitboard[8*64+(kingposition+1)+i]==1 || currentbitboard[9*64+(kingposition+1)+i]==1 || currentbitboard[10*64+(kingposition+1)+i]==1 || currentbitboard[11*64+(kingposition+1)+i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end
        if (kingposition+1)>=8
            #north direction
            for i=1:floor(Int,((kingposition+1)-0.1)/8)
                if currentbitboard[3*64+(kingposition+1)-8*i]==1 || currentbitboard[4*64+(kingposition+1)-8*i]==1
                    #rock or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)-8*i]==1 || currentbitboard[1*64+(kingposition+1)-8*i]==1 || currentbitboard[2*64+(kingposition+1)-8*i]==1 || currentbitboard[5*64+(kingposition+1)-8*i]==1 || currentbitboard[6*64+(kingposition+1)-8*i]==1 || currentbitboard[7*64+(kingposition+1)-8*i]==1 || currentbitboard[8*64+(kingposition+1)-8*i]==1 || currentbitboard[9*64+(kingposition+1)-8*i]==1 || currentbitboard[10*64+(kingposition+1)-8*i]==1 || currentbitboard[11*64+(kingposition+1)-8*i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end
        if (kingposition+1)<=56
            #south direction
            for i=1:8-1-floor(Int,((kingposition+1)-0.1)/8)
                if currentbitboard[3*64+(kingposition+1)+8*i]==1 || currentbitboard[4*64+(kingposition+1)+8*i]==1
                    #rock or queen checking king
                    return true;
                elseif currentbitboard[0*64+(kingposition+1)+8*i]==1 || currentbitboard[1*64+(kingposition+1)+8*i]==1 || currentbitboard[2*64+(kingposition+1)+8*i]==1 || currentbitboard[5*64+(kingposition+1)+8*i]==1 || currentbitboard[6*64+(kingposition+1)+8*i]==1 || currentbitboard[7*64+(kingposition+1)+8*i]==1 || currentbitboard[8*64+(kingposition+1)+8*i]==1 || currentbitboard[9*64+(kingposition+1)+8*i]==1 || currentbitboard[10*64+(kingposition+1)+8*i]==1 || currentbitboard[11*64+(kingposition+1)+8*i]==1
                    #another piece blocking the row
                    break;
                end
            end
        end
        #check by white queen already analyzed
    end
    return false;
end
