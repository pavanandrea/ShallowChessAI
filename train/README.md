# ShallowChessAI - Training

This directory contains all necessary scripts and files for training the neural network model.
You can also find two pretrained model variants with approximately 24k and 50k parameters.


Getting Started
---------------

Training the MLP model from scratch is as simple as running a single terminal command.
For small sizes training is very quick, typically taking only a few minutes on a standard desktop
computer CPU (a GPU is not needed).

To train the MLP model on the included dataset, follow these steps:
1. Download the file dataset/training_dataset_490k.zip from this repository and unzip it to dataset/training_dataset_490k.csv.
2. Open the Julia REPL in Package manager mode and run `add Flux JLD2` to add the required packages.
3. Open your terminal or command prompt and run `julia train.jl -i ./dataset/training_dataset_490k.csv`.


Dataset Generation
------------------

To generate your own dataset and train the MLP model on it, follow these steps:
1. Download and install Python+Pip for your operating system.
2. Create a new Python environment and run `pip install chess` to add the required package.
3. Open the Julia REPL in Package manager mode and run `add Flux JLD2 PyCall` to add the required packages.
4. Download Stockfish from the official [website](https://stockfishchess.org/download/).
5. Download a PGN database [like this one](https://database.lichess.org/standard/lichess_db_standard_rated_2013-01.pgn.zst).
You may have to unzip it in order to obtain a single large .pgn file.
6. Open your terminal or command prompt and run `julia train.jl --from-pgn ./path/to/database.pgn --uci-engine ./path/to/stockfish.exe`.
