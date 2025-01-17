//---------------------------------------------------------------------
//  Testing program for the perft() function
//
//  How to run:
//  g++ -Wall -Wextra 04_test_perft.c -o 04_test_perft
//  ./04_test_perft
//
//  Author: Andrea Pavan
//  License: MIT
//---------------------------------------------------------------------
#include <stdio.h>
#include "../chess.c"


int main() {
    printf("Testing program for the perft() function\n");
    int gameboard[783] = {0};

    //test #1: initial position at depth 0
    set_position_from_fen(&gameboard, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    if (perft(&gameboard,0)==20) {
        printf("Test 1 - SUCCESS :)\n");
    }
    else {
        printf("Test 1 - FAILED :(\n");
        return 0;
    }

    //test #2: initial position at depth 1
    set_position_from_fen(&gameboard, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    if (perft(&gameboard,1)==400) {
        printf("Test 2 - SUCCESS :)\n");
    }
    else {
        printf("Test 2 - FAILED :(\n");
        return 0;
    }

    //test #3: position #3 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -");
    if (perft(&gameboard,2)==2812) {
        printf("Test 3 - SUCCESS :)\n");
    }
    else {
        printf("Test 3 - FAILED :(\n");
        return 0;
    }
    /*
        Stockfish output:
        $ ./stockfish-ubuntu-x86-64-avx2
            Stockfish 16 by the Stockfish developers (see AUTHORS file)
            ucinewgame
            position fen 8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -
            go perft 3
            e2e3: 205
            g2g3: 54
            a5a6: 240
            e2e4: 177
            g2g4: 226
            b4b1: 265
            b4b2: 205
            b4b3: 248
            b4a4: 202
            b4c4: 254
            b4d4: 243
            b4e4: 228
            b4f4: 41
            a5a4: 224

            Nodes searched: 2812
    */

    //test #4: position #6 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10");
    if (perft(&gameboard,2)==89890) {
        printf("Test 4 - SUCCESS :)\n");
    }
    else {
        printf("Test 4 - FAILED :(\n");
        return 0;
    }

    //test #5: position #3 from https://www.chessprogramming.org/Perft_Results
    set_position_from_fen(&gameboard, "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -");
    if (perft(&gameboard,4)==674624) {
        printf("Test 5 - SUCCESS :)\n");
    }
    else {
        printf("Test 5 - FAILED :(\n");
        return 0;
    }

    //test #6: Scandinavian Defense variant
    set_position_from_fen(&gameboard, "rnb1kbnr/ppp1pppp/8/8/8/2N2q2/PPPP1PPP/R1BQKBNR w KQkq - 0 1");
    if (perft(&gameboard,2)==29856) {
        printf("Test 6 - SUCCESS :)\n");
    }
    else {
        printf("Test 6 - FAILED :(\n");
        return 0;
    }
    

    //test #7: Scandinavian Defense variant
    set_position_from_fen(&gameboard, "rnb1kbnr/ppp1pppp/8/3q4/8/2N5/PPPP1PPP/R1BQKBNR b KQkq - 0 1");
    
    if (perft(&gameboard,3)==1715862) {
        printf("Test 7 - SUCCESS :)\n");
    }
    else {
        printf("Test 7 - FAILED :(\n");
        return 0;
    }
    /*
        Stockfish output:
        $ ./stockfish-ubuntu-x86-64-avx2
            Stockfish 16 by the Stockfish developers (see AUTHORS file)
            ucinewgame
            position fen 8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -
            go perft 4
            a7a6: 41870
            b7b6: 44709
            c7c6: 40768
            e7e6: 44575
            f7f6: 41160
            g7g6: 43743
            h7h6: 41683
            a7a5: 42814
            b7b5: 40576
            c7c5: 38856
            e7e5: 46262
            f7f5: 36496
            g7g5: 41514
            h7h5: 42910
            b8a6: 41595
            b8c6: 44604
            b8d7: 38787
            g8f6: 44777
            g8h6: 42657
            c8h3: 40544
            c8g4: 39046
            c8f5: 42372
            c8e6: 40427
            c8d7: 42558
            d5a2: 36355
            d5d2: 2812
            d5g2: 34016
            d5b3: 37123
            d5d3: 31977
            d5f3: 29856
            d5c4: 36168
            d5d4: 38903
            d5e4: 4801
            d5a5: 37223
            d5b5: 37346
            d5c5: 39429
            d5e5: 5024
            d5f5: 37305
            d5g5: 38977
            d5h5: 36122
            d5c6: 38814
            d5d6: 43522
            d5e6: 4621
            d5d7: 30732
            d5d8: 30072
            e8d7: 36448
            e8d8: 42913

            Nodes searched: 1715862
    */

    return 0;
}
