#======================================================================
    This script finds the best move in a given board position using
    the Minimax search algorithm with alpha-beta pruning

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 29/10/2023
======================================================================#
include("07b_move_generation_legal_v2.jl");


"""
ISGAMEOVER returns true if the chess game reached an end
    res = isgameover(board)
INPUT:
    bitboard: vector of size 783 representing a chess board
OUTPUT:
    res: true if the chess game reached an end
"""
#check if the game is over
function isgameover(currentbitboard)
    #check if the kings are still in play
    if sum(currentbitboard[5*64+1:6*64])==0 || sum(currentbitboard[11*64+1:12*64])==0
        return true;
    end
    #check if the current player can move
    (moves,_) = legalmoves(currentbitboard,currentbitboard[769]);
    if length(moves)==0 || sum(currentbitboard[1:768])==2
        #no legal move available
        return true;
    end
    return false;
end



"""
SCORE returns the evaluation of a chess board
    s = score(bitboard,nolegalmoves)
INPUT:
    bitboard: vector of size 783 representing a chess board
OPTIONAL INPUT:
    nolegalmoves: flag to suggest if the current player has no legal moves [default: false]
OUTPUT:
    s: evaluation score of the board (a float number between -1 to +1)
"""
function score(currentbitboard,nolegalmoves=false)
    if sum(currentbitboard[1:768])==2
        #draw - only two kings on the board
        return 0;
    end
    if sum(currentbitboard[5*64+1:6*64])==0
        #white lost the king
        return -1;
    end
    if sum(currentbitboard[11*64+1:12*64])==0
        #black lost the king
        return 1;
    end
    player = currentbitboard[769];
    if nolegalmoves && (player==1 && currentbitboard[774]==1)
        #no legal moves and white is checked
        return -1;
    end
    if nolegalmoves && (player!=1 && currentbitboard[775]==1)
        #no legal moves and black is checked
        return 1;
    end
    #return myneuralnet(currentbitboard);
    return myneuralnet(convert(Vector{Float32},currentbitboard));
end



"""
MINIMAX is a recursive implementation of the minimax search algorithm with alpha-beta pruning
    (bestmove,childboard,score) = minimax(gameboard,player,maxdepth,α,β)
INPUT:
    bitboard: vector of size 783 representing a chess board
    player: moving player (1=white, -1=black)
OPTIONAL INPUT
    maxdepth: maximum depth limit [default: 4]
    α: pruning parameter for black [default: -1]
    β: pruning parameter for white [default: 1]
OUTPUT:
    bestmove: int vector of size 2 containing the starting square and the ending square
    childboard: bitboard after making the bestmove
    score: evaluation of the bitboard after making the bestmove 
"""
function minimax(board,player,maxdepth=4,α=-1,β=1)
    #check if the board is a terminal state
    if sum(board[5*64+1:6*64])==0 || sum(board[11*64+1:12*64])==0 || sum(board[1:768])==2       #if isgameover(board)
        return ([0,0],board,score(board,true));
    end

    #find legal moves
    (availablemoves,childboards) = legalmoves(board,player);        #vector containing the legal moves and each subsequent board
    if length(availablemoves)==0
        return ([0,0],board,score(board,true));
    end
    if maxdepth==0
        return ([0,0],board,score(board));
    end

    #evaluate legal moves
    bestmove = availablemoves[1];                                   #best move according to the minimax algorithm
    bestmovechildboard = childboards[:,1];                          #child board after doing the best move
    bestmovescore = -1*player;                                      #score of the best move
    for i=1:lastindex(availablemoves)
        #evaluate child node
        if maxdepth>0
            #recursive minimax
            (_,_,childmovescore) = minimax(childboards[:,i],-player,maxdepth-1,α,β);
        else
            #reached the depth limit
            return (availablemoves[i], childboards[:,i], score(childboards[:,i]));
        end

        #compare to the best child
        if (player==1 && childmovescore[1]>bestmovescore) || (player==-1 && childmovescore[1]<bestmovescore)
            bestmove = availablemoves[i];
            bestmovechildboard = childboards[:,i];
            bestmovescore = childmovescore[1];
        end

        #alpha-beta pruning
        if (player==1 && bestmovescore>β) || (player==-1 && bestmovescore<α)
            #stop evaluating other children
            break;
        end

        #update the values of α,β
        if player==1 && bestmovescore>α
            α = bestmovescore;
        elseif player==-1 && bestmovescore<β
            β = bestmovescore;
        end
    end
    return (bestmove, bestmovechildboard, bestmovescore);
end
