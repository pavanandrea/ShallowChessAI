# ShallowChessAI Development Changelog

### Update 2023/12/03

Enhancements:

* Changed models format from JLD2 to BIN, easier to read with other languages and slightly lighter on storage (-6% for the 24k model).
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
