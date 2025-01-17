//---------------------------------------------------------------------
//  Play chess with ShallowChessAI online
//
//  How to compile:
//  ./compile-wasm.sh
//
//  Author: Andrea Pavan
//  License: MIT
//---------------------------------------------------------------------
#include <iostream>
#include <emscripten.h>
#include "../chess.c"
#include "../inference.c"


//global declarations
int gameboard[783] = {0};
int legal_moves[64][64] = {0};
const char columns[] = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'};
extern "C" {
    void restart();
    void highlight_legal_moves(int square);
    void request_move(int square_start, int square_target);
    void request_engine_change(int desired_engine, int desired_depth);
}

//define chess engine
neuralnetwork pretrained_model;
enum engine {
    random_move = 0,
    pretrained_2311_24k = 1
};
engine current_engine = random_move;
int depth = 0;

//highlight legal moves when user starts dragging a piece
void highlight_legal_moves(int square) {
    for (int i=0; i<64; i++) {
        if (legal_moves[square][i]!=0 && legal_moves[square][i]!=7) {
            EM_ASM({
                highlight_square("square"+$0, highlight_color_legal);
            },i);
        }
        else if (legal_moves[square][i]==7 && i<=7) {
            //pawn promoting
            //note: the condition i<=7 allows to skip the (illegal) moves that encode the various promotions
            EM_ASM({
                highlight_square("square"+$0, highlight_color_legal);
            },i);
        }
    }
    /*EM_ASM({
        highlight_square("square37", highlight_color_legal);
        highlight_square("square45", highlight_color_legal);
    });*/
}

//draw board on the web gui
void draw_board_on_screen() {
    //clean board
    EM_ASM({
        disable_all_highlights();
        document.querySelectorAll(".square").forEach((square) => {
            square.innerHTML = "";
        });
    });

    //draw white pieces
    for (int i=0; i<6*64; i++) {
        if (gameboard[i]==1) {
            EM_ASM({
                document.getElementById("square"+$0).innerHTML = "<div draggable=\"true\">"+chess_icons[$1]+"</div>";
            },i%64,i/64);
        }
    }

    //draw black pieces
    for (int i=6*64; i<12*64; i++) {
        if (gameboard[i]==1) {
            EM_ASM({
                document.getElementById("square"+$0).innerHTML = chess_icons[$1];
            },i%64,i/64);
        }
    }

    //update castling options
    EM_ASM({
        document.getElementById("castlingLabel").innerHTML = "Castling options: ";
        document.getElementById("castlingLabel").innerHTML += $0 ? "K" : "-";
        document.getElementById("castlingLabel").innerHTML += $1 ? "Q" : "-";
        document.getElementById("castlingLabel").innerHTML += $2 ? "k" : "-";
        document.getElementById("castlingLabel").innerHTML += $3 ? "q" : "-";
    },gameboard[770-1],gameboard[771-1],gameboard[772-1],gameboard[773-1]);
}

//restart game
void restart() {
    set_starting_position(&gameboard);
    generate_legal_moves(&legal_moves, &gameboard);
    draw_board_on_screen();
    EM_ASM({
        set_user_dragging(true);
    });
    std::cout << "WASM - Game restarted" << std::endl;
}

//notifies the user that the game has ended
void game_over() {
    std::cout << "WASM - Game Over" << std::endl;
    EM_ASM({
        disable_all_highlights();
        set_user_dragging(false);
        alert("Well played! The game is over");
    });
    return;
}

//make computer move
void make_computer_move() {
    if (gameboard[769-1]) {
        //white is moving
        std::cout << "WASM - Error calling make_computer_move(): white is moving" << std::endl;
        return;
    }
    if (isgameover(&legal_moves)) {
        game_over();
        return;
    }

    //run chess engine
    EM_ASM({
        set_user_dragging(false);
    });
    enginemove computer_move;
    if (current_engine==pretrained_2311_24k && depth==0) {
        //play move suggested by the AI without search
        //std::cout << "Running engine pretrained-2311-24k without search" << std::endl;
        computer_move = move_without_search(&pretrained_model, &legal_moves, &gameboard);
    }
    else if (current_engine==pretrained_2311_24k && depth>=1) {
        //choose a move using the minimax algorithm
        computer_move = minimax(&pretrained_model, &legal_moves, &gameboard, depth);
    }
    else {
        //random move
        //std::cout << "Running engine random move" << std::endl;
        computer_move = play_random_move(&legal_moves, &gameboard);
    }
    make_move(&gameboard, computer_move.start, computer_move.target, legal_moves[computer_move.start][computer_move.target]);
    generate_legal_moves(&legal_moves, &gameboard);
    std::cout << "WASM - Engine played " << columns[computer_move.start%8] << (8-computer_move.start/8) << columns[computer_move.target%8] << (8-computer_move.target/8) << std::endl;
    
    //display new board on screen
    draw_board_on_screen();
    EM_ASM({
        highlight_square("square"+$0, highlight_color_start);
        highlight_square("square"+$1, highlight_color_target);
        set_user_dragging(true);
    },computer_move.start,computer_move.target);

    //check if the game is over
    if (isgameover(&legal_moves)) {
        game_over();
    }
    return;
}

//user request to make a move
void request_move(int square_start, int square_target) {
    if (legal_moves[square_start][square_target]==0) {
        std::cout << "WASM - User submitted an invalid move " << columns[square_start%8] << (8-square_start/8) << columns[square_target%8] << (8-square_target/8) << std::endl;
        return;
    }
    make_move(&gameboard, square_start, square_target, legal_moves[square_start][square_target]);
    generate_legal_moves(&legal_moves, &gameboard);
    std::cout << "WASM - User played " << columns[square_start%8] << (8-square_start/8) << columns[square_target%8] << (8-square_target/8) << std::endl;
    
    //display new board on screen
    draw_board_on_screen();
    EM_ASM({
        highlight_square("square"+$0, highlight_color_start);
        highlight_square("square"+$1, highlight_color_target);
        set_user_dragging(true);
    },square_start,square_target);

    //run engine for next move
    make_computer_move();
    return;
}

//user request to change engine model and/or depth
void request_engine_change(int desired_engine=-1, int desired_depth=-1) {
    if (desired_engine>=0 && current_engine!=desired_engine) {
        current_engine = static_cast<engine>(desired_engine);
        std::cout << "WASM - Selected engine: " << current_engine << std::endl;
    }
    if (desired_depth>=0 && depth!=desired_depth) {
        depth = desired_depth;
        std::cout << "WASM - Selected depth: " << depth << std::endl;
    }
    return;
}

//main function
int main() {
    std::cout << "ShallowChessAI running on WASM" << std::endl;
    
    //load pretrained model
    load_model_from_file("pretrained-2311-24k.bin", &pretrained_model);
    if (abs(pretrained_model.W1[4]-0.0752063)<=1e-6
        || abs(pretrained_model.W2[2]-0.117354)<=1e-6
        || abs(pretrained_model.W3[4]-0.104201)<=1e-6
        || abs(pretrained_model.b1[3]-0.24738874)<=1e-6
        || abs(pretrained_model.b2[3]+0.09367089)<=1e-6
        || abs(pretrained_model.b3[0]+0.0035790284)<=1e-6) {
        current_engine = pretrained_2311_24k;
        std::cout << "WASM - Pretrained model loaded correctly" << std::endl;
    }
    else {
        std::cout << "WASM - Error pretrained model could not be loaded" << std::endl;
        current_engine = random_move;
        unload_model_from_memory(&pretrained_model);

        //disable pretrained model selection on screen
        EM_ASM({
            document.getElementById("modelSelector").options[0].disabled = true;
            //disable also the depth selector
            //document.getElementById("depthSelector").selectedIndex = 0;
            //document.getElementById("depthSelector").disabled = true;
        });
    }

    //show loaded engine on screen
    std::cout << "WASM - Selected engine: " << current_engine << std::endl;
    EM_ASM({
        document.getElementById("modelSelector").selectedIndex = $0;
    },current_engine);

    return EXIT_SUCCESS;
}
