//------------------------------------------------------------------------------
//  ShallowChessAI running on WASM or on a command line
//  Simple minimax algorithm with alpha-beta pruning
//
//  Author: Andrea Pavan
//  License: MIT
//------------------------------------------------------------------------------
#ifndef CHESS_H
#define CHESS_H
#include <stdbool.h>
#include <stdint.h>


//-------------------------
//  BOARD REPRESENTATION
//-------------------------

//a board state is represented by a total of 783 bits:
//768 bits for piece positions: 12 piece types x 64 bits (one bit per square)
//15 bits for metadata: active player, castling rights, check status and en-passant
//squares are ordered from top-left to bottom-right (0=a8 ... 63=h1)
typedef struct {
    uint64_t white_pawns;
    uint64_t white_knights;
    uint64_t white_bishops;
    uint64_t white_rooks;
    uint64_t white_queens;
    uint64_t white_kings;
    uint64_t black_pawns;
    uint64_t black_knights;
    uint64_t black_bishops;
    uint64_t black_rooks;
    uint64_t black_queens;
    uint64_t black_kings;
    uint8_t metadata;       //={moving_player, castling_K, castling_Q, castling_k, castling_q, white_in_check, black_in_check, 0}
    uint8_t enpassant;      //8 bits, one for each column
} BitBoard;

static const uint8_t METADATA_IS_WHITE_MOVING = 1<<0;
static const uint8_t METADATA_CASTLE_K = 1<<1;
static const uint8_t METADATA_CASTLE_Q = 1<<2;
static const uint8_t METADATA_CASTLE_k = 1<<3;
static const uint8_t METADATA_CASTLE_q = 1<<4;
static const uint8_t METADATA_WHITE_IN_CHECK = 1<<5;
static const uint8_t METADATA_BLACK_IN_CHECK = 1<<6;


//------------------------
//  MOVE REPRESENTATION
//------------------------

typedef struct {
    uint8_t start_square;
    uint8_t target_square;
    uint8_t flags;              //={is_capture, is_promotion, is_castling_k, is_castling_q, is_enpassant, is_double_pawn_move, 0, 0}
    uint8_t promotion;          //0=Q, 1=R, 2=B, 3=N (if is_promotion)
} Move;

typedef struct {
    int NMOVES;
    Move moves[256];
} MoveList;

static const uint8_t FLAG_IS_CAPTURE = 1<<0;
static const uint8_t FLAG_IS_PROMOTION = 1<<1;
static const uint8_t FLAG_IS_CASTLING_K = 1<<2;
static const uint8_t FLAG_IS_CASTLING_Q = 1<<3;
static const uint8_t FLAG_IS_ENPASSANT = 1<<4;
static const uint8_t FLAG_IS_DOUBLE = 1<<5;


//-------------------------
//  FUNCTION DECLARATIONS
//-------------------------

//set bitboard to starting position
void set_starting_position(BitBoard* board);

//converts a FEN string to bitboard
//see: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation
//WARNING: safety checks on user input are not implemented yet
void set_position_from_fen(BitBoard* board, const char* fenstring);

//generate legal moves
void generate_legal_moves(MoveList* movelist, BitBoard* board);

//make move
//NOTE: legality of the move is NOT checked
void make_move(BitBoard* board, Move* move);

//count the number of legal moves at a given depth
uint64_t perft(BitBoard* board, int depth, bool print_uci_output);

//check if the game is over
bool isgameover(MoveList* movelist);

//convert a BitBoard to a flattened float32 array of size 783
//that can be used as input for the neural network
void bitboard_to_fp32_array(float* output, BitBoard* board);

//play random move
void play_random_move(Move* output_move, MoveList* movelist);

//convert centipawns from/to bounded score
float centipawn2score(int cp);
int score2centipawn(float score);

//a basic evaluation function that only counts material imbalance
//bounded in the range [-2,+2]
float evaluate_material(BitBoard* board);

//minimax algorithm with alpha-beta pruning
//call with alpha=-3.0f and beta=+3.0f
float minimax(Move* move, BitBoard* board, uint8_t depth, float alpha, float beta, float (*evaluation_function)(BitBoard* board));

#endif  //CHESS_H
