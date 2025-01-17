//---------------------------------------------------------------------
//  Testing program for the generate_pseudolegal_moves() function
//
//  How to run:
//  g++ -Wall -Wextra 02_test_generate_pseudolegal_moves.c -o 02_test_generate_pseudolegal_moves
//  ./02_test_generate_pseudolegal_moves
//
//  Author: Andrea Pavan
//  License: MIT
//---------------------------------------------------------------------
#include <stdio.h>
#include "../chess.c"


int main() {
    printf("Testing program for the generate_pseudolegal_moves() function\n");
    int gameboard[783] = {0};
    int moves[64][64];
    int counter = 0;

    //test #1: white pawns
    set_position_from_fen(&gameboard, "8/8/8/5pP1/8/6n1/PP5P/8 w - f6 0 1");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==9) {
        printf("Test 1 - SUCCESS :)\n");
    }
    else {
        printf("Test 1 - FAILED :(\n");
        return 0;
    }

    //test #2: white bishops and pawn
    set_position_from_fen(&gameboard, "8/2p5/8/4B3/3P4/8/8/7B w - - 0 1");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==16) {
        printf("Test 2 - SUCCESS :)\n");
    }
    else {
        printf("Test 2 - FAILED :(\n");
        return 0;
    }


    //test #3: white rocks and queen
    set_position_from_fen(&gameboard, "7R/5n2/4Q3/8/4p3/4R3/8/8 w - - 0 1");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==14+10+21) {
        printf("Test 3 - SUCCESS :)\n");
    }
    else {
        printf("Test 3 - FAILED :(\n");
        return 0;
    }


    //test #4: white king
    set_position_from_fen(&gameboard, "4b3/4P3/4Kn2/8/8/8/8/8 w - - 0 1");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==7) {
        printf("Test 4 - SUCCESS :)\n");
    }
    else {
        printf("Test 4 - FAILED :(\n");
        return 0;
    }

    //test #5: black pawns
    set_position_from_fen(&gameboard, "8/1p6/7p/6N1/pP6/8/8/8 b - b3 0 1");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==6) {
        printf("Test 5 - SUCCESS :)\n");
    }
    else {
        printf("Test 5 - FAILED :(\n");
        return 0;
    }

    //test #6: black knights and pawn
    set_position_from_fen(&gameboard, "8/8/2p1P3/3p4/3n4/8/8/7n b - - 0 1");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==10) {
        printf("Test 6 - SUCCESS :)\n");
    }
    else {
        printf("Test 6 - FAILED :(\n");
        return 0;
    }

    //test #7: black bishops
    set_position_from_fen(&gameboard, "7b/8/6b1/8/4Q3/8/8/8 b - - 0 1");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==13) {
        printf("Test 7 - SUCCESS :)\n");
    }
    else {
        printf("Test 7 - FAILED :(\n");
        return 0;
    }

    //test #8: black rocks and queen
    set_position_from_fen(&gameboard, "8/8/5P2/8/3qN1r1/8/8/7r b - - 0 1");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==22+10+14) {
        printf("Test 8 - SUCCESS :)\n");
    }
    else {
        printf("Test 8 - FAILED :(\n");
        return 0;
    }

    //test #9: black king
    set_position_from_fen(&gameboard, "8/8/4p3/4k3/5P2/8/8/8 b - - 0 1");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==7) {
        printf("Test 9 - SUCCESS :)\n");
    }
    else {
        printf("Test 9 - FAILED :(\n");
        return 0;
    }

    //test #10: castling not allowed
    set_position_from_fen(&gameboard, "7r/8/8/5q2/8/8/P6P/R3K2R w KQh - 0 1");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==15) {
        printf("Test 10 - SUCCESS :)\n");
    }
    else {
        printf("Test 10 - FAILED :(\n");
        return 0;
    }

    //test #11: initial position
    set_position_from_fen(&gameboard, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==20) {
        printf("Test 11 - SUCCESS :)\n");
    }
    else {
        printf("Test 11 - FAILED :(\n");
        return 0;
    }

    //test #12: position #2 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==48) {
        printf("Test 12 - SUCCESS :)\n");
    }
    else {
        printf("Test 12 - FAILED :(\n");
        return 0;
    }

    //test #13: opening C88 Ruy-Lopez Closed variation
    set_position_from_fen(&gameboard, "r1bqk2r/2ppbppp/p1n2n2/1p2p3/4P3/1B3N2/PPPP1PPP/RNBQR1K1 b kq - 0 1");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==8+10+6+4+0+2) {
        printf("Test 13 - SUCCESS :)\n");
    }
    else {
        printf("Test 13 - FAILED :(\n");
        return 0;
    }

    //test #14: position #5 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==44 || counter==41) {
        printf("Test 14 - SUCCESS :)\n");
        if (counter==41) {
            printf("Note: test is successful only if knight, bishop and rook promotions are disabled\n");
        }
    }
    else {
        printf("Test 14 - FAILED :(\n");
        return 0;
    }

    //test #15: position #6 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - -");
    generate_pseudolegal_moves(&moves, &gameboard);
    counter = count_legal_moves(&moves);
    if (counter==46) {
        printf("Test 15 - SUCCESS :)\n");
    }
    else {
        printf("Test 15 - FAILED :(\n");
        return 0;
    }

    return 0;
}


