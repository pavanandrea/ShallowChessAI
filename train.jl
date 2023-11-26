#======================================================================
    This script trains a small neural network (MLP architecture) to
    predict the score of a chess board.

    Recommended usage on single desktop CPU:
        julia train.jl -i dataset/training_dataset_483k.csv

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 25/11/2023
======================================================================#
using Flux;
using JLD2;
#using Plots;       #optional


#parse command line arguments
pgndatabase = "";                                   #full path to the large PGN database (for dataset generation only - not required for training)
stockfishexecutable = joinpath(@__DIR__,"./stockfish/stockfish-ubuntu-x86-64-avx2");    #full path to Stockfish engine (for dataset generation only - not required for training)
Nsamplestarget = 500_000;                                                               #desired total number of samples in the dataset (for dataset generation only - not required for training)
samplesaugmentingfactor = 0.8;                                                          #percentage of augmented boards in the dataset (for dataset generation only - not required for training)
datasetfile = joinpath(@__DIR__,"./dataset/training_dataset_483k.csv");                 #full path to the dataset CSV file (required for training)
resumefile = "";                                    #full path to a JLD2 checkpoint if resuming training (optional for training)
batchsize = 256;                                    #training batch size (required for training)
epochs = 300;                                       #number of training epochs (required for training)
println("ShallowChessAI - Training script","\n");
for (i,arg) in enumerate(ARGS)
    if arg == "--help" || arg == "-h"
        println("Command line options:")
        println("    -h, --help             Print this message");
        println("    --from-pgn FILE.pgn    Import a PGN database and generate dataset");
        println("    -i FILE.csv            Import a dataset in CSV format for training");
        println("    --resume FILE.jld2     Resume training from a JLD2 checkpoint");
        println("    --uci-engine FILE.exe  Path to Stockfish executable");
        println("Execution stopped\n");
        exit();
    elseif arg == "--from-pgn" && i<lastindex(ARGS)
        global pgndatabase = joinpath(@__DIR__,ARGS[i+1]);
    elseif arg == "-i" && i<lastindex(ARGS)
        global datasetfile = joinpath(@__DIR__,ARGS[i+1]);
    elseif arg == "--resume" && i<lastindex(ARGS)
        global resumefile = joinpath(@__DIR__,ARGS[i+1]);
    elseif arg == "--uci-engine" && i<lastindex(ARGS)
        global stockfishexecutable = joinpath(@__DIR__,ARGS[i+1]);
    #=else
        println("Unrecognized option \"",arg,"\"");
        println("Execution stopped");
        exit();=#
    end
end

println("Parameters:");
if pgndatabase != ""
    println("  pgndatabase = \"",pgndatabase,"\"");
    println("  Nsamplestarget = ",Nsamplestarget);
    println("  samplesaugmentingfactor = ",samplesaugmentingfactor);
else
    println("  datasetfile = \"",datasetfile,"\"");
end
if resumefile != ""
    println("  resumefile = \"",resumefile,"\"");
end
println("  batchsize = ",batchsize);
println("  epochs = ",epochs);
println("\n");


#-----------------------------------------------------------------------------------
#import PGN database
if pgndatabase != "" && isfile(pgndatabase)
    global datasetfile = replace(pgndatabase,".pgn"=>".csv");
    if !isfile(stockfishexecutable)
        error("ERROR: unable to find Stockfish executable");
        exit();
    end
    
    #convert PGN database to CSV dataset
    include("dev/10_extract_dataset_from_pgn.jl");
    Nextractedsamples = round(Int,Nsamplestarget*(1-samplesaugmentingfactor));      #number of boards to extract from PGN database
    #println("Extracting ",Nextractedsamples," boards");
    extractpgn(pgndatabase,datasetfile,stockfishexecutable,Nextractedsamples);
    println("\n");

    #expand CSV dataset by playing random moves
    include("dev/10b_expand_dataset.jl");
    for i in 1:round(Nsamplestarget/Nextractedsamples)-1
        println("Augmentation round ",floor(Int,i),"/",floor(Int,round(Nsamplestarget/Nextractedsamples)-1));
        expandcsvdataset(datasetfile,stockfishexecutable,Nextractedsamples);
        println("\n");
    end

    println("Dataset generation completed");
    println("Saved to file ",datasetfile);
    println("\n");
end


#-----------------------------------------------------------------------------------
#import CSV dataset
if !isfile(datasetfile)
    error("ERROR: dataset \"",datasetfile,"\" not found. Execution stopped.");
    exit();
end
println("ShallowChessAI - Training neural network");

#count the number of samples in the CSV dataset
N = -1;                             #total number of samples in the dataset (initialized to -1 to account for the column names in the first row)
for line in eachline(datasetfile)
    global N += 1;
end
println("Found ",N, " samples in the dataset");
Ntrain = floor(Int,0.8*N);          #number of training samples
Nvalidation = N-Ntrain;             #number of validation samples
#drop some samples in order to have a constant batch size
Ntrain -= Ntrain%batchsize;
Nvalidation -= Nvalidation%batchsize;
println("  ",Ntrain," are used for training");
println("  ",Nvalidation," are used for validation");
println("  ",N-Ntrain-Nvalidation," are dropped");


#import data
include("dev/08b_bitboard_from_fen_v2.jl");
xtrain = zeros(Float32,(783,Ntrain));
xvalidation = zeros(Float32,(783,Nvalidation));
ytrain = zeros(Float32,(1,Ntrain));
yvalidation = zeros(Float32,(1,Nvalidation));
#read dataset from CSV
for (i,line) in enumerate(eachline(datasetfile))
    if i>1
        #convert fen string to bitboard
        #line example: "r3kb1r/pp1b3p/7n/n1p1pp2/2PpP1p1/PP1P2PP/3N1P1N/1RB1KB1R w Kkq - 0 16,204"
        currententry = split(line, ",");
        currentbitboard = bitboardfromfen(currententry[1]);
        if i<=Ntrain
            xtrain[:,i] .= convert(Vector{Float32},currentbitboard);
            ytrain[i] = parse(Int,currententry[end]);
        elseif Ntrain<i<=Ntrain+Nvalidation
            xvalidation[:,i-Ntrain] .= convert(Vector{Float32},currentbitboard);
            yvalidation[i-Ntrain] = parse(Int,currententry[end]);
        end

        #=
        #code to parse an old version of the dataset with the nonzero bitboard entries instead of fen string
        #line example: "[38, 42, 45, 49, 51, ... , 577, 629, 710, 769],1559"
        currententry = parse.(Int,split(replace(line,"["=>"","]"=>""," "=>""), ","));
        if i<=Ntrain
            xtrain[currententry[1:end-1],i] .= 1;
            ytrain[i] = currententry[end];
        elseif Ntrain<i<=Ntrain+Nvalidation
            xvalidation[currententry[1:end-1],i-Ntrain] .= 1;
            yvalidation[i-Ntrain] = currententry[end];
        end
        =#
    end
end
#cap boards evaluations to ±1500 centipawns (±15 pawns)
ytrain[findall(ytrain.>=1500)] .= 1500;
ytrain[findall(ytrain.<=-1500)] .= -1500;
yvalidation[findall(yvalidation.>=1500)] .= 1500;
yvalidation[findall(yvalidation.<=-1500)] .= -1500;
#normalize boards evaluations to the range [-1,1]
ytrain = @. cbrt(ytrain/1500);
yvalidation = @. cbrt(yvalidation/1500);
println("Dataset parsed successfully","\n");


#define neural network architecture and loss function
println("Defining a MLP neural network:");
myneuralnet = Chain(
    Dense(783 => 30, tanh),
    Dense(30 => 30, tanh),
    Dense(30 => 1, tanh)
);
#OR resume existing neural network from file
if resumefile != ""
    #myneuralnet = JLD2.load("myneuralnet_training_checkpoint.jld2","myneuralnet");
    myneuralnet = JLD2.load(resumefile,"myneuralnet");
end
display(myneuralnet);
#lossfun(y,yexact) = Flux.mse(y,yexact);
lossfun(y,yexact) = Flux.mae(y,yexact);


#initial evaluation
println("Initial inference:");
ynn = myneuralnet(xtrain);
println("  loss = ",lossfun(ynn,ytrain),"\n");


#training
println("Training:");
trainingloss = zeros(Float64,epochs);           #training loss history over epochs
validationloss = zeros(Float64,epochs);         #validation loss history over epochs
validationaccuracy = zeros(Float64,epochs);     #validation accuracy history over epochs
trainingdata = Flux.DataLoader((xtrain,ytrain),batchsize=batchsize);        #setting up training data for batch use
optimizer = Flux.setup(Adam(), myneuralnet);                                #Adam optimizer without regularization
@time for epoch in 1:epochs
    #single batch training
    #(currentloss,currentgradient) = Flux.withgradient(m -> lossfun(m(xtrain),ytrain), myneuralnet);
    #Flux.update!(optimizer, myneuralnet, currentgradient[1]);

    #minibatch training
    currentloss = 0;
    for (xbatch,ybatch) in trainingdata
        (currentloss,currentgradient) = Flux.withgradient(m -> lossfun(m(xbatch),ybatch), myneuralnet);
        Flux.update!(optimizer, myneuralnet, currentgradient[1]);
    end

    #evaluate performance of the current model
    trainingloss[epoch] = currentloss;
    ynnval = myneuralnet(xvalidation);
    validationloss[epoch] = lossfun(ynnval,yvalidation);
    validationaccuracy[epoch] = length(findall(abs.(1500*ynnval.^3-1500*yvalidation.^3).<=100))/Nvalidation;
    if epoch%10 == 0
        println("  epoch ",epoch," - training loss = ",rpad(round(trainingloss[epoch],digits=6),8,'0')," - validation accuracy = ",rpad(round(100*validationaccuracy[epoch],digits=2),5,'0'),"%");
    end

    #save current model if it outperforms the best model so far
    if epoch>10 && validationloss[epoch]<=minimum(validationloss[1:epoch-1])
        jldsave("models/myneuralnet_training_checkpoint.jld2"; myneuralnet);
    end
end
println("Training completed");

#=
#training convergence plot
plt2 = plot(1:epochs, trainingloss, color=:blue, linewidth=3, label="Training loss",
    title="Training & validation loss",
    xlabel="Epoch",
    ylabel="Loss function",
    ylims=[0.1,0.3]
);
plot!(plt2, 1:epochs, validationloss, color=:orange, linewidth=3, label="Validation loss");
display(plt2);
=#


#save model
#jldsave("models/myneuralnet.jld2"; myneuralnet);
mv("models/myneuralnet_training_checkpoint.jld2","models/myneuralnet.jld2");
println("Model saved to file");


#show some cp scores
println("Displaying some cp scores from the validation data:")
ynnval = myneuralnet(xvalidation);
println("  Stockfish  |  Neural network");
for i in rand(1:Nvalidation,7)
    cp1 = string(Int(round(1500*yvalidation[i].^3,digits=0)));
    cp2 = string(Int(round(1500*ynnval[i].^3,digits=0)));
    print("  ");
    for _ in 1:6-length(cp1)
        print(" ");
    end
    print(cp1,"   ","  |  ");
    for _ in 1:6-length(cp2)
        print(" ");
    end
    println(cp2);
end
