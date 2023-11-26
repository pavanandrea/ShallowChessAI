#======================================================================
    This script imports a training dataset and plots its centipawn
    score distribution

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 30/10/2023
======================================================================#
using Plots;


datasetfile = joinpath(@__DIR__,"../dataset/training_dataset_483k.csv");
batchsize = 32768;


#count the number of samples in the CSV dataset
N = 0;                              #total number of samples in the dataset
for line in eachline(datasetfile)
    if line[1]=='['
        global N += 1;
    end
end
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


#plot training dataset score distribution
plt1 = histogram(ytrain[:], label="Original dataset",
    title="Score distribution - original dataset",
    legend=false,
    normalize=:probability,
    xlabel="cp",
    ylims=[0,0.2]
);
display(plt1);


#cap boards evaluations to ±1500 centipawns (±15 pawns)
ytrain[findall(ytrain.>=1500)] .= 1500;
ytrain[findall(ytrain.<=-1500)] .= -1500;
yvalidation[findall(yvalidation.>=1500)] .= 1500;
yvalidation[findall(yvalidation.<=-1500)] .= -1500;


#rescale board scores to the range [-1,1]
#ytrain ./= 1500;                                       #simple constant rescale
#yvalidation ./= 1500;
#ytrain .= @. (ytrain/1500)/sqrt(abs(ytrain/1500));     #sqrt rescale
#yvalidation .= @. (yvalidation/1500)/sqrt(abs(yvalidation/1500));
ytrain = @. cbrt(ytrain/1500);                          #cubic root rescale
yvalidation = @. cbrt(yvalidation/1500);


#plot normalized dataset score distribution
plt2 = histogram(ytrain[:], label="Normalized dataset",
    title="Score distribution - normalized dataset",
    legend=false,
    normalize=:probability,
    xlabel="cp",
    ylims=[0,0.2]
);
display(plt2);


# one problem during training is that the samples with the highest scores are monopolizing the loss function
# changing the loss function (e.g. from mse to mae) definitely have a large impact
# it is also possible to change normalization function, to make samples with a near-zero score more relevant
# with the cubic root rescale indeed the cp distribution is more "full" at the tails
