#======================================================================
    This script trains a small neural network (MLP architecture) to
    predict the score of a chess board

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 14/10/2023
======================================================================#
using Plots;
include("./feedforward.jl");
using Main.FeedForward;


#count the number of samples in the CSV dataset
N = 0;                              #total number of samples in the dataset
for line in eachline("dataset/training_dataset_117k.csv")
    if line[1]=='['
        global N += 1;
    end
end
println("Found ",N, " samples in the dataset");
Ntrain = floor(Int,0.8*N);          #number of training samples
Nvalidation = N-Ntrain;             #number of validation samples
#drop some samples in order to have a constant batch size
batchsize = 1024;
Ntrain -= Ntrain%batchsize;
Nvalidation -= Nvalidation%batchsize;


#import data
xtrain = zeros(775,Ntrain);
xvalidation = zeros(775,Nvalidation);
ytrain = zeros(1,Ntrain);
yvalidation = zeros(1,Nvalidation);
i = 1;
#read dataset from CSV
for line in eachline("dataset/training_dataset_117k.csv")
    if line[1]=='['
        currententry = parse.(Int,split(replace(line,"["=>"","]"=>""," "=>""), ","));
        if i<=Ntrain
            xtrain[currententry[1:end-1],i] .= 1;
            ytrain[i] = currententry[end];
        elseif Ntrain<i<=Ntrain+Nvalidation
            xvalidation[currententry[1:end-1],i-Ntrain] .= 1;
            yvalidation[i-Ntrain] = currententry[end];
        end
        global i += 1;
    end
end
#cap boards evaluations to ±5000 centipawns (±50 pawns)
ytrain[findall(ytrain.>=5000)] .= 5000;
ytrain[findall(ytrain.<=-5000)] .= -5000;
yvalidation[findall(yvalidation.>=5000)] .= 5000;
yvalidation[findall(yvalidation.<=-5000)] .= -5000;
#normalize boards evaluations to the range [-1,1]
ytrain ./= 5000;
yvalidation ./= 5000;
println("Dataset parsed successfully");


#plot the normalized score distribution of the training dataset
#=plt1 = histogram(ytrain[:], label="Training dataset",
    title="Training dataset distribution",
    legend=false,
    normalize=:probability,
    xlabel="Normalized cp"
);
display(plt1);=#


#define neural network
#=myneuralnet = FeedForwardNeuralNetwork([
    Linear(775,30), ReLU(30),
    Linear(30,30), ReLU(30),
    Linear(30,1), Tanh(1)
    ],
    meansquared,
    batchsize
);=#
myneuralnet = FeedForwardNeuralNetwork([
    Linear(775,50), ReLU(50),
    Linear(50,30), ReLU(30),
    Linear(30,10), ReLU(10),
    Linear(10,20), ReLU(20),
    Linear(20,100), ReLU(100),
    Linear(100,1), Tanh(1)
    ],
    meansquared,
    batchsize
);
initializetraining!(myneuralnet);       #prepare the neural network for training
println("Defined a MLP neural network:")
println("  Layers: ",myneuralnet.layersizes);
println("  Loss function: ",myneuralnet.loss);
println("  Total number of parameters: ",length(getparams(myneuralnet)));


#initial evaluation
println("Initial inference:");
ynn = Matrix{Float64}(undef,(myneuralnet.layersizes[end],Ntrain));
for iteration = 1:ceil(Int,Ntrain/batchsize)
    batch = 1+(iteration-1)*batchsize:min(Ntrain,iteration*batchsize);
    ynn[:,batch] = evaluate!(myneuralnet, ynn[:,batch], xtrain[:,batch]);
end
println("  loss = ",myneuralnet.loss(ynn,ytrain));


#training (gradient descent method)
η = 0.1;                               #constant learning rate
epochs = 1500;                          #number of epochs
println("Training:");
trainingloss = zeros(Float64,epochs);           #training loss history over epochs
validationloss = zeros(Float64,epochs);         #validation loss history over epochs
validationaccuracy = zeros(Float64,epochs);     #validation accuracy history over epochs
ynnval = 0*yvalidation;
@time for epoch in 1:epochs
    #minibatch training
    for iteration = 1:ceil(Int,Ntrain/batchsize)
        batch = 1+(iteration-1)*batchsize:min(Ntrain,iteration*batchsize);
        backpropagate!(myneuralnet, xtrain[:,batch], ytrain[:,batch], η);
        ynn[:,batch] = myneuralnet.cache[end];
    end

    #evaluate performance of the current model
    trainingloss[epoch] = myneuralnet.loss(ynn,ytrain);
    for iteration = 1:ceil(Int,Nvalidation/batchsize)
        batch = 1+(iteration-1)*batchsize:min(Nvalidation,iteration*batchsize);
        ynnval[:,batch] = evaluate!(myneuralnet, ynnval[:,batch], xvalidation[:,batch]);
    end
    validationloss[epoch] = myneuralnet.loss(ynnval,yvalidation);
    validationaccuracy[epoch] = length(findall(abs.(5000*ynnval-5000*yvalidation).<=100))/Nvalidation;
    if epoch%10 == 0
        println("  epoch ",epoch," - training loss = ",round(trainingloss[epoch],digits=6)," - validation accuracy = ",round(100*validationaccuracy[epoch],digits=2),"%");
    end
end
println("Training completed");

#training convergence plot
plt2 = plot(1:epochs, trainingloss, color=:blue, linewidth=3, label="Training loss",
    title="Training & validation loss",
    xlabel="Epoch",
    ylabel="Loss function"
);
plot!(plt2, 1:epochs, validationloss, color=:orange, linewidth=3, label="Validation loss");
display(plt2);

#RESULTS WITH training_dataset_117k.csv:
#24k params (3 layers, 30 depth, η=0.02): epoch 1000 - training loss = 0.015798 - validation accuracy = 27.57%
#32k params (3 layers, 40 depth, η=0.02): epoch 1000 - training loss = 0.015560 - validation accuracy = 27.41%
#26k params (5 layers, 30 depth, η=0.02): epoch 1000 - training loss = 0.011403 - validation accuracy = 28.35%
#17k params (7 layers, 20 depth, η=0.02): epoch 1000 - training loss = 0.012996 - validation accuracy = 25.47%
#25k params (6 layers, va depth, η=0.02): epoch 1000 - training loss = 0.011203 - validation accuracy = 27.35%
#43k params (6 layers, va depth, η=0.01): epoch 1500 - training loss = 0.009046 - validation accuracy = 28.20%
#43k params (6 layers, tanh act, η=0.10): epoch 1500 - training loss = 0.008109 - validation accuracy = 32.45%
#43k params (6 layers, relu act, η=0.10): epoch 1500 - training loss = 0.004227 - validation accuracy = 36.40%


#show some cp scores
println("  Stockfish  |  Neural network");
for i in rand(1:Nvalidation,7)
    cp1 = string(Int(round(5000*yvalidation[i],digits=0)));
    cp2 = string(Int(round(5000*ynnval[i],digits=0)));
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

#plot centipawn error frequency
nnvalerr = abs.(5000*ynnval-5000*yvalidation);
plt3 = scatter(reshape(5000*yvalidation,Nvalidation), reshape(nnvalerr,Nvalidation), title="Centipawn error (validation set)", xlabel="Score (cp)", ylabel="Absolute error on cp");
display(plt3);
