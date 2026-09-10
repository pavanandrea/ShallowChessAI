//------------------------------------------------------------------------------
//  A minimal and lightweight chess library based on bitboards.
//  The library provides:
//  - board initialisation from start position or FEN
//  - legal move generation for all pieces
//  - check detection and game-over test
//  Square indexing is rank-major (i.e. 0...63 with 0="a8" and 63="h1").
//
//  How to build as a shared library:
//  gcc chess.c -o chess.so -O2 -std=c17 -shared -fPIC -Wall -Wextra -lm
//
//  Author: Andrea Pavan
//  License: MIT
//------------------------------------------------------------------------------
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "chess.h"


//returns a 64-bit mask with a single bit set at position 'square' and all other bits zero
//example: square2mask(0)  = 000...0001
//example: square2mask(63) = 100...0000
static inline uint64_t square2mask(int square)
{
    return 1ULL << square;
}

//get all occupied squares
uint64_t occupied_squares_mask(BitBoard *board) {
    return board->white_pawns | board->white_knights | board->white_bishops |
           board->white_rooks | board->white_queens | board->white_kings |
           board->black_pawns | board->black_knights | board->black_bishops |
           board->black_rooks | board->black_queens | board->black_kings;
}

//append a new move to a movelist
static inline void movelist_add(MoveList* movelist, Move move){
    movelist->moves[movelist->NMOVES++] = move;
}

//print a move on screen (useful for debugging)
void move_print(Move* move) {
    int s = move->start_square;
    int t = move->target_square;
    const char columns[] = {'a','b','c','d','e','f','g','h'};
    printf("start=%c%d, target=%c%d\n", columns[s%8], 8-s/8, columns[t%8], 8-t/8);
}

//print a movelist on screen (useful for debugging)
void movelist_print(MoveList* movelist) {
    printf("> movelist.NMOVES = %d\n", movelist->NMOVES);
    for (int i=0; i<movelist->NMOVES; ++i) {
        int s = movelist->moves[i].start_square;
        int t = movelist->moves[i].target_square;
        const char columns[] = {'a','b','c','d','e','f','g','h'};
        printf("> movelist[%d] = {start=%c%d, target=%c%d}\n", i, columns[s%8], 8-s/8, columns[t%8], 8-t/8);
    }
    return;
}

//set bitboard to starting position
void set_starting_position(BitBoard* board) {
    if (!board) {
        return;
    }
    board->white_pawns = 0xFFULL << 48;
    board->white_knights = square2mask(57) | square2mask(62);
    board->white_bishops = square2mask(58) | square2mask(61);
    board->white_rooks = square2mask(56) | square2mask(63);
    board->white_queens = square2mask(59);
    board->white_kings = square2mask(60);
    board->black_pawns = 0xFFULL << 8;
    board->black_knights = square2mask(1) | square2mask(6);
    board->black_bishops = square2mask(2) | square2mask(5);
    board->black_rooks = square2mask(0) | square2mask(7);
    board->black_queens = square2mask(3);
    board->black_kings = square2mask(4);
    board->metadata = METADATA_IS_WHITE_MOVING | METADATA_CASTLE_K | METADATA_CASTLE_Q | METADATA_CASTLE_k | METADATA_CASTLE_q;
    board->enpassant = 0;
    return;
}

//check if a square is empty
//if a piece is present, return 1 if white or -1 if black
int isempty(BitBoard* board, int square) {
    uint64_t square_bit = square2mask(square);

    //check for white pieces
    if ((board->white_pawns | board->white_knights | board->white_bishops |
         board->white_rooks | board->white_queens | board->white_kings) & square_bit) {
        return 1;
    }

    //check for black pieces
    if ((board->black_pawns | board->black_knights | board->black_bishops |
         board->black_rooks | board->black_queens | board->black_kings) & square_bit) {
        return -1;
    }

    //square is empty
    return 0;
}

//check if a square is threatened by a player
bool isthreatened(BitBoard* board, int square, int player) {
    //check white pawns
    if (player == 1) {
        //check if there is a white pawn in [row+1,column-1]
        if (square%8>=1 && square<=55 && (board->white_pawns & square2mask(square+8-1))) {
            return true;
        }
        //check if there is a white pawn in [row+1,column+1]
        if (square%8<=6 && square<=55 && (board->white_pawns & square2mask(square+8+1))) {
            return true;
        }
    }

    //check black pawns
    if (player == -1) {
        //check if there is a black pawn in [row-1,column-1]
        if (square%8>=1 && square>=8 && (board->black_pawns & square2mask(square-8-1))) {
            return true;
        }
        //check if there is a black pawn in [row-1,column+1]
        if (square%8<=6 && square>=8 && (board->black_pawns & square2mask(square-8+1))) {
            return true;
        }
    }

    //check knights
    uint64_t player_knights = (player==1) ? board->white_knights : board->black_knights;
    if ((square>=16 && square%8>=1 && (player_knights & square2mask(square-16-1)))              //check if there is a player knight in [row-2,column-1]
            || (square>=16 && square%8<=6 && (player_knights & square2mask(square-16+1)))       //check if there is a player knight in [row-2,column+1]
            || (square>=8 && square%8>=2 && (player_knights & square2mask(square-8-2)))         //check if there is a player knight in [row-1,column-2]
            || (square>=8 && square%8<=5 && (player_knights & square2mask(square-8+2)))         //check if there is a player knight in [row-1,column+2]
            || (square<=55 && square%8>=2 && (player_knights & square2mask(square+8-2)))        //check if there is a player knight in [row+1,column-2]
            || (square<=55 && square%8<=5 && (player_knights & square2mask(square+8+2)))        //check if there is a player knight in [row+1,column+2]
            || (square<=47 && square%8>=1 && (player_knights & square2mask(square+16-1)))       //check if there is a player knight in [row+2,column-1]
            || (square<=47 && square%8<=6 && (player_knights & square2mask(square+16+1))) ) {   //check if there is a player knight in [row+2,column+1]
        return true;
    }

    //check bishops and queens (upper-left diagonal)
    uint64_t player_bishops = (player==1) ? board->white_bishops : board->black_bishops;
    uint64_t player_queens  = (player==1) ? board->white_queens  : board->black_queens;
    uint64_t occupied = occupied_squares_mask(board);
    int jmax = square%8;
    if (square/8 < jmax) {
        jmax = square/8;
    }
    for (int j=1; j<=jmax; j++) {
        uint64_t current_square_bit = square2mask(square-8*j-j);
        if ((player_bishops | player_queens) & current_square_bit) {
            return true;
        }
        if (occupied & current_square_bit) {
            break;
        }
    }

    //check bishops and queens (upper-right diagonal)
    jmax = 7-square%8;
    if (square/8 < jmax) {
        jmax = square/8;
    }
    for (int j=1; j<=jmax; j++) {
        uint64_t current_square_bit = square2mask(square-8*j+j);
        if ((player_bishops | player_queens) & current_square_bit) {
            return true;
        }
        if (occupied & current_square_bit) {
            break;
        }
    }

    //check bishops and queens (lower-left diagonal)
    jmax = square%8;
    if (7-square/8 < jmax) {
        jmax = 7-square/8;
    }
    for (int j=1; j<=jmax; j++) {
        uint64_t current_square_bit = square2mask(square+8*j-j);
        if ((player_bishops | player_queens) & current_square_bit) {
            return true;
        }
        if (occupied & current_square_bit) {
            break;
        }
    }

    //check bishops and queens (lower-right diagonal)
    jmax = 7-square%8;
    if (7-square/8 < jmax) {
        jmax = 7-square/8;
    }
    for (int j=1; j<=jmax; j++) {
        uint64_t current_square_bit = square2mask(square+8*j+j);
        if ((player_bishops | player_queens) & current_square_bit) {
            return true;
        }
        if (occupied & current_square_bit) {
            break;
        }
    }

    //check rooks and queens (upper column)
    uint64_t player_rooks = (player==1) ? board->white_rooks : board->black_rooks;
    jmax = square/8;
    for (int j=1; j<=jmax; j++) {
        uint64_t current_square_bit = square2mask(square-8*j);
        if ((player_rooks | player_queens) & current_square_bit) {
            return true;
        }
        if (occupied & current_square_bit) {
            break;
        }
    }

    //check rooks and queens (lower column)
    jmax = 7-square/8;
    for (int j=1; j<=jmax; j++) {
        uint64_t current_square_bit = square2mask(square+8*j);
        if ((player_rooks | player_queens) & current_square_bit) {
            return true;
        }
        if (occupied & current_square_bit) {
            break;
        }
    }

    //check rooks and queens (left row)
    jmax = square%8;
    for (int j=1; j<=jmax; j++) {
        uint64_t current_square_bit = square2mask(square-j);
        if ((player_rooks | player_queens) & current_square_bit) {
            return true;
        }
        if (occupied & current_square_bit) {
            break;
        }
    }

    //check rooks and queens (right row)
    jmax = 7-square%8;
    for (int j=1; j<=jmax; j++) {
        uint64_t current_square_bit = square2mask(square+j);
        if ((player_rooks | player_queens) & current_square_bit) {
            return true;
        }
        if (occupied & current_square_bit) {
            break;
        }
    }

    //check kings
    uint64_t player_kings = (player==1) ? board->white_kings : board->black_kings;
    if (square>=8 && square%8>=1 && (player_kings & square2mask(square-8-1))) {
        return true;
    }
    if (square>=8 && (player_kings & square2mask(square-8))) {
        return true;
    }
    if (square>=8 && square%8<=6 && (player_kings & square2mask(square-8+1))) {
        return true;
    }
    if (square%8>=1 && (player_kings & square2mask(square-1))) {
        return true;
    }
    if (square%8<=6 && (player_kings & square2mask(square+1))) {
        return true;
    }
    if (square<=55 && square%8>=1 && (player_kings & square2mask(square+8-1))) {
        return true;
    }
    if (square<=55 && (player_kings & square2mask(square+8))) {
        return true;
    }
    if (square<=55 && square%8<=6 && (player_kings & square2mask(square+8+1))) {
        return true;
    }

    //no threats
    return false;
}

//generate pseudolegal moves for white pawns
void generate_pseudolegal_moves_white_pawns(MoveList* movelist, BitBoard* board){
    //let i be the square of the pawn
    for (int i=8; i<56; i++) {
        if (!(board->white_pawns & square2mask(i))) {
            continue;
        }

        //check move one square forward
        if (isempty(board,i-8)==0) {
            Move move = {i, i-8, 0, 0};
            if (i<16) {
                //pawn is promoting
                move.flags |= FLAG_IS_PROMOTION;                //move is now queen promotion
                movelist_add(movelist, move);
                Move moveR = {i, i-8, FLAG_IS_PROMOTION, 1};    //promote to rook
                movelist_add(movelist, moveR);
                Move moveB = {i, i-8, FLAG_IS_PROMOTION, 2};    //promote to bishop
                movelist_add(movelist, moveB);
                Move moveN = {i, i-8, FLAG_IS_PROMOTION, 3};    //promote to knight
                movelist_add(movelist, moveN);
            }
            else {
                movelist_add(movelist, move);
            }
        }

        //check move two squares forward
        if (i>=48 && isempty(board,i-8)==0 && isempty(board,i-16)==0) {
            Move move = {i, i-16, FLAG_IS_DOUBLE, 0};
            movelist_add(movelist, move);
        }

        //check capture to the right
        if (i%8<=6 && isempty(board,i-8+1)==-1) {
            Move move = {i, i-8+1, FLAG_IS_CAPTURE, 0};
            if (i<16) {
                //pawn is promoting
                move.flags |= FLAG_IS_PROMOTION;                                //move is now queen promotion
                movelist_add(movelist, move);
                Move moveR = {i, i-8+1, FLAG_IS_CAPTURE|FLAG_IS_PROMOTION, 1};  //promote to rook
                movelist_add(movelist, moveR);
                Move moveB = {i, i-8+1, FLAG_IS_CAPTURE|FLAG_IS_PROMOTION, 2};  //promote to bishop
                movelist_add(movelist, moveB);
                Move moveN = {i, i-8+1, FLAG_IS_CAPTURE|FLAG_IS_PROMOTION, 3};  //promote to knight
                movelist_add(movelist, moveN);
            }
            else {
                movelist_add(movelist, move);
            }
        }

        //check capture to the left
        if (i%8>=1 && isempty(board,i-8-1)==-1) {
            Move move = {i, i-8-1, FLAG_IS_CAPTURE, 0};
            if (i<16) {
                //pawn is promoting
                move.flags |= FLAG_IS_PROMOTION;                                //move is now queen promotion
                movelist_add(movelist, move);
                Move moveR = {i, i-8-1, FLAG_IS_CAPTURE|FLAG_IS_PROMOTION, 1};  //promote to rook
                movelist_add(movelist, moveR);
                Move moveB = {i, i-8-1, FLAG_IS_CAPTURE|FLAG_IS_PROMOTION, 2};  //promote to bishop
                movelist_add(movelist, moveB);
                Move moveN = {i, i-8-1, FLAG_IS_CAPTURE|FLAG_IS_PROMOTION, 3};  //promote to knight
                movelist_add(movelist, moveN);
            }
            else {
                movelist_add(movelist, move);
            }
        }

        //check en-passant capture to the left
        if (i>=25 && i<=31 && (board->enpassant & (1<<(i%8-1))) && (board->black_pawns & square2mask(i-1))) {
            Move move = {i, i-8-1, FLAG_IS_CAPTURE|FLAG_IS_ENPASSANT, 0};
            movelist_add(movelist, move);
        }

        //check en-passant capture to the right
        if (i>=24 && i<=30 && (board->enpassant & (1<<(i%8+1))) && (board->black_pawns & square2mask(i+1))) {
            Move move = {i, i-8+1, FLAG_IS_CAPTURE|FLAG_IS_ENPASSANT, 0};
            movelist_add(movelist, move);
        }
    }
    return;
}

//generate pseudolegal moves for black pawns
void generate_pseudolegal_moves_black_pawns(MoveList* movelist, BitBoard* board) {
    //let i be the square of the pawn
    for (int i=8; i<56; i++) {
        if (!(board->black_pawns & square2mask(i))) {
            continue;
        }

        //check move one square forward
        if (isempty(board,i+8)==0) {
            Move move = {i, i+8, 0, 0};
            if (i>=48) {
                //pawn is promoting
                move.flags |= FLAG_IS_PROMOTION;                //move is now queen promotion
                movelist_add(movelist, move);
                Move moveR = {i, i+8, FLAG_IS_PROMOTION, 1};    //promote to rook
                movelist_add(movelist, moveR);
                Move moveB = {i, i+8, FLAG_IS_PROMOTION, 2};    //promote to bishop
                movelist_add(movelist, moveB);
                Move moveN = {i, i+8, FLAG_IS_PROMOTION, 3};    //promote to knight
                movelist_add(movelist, moveN);
            }
            else {
                movelist_add(movelist, move);
            }
        }

        //check move two squares forward
        if (i<=15 && isempty(board,i+8)==0 && isempty(board,i+16)==0) {
            Move move = {i, i+16, FLAG_IS_DOUBLE, 0};
            movelist_add(movelist, move);
        }

        //check capture to the left
        if (i%8>=1 && isempty(board,i+8-1)==1) {
            Move move = {i, i+8-1, FLAG_IS_CAPTURE, 0};
            if (i>=48) {
                //pawn is promoting
                move.flags |= FLAG_IS_PROMOTION;                                //move is now queen promotion
                movelist_add(movelist, move);
                Move moveR = {i, i+8-1, FLAG_IS_CAPTURE|FLAG_IS_PROMOTION, 1};  //promote to rook
                movelist_add(movelist, moveR);
                Move moveB = {i, i+8-1, FLAG_IS_CAPTURE|FLAG_IS_PROMOTION, 2};  //promote to bishop
                movelist_add(movelist, moveB);
                Move moveN = {i, i+8-1, FLAG_IS_CAPTURE|FLAG_IS_PROMOTION, 3};  //promote to knight
                movelist_add(movelist, moveN);
            }
            else {
                movelist_add(movelist, move);
            }
        }

        //check capture to the right
        if (i%8<=6 && isempty(board,i+8+1)==1) {
            Move move = {i, i+8+1, FLAG_IS_CAPTURE, 0};
            if (i>=48) {
                //pawn is promoting
                move.flags |= FLAG_IS_PROMOTION;                                //move is now queen promotion
                movelist_add(movelist, move);
                Move moveR = {i, i+8+1, FLAG_IS_CAPTURE|FLAG_IS_PROMOTION, 1};  //promote to rook
                movelist_add(movelist, moveR);
                Move moveB = {i, i+8+1, FLAG_IS_CAPTURE|FLAG_IS_PROMOTION, 2};  //promote to bishop
                movelist_add(movelist, moveB);
                Move moveN = {i, i+8+1, FLAG_IS_CAPTURE|FLAG_IS_PROMOTION, 3};  //promote to knight
                movelist_add(movelist, moveN);
            }
            else {
                movelist_add(movelist, move);
            }
        }

        //check en-passant capture to the left
        if (i>=33 && i<=39 && (board->enpassant & (1<<(i%8-1))) && (board->white_pawns & square2mask(i-1))) {
            Move move = {i, i+8-1, FLAG_IS_CAPTURE|FLAG_IS_ENPASSANT, 0};
            movelist_add(movelist, move);
        }

        //check en-passant capture to the right
        if (i>=32 && i<=38 && (board->enpassant & (1<<(i%8+1))) && (board->white_pawns & square2mask(i+1))) {
            Move move = {i, i+8+1, FLAG_IS_CAPTURE|FLAG_IS_ENPASSANT, 0};
            movelist_add(movelist, move);
        }
    }
    return;
}

//generate pseudolegal moves for knights
void generate_pseudolegal_moves_knights(MoveList* movelist, BitBoard* board, int player) {
    //let i be the square of the knight
    uint64_t player_knights = (player==1) ? board->white_knights : board->black_knights;
    for (int i=0; i<64; i++) {
        if (!(player_knights & square2mask(i))) {
            continue;
        }

        //check move to [row-2,column-1]
        if (i>=16 && i%8>=1 && isempty(board,i-16-1)!=player) {
            Move move = {i, i-16-1, 0, 0};
            movelist_add(movelist, move);
        }
        //check move to [row-2,column+1]
        if (i>=16 && i%8<=6 && isempty(board,i-16+1)!=player) {
            Move move = {i, i-16+1, 0, 0};
            movelist_add(movelist, move);
        }
        //check move to [row-1,column-2]
        if (i>=8 && i%8>=2 && isempty(board,i-8-2)!=player) {
            Move move = {i, i-8-2, 0, 0};
            movelist_add(movelist, move);
        }
        //check move to [row-1,column+2]
        if (i>=8 && i%8<=5 && isempty(board,i-8+2)!=player) {
            Move move = {i, i-8+2, 0, 0};
            movelist_add(movelist, move);
        }
        //check move to [row+1,column-2]
        if (i<56 && i%8>=2 && isempty(board,i+8-2)!=player) {
            Move move = {i, i+8-2, 0, 0};
            movelist_add(movelist, move);
        }
        //check move to [row+1,column+2]
        if (i<56 && i%8<=5 && isempty(board,i+8+2)!=player) {
            Move move = {i, i+8+2, 0, 0};
            movelist_add(movelist, move);
        }
        //check move to [row+2,column-1]
        if (i<48 && i%8>=1 && isempty(board,i+16-1)!=player) {
            Move move = {i, i+16-1, 0, 0};
            movelist_add(movelist, move);
        }
        //check move to [row+2,column+1]
        if (i<48 && i%8<=6 && isempty(board,i+16+1)!=player) {
            Move move = {i, i+16+1, 0, 0};
            movelist_add(movelist, move);
        }
    }
    return;
}

//generate pseudolegal moves for bishops (and queens by diagonal)
void generate_pseudolegal_moves_bishops(MoveList* movelist, BitBoard* board, int player) {
    //let i be the square of the bishop/queen
    uint64_t player_pieces = (player==1) ? board->white_bishops|board->white_queens : board->black_bishops|board->black_queens;
    for (int i=0; i<64; i++) {
        if (!(player_pieces & square2mask(i))) {
            continue;
        }

        //upper-left diagonal
        int jmax = i%8;
        if (i/8<jmax) {
            jmax = i/8;
        }
        for (int j=1; j<=jmax; j++) {
            if (isempty(board,i-8*j-j)!=player) {
                Move move = {i, i-8*j-j, 0, 0};
                movelist_add(movelist, move);
            }
            if (isempty(board,i-8*j-j)!=0) {
                break;
            }
        }

        //upper-right diagonal
        jmax = 7-i%8;
        if (i/8<jmax) {
            jmax = i/8;
        }
        for (int j=1; j<=jmax; j++) {
            if (isempty(board,i-8*j+j)!=player) {
                Move move = {i, i-8*j+j, 0, 0};
                movelist_add(movelist, move);
            }
            if (isempty(board,i-8*j+j)!=0) {
                break;
            }
        }

        //lower-left diagonal
        jmax = i%8;
        if (7-i/8<jmax) {
            jmax = 7-i/8;
        }
        for (int j=1; j<=jmax; j++) {
            if (isempty(board,i+8*j-j)!=player) {
                Move move = {i, i+8*j-j, 0, 0};
                movelist_add(movelist, move);
            }
            if (isempty(board,i+8*j-j)!=0) {
                break;
            }
        }

        //lower-right diagonal
        jmax = 7-i%8;
        if (7-i/8<jmax) {
            jmax = 7-i/8;
        }
        for (int j=1; j<=jmax; j++) {
            if (isempty(board,i+8*j+j)!=player) {
                Move move = {i, i+8*j+j, 0, 0};
                movelist_add(movelist, move);
            }
            if (isempty(board,i+8*j+j)!=0) {
                break;
            }
        }
    }
    return;
}

//generate pseudolegal moves for rooks (and queens by row/column)
void generate_pseudolegal_moves_rooks(MoveList* movelist, BitBoard* board, int player) {
    //let i be the square of the rook/queen
    uint64_t player_pieces = (player==1) ? board->white_rooks|board->white_queens : board->black_rooks|board->black_queens;
    for (int i=0; i<64; i++) {
        if (!(player_pieces & square2mask(i))) {
            continue;
        }

        //upper column
        int jmax = i/8;
        for (int j=1; j<=jmax; j++) {
            if (isempty(board,i-8*j)!=player) {
                Move move = {i, i-8*j, 0, 0};
                movelist_add(movelist, move);
            }
            if (isempty(board,i-8*j)!=0) {
                break;
            }
        }

        //lower column
        jmax = 7-i/8;
        for (int j=1; j<=jmax; j++) {
            if (isempty(board,i+8*j)!=player) {
                Move move = {i, i+8*j, 0, 0};
                movelist_add(movelist, move);
            }
            if (isempty(board,i+8*j)!=0) {
                break;
            }
        }

        //left row
        jmax = i%8;
        for (int j=1; j<=jmax; j++) {
            if (isempty(board,i-j)!=player) {
                Move move = {i, i-j, 0, 0};
                movelist_add(movelist, move);
            }
            if (isempty(board,i-j)!=0) {
                break;
            }
        }

        //right row
        jmax = 7-i%8;
        for (int j=1; j<=jmax; j++) {
            if (isempty(board,i+j)!=player) {
                Move move = {i, i+j, 0, 0};
                movelist_add(movelist, move);
            }
            if (isempty(board,i+j)!=0) {
                break;
            }
        }
    }
    return;
}

//generate pseudolegal moves for kings
void generate_pseudolegal_moves_kings(MoveList* movelist, BitBoard* board, int player) {
    //let i be the square of the king
    uint64_t player_kings = (player==1) ? board->white_kings : board->black_kings;
    for (int i=0; i<64; i++) {
        if (!(player_kings & square2mask(i))) {
            continue;
        }

        if (i>=8 && i%8>=1 && isempty(board,i-8-1)!=player) {
            Move move = {i, i-8-1, 0, 0};
            movelist_add(movelist, move);
        }
        if (i>=8 && isempty(board,i-8)!=player) {
            Move move = {i, i-8, 0, 0};
            movelist_add(movelist, move);
        }
        if (i>=8 && i%8<=6 && isempty(board,i-8+1)!=player) {
            Move move = {i, i-8+1, 0, 0};
            movelist_add(movelist, move);
        }
        if (i%8>=1 && isempty(board,i-1)!=player) {
            Move move = {i, i-1, 0, 0};
            movelist_add(movelist, move);
        }
        if (i%8<=6 && isempty(board,i+1)!=player) {
            Move move = {i, i+1, 0, 0};
            movelist_add(movelist, move);
        }
        if (i<=55 && i%8>=1 && isempty(board,i+8-1)!=player) {
            Move move = {i, i+8-1, 0, 0};
            movelist_add(movelist, move);
        }
        if (i<=55 && isempty(board,i+8)!=player) {
            Move move = {i, i+8, 0, 0};
            movelist_add(movelist, move);
        }
        if (i<=55 && i%8<=6 && isempty(board,i+8+1)!=player) {
            Move move = {i, i+8+1, 0, 0};
            movelist_add(movelist, move);
        }
        break;
    }

    //castling
    if(player==1 && (board->metadata & METADATA_CASTLE_K) && (board->white_kings & square2mask(60)) && (board->white_rooks & square2mask(63)) && isempty(board,61)==0 && isempty(board,62)==0 && !isthreatened(board,60,-1) && !isthreatened(board,61,-1) && !isthreatened(board,62,-1)) {
        //white kingside
        Move move = {60, 62, FLAG_IS_CASTLING_K, 0};
        movelist_add(movelist, move);
    }
    if(player==1 && (board->metadata & METADATA_CASTLE_Q) && (board->white_kings & square2mask(60)) && (board->white_rooks & square2mask(56)) && isempty(board,57)==0 && isempty(board,58)==0 && isempty(board,59)==0 && !isthreatened(board,58,-1) && !isthreatened(board,59,-1) && !isthreatened(board,60,-1)) {
        //white queenside
        Move move = {60, 58, FLAG_IS_CASTLING_Q, 0};
        movelist_add(movelist, move);
    }
    if(player==-1 && (board->metadata & METADATA_CASTLE_k) && (board->black_kings & square2mask(4)) && (board->black_rooks & square2mask(7)) && isempty(board,5)==0 && isempty(board,6)==0 && !isthreatened(board,4,1) && !isthreatened(board,5,1) && !isthreatened(board,6,1)) {
        //black kingside
        Move move = {4, 6, FLAG_IS_CASTLING_K, 0};
        movelist_add(movelist, move);
    }
    if(player==-1 && (board->metadata & METADATA_CASTLE_q) && (board->black_kings & square2mask(4)) && (board->black_rooks & square2mask(0)) && isempty(board,1)==0 && isempty(board,2)==0 && isempty(board,3)==0 && !isthreatened(board,2,1) && !isthreatened(board,3,1) && !isthreatened(board,4,1)) {
        //black queenside
        Move move = {4, 2, FLAG_IS_CASTLING_Q, 0};
        movelist_add(movelist, move);
    }
    return;
}

//generate pseudolegal moves
void generate_pseudolegal_moves(MoveList* movelist, BitBoard* board) {
    //clear all
    movelist->NMOVES = 0;

    //generate moves for each piece
    int player = (board->metadata & METADATA_IS_WHITE_MOVING) ? 1 : -1;
    if (player==1) {
        //white is moving
        generate_pseudolegal_moves_white_pawns(movelist, board);
    }
    else {
        //black is moving
        generate_pseudolegal_moves_black_pawns(movelist, board);
    }
    generate_pseudolegal_moves_knights(movelist, board, player);
    generate_pseudolegal_moves_bishops(movelist, board, player);
    generate_pseudolegal_moves_rooks(movelist, board, player);
    generate_pseudolegal_moves_kings(movelist, board, player);
    return;
}

//make move
//NOTE: legality of the move is NOT checked
void make_move(BitBoard* board, Move* move) {
    int player = (board->metadata & METADATA_IS_WHITE_MOVING) ? 1 : -1;
    uint64_t start_square_bit = square2mask(move->start_square);
    uint64_t target_square_bit = square2mask(move->target_square);

    //kingside castling
    if (move->flags & FLAG_IS_CASTLING_K) {
        if (player == 1){
            board->white_kings &= ~square2mask(60);
            board->white_kings |= square2mask(62);
            board->white_rooks &= ~square2mask(63);
            board->white_rooks |= square2mask(61);
            board->metadata &= ~(METADATA_CASTLE_K | METADATA_CASTLE_Q);
        }
        else {
            board->black_kings &= ~square2mask(4);
            board->black_kings |= square2mask(6);
            board->black_rooks &= ~square2mask(7);
            board->black_rooks |= square2mask(5);
            board->metadata &= ~(METADATA_CASTLE_k | METADATA_CASTLE_q);
        }
        board->enpassant = 0;
        board->metadata ^= METADATA_IS_WHITE_MOVING;
        return;
    }

    //queenside castling
    if (move->flags & FLAG_IS_CASTLING_Q) {
        if (player == 1) {
            board->white_kings &= ~square2mask(60);
            board->white_kings |= square2mask(58);
            board->white_rooks &= ~square2mask(56);
            board->white_rooks |= square2mask(59);
            board->metadata &= ~(METADATA_CASTLE_K | METADATA_CASTLE_Q);
        }
        else {
            board->black_kings &= ~square2mask(4);
            board->black_kings |= square2mask(2);
            board->black_rooks &= ~square2mask(0);
            board->black_rooks |= square2mask(3);
            board->metadata &= ~(METADATA_CASTLE_k | METADATA_CASTLE_q);
        }
        board->enpassant = 0;
        board->metadata ^= METADATA_IS_WHITE_MOVING;
        return;
    }

    //en-passant capture
    if (move->flags & FLAG_IS_ENPASSANT) {
        int captured_square = move->start_square + (move->target_square%8 - move->start_square%8);
        uint64_t captured_square_bit = square2mask(captured_square);
        if (player == 1) {
            board->black_pawns &= ~captured_square_bit;
        }
        else {
            board->white_pawns &= ~captured_square_bit;
        }
    }

    //remove piece on the target square
    //if (move->flags & FLAG_IS_CAPTURE) {
        if (player == 1) {
            if (board->black_pawns & target_square_bit) {
                board->black_pawns &= ~target_square_bit;
            }
            if (board->black_knights & target_square_bit) {
                board->black_knights &= ~target_square_bit;
            }
            if (board->black_bishops & target_square_bit) {
                board->black_bishops &= ~target_square_bit;
            }
            if (board->black_rooks & target_square_bit) {
                board->black_rooks &= ~target_square_bit;
            }
            if (board->black_queens & target_square_bit) {
                board->black_queens &= ~target_square_bit;
            }
            if (board->black_kings & target_square_bit) {
                board->black_kings &= ~target_square_bit;
            }
        }
        else {
            if (board->white_pawns & target_square_bit) {
                board->white_pawns &= ~target_square_bit;
            }
            if (board->white_knights & target_square_bit) {
                board->white_knights &= ~target_square_bit;
            }
            if (board->white_bishops & target_square_bit) {
                board->white_bishops &= ~target_square_bit;
            }
            if (board->white_rooks & target_square_bit) {
                board->white_rooks &= ~target_square_bit;
            }
            if (board->white_queens & target_square_bit) {
                board->white_queens &= ~target_square_bit;
            }
            if (board->white_kings & target_square_bit) {
                board->white_kings &= ~target_square_bit;
            }
        }
    //}

    //move piece
    if (player == 1) {
        if (board->white_pawns & start_square_bit) {
            board->white_pawns &= ~start_square_bit;
            if (move->flags & FLAG_IS_PROMOTION) {
                switch (move->promotion) {
                    case 0: board->white_queens  |= target_square_bit; break;
                    case 1: board->white_rooks   |= target_square_bit; break;
                    case 2: board->white_bishops |= target_square_bit; break;
                    case 3: board->white_knights |= target_square_bit; break;
                }
            }
            else {
                board->white_pawns |= target_square_bit;
            }
        }
        else if (board->white_knights & start_square_bit) {
            board->white_knights &= ~start_square_bit;
            board->white_knights |= target_square_bit;
        }
        else if (board->white_bishops & start_square_bit) {
            board->white_bishops &= ~start_square_bit;
            board->white_bishops |= target_square_bit;
        }
        else if (board->white_rooks & start_square_bit) {
            board->white_rooks &= ~start_square_bit;
            board->white_rooks |= target_square_bit;
        }
        else if (board->white_queens & start_square_bit) {
            board->white_queens &= ~start_square_bit;
            board->white_queens |= target_square_bit;
        }
        else if (board->white_kings & start_square_bit) {
            board->white_kings &= ~start_square_bit;
            board->white_kings |= target_square_bit;
        }
    }
    else {
        if (board->black_pawns & start_square_bit) {
            board->black_pawns &= ~start_square_bit;
            if (move->flags & FLAG_IS_PROMOTION) {
                switch (move->promotion) {
                    case 0: board->black_queens  |= target_square_bit; break;
                    case 1: board->black_rooks   |= target_square_bit; break;
                    case 2: board->black_bishops |= target_square_bit; break;
                    case 3: board->black_knights |= target_square_bit; break;
                }
            }
            else {
                board->black_pawns |= target_square_bit;
            }
        }
        else if (board->black_knights & start_square_bit) {
            board->black_knights &= ~start_square_bit;
            board->black_knights |= target_square_bit;
        }
        else if (board->black_bishops & start_square_bit) {
            board->black_bishops &= ~start_square_bit;
            board->black_bishops |= target_square_bit;
        }
        else if (board->black_rooks & start_square_bit) {
            board->black_rooks &= ~start_square_bit;
            board->black_rooks |= target_square_bit;
        }
        else if (board->black_queens & start_square_bit) {
            board->black_queens &= ~start_square_bit;
            board->black_queens |= target_square_bit;
        }
        else if (board->black_kings & start_square_bit) {
            board->black_kings &= ~start_square_bit;
            board->black_kings |= target_square_bit;
        }
    }

    //update castling rights
    if (player == 1) {
        if (move->start_square == 60 || move->target_square == 60) {
            board->metadata &= ~(METADATA_CASTLE_K|METADATA_CASTLE_Q);
        }
        if (move->start_square == 63 || move->target_square == 63) {
            board->metadata &= ~METADATA_CASTLE_K;
        }
        if (move->start_square == 56 || move->target_square == 56) {
            board->metadata &= ~METADATA_CASTLE_Q;
        }
    }
    else {
        if (move->start_square == 4 || move->target_square == 4) {
            board->metadata &= ~(METADATA_CASTLE_k|METADATA_CASTLE_q);
        }
        if (move->start_square == 7 || move->target_square == 7) {
            board->metadata &= ~METADATA_CASTLE_k;
        }
        if (move->start_square == 0 || move->target_square == 0) {
            board->metadata &= ~METADATA_CASTLE_q;
        }
    }

    //reset en-passant flags
    board->enpassant = 0;
    if (move->flags & FLAG_IS_DOUBLE) {
        board->enpassant = 1u << (move->start_square % 8);
    }

    //set moving player
    board->metadata ^= METADATA_IS_WHITE_MOVING;
    return;
}

//find position of the king
int find_king_square(BitBoard* board, int player) {
    uint64_t player_kings = (player==1) ? board->white_kings : board->black_kings;
    for(int i=0;i<64;i++) {
        if(player_kings & square2mask(i)) {
            return i;
        }
    }
    return -1;
}

//check if the king of the player is in check
bool ischecked(BitBoard* board, int player) {
    return isthreatened(board, find_king_square(board,player), -player);
}

//converts a FEN string to bitboard
//see: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation
//WARNING: safety checks on user input are not implemented yet
void set_position_from_fen(BitBoard* board, const char* fenstring) {
    //clear all
    board->white_pawns = 0;
    board->white_knights = 0;
    board->white_bishops = 0;
    board->white_rooks = 0;
    board->white_queens = 0;
    board->white_kings = 0;
    board->black_pawns = 0;
    board->black_knights = 0;
    board->black_bishops = 0;
    board->black_rooks = 0;
    board->black_queens = 0;
    board->black_kings = 0;
    board->metadata = 0;
    board->enpassant = 0;

    //parse first field: piece placement
    const char* current_character = fenstring;
    int current_square = 0;
    const char chess_pieces[] = {'P', 'N', 'B', 'R', 'Q', 'K', 'p', 'n', 'b', 'r', 'q', 'k'};
    uint64_t* piece_bitboards[] = {
        &board->white_pawns,
        &board->white_knights,
        &board->white_bishops,
        &board->white_rooks,
        &board->white_queens,
        &board->white_kings,
        &board->black_pawns,
        &board->black_knights,
        &board->black_bishops,
        &board->black_rooks,
        &board->black_queens,
        &board->black_kings
    };
    while ((*current_character)!=' ') {
        if ((*current_character)=='\0') {
            return;
        }
        if ((*current_character)>='1' && (*current_character)<='8') {
            //skip empty squares
            current_square += ((*current_character) - '0');
        }
        else if ((*current_character)!='/') {
            //slash characters can be ignored
            for (int j=0; j<12; j++) {
                if ((*current_character)==chess_pieces[j]) {
                    //insert piece
                    *piece_bitboards[j] |= square2mask(current_square);
                    current_square++;
                    break;
                }
            }
        }
        current_character++;    //move pointer to the next character
    }

    //parse second field: moving player
    current_character++;
    if ((*current_character)=='w') {
        board->metadata |= METADATA_IS_WHITE_MOVING;
    }
    current_character += 2;

    //parse third field: castling
    while ((*current_character)!=' ') {
        if ((*current_character)=='\0') {
            return;
        }
        if ((*current_character)=='K') {
            board->metadata |= METADATA_CASTLE_K;
        }
        else if ((*current_character)=='Q') {
            board->metadata |= METADATA_CASTLE_Q;
        }
        else if ((*current_character)=='k') {
            board->metadata |= METADATA_CASTLE_k;
        }
        else if ((*current_character)=='q') {
            board->metadata |= METADATA_CASTLE_q;
        }
        current_character++;    //move pointer to the next character
    }
    current_character += 1;

    //check if white king or black king are in check
    if (ischecked(board, 1)) {
        board->metadata |= METADATA_WHITE_IN_CHECK;
    }
    if (ischecked(board, -1)) {
        board->metadata |= METADATA_BLACK_IN_CHECK;
    }

    //parse fourth field: en-passant
    if ((*current_character)!='-') {
        const char columns[] = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'};
        for (int j=0; j<8; j++) {
            if ((*current_character)==columns[j]) {
                board->enpassant = 1<<j;
                break;
            }
        }
    }

    //ignore fifth field: number of halfmoves since the last capture or pawn advance
    //ignore sixth field: number of moves played by the black
}

//duplicate board
void duplicate_board(BitBoard* childboard, BitBoard* board){
    *childboard = *board;
}

//generate legal moves
void generate_legal_moves(MoveList* movelist, BitBoard* board) {
    MoveList pseudomovelist;
    generate_pseudolegal_moves(&pseudomovelist, board);
    int player = (board->metadata & METADATA_IS_WHITE_MOVING) ? 1 : -1;
    
    movelist->NMOVES = 0;
    BitBoard childboard;
    for(int i=0; i<pseudomovelist.NMOVES; ++i){
        //check if i-th move is legal
        duplicate_board(&childboard, board);
        make_move(&childboard, &pseudomovelist.moves[i]);
        if(!ischecked(&childboard, player)) {
            movelist_add(movelist, pseudomovelist.moves[i]);
        }
    }
    return;
}

//count the number of legal moves at a given depth
uint64_t perft(BitBoard* board, int depth, bool print_uci_output) {
    if (depth == 0) {
        return 0;
    }
    MoveList movelist;
    generate_legal_moves(&movelist, board);
    if (depth == 1) {
        return movelist.NMOVES;
    }

    uint64_t counter = 0;
    BitBoard childboard;
    for (int i=0; i<movelist.NMOVES; ++i) {
        duplicate_board(&childboard, board);
        make_move(&childboard, &movelist.moves[i]);

        uint64_t current_move_counter = perft(&childboard, depth-1, false);
        if (print_uci_output) {
            //output the perft result in the Stockfish format
            int s = movelist.moves[i].start_square;
            int t = movelist.moves[i].target_square;
            const char columns[] = {'a','b','c','d','e','f','g','h'};
            printf("%c%i%c%i: %llu\n", columns[s%8], 8-s/8, columns[t%8], 8-t/8, (unsigned long long)current_move_counter);     //cast to llu to avoid warnings when building with emcc
        }
        counter += current_move_counter;
    }
    
    if (print_uci_output) {
        printf("Nodes searched: %llu\n", (unsigned long long)counter);
    }
    return counter;
}

//check if the game is over
bool isgameover(MoveList* movelist) {
    if (movelist->NMOVES == 0) {
        return true;
    }
    return false;
}

//convert a BitBoard to a flattened float32 array of size 783
//that can be used as input for the neural network
void bitboard_to_fp32_array(float* output, BitBoard* board) {
    uint16_t idx = 0;

    //white pieces
    for (uint8_t i=0; i<64; ++i) {
        output[idx++] = (float)(((board->white_pawns) >> i) & 1ULL);
    }
    for (uint8_t i=0; i<64; ++i) {
        output[idx++] = (float)(((board->white_knights) >> i) & 1ULL);
    }
    for (uint8_t i=0; i<64; ++i) {
        output[idx++] = (float)(((board->white_bishops) >> i) & 1ULL);
    }
    for (uint8_t i=0; i<64; ++i) {
        output[idx++] = (float)(((board->white_rooks) >> i) & 1ULL);
    }
    for (uint8_t i=0; i<64; ++i) {
        output[idx++] = (float)(((board->white_queens) >> i) & 1ULL);
    }
    for (uint8_t i=0; i<64; ++i) {
        output[idx++] = (float)(((board->white_kings) >> i) & 1ULL);
    }

    //black pieces
    for (uint8_t i=0; i<64; ++i) {
        output[idx++] = (float)(((board->black_pawns) >> i) & 1ULL);
    }
    for (uint8_t i=0; i<64; ++i) {
        output[idx++] = (float)(((board->black_knights) >> i) & 1ULL);
    }
    for (uint8_t i=0; i<64; ++i) {
        output[idx++] = (float)(((board->black_bishops) >> i) & 1ULL);
    }
    for (uint8_t i=0; i<64; ++i) {
        output[idx++] = (float)(((board->black_rooks) >> i) & 1ULL);
    }
    for (uint8_t i=0; i<64; ++i) {
        output[idx++] = (float)(((board->black_queens) >> i) & 1ULL);
    }
    for (uint8_t i=0; i<64; ++i) {
        output[idx++] = (float)(((board->black_kings) >> i) & 1ULL);
    }

    //metadata bits
    for (uint8_t i=0; i<7; ++i) {
        output[idx++] = (float)((board->metadata >> i) & 1u);
    }

    //enpassant bits
    for (uint8_t i=0; i<8; ++i) {
        output[idx++] = (float)((board->enpassant >> i) & 1u);
    }

    return;
}

//play random move
void play_random_move(Move* output_move, MoveList* movelist) {
    //initialize variables
    output_move->start_square = 0;
    output_move->target_square = 0;
    output_move->flags = 0;
    output_move->promotion = 0;
    //srand(42)
    //srand(time(NULL));

    //check legal moves
    if (movelist->NMOVES == 0) {
        return;
    }

    //pick a random move
    int idx = rand() % movelist->NMOVES;
    output_move->start_square = movelist->moves[idx].start_square;
    output_move->target_square = movelist->moves[idx].target_square;
    output_move->flags = movelist->moves[idx].flags;
    output_move->promotion = movelist->moves[idx].promotion;
    return;
}

//convert centipawns from/to bounded score
float centipawn2score(int cp) {
    if (cp > 1500) cp = 1500;
    if (cp < -1500) cp = -1500;
    return 2.0f * tanhf((float)cp / 364.0f);
}
int score2centipawn(float score) {
    if (score >=  2.0f || score <= -2.0f) {
        int sign  = (score >= 0.0f) ? 1 : -1;
        float delta = fabsf(score) - 2.0f;   //= 1 / N^(2/3)
        if (delta <= 0.0f) {
            //|score| == 2 exactly
            return sign * 1500;
        }
        int N = (int)ceilf(powf(1.0f / delta, 1.5f));
        if (N < 1) N = 1;
        return sign * (10000 - N);        //mate-in-1 → 9999, mate-in-2 → 9998, ...
    }
    int cp = (int)roundf(364.0f * atanhf(score / 2.0f));
    if (cp > 1500) cp = 1500;
    if (cp < -1500) cp = -1500;
    return cp;
}

//a basic evaluation function that only counts material imbalance
//bounded in the range [-2,+2]
float evaluate_material(BitBoard* board) {
    int cp = 0;
    uint64_t x;

    //white adds to score
    x = board->white_pawns;
    while (x) {
        cp += 100;
        x &= x - 1;     //clears the lowest set bit each iteration, so the inner while runs exactly once per occupied square
    }
    x = board->white_knights;
    while (x) {
        cp += 300;
        x &= x - 1;
    }
    x = board->white_bishops;
    while (x) {
        cp += 300;
        x &= x - 1;
    }
    x = board->white_rooks;
    while (x) {
        cp += 500;
        x &= x - 1;
    }
    x = board->white_queens;
    while (x) {
        cp += 900;
        x &= x - 1;
    }

    //black subtracts from score
    x = board->black_pawns;
    while (x) {
        cp -= 100;
        x &= x - 1;
    }
    x = board->black_knights;
    while (x) {
        cp -= 300;
        x &= x - 1;
    }
    x = board->black_bishops;
    while (x) {
        cp -= 300;
        x &= x - 1;
    }
    x = board->black_rooks;
    while (x) {
        cp -= 500;
        x &= x - 1;
    }
    x = board->black_queens;
    while (x) {
        cp -= 900;
        x &= x - 1;
    }

    //clip to [-1500, +1500]
    if (cp > 1500)  cp = 1500;
    if (cp < -1500) cp = -1500;

    //return score bounded to [-2,+2]
    return 2.0 * tanh((float)cp / 364.0f);
}

//minimax algorithm with alpha-beta pruning
//call with alpha=-3.0f and beta=+3.0f
float minimax(Move* move, BitBoard* board, uint8_t depth, float alpha, float beta, float (*evaluation_function)(BitBoard* board))
{
    //leaf node
    if (depth == 0) {
        //move->start_square = 0;
        //move->target_square = 0;
        //move->flags = 0;
        //move->promotion = 0;
        return evaluation_function(board);
    }

    const int player = (board->metadata & METADATA_IS_WHITE_MOVING) ? 1 : -1;
    float bestscore = -3.0f * player;

    //generate legal moves
    MoveList movelist;
    generate_legal_moves(&movelist, board);
    if (movelist.NMOVES == 0) {
        if (ischecked(board, player)) {
            //checkmate: the side to move has lost
            return bestscore;
        }

        //stalemate
        return 0.0f;
    }

    //evaluate legal moves by calling minimax recursively
    BitBoard childboard;
    for (int i=0; i<movelist.NMOVES; ++i) {
        //apply move and search one level deeper
        duplicate_board(&childboard, board);
        make_move(&childboard, &movelist.moves[i]);
        Move childmove;
        float childscore = minimax(&childmove, &childboard, depth-1, alpha, beta, evaluation_function);

        //compare with best move so far
        if (childscore*player >= bestscore*player) {
            bestscore = childscore;
            move->start_square = movelist.moves[i].start_square;
            move->target_square = movelist.moves[i].target_square;
            move->flags = movelist.moves[i].flags;
            move->promotion = movelist.moves[i].promotion;
        }

        //alpha-beta pruning
        if ((player==1 && bestscore>beta) || (player==-1 && bestscore<alpha)) {
            //stop evaluating other moves from this branch
            break;
        }

        //update values of alpha and beta
        if (player==1 && bestscore>alpha) {
            alpha = bestscore;
        }
        else if (player==-1 && bestscore<beta) {
            beta = bestscore;
        }
    }

    return bestscore;
}

