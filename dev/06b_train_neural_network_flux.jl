#======================================================================
    This script trains a small neural network (MLP architecture) to
    predict the score of a chess board

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 15/10/2023
======================================================================#
using Flux;
using Plots;


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
#batchsize = 2048;
#batchsize = 512;
#batchsize = 256;
Ntrain -= Ntrain%batchsize;
Nvalidation -= Nvalidation%batchsize;


#import data
xtrain = zeros(Float32,(775,Ntrain));
xvalidation = zeros(Float32,(775,Nvalidation));
ytrain = zeros(Float32,(1,Ntrain));
yvalidation = zeros(Float32,(1,Nvalidation));
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


#define neural network
println("Defining a MLP neural network:")
#24k params (3 layers, 30 depth)
#=myneuralnet = Chain(
    Dense(775 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 1, tanh)
);=#
#43k params (6 layers, variable depth)
#=myneuralnet = Chain(
    Dense(775 => 50, relu),
    Dense(50 => 30, relu),
    Dense(30 => 10, relu),
    Dense(10 => 20, relu),
    Dense(20 => 100, relu),
    Dense(100 => 1, tanh)
);=#
#56k params (9 layers)
myneuralnet = Chain(
    Dense(775 => 50, relu),
    Dense(50 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 50, relu),
    Dense(50 => 200, relu),
    Dense(200 => 1, tanh)
);
#58k params (12 layers)
#=myneuralnet = Chain(
    Dense(775 => 50, relu),
    Dense(50 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 50, relu),
    Dense(50 => 200, relu),
    Dense(200 => 1, tanh)
);=#
#58k params (15 layers)
#=myneuralnet = Chain(
    Dense(775 => 50, relu),
    Dense(50 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 50, relu),
    Dense(50 => 200, relu),
    Dense(200 => 1, tanh)
);=#
#41k params (3 layers, 50 depth)
#=myneuralnet = Chain(
    Dense(775 => 50, relu),
    Dense(50 => 50, relu),
    Dense(50 => 1, tanh)
);=#
#30k params (9 layers, 30 depth with 50 final)
#=yneuralnet = Chain(
    Dense(775 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 50, relu),
    Dense(50 => 1, tanh)
);=#
#35k params (9 layers, 30 depth with 200 final)
#=myneuralnet = Chain(
    Dense(775 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 30, relu),
    Dense(30 => 200, relu),
    Dense(200 => 1, tanh)
);=#
display(myneuralnet);


#initial evaluation
println("Initial inference:");
ynn = myneuralnet(xtrain);
println("  loss = ",Flux.mse(ynn,ytrain));


#training
println("Training:");
epochs = 1000;                                  #number of epochs
trainingloss = zeros(Float64,epochs);           #training loss history over epochs
validationloss = zeros(Float64,epochs);         #validation loss history over epochs
validationaccuracy = zeros(Float64,epochs);     #validation accuracy history over epochs
trainingdata = data = Flux.DataLoader((xtrain,ytrain),batchsize=batchsize);     #setting up training data for batch use
optimizer = Flux.setup(Adam(), myneuralnet);                                    #Adam optimizer without regularization
@time for epoch in 1:epochs
    #single batch training
    #(currentloss,currentgradient) = Flux.withgradient(m -> Flux.mse(m(xtrain),ytrain), myneuralnet);
    #Flux.update!(optimizer, myneuralnet, currentgradient[1]);

    #minibatch training
    currentloss = 0;
    for (xbatch,ybatch) in trainingdata
        (currentloss,currentgradient) = Flux.withgradient(m -> Flux.mse(m(xbatch),ybatch), myneuralnet);
        Flux.update!(optimizer, myneuralnet, currentgradient[1]);
    end

    #evaluate performance of the current model
    trainingloss[epoch] = currentloss;
    ynnval = myneuralnet(xvalidation);
    validationloss[epoch] = Flux.mse(ynnval,yvalidation);
    validationaccuracy[epoch] = length(findall(abs.(5000*ynnval-5000*yvalidation).<=100))/Nvalidation;
    if epoch%10 == 0
        println("  epoch ",epoch," - training loss = ",rpad(round(trainingloss[epoch],digits=6),8,'0')," - validation accuracy = ",rpad(round(100*validationaccuracy[epoch],digits=2),5,'0'),"%");
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
#24k params ( 3 layers, 30 depth, batchsize=1024): epoch 1000 - training loss = 0.003664 - validation accuracy = 38.81%
#43k params ( 6 layers, va depth, batchsize=1024): epoch 1000 - training loss = 0.003052 - validation accuracy = 42.95%
#56k params ( 9 layers, va depth, batchsize=1024): epoch 1000 - training loss = 0.002302 - validation accuracy = 46.17%
#58k params (12 layers, va depth, batchsize=2048): epoch 1000 - training loss = 0.002488 - validation accuracy = 45.93%
#61k params (15 layers, va depth, batchsize=512 ): epoch 1000 - training loss = 0.001108 - validation accuracy = 44.41%
#41k params ( 3 layers, 50 depth, batchsize=512 ): epoch 1000 - training loss = 0.001098 - validation accuracy = 40.10%
#30k params ( 9 layers, 30 depth, batchsize=512 ): epoch 1000 - training loss = 0.002486 - validation accuracy = 41.06%
#35k params ( 9 layers, 30 depth, batchsize=256 ): epoch 1000 - training loss = 0.001380 - validation accuracy = 41.93%


#show some cp scores
ynnval = myneuralnet(xvalidation);
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
