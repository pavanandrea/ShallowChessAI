#======================================================================
    Play chess on a command line against a neural network

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 03/12/2023
======================================================================#
include("./dev/08b_bitboard_from_fen_v2.jl");
include("./dev/09_minimax_search.jl");


#import 24k model
#myneuralnet = JLD2.load(joinpath(@__DIR__,"../models/myneuralnet_24k.jld2"),"myneuralnet");
W1 = Matrix{Float32}(undef,30,783);
b1 = Vector{Float32}(undef,30);
W2 = Matrix{Float32}(undef,30,30);
b2 = Vector{Float32}(undef,30);
W3 = Matrix{Float32}(undef,1,30);
b3 = Vector{Float32}(undef,1);
function import24kmodel(binfile)
    arrayin = Vector{Float32}(undef,filesize(binfile)÷4);
    read!(binfile,arrayin);
    global W1 = reshape(arrayin[4:23493],30,783);
    global b1 = arrayin[23494:23523];
    global W2 = reshape(arrayin[23527:24426],30,30);
    global b2 = arrayin[24427:24456];
    global W3 = reshape(arrayin[24460:24489],1,30);
    global b3 = [arrayin[24490]];
end
import24kmodel(joinpath(@__DIR__,"../models/myneuralnet_24k.bin"));
function myneuralnet(xin)
    a2 = tanh.(W1*xin.+b1);
    a3 = tanh.(W2*a2.+b2);
    return tanh.(W3*a3.+b3);
end


#batch-supporting score function
function batchscore(bitboards)
    N = size(bitboards,2);
    scores = myneuralnet(convert(Matrix{Float32},bitboards));
    for i=1:N
        currentbitboard = bitboards[:,i];
        if sum(currentbitboard[1:768])==2
            #draw - only two kings on the board
            scores[i] = 0;
        end
        if sum(currentbitboard[5*64+1:6*64])==0
            #white lost the king
            scores[i] = -1;
        end
        if sum(currentbitboard[11*64+1:12*64])==0
            #black lost the king
            scores[i] = 1;
        end
    end
    return scores;
end


#zero-lookahead batch inference
function batchinference(board,player)
    #check if the board is a terminal state
    if sum(board[5*64+1:6*64])==0 || sum(board[11*64+1:12*64])==0 || sum(board[1:768])==2       #if isgameover(board)
        return ([0,0],board,score(board,true));
    end

    #find legal moves
    (availablemoves,childboards) = legalmoves(board,player);        #vector containing the legal moves and each subsequent board
    if length(availablemoves)==0
        return ([0,0],board,score(board,true));
    end

    #evaluate legal moves
    childscores = batchscore(childboards)[:];
    bestchildidx = 1;
    if player==1
        bestchildidx = findfirst(childscores.==maximum(childscores));
    else
        bestchildidx = findfirst(childscores.==minimum(childscores));
    end
    return (availablemoves[bestchildidx], childboards[:,bestchildidx], childscores[bestchildidx]);
end


#display board on screen
#pieces = ['P','N','B','R','Q','K','p','n','b','r','q','k'];
pieces = ['♙','♘','♗','♖','♕','♔','🨾','♞','♝','♜','♛','♚'];
squares = ["a8","b8","c8","d8","e8","f8","g8","h8",
            "a7","b7","c7","d7","e7","f7","g7","h7",
            "a6","b6","c6","d6","e6","f6","g6","h6",
            "a5","b5","c5","d5","e5","f5","g5","h5",
            "a4","b4","c4","d4","e4","f4","g4","h4",
            "a3","b3","c3","d3","e3","f3","g3","h3",
            "a2","b2","c2","d2","e2","f2","g2","h2",
            "a1","b1","c1","d1","e1","f1","g1","h1"];
function printboard(currentbitboard)
    #write(stdin.buffer, 0x0C);
    #moving player
    if currentbitboard[769]==1
        print("\n white");
    else
        print("\n black");
    end
    #castling options
    print("  ");
    if currentbitboard[770]==1
        print("K");
    else
        print("-");
    end
    if currentbitboard[771]==1
        print("Q");
    else
        print("-");
    end
    if currentbitboard[772]==1
        print("k");
    else
        print("-");
    end
    if currentbitboard[773]==1
        print("q");
    else
        print("-");
    end
    #board
    for i=1:64
        if (i-1)%8==0
            print("\n ");
        end
        currentpieceidx = findfirst(currentbitboard[i.+(0:11)*64].==1);
        if isnothing(currentpieceidx)
            print("."," ");
        else
            print(pieces[currentpieceidx]," ");
        end
    end
    println("\n");
    #write(stdin.buffer, 0x0C);
end


#main function
function main()
    println("ShallowChessAI - Chess game on command line\n");
    gameboard = bitboardfromfen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    #maxdepth = 4;
    maxdepth = 1;

    #choose the starting player
    print("Choose the starting player (1=you, -1=computer): ");
    startingplayer = readline();
    startingplayer = parse(Int,startingplayer);
    if startingplayer == -1
        println("The computer will be the white player");
        time1 = time();
        if maxdepth>1
            (computermove,childboard,childmovescore) = minimax(gameboard,-startingplayer,maxdepth,-1,1);
        else
            (computermove,childboard,childmovescore) = batchinference(gameboard,-startingplayer);
        end
        println("Computer move: ",printsquare(computermove[1]),printsquare(computermove[2])," (score: ",childmovescore,", analyzed in ",round(time()-time1,digits=2)," s)");
        gameboard = childboard;
    else
        println("You will be the white player");
        startingplayer = 1;
    end
    printboard(gameboard);

    #gameplay
    while !isgameover(gameboard)
        #player move
        move = [0, 0];
        (availablemoves,childboards) = legalmoves(gameboard,startingplayer);
        while move==[0,0]
            #ask the user for a valid move
            print("Your move: ");
            movestr = readline();
            if movestr[1:2] in squares && movestr[3:4] in squares
                move[1] = findfirst(squares.==movestr[1:2]);
                move[2] = findfirst(squares.==movestr[3:4]);
            end
            if move in availablemoves
                #println("Your move: ",move);
                i = findfirst(x->x==move,availablemoves);
                gameboard = childboards[:,i];
            else
                println("Invalid move");
                move = [0, 0];
            end
        end
        #printboard(gameboard);

        #computer move (minimax algorithm with alpha-beta pruning)
        if isgameover(gameboard)
            break;
        end
        time1 = time();
        if maxdepth>1
            (computermove,childboard,childmovescore) = minimax(gameboard,-startingplayer,maxdepth,-1,1);
        else
            (computermove,childboard,childmovescore) = batchinference(gameboard,-startingplayer);
        end
        println("Computer move: ",printsquare(computermove[1]),printsquare(computermove[2])," (score: ",floor(Int,1500*childmovescore[1]^3),", analyzed in ",round(time()-time1,digits=2)," s)");
        gameboard = childboard;
        printboard(gameboard);
    end

    #the game has ended
    finalscore = score(gameboard)[1];
    println("Game is over (static score: ",1500*finalscore^3,")");
    #=if finalscore==1
        println("You have won");
    elseif finalscore==-1
        println("The computer has won");
    else
        println("The game ended in a tie");
    end=#
end
main();
