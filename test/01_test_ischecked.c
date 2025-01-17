//---------------------------------------------------------------------
//  Testing program for the ischecked() function
//
//  How to run:
//  g++ -Wall -Wextra 01_test_ischecked.c -o 01_test_ischecked && ./01_test_ischecked
//
//  Author: Andrea Pavan
//  License: MIT
//---------------------------------------------------------------------
#include <stdio.h>
#include "../chess.c"


int main() {
    printf("Testing program for the ischecked() function\n");
    int gameboard[783] = {0};

    //test #1: starting position
    //https://lichess.org/editor/
    set_position_from_fen(&gameboard, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    if (!ischecked(&gameboard,1)) {
        printf("Test 1 - SUCCESS :)\n");
    }
    else {
        printf("Test 1 - FAILED :(\n");
        return 0;
    }

    //test #2: white king in check by black pawn
    //https://lichess.org/editor/r3kb1r/pbpq2pp/np5B/5p2/3P4/P1N5/RPP2pPP/3QKBNR_w_Kkq_-_0_14?color=white
    set_position_from_fen(&gameboard, "r3kb1r/pbpq2pp/np5B/5p2/3P4/P1N5/RPP2pPP/3QKBNR w Kkq - 0 14");
    if (ischecked(&gameboard,1)) {
        printf("Test 2 - SUCCESS :)\n");
    }
    else {
        printf("Test 2 - FAILED :(\n");
        return 0;
    }

    //test #3: white king in check by black knight
    //https://lichess.org/editor/r3kb1r/pbpp1p1p/1p2p3/7B/4P2q/PnN2Q2/1PP2PPP/2KRR3_w_kq_-_2_4?color=white
    set_position_from_fen(&gameboard, "r3kb1r/pbpp1p1p/1p2p3/7B/4P2q/PnN2Q2/1PP2PPP/2KRR3 w kq - 2 4");
    if (ischecked(&gameboard,1)) {
        printf("Test 3 - SUCCESS :)\n");
    }
    else {
        printf("Test 3 - FAILED :(\n");
        return 0;
    }

    //test #4: white king in check by black bishop
    set_position_from_fen(&gameboard, "rnbqk1nr/pppp1ppp/8/1B2p3/4P3/5N2/PPPb1PPP/RNBQK2R w KQkq - 0 4");
    if (ischecked(&gameboard,1)) {
        printf("Test 4 - SUCCESS :)\n");
    }
    else {
        printf("Test 4 - FAILED :(\n");
        return 0;
    }
    
    //test #5 - white king in check by black rock
    set_position_from_fen(&gameboard, "rnb3k1/pppr1ppp/5n2/4p1N1/4P3/2N2Q2/PPPK1PPP/R1B4R w - - 0 9");
    if (ischecked(&gameboard,1)) {
        printf("Test 5 - SUCCESS :)\n");
    }
    else {
        printf("Test 5 - FAILED :(\n");
        return 0;
    }

    //test #6 - white king in check by black queen
    set_position_from_fen(&gameboard, "rnb1k1nr/pppp1ppp/8/1B2p1q1/4P3/5N2/PPPK1PPP/RNBQ3R w kq - 1 5");
    if (ischecked(&gameboard,1)) {
        printf("Test 6 - SUCCESS :)\n");
    }
    else {
        printf("Test 6 - FAILED :(\n");
        return 0;
    }

    //test #7 - black king in check by white pawn
    set_position_from_fen(&gameboard, "r2qkb1r/pbpP2pp/np2pp1B/8/3P4/P1N5/1PP2PPP/R2QKBNR b KQkq - 0 8");
    if (ischecked(&gameboard,-1)) {
        printf("Test 7 - SUCCESS :)\n");
    }
    else {
        printf("Test 7 - FAILED :(\n");
        return 0;
    }

    //test #8 - black king in check by white knight
    set_position_from_fen(&gameboard, "r3k2r/pbNp1p1p/1pn1p2b/7B/3PP2q/P4Q2/1PP2PPP/R3K2R b KQkq - 0 3");
    if (ischecked(&gameboard,-1)) {
        printf("Test 8 - SUCCESS :)\n");
    }
    else {
        printf("Test 8 - FAILED :(\n");
        return 0;
    }

    //test #9 - black king in check by white bishop
    set_position_from_fen(&gameboard, "r3kb1r/ppp1pppp/n3Qn2/1B6/8/8/NPPP1PPP/R1B1K1NR b KQkq - 2 7");
    if (ischecked(&gameboard,-1)) {
        printf("Test 9 - SUCCESS :)\n");
    }
    else {
        printf("Test 9 - FAILED :(\n");
        return 0;
    }

    //test #10 - black king in check by white rock
    set_position_from_fen(&gameboard, "r1bR2k1/ppp2ppp/5n2/4p1N1/1n2P3/2N1KQ2/PPP2PPP/R1B5 b - - 2 12");
    if (ischecked(&gameboard,-1)) {
        printf("Test 10 - SUCCESS :)\n");
    }
    else {
        printf("Test 10 - FAILED :(\n");
        return 0;
    }

    //test #11 - black king in check by white queen
    set_position_from_fen(&gameboard, "r1bRn1k1/ppp2Qpp/8/4p1N1/1n2P3/2N1K3/PPP2PPP/R1B5 b - - 0 13");
    if (ischecked(&gameboard,-1)) {
        printf("Test 10 - SUCCESS :)\n");
    }
    else {
        printf("Test 10 - FAILED :(\n");
        return 0;
    }

    return 0;
}
