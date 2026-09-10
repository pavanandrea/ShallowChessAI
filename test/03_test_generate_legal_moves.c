//---------------------------------------------------------------------
//  Testing program for the generate_legal_moves() function
//
//  How to run:
//  gcc 03_test_generate_legal_moves.c -o 03_test_generate_legal_moves -std=c17 -Wall -Wextra
//  ./03_test_generate_legal_moves
//
//  Author: Andrea Pavan
//  License: MIT
//---------------------------------------------------------------------
#include <stdio.h>
#include "../src/chess.c"


int main() {
    printf("Testing program for the generate_legal_moves() function\n");
    BitBoard gameboard;
    MoveList movelist;

    //test #1: position #2 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -");
    generate_legal_moves(&movelist, &gameboard);
    if (movelist.NMOVES==48) {
        printf("Test 1 - SUCCESS :)\n");
    }
    else {
        printf("Test 1 - FAILED :(\n");
        return 0;
    }

    //test #2: position #3 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -");
    generate_legal_moves(&movelist, &gameboard);
    if (movelist.NMOVES==14) {
        printf("Test 2 - SUCCESS :)\n");
    }
    else {
        printf("Test 2 - FAILED :(\n");
        return 0;
    }

    //test #3: position #5 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8");
    generate_legal_moves(&movelist, &gameboard);
    if (movelist.NMOVES==44 || movelist.NMOVES==41) {
        printf("Test 3 - SUCCESS :)\n");
        if (movelist.NMOVES==41) {
            printf("Note: test is successful only if knight, bishop and rook promotions are disabled\n");
        }
    }
    else {
        printf("Test 3 - FAILED :(\n");
        return 0;
    }

    //test #4: position #6 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - -");
    generate_legal_moves(&movelist, &gameboard);
    if (movelist.NMOVES==46) {
        printf("Test 4 - SUCCESS :)\n");
    }
    else {
        printf("Test 4 - FAILED :(\n");
        return 0;
    }

    //test #5: variant of position #3 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "8/2p5/3p4/1P5r/KR3p1k/8/4P1P1/8 b - - 1 1");
    generate_legal_moves(&movelist, &gameboard);
    if (movelist.NMOVES==15) {
        printf("Test 5 - SUCCESS :)\n");
    }
    else {
        printf("Test 5 - FAILED :(\n");
        return 0;
    }

    //test #6: checkmate position
    set_position_from_fen(&gameboard, "3k4/8/8/8/8/8/5PPP/3q2K1 w - - 0 1");
    generate_legal_moves(&movelist, &gameboard);
    if (movelist.NMOVES==0) {
        printf("Test 6 - SUCCESS :)\n");
    }
    else {
        printf("Test 6 - FAILED :(\n");
        return 0;
    }

    return 0;
}


