#======================================================================
    Convert a Flux neural network in JLD2 format to a lightweight and
    easier to read custom BIN format with the following specifications:
    * single array of type Float32 (4 bytes for each element)
    * first element is the number of rows of the weight matrix (layer 1)
    * second element is the number of columns of the weight matrix (layer 1)
    * third element is an identifier for the nonlinear activation function (layer 1)
    * weights ordered by column (layer 1)
    * biases (layer 1)
    * number of rows of the weight matrix (layer 2)
    * [repeat...]

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 02/12/2023
======================================================================#
using Flux;
using JLD2;


#import JLD2 model
filein = joinpath(@__DIR__,"../models/myneuralnet_24k.jld2");
myneuralnet = JLD2.load(filein,"myneuralnet");
display(myneuralnet);
#weights are accessible using: myneuralnet.layers[1].weight (type: Matrix{Float32})
#biases are accessible using: myneuralnet.layers[1].bias (type: Vector{Float32})
#activation function is accessible using: myneuralnet.layers[1].σ (type: generic function)


#export BIN model
fileout = replace(filein,"jld2"=>"bin");        #output file name
sizeout = 0;                                    #number of output elements stored
for layer in myneuralnet.layers
    global sizeout += 3;
    global sizeout += prod(size(layer.weight));
    global sizeout += sum(size(layer.bias));
end
σid = [tanh, sigmoid, relu, leakyrelu];         #list of activation functions (useful for the identifier at position 3)
arrayout = zeros(Float32,sizeout);              #output data array
i = 1;                                          #current array index
for layer in myneuralnet.layers
    arrayout[i] = size(layer.weight,1);         #number of rows
    global i += 1;
    arrayout[i] = size(layer.weight,2);         #number of columns
    global i += 1;
    arrayout[i] = findfirst(σid.==layer.σ);     #activation function identifier
    global i += 1;
    for w in layer.weight                       #weights matrix
        arrayout[i] = w;
        global i += 1;
    end
    for b in layer.bias                         #biases vector
        arrayout[i] = b;
        global i += 1;
    end
end
fileio = open(fileout,"w");
write(fileio,arrayout);
close(fileio);


#=
#code to import BIN model
arrayin = Vector{Float32}(undef,filesize(fileout)÷4);
read!(fileout,arrayin);
=#
