#======================================================================
    This script reads a CSV dataset and plots its centipawn score
    distribution

    Author: Andrea Pavan
    Project: ShallowChessAI
    License: MIT
    Date: 05/10/2023
======================================================================#
using Plots;


#raw dataset score distribution
rawscore = [];
rawdataset = readlines("dataset/dataset_20k_20deep.csv");
for line in rawdataset[2:end]
    currententry = split(line, ",");
    if contains("-0123456789",currententry[2][1])
        push!(rawscore, parse(Int,currententry[2]));
    end
end

#raw+augmented dataset score distribution
score = copy(rawscore);
augdataset = readlines("dataset/dataset_random_97k_10deep.csv");
for line in augdataset[2:end]
    currententry = split(line, ",");
    if contains("-0123456789",currententry[2][1])
        push!(score, parse(Int,currententry[2]));
    end
end

#plot
plt1 = histogram(rawscore, label="Original dataset",
    title="Score distribution - original dataset",
    legend=false,
    normalize=:probability,
    xlabel="cp",
    ylims=[0,0.2]
);
display(plt1);
plt2 = histogram(score, label="Augmented dataset",
    title="Score distribution - augmented dataset",
    legend=false,
    normalize=:probability,
    xlabel="cp",
    ylims=[0,0.2]
);
display(plt2);
