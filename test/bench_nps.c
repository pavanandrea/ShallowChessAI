//------------------------------------------------------------------------------
//  NPS Benchmark program
//
//  How to run:
//  gcc bench_nps.c -o bench_nps -O2 -std=c17 -Wall -Wextra
//  ./bench_nps
//
//  Author: Andrea Pavan
//  License: MIT
//------------------------------------------------------------------------------
#define _POSIX_C_SOURCE 200809L     //expose CLOCK_MONOTONIC under -std=c17
#include <stdio.h>
#include <time.h>
#include "../src/chess.c"


//timing helper
static double clock_now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

int main(void) {
    BitBoard board;
    set_starting_position(&board);
    const int depth = 7;

    double t0 = clock_now();
    uint64_t nodes = perft(&board, depth, false);
    double t1 = clock_now();

    double elapsed = t1 - t0;
    double Mnps = nodes / elapsed / 1e6;
    printf("perft(%d) from start position\n", depth);
    printf("  nodes : %ld\n", nodes);
    printf("  time  : %.6f s\n", elapsed);
    printf("  speed : %.2f Mnodes/s\n", Mnps);

    return 0;
}
