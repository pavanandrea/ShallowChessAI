//---------------------------------------------------------------------
//  Testing program for the minimax() function
//
//  How to run:
//  gcc 05_test_minimax.c -o 05_test_minimax -std=c17 -Wall -Wextra -lm
//  ./05_test_minimax
//
//  Author: Andrea Pavan
//  License: MIT
//---------------------------------------------------------------------
#include <math.h>
#include <stdio.h>
#include "../src/chess.c"


int main() {
    printf("Testing program for the minimax() function\n");
    BitBoard gameboard;
    Move move;

    //test #1: score of starting position (standard and with missing pieces)
    set_starting_position(&gameboard);
    float score0 = evaluate_material(&gameboard);
    set_position_from_fen(&gameboard, "rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");  //missing black queen
    float score1 = evaluate_material(&gameboard);
    set_position_from_fen(&gameboard, "rnbqkbnr/pppppppp/8/8/8/8/1PPPPPPP/RNBQKBNR w KQkq - 0 1");  //missing white pawn
    float score2 = evaluate_material(&gameboard);
    if (score0 == 0.0f && fabs(score1 - centipawn2score(900)) <= 1e-5
                && fabs(score2 - centipawn2score(-100)) <= 1e-5) {
        printf("Test 1 - SUCCESS :)\n");
    }
    else {
        printf("Test 1 - FAILED :(\n");
        return 0;
    }

    //test #2: position with promotion at depth 1
    //NOTE: evaluation function must be simple material balance
    set_position_from_fen(&gameboard, "7k/1P6/8/8/8/8/1p6/7K w - - 0 1");
    score0 = minimax(&move, &gameboard, 0, -3, +3, evaluate_material);
    score1 = minimax(&move, &gameboard, 1, -3, +3, evaluate_material);
    if (score0 == 0.0f && fabs(score1 - centipawn2score(800)) <= 1e-5) {
        printf("Test 2 - SUCCESS :)\n");
    }
    else {
        printf("Test 2 - FAILED :(\n");
        return 0;
    }

    //test #3: Paul Morphy's Amazing Checkmate in Two
    //https://www.chess.com/blog/ThePawnSlayer/checkmate-in-two-puzzles-test-very-hard
    set_position_from_fen(&gameboard, "kbK5/pp6/1P6/8/8/8/8/R7 w - - 0 1");
    score0 = minimax(&move, &gameboard, 4, -3, +3, evaluate_material);
    if (score0 == 3.0f && move.start_square == 56 && move.target_square == 16) {
        printf("Test 3 - SUCCESS :)\n");
    }
    else {
        printf("Test 3 - FAILED :(\n");
        return 0;
    }
    
    return 0;
}
