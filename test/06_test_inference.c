//---------------------------------------------------------------------
//  Testing program for neural network inference in ONNX
//
//  How to run:
//  gcc 05_test_inference -o 05_test_inference -std=c17 -Wall -Wextra
//  ./05_test_inference
//
//  Author: Andrea Pavan
//  License: MIT
//---------------------------------------------------------------------
#include <stdio.h>
#include "../src/chess.c"


int main() {
    printf("Testing program neural network inference in ONNX\n");
    BitBoard gameboard;
    float flattened_array[783];

    //test #1: convert bitboard to flattened FP32 array
    set_starting_position(&gameboard);
    bitboard_to_fp32_array(flattened_array, &gameboard);
    float flattened_array_sum = 0.0f;
    for (uint16_t i=0; i<783; ++i) {
        flattened_array_sum += flattened_array[i];
    }
    if (flattened_array_sum == 32+5+0) {
        printf("Test 1 - SUCCESS :)\n");
    }
    else {
        printf("Test 1 - FAILED :(\n");
        return 0;
    }


    return 0;
}
