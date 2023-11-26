#======================================================================
    Play chess on a command line against a neural network

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 29/10/2023
======================================================================#
using Flux;
using JLD2;
include("dev/08b_bitboard_from_fen_v2.jl");
include("dev/09_minimax_search.jl");


#initialization
myneuralnet = JLD2.load("./models/myneuralnet_24k.jld2","myneuralnet");
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


#display board on screen
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
    maxdepth = 4;

    #choose the starting player
    print("Choose the starting player (1=you, -1=computer): ");
    startingplayer = readline();
    startingplayer = parse(Int,startingplayer);
    if startingplayer == -1
        println("The computer will be the white player");
        time1 = time();
        (computermove,childboard,childmovescore) = minimax(gameboard,-startingplayer,maxdepth,-1,1);
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
        (computermove,childboard,childmovescore) = minimax(gameboard,-startingplayer,maxdepth,-1,1);
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
