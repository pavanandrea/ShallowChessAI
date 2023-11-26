# ShallowChessAI Development Changelog

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
