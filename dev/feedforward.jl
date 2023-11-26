#======================================================================
    Simple Multi-Layer Perceptron (MLP) network training and inference

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 06/10/2023
======================================================================#
module FeedForward
using LinearAlgebra;
export FeedForwardNeuralNetwork, evaluate!, getparams,
       initializetraining!, backpropagate!,
       Layer, Linear, Sigmoid, Tanh, ReLU,
       meansquared, crossentropy;


#=== generic layer definition ===#
mutable struct Layer
    type::String
    layersize::Int
    evaluate!::Function
    backpropagate!::Function
    nparams::Int
    weights::Matrix{Float64}
    biases::Vector{Float64}

    #constructor
    function Layer(t::String, size::Int, evaluatefun::Function, backpropfun::Function, numberofparams::Int=0)
        return new{}(t, size, evaluatefun, backpropfun, numberofparams);
    end
end

#inference of a generic layer
function evaluatelayer!(layer::Layer, y, x)
    layer.evaluate!(layer, y, x);
end

#inference function of a linear layer
function evaluatelinearlayer!(layer::Layer, y, x)
    mul!(y, layer.weights, x);
    y .+= layer.biases;
end

#inference function of a sigmoid layer
function evaluatesigmoidlayer!(layer::Layer, y, x)
    y .= @. 1/(1+exp(-x));
end

#inference function of a tanh layer
function evaluatetanhlayer!(layer::Layer, y, x)
    y .= @. tanh(x);
end

#inference function of a relu layer
function evaluaterelulayer!(layer::Layer, y, x)
    y .= max.(0,x);
end

#backpropagation through a generic layer
function backpropagatelayer!(layer::Layer, δprev, δ, a);
    layer.backpropagate!(layer, δprev, δ, a);
end

#backpropagation function of a linear layer
function backpropagatelinearlayer!(layer::Layer, δprev, δ, a);
    mul!(δprev, transpose(layer.weights), δ);
end

#backpropagation function of a sigmoid layer
function backpropagatesigmoidlayer!(layer::Layer, δprev, δ, a);
    δprev .= δ .* a.*((1).-a);
end

#backpropagation function of a tanh layer
function backpropagatetanhlayer!(layer::Layer, δprev, δ, a);
    δprev .= δ .* ((1).-(a.^2));
end

#backpropagation function of a relu layer
function backpropagaterelulayer!(layer::Layer, δprev, δ, a);
    δprev .= δ .* max.(0,sign.(a));
end

#linear layer
function Linear(sizein::Int, sizeout::Int)
    newlayer = Layer("LinearLayer", sizeout, evaluatelinearlayer!, backpropagatelinearlayer!, sizeout*sizein + sizeout);
    newlayer.weights = randn(Float64,sizeout,sizein) * 1/sqrt(sizein);
    newlayer.biases = zeros(sizeout);
    return newlayer;
end

#sigmoid layer
function Sigmoid(size::Int)
    return Layer("SigmoidLayer", size, evaluatesigmoidlayer!, backpropagatesigmoidlayer!);
end

#tanh layer
function Tanh(size::Int)
    return Layer("TanhLayer", size, evaluatetanhlayer!, backpropagatetanhlayer!);
end

#relu layer
function ReLU(size::Int)
    return Layer("ReLULayer", size, evaluaterelulayer!, backpropagaterelulayer!);
end


#===  define some common loss functions  ===#
meansquared(y,yexact) = sum(sum((y - yexact).^2,dims=1)/size(y,1))/size(y,2);
crossentropy(y,yexact) = sum(-sum(yexact.*log.(y),dims=1)/size(y,1))/size(y,2);


#=== define the neural network architecture ===#
mutable struct FeedForwardNeuralNetwork
    layers::Vector{Layer}
    layersizes::Vector{Int}
    loss::Function
    batchsize::Int

    #variables for training
    cache::Vector{Matrix{Float64}}              #cache for the inference values of all layers
    δ::Vector{Matrix{Float64}}                  #derivative dC/dz (useful for backpropagation)
    dCdw::Vector{Matrix{Float64}}
    dCdb::Vector{Vector{Float64}}

    #constructor
    function FeedForwardNeuralNetwork(layersvec::Vector{Layer}, lossfun::Function=meansquared, batchdim::Int=1)
        layersizes = Vector{Int}(undef,length(layersvec));
        for l=1:length(layersvec)
            layersizes[l] = layersvec[l].layersize;
        end
        return new{}(layersvec, layersizes, lossfun, batchdim);
    end
end

#neural network inference
function evaluate!(nn::FeedForwardNeuralNetwork, y, x)
    evaluatelayer!(nn.layers[1], nn.cache[1], x);
    for l=2:length(nn.layersizes)
        evaluatelayer!(nn.layers[l], nn.cache[l], nn.cache[l-1]);
    end
    y .= nn.cache[end];
end

#initialize neural network for training
function initializetraining!(nn::FeedForwardNeuralNetwork)
    nn.cache = Vector{Matrix{Float64}}(undef,length(nn.layersizes));
    nn.δ = Vector{Matrix{Float64}}(undef,length(nn.layersizes));
    nn.dCdw = Vector{Matrix{Float64}}(undef,length(nn.layersizes));
    nn.dCdb = Vector{Vector{Float64}}(undef,length(nn.layersizes));
    for l=1:length(nn.layersizes)
        nn.cache[l] = zeros(nn.layersizes[l],nn.batchsize);
        nn.δ[l] = zeros(nn.layersizes[l],nn.batchsize);
        if nn.layers[l].nparams>0
            nn.dCdw[l] = zeros(size(nn.layers[l].weights));
            nn.dCdb[l] = zeros(length(nn.layers[l].biases));
        end
    end
end

#neural network backpropagation
function backpropagate!(nn::FeedForwardNeuralNetwork, x, y, η)
    #evaluate batch
    evaluate!(nn,nn.cache[end],x);

    #calculate partial derivatives and apply the chain rule
    nn.δ[end] .= 2*(nn.cache[end]-y);
    for l=length(nn.layersizes):-1:2
        backpropagatelayer!(nn.layers[l], nn.δ[l-1], nn.δ[l], nn.cache[l]);
        if nn.layers[l].nparams>0
            mul!(nn.dCdw[l], nn.δ[l], transpose(nn.cache[l-1]));
            nn.dCdw[l] ./= size(x,2);
            nn.dCdb[l] = reshape(sum(nn.δ[l], dims=2)/size(x,2), length(nn.dCdb[l]));
        end
    end
    if nn.layers[1].nparams>0
        mul!(nn.dCdw[1], nn.δ[1], transpose(x));
        nn.dCdw[1] ./= size(x,2);
        nn.dCdb[1] = reshape(sum(nn.δ[1], dims=2)/size(x,2), length(nn.dCdb[1]));
    end

    #update weights
    for l=1:length(nn.layersizes)
        if nn.layers[l].nparams>0
            nn.layers[l].weights .-= η*nn.dCdw[l];
            nn.layers[l].biases .-= η*nn.dCdb[l];
        end
    end
end


#get neural network trainable parameters
function getparams(nn::FeedForwardNeuralNetwork)
    params = Vector{Float64}(undef,0);
    for l=1:length(nn.layersizes)
        if nn.layers[l].type=="LinearLayer"
            params = vcat(params, reshape(nn.layers[l].weights, prod(size(nn.layers[l].weights))));
            params = vcat(params, nn.layers[l].biases);
        end
    end
    return params;
end

end
