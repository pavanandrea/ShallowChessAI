//---------------------------------------------------------------------
//  Testing program for the perft() function
//
//  How to run:
//  gcc 04_test_perft.c -o 04_test_perft -std=c17 -Wall -Wextra
//  ./04_test_perft
//
//  Author: Andrea Pavan
//  License: MIT
//---------------------------------------------------------------------
#include <stdio.h>
#include "../src/chess.c"


int main() {
    printf("Testing program for the perft() function\n");
    BitBoard gameboard;

    //test #1: initial position
    set_starting_position(&gameboard);
    if (perft(&gameboard,5,false)==4865609) {
        printf("Test 1 - SUCCESS :)\n");
    }
    else {
        printf("Test 1 - FAILED :(\n");
        return 0;
    }

    //test #2: position #2 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -");
    if (perft(&gameboard,4,false)==4085603) {
        printf("Test 2 - SUCCESS :)\n");
    }
    else {
        printf("Test 2 - FAILED :(\n");
        return 0;
    }

    //test #3: position #3 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1");
    if (perft(&gameboard,5,false)==674624) {
        printf("Test 3 - SUCCESS :)\n");
    }
    else {
        printf("Test 3 - FAILED :(\n");
        return 0;
    }

    //test #4: position #4 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1");
    if (perft(&gameboard,4,false)==422333) {
        printf("Test 4 - SUCCESS :)\n");
    }
    else {
        printf("Test 4 - FAILED :(\n");
        return 0;
    }

    //test #5: position #5 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8");
    if (perft(&gameboard,4,false)==2103487) {
        printf("Test 5 - SUCCESS :)\n");
    }
    else {
        printf("Test 5 - FAILED :(\n");
        return 0;
    }

    //test #6: position #6 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10");
    if (perft(&gameboard,4,false)==3894594) {
        printf("Test 6 - SUCCESS :)\n");
    }
    else {
        printf("Test 6 - FAILED :(\n");
        return 0;
    }

    //test #7: Scandinavian Defense variant
    set_position_from_fen(&gameboard, "rnb1kbnr/ppp1pppp/8/3q4/8/2N5/PPPP1PPP/R1BQKBNR b KQkq - 0 1");
    if (perft(&gameboard,4,false)==1715862) {
        printf("Test 7 - SUCCESS :)\n");
    }
    else {
        printf("Test 7 - FAILED :(\n");
        return 0;
    }

    return 0;
}
