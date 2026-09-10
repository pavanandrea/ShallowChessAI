#!/bin/bash
source /home/andrea/Downloads/emsdk-main/emsdk_env.sh

emcc chess-web.c \
    -o chess-web.js \
    -O2 \
    -s MODULARIZE=1 \
    -s EXPORT_NAME="ChessWasm" \
    -s ASYNCIFY=1 \
    -s EXPORTED_FUNCTIONS='[
        "_main",
        "_restart",
        "_make_user_move",
        "_make_computer_move",
        "_is_game_over",
        "_is_white_moving",
        "_get_castling",
        "_get_legal_targets",
        "_get_last_move_start",
        "_get_last_move_target",
        "_get_last_move_flags",
        "_get_board_state_ptr",
        "_get_legal_targets_ptr",
        "_get_board_byte",
        "_get_legal_target_byte",
        "_set_engine",
        "_set_depth",
        "_set_fen_position",
        "_get_board_features",
        "_score2centipawn"
    ]' \
    -s EXPORTED_RUNTIME_METHODS='["cwrap","ccall","HEAPF32"]' \
    -s ALLOW_MEMORY_GROWTH=1

#run
#firefox -private-window http://0.0.0.0:8080/index.html &
#python3 -m http.server 8080
