#!/bin/bash
source /home/andrea/Downloads/emsdk-3.1.74/emsdk_env.sh
emcc shallowchessai-web.cpp -o shallowchessai-web.js -O2 -s EXPORTED_FUNCTIONS='["_restart", "_main", "_highlight_legal_moves", "_request_move", "_request_engine_change"]' -s WASM=1 -s EXPORTED_RUNTIME_METHODS='["cwrap","ccall"]' -s FORCE_FILESYSTEM=1 --preload-file pretrained-2311-24k.bin

#run
firefox -private-window http://0.0.0.0:8080/index.html &
python3 -m http.server 8080
