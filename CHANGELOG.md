# ShallowChessAI Development Changelog

### Update 2026/09/10

Enhancements:
* Replaced int array data structure with an actual bitboard.
* Refactored data structure for moves.
* Perft performance improved to ∼16.8M NPS (for reference, Stockfish on the same machine achieves ∼124.1M NPS).
* Added new positions to the perft test.
* Improved documentation and reproducibility.
* New dataset generation & training pipeline in Python & PyTorch.
* New dataset of 38.9M unique positions.
* New MLP model (v2609) with 43k parameters.
* Replaced inference code with ONNX Runtime Web.
* Comparison between v2609 and v2311.


### Update 2025/01/16

Enhancements:

* Refactored the whole algorithm from Julia to C.
* Made a Web GUI and an online demo using WebAssembly.
* Simplified folder structure of the codebase.
* Support for promotion to knight/bishop/rook.


### Update 2023/12/03

Enhancements:

* Changed models format from JLD2 to BIN, easier to read from other languages.
* Zero-dependencies inference, to simplify the installation procedure. Not set as the default option because of significantly lower performance compared to Flux.
* Introduced efficient batch inference when maxdepth==1 (zero lookahead).
* Play against random opponent.

Bug fixes:

* Fixed promotion while capturing bug in the pseudolegal move generator.


### Update 2023/11/26

Enhancements:

* Bitboard format changed from Vector{Float32} to BitVector, leading to a reduction of RAM usage of 3 orders of magnitude.
* Perft performance improved from ∼130k NPS to ∼800k NPS. Not bad, but still a long way to SOTA levels.
* Unified training script, easier to use.
* Dataset boards represented in FEN notation instead of bitboard, leading to a -49% in the CSV file size.
* More tests for the minimax function.

Bug fixes:

* Now the model has no difficulties in making a checkmate.
* Fixed promotion bug in the pseudolegal move generator.
* Miscellaneous small fixes in the minimax function.
