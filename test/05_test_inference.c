//---------------------------------------------------------------------
//  Testing program for the forward_pass() function
//
//  How to run:
//  g++ -Wall -Wextra 05_test_inference.c -o 05_test_inference
//  ./05_test_inference
//
//  Author: Andrea Pavan
//  License: MIT
//---------------------------------------------------------------------
#include <stdio.h>
#include <stdlib.h>
#include "../chess.c"
#include "../inference.c"


int main() {
    //load pretrained model
    neuralnetwork pretrained_model;
    load_model_from_file("../webgui/pretrained-2311-24k.bin", &pretrained_model);

    //initialize board to starting position
    int gameboard[783] = {0};
    int legal_moves[64][64] = {0};
    set_starting_position(&gameboard);
    generate_legal_moves(&legal_moves, &gameboard);

    //test #1: check that the weights are correct
    if (abs(pretrained_model.W1[4]-0.0752063)<=1e-6
        || abs(pretrained_model.W2[2]-0.117354)<=1e-6
        || abs(pretrained_model.W3[4]-0.104201)<=1e-6
        || abs(pretrained_model.b1[3]-0.24738874)<=1e-6
        || abs(pretrained_model.b2[3]+0.09367089)<=1e-6
        || abs(pretrained_model.b3[0]+0.0035790284)<=1e-6) {
        printf("Test 1 - SUCCESS :)\n");
        printf("Model loaded correctly\n");
    }
    else {
        printf("Test 1 - FAILED :(\n");
        printf("Model not loaded correctly\n");
        unload_model_from_memory(&pretrained_model);
        return 0;
    }
    
    //test #2: starting position
    if (abs(forward_pass(&pretrained_model,&gameboard)-0.28675386)<=1e-6) {
        printf("Test 2 - SUCCESS :)\n");
    }
    else {
        printf("Test 2 - FAILED :(\n");
        unload_model_from_memory(&pretrained_model);
        return 0;
    }

    //test #3: score after move 1.e2e4
    make_move(&gameboard, 52, 36, legal_moves[52][36]);
    if (score(&pretrained_model,&gameboard)==35) {
        printf("Test 3 - SUCCESS :)\n");
    }
    else {
        printf("Test 3 - FAILED :(\n");
        unload_model_from_memory(&pretrained_model);
        return 0;
    }
    set_starting_position(&gameboard);


    unload_model_from_memory(&pretrained_model);
    return 0;
}
