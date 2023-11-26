#======================================================================
    This script converts a CSV dataset using a FEN string to represent
    boards to the following bitboard format:
    * bitboard[1:64] entries are for white pawns
    * bitboard[65:128] entries are for white knights
    * bitboard[129:192] entries are for white bishops
    * bitboard[193:256] entries are for white rocks
    * bitboard[257:320] entries are for white queens
    * bitboard[321:384] entries are for the white king
    * bitboard[385:448] entries are for black pawns
    * bitboard[385:512] entries are for black knights
    * bitboard[513:576] entries are for black bishops
    * bitboard[577:640] entries are for black rocks
    * bitboard[641:704] entries are for black queens
    * bitboard[705:768] entries are for the black king
    * bitboard[769] indicates the moving player
    * bitboard[770:773] show the castling options
    * bitboard[774:775] indicate if a king is in check
    * bitboard[776:783] indicate if each column pawn has just been moved by two squares (for en-passant)
    The output CSV file also contains the board score as evaluated
    by Stockfish.

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 11/10/2023
======================================================================#
using Random;
include("08b_bitboard_from_fen_v1.jl");


function main()
    println("ShallowChessAI - Dataset conversion from FEN to bitboard");
    #fileout = joinpath(@__DIR__,"../dataset/training_dataset_117k.csv");
    fileout = joinpath(@__DIR__,"../dataset/training_dataset_483k.csv");

    #create an empty CSV file
    if !isfile(fileout)
        csvfileio = open(fileout,"w");
        write(csvfileio, "bitboard,score\n");
        close(csvfileio);
    end

    #merge raw dataset and augmented dataset
    #datain = vcat(readlines("../dataset/dataset_20k_20deep.csv")[2:end], readlines("../dataset/dataset_random_97k_10deep.csv")[2:end]);
    datain = vcat(
        readlines(joinpath(@__DIR__,"../dataset/dataset_811k_10deep.csv"))[2:100_000],
        readlines(joinpath(@__DIR__,"../dataset/dataset_random_383k_10deep.csv"))[2:end]
    );
    datain = datain[shuffle(1:end)];

    #convert dataset
    for (i,line) in enumerate(datain)
        currententry = split(line, ",");
        #currentscore = parse(Int,currententry[2]);

        #calculate bitboard
        currentbitboard = zeros(783);
        currentbitboard = bitboardfromfen(currententry[1]);

        #save bitboard
        csvfileio = open(fileout,"a");
        write(csvfileio, string(findall(currentbitboard.==1))*","*currententry[2]*"\n");
        close(csvfileio);

        #show progress
        if i%floor(Int,length(datain)/100)==0
            println("Parsing progress: ",floor(Int,i/floor(Int,length(datain)/100)),"%");
        end
    end
    println("Completed");
end
main();
