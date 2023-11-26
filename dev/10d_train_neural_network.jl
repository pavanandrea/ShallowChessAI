#======================================================================
    This script trains a small neural network (MLP architecture) to
    predict the score of a chess board

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 15/10/2023
======================================================================#
using Flux;
using JLD2;
using Plots;


println("ShallowChessAI - Training neural network");
#datasetfile = joinpath(@__DIR__,"../dataset/training_dataset_117k.csv");
datasetfile = joinpath(@__DIR__,"../dataset/training_dataset_483k.csv");
batchsize = 256;

#count the number of samples in the CSV dataset
N = 0;                              #total number of samples in the dataset
for line in eachline(datasetfile)
    if line[1]=='['
        global N += 1;
    end
end
println("Found ",N, " samples in the dataset");
Ntrain = floor(Int,0.8*N);          #number of training samples
Nvalidation = N-Ntrain;             #number of validation samples
#drop some samples in order to have a constant batch size
Ntrain -= Ntrain%batchsize;
Nvalidation -= Nvalidation%batchsize;


#import data
xtrain = zeros(Float32,(783,Ntrain));
xvalidation = zeros(Float32,(783,Nvalidation));
ytrain = zeros(Float32,(1,Ntrain));
yvalidation = zeros(Float32,(1,Nvalidation));
i = 1;
#read dataset from CSV
for line in eachline(datasetfile)
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
#cap boards evaluations to ±1500 centipawns (±15 pawns)
ytrain[findall(ytrain.>=1500)] .= 1500;
ytrain[findall(ytrain.<=-1500)] .= -1500;
yvalidation[findall(yvalidation.>=1500)] .= 1500;
yvalidation[findall(yvalidation.<=-1500)] .= -1500;
#normalize boards evaluations to the range [-1,1]
#ytrain ./= 1500;
#yvalidation ./= 1500;
ytrain = @. cbrt(ytrain/1500);
yvalidation = @. cbrt(yvalidation/1500);
println("Dataset parsed successfully");


#define neural network
println("Defining a MLP neural network:");
myneuralnet = Chain(
    Dense(783 => 30, tanh),
    Dense(30 => 30, tanh),
    Dense(30 => 1, tanh)
);
#OR resume existing neural network from file
#myneuralnet = JLD2.load("myneuralnet_training_checkpoint.jld2","myneuralnet");
display(myneuralnet);
#lossfun(y,yexact) = Flux.mse(y,yexact);
lossfun(y,yexact) = Flux.mae(y,yexact);


#initial evaluation
println("Initial inference:");
ynn = myneuralnet(xtrain);
println("  loss = ",lossfun(ynn,ytrain));


#training
println("Training:");
epochs = 1000;                                  #number of epochs
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
        jldsave("myneuralnet_training_checkpoint.jld2"; myneuralnet);
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


#save model
#jldsave("myneuralnet.jld2"; myneuralnet);
mv("myneuralnet_training_checkpoint.jld2","myneuralnet.jld2");
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
