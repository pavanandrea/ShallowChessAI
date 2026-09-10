//------------------------------------------------------------------------------
//  ShallowChessAI web frontend (WASM)
//
//  Author: Andrea Pavan
//  License: MIT
//------------------------------------------------------------------------------
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdbool.h>
#include <math.h>
#include <emscripten.h>
#include "../../src/chess.c"


//-----------------------
//  INTERNAL GAME STATE
//-----------------------
static BitBoard board;
static MoveList movelist;

//scratch buffers
static uint8_t board_state[64];     //0-11 = piece, 0xFF = empty
static uint8_t legal_targets[64];   //filled by get_legal_targets()
static int legal_target_count;
static int last_move_start = -1;
static int last_move_target = -1;
static int last_move_flags = 0;

static int engine_type = 0;         //0 = random, 1 = minimax-material, 2 = NN
static uint8_t engine_depth = 1;    //minimax depth


//-----------
//  HELPERS
//-----------

static void sync_board_state(void) {
    for (int i=0; i<64; ++i) {
        board_state[i] = 0xFF;      //empty
    }

    uint64_t wb[6] = {
        board.white_pawns,
        board.white_knights,
        board.white_bishops,
        board.white_rooks,
        board.white_queens,
        board.white_kings
    };
    for (int pt = 0; pt < 6; pt++)
        for (int sq = 0; sq < 64; sq++)
            if (wb[pt] & (1ULL << sq)) board_state[sq] = (uint8_t)pt;

    uint64_t bb[6] = { board.black_pawns, board.black_knights, board.black_bishops,
                       board.black_rooks, board.black_queens,  board.black_kings  };
    for (int pt = 0; pt < 6; pt++)
        for (int sq = 0; sq < 64; sq++)
            if (bb[pt] & (1ULL << sq)) board_state[sq] = (uint8_t)(pt + 6);
}

static void record_move(const Move* move) {
    last_move_start = move->start_square;
    last_move_target = move->target_square;
    last_move_flags = move->flags;
}


// ---------------------
//  EXPORTED FUNCTIONS
// ---------------------

//reset to the initial position.
void restart(void) {
    set_starting_position(&board);
    generate_legal_moves(&movelist, &board);
    sync_board_state();
    last_move_start = -1;
    last_move_target = -1;
    last_move_flags = 0;
    printf("[WASM] Game restarted\n");
}

//set position from a FEN string
int set_fen_position(const char* fen) {
    if (!fen || !fen[0]) {
        return -1;
    }

    set_position_from_fen(&board, fen);
    generate_legal_moves(&movelist, &board);
    sync_board_state();

    last_move_start = -1;
    last_move_target = -1;
    last_move_flags = 0;
    return 0;
}

//attempt a user move
//returns 0 on success, -1 if the move is illegal
int make_user_move(int start, int target) {
    Move* move = NULL;
    for (int i=0; i<movelist.NMOVES; ++i) {
        if (movelist.moves[i].start_square == (uint8_t)start
                    && movelist.moves[i].target_square == (uint8_t)target) {
            move = &movelist.moves[i];
            break;
        }
    }
    if (!move) {
        return -1;
    }

    make_move(&board, move);
    generate_legal_moves(&movelist, &board);
    sync_board_state();
    record_move(move);
    return 0;
}

//EM_JS bridge: call the ONNX model (async in JS) from C
//features is a pointer into WASM linear memory (HEAPF32)
EM_ASYNC_JS(float, nn_evaluate_position, (float* features), {
    //build a view over WASM memory - no copy needed
    const f32 = new Float32Array(Module.HEAPF32.buffer, features, 783);
    const score = await run_onnx_model(f32);
    return score;
});

//wrapper of the evaluation function for minimax
static float evaluate_nn(BitBoard* board) {
    static float features[783];
    bitboard_to_fp32_array(features, board);
    return nn_evaluate_position(features);   //Asyncify suspends here
}

//pick and execute a move for the black player
//returns 0 if a move is made, 1 if no legal moves are available, -1 on misuse
int make_computer_move(void) {
    if (board.metadata & METADATA_IS_WHITE_MOVING) {
        printf("[ERROR in make_computer_move] Function called during white's turn\n");
        return -1;
    }

    if (isgameover(&movelist)) {
        return 1;
    }

    Move move = {0, 0, 0, 0};
    if (engine_type == 2) {
        //minimax with pretrained neural network
        float score = minimax(&move, &board, engine_depth, -3.0f, +3.0f, evaluate_nn);

    }
    else if (engine_type == 1) {
        //minimax-material engine
        float score = minimax(&move, &board, engine_depth, -3.0f, +3.0f, evaluate_material);
    }
    else {
        //random move
        int idx = rand() % movelist.NMOVES;
        move = movelist.moves[idx];
    }

    make_move(&board, &move);
    generate_legal_moves(&movelist, &board);
    sync_board_state();
    record_move(&move);

    return 0;
}

//returns 0 if game still going, 1 if over
int is_game_over(void) {
    return isgameover(&movelist) ? 1 : 0;
}

//returns 1 if white to move, 0 if black to move
int is_white_moving(void) {
    return (board.metadata & METADATA_IS_WHITE_MOVING) ? 1 : 0;
}

// Packed castling rights: bit0=K, bit1=Q, bit2=k, bit3=q
int get_castling(void) {
    int r = 0;
    if (board.metadata & METADATA_CASTLE_K) r |= 1;
    if (board.metadata & METADATA_CASTLE_Q) r |= 2;
    if (board.metadata & METADATA_CASTLE_k) r |= 4;
    if (board.metadata & METADATA_CASTLE_q) r |= 8;
    return r;
}

//last move info
int get_last_move_start(void) {
    return last_move_start;
}
int get_last_move_target(void) {
    return last_move_target;
}
int get_last_move_flags(void) {
    return last_move_flags;
}

//list all legal target squares from a given square
//JS should call this, then read `legal_targets[0 .. count-1]`.
//returns the count (0 if none).
int get_legal_targets(int square) {
    legal_target_count = 0;
    for (int i=0; i<movelist.NMOVES && legal_target_count<64; ++i) {
        if (movelist.moves[i].start_square == (uint8_t)square) {
            legal_targets[legal_target_count] = movelist.moves[i].target_square;
            legal_target_count += 1;
        }
    }
    return legal_target_count;
}

//pointer exports - let JS grab a direct view into WASM memory
uint8_t* get_board_state_ptr(void) {
    return board_state;
}
uint8_t* get_legal_targets_ptr(void){
    return legal_targets;
}

//byte-level accessors
int get_board_byte(int idx) {
    if (idx < 0 || idx >= 64) return -1;
    return (int)board_state[idx];
}
int get_legal_target_byte(int idx) {
    if (idx < 0 || idx >= 64) return -1;
    return (int)legal_targets[idx];
}

//change chess engine algorithm
void set_engine(int type) {
    if (type >= 2) {
        engine_type = 2;
    }
    else if (type == 1) {
        engine_type = 1;
    }
    else {
        engine_type = 0;
    }
}

//set minimax depth
void set_depth(int depth) {
    if (depth <= 1) {
        depth = 1;
    }
    engine_depth = (uint8_t)depth;
}

//fill a WASM-owned float[783] buffer with the current position
//encoded the way the neural network expects.
float* get_board_features(void) {
    static float features[783];
    bitboard_to_fp32_array(features, &board);
    return features;
}

//initialize at startup
int main(void) {
    printf("ShallowChessAI - WASM backend started\n");
    srand((unsigned)time(NULL));
    restart();
    return 0;
}
