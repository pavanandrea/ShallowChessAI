//---------------------------------------------------------------------
//  Load and run the pretrained models in pure C without dependencies
//
//
//  Author: Andrea Pavan
//  License: MIT
//---------------------------------------------------------------------
#include <stdio.h>
#include <stdlib.h>
#include <math.h>


//Define the structure of the pretrained 24k model:
//      Chain(
//          Dense(783 => 30, tanh),               # 23_520 parameters
//          Dense(30 => 30, tanh),                # 930 parameters
//          Dense(30 => 1, tanh),                 # 31 parameters
//      )                   # Total: 6 arrays, 24_481 parameters, 95.934 KiB.
typedef struct {
    float* W1;          //30x783 float32 matrix
    float* b1;          //30-element float32 vector
    float sigma1;       //float32 flag (1=tanh, 2=sigmoid, 3=relu, 4=leakyrelu)
    float* W2;          //30x30 float32 matrix
    float* b2;          //30-element float32 vector
    float sigma2;       //float32 flag (1=tanh, 2=sigmoid, 3=relu, 4=leakyrelu)
    float* W3;          //1x30 float32 matrix
    float* b3;          //30-element float32 vector
    float sigma3;       //float32 flag (1=tanh, 2=sigmoid, 3=relu, 4=leakyrelu)
} neuralnetwork;


//load weights and biases from BIN file
void load_model_from_file(const char* filename, neuralnetwork* model) {
    FILE* fileio = fopen(filename, "rb");
    if (!fileio) {
        printf("ERROR while opening file");
        return;
    }

    //check number of elements
    //for the 24k model it should be 24490 in total:
    //- 24481 parameters
    //- each layer has 3 additional elements (number of rows, number of colums and a flag for the activation function)
    //- the model has 3 layers
    fseek(fileio, 0, SEEK_END);
    long filesize = ftell(fileio);
    fseek(fileio, 0, SEEK_SET);
    int nelems = filesize/sizeof(float);
    //printf("Number of elements: %i\n",nelems);
    if (nelems!=24481+3*3) {
        printf("ERROR unrecognized model");
        return;
    }

    //allocate memory for weights and biases
    float* file_content = (float*) malloc(filesize);
    if (!file_content) {
        printf("ERROR failed to allocate memory");
        fclose(fileio);
        return;
    }

    //read file into the file_content array
    //BIN file format:
    //* single array of type Float32 (4 bytes for each element)
    //* first element is the number of rows of the weight matrix (layer 1)
    //* second element is the number of columns of the weight matrix (layer 1)
    //* third element is an identifier for the nonlinear activation function (layer 1)
    //* weights ordered by column (layer 1)
    //* biases (layer 1)
    //* number of rows of the weight matrix (layer 2)
    //* [repeat...]
    //* activation functions are encoded as follows: 1=tanh, 2=sigmoid, 3=relu, 4=leakyrelu
    fread(file_content, sizeof(float), nelems, fileio);
    fclose(fileio);

    //assign weights and biases according to the BIN file format
    model->sigma1 = file_content[3-1];
    model->W1 = &file_content[4-1];
    model->b1 = &file_content[4+783*30-1];
    model->sigma2 = file_content[4+783*30+30+2-1];
    model->W2 = &file_content[4+783*30+30+3-1];
    model->b2 = &file_content[4+783*30+30+3+30*30-1];
    model->sigma3 = file_content[4+783*30+30+3+30*30+30+2-1];
    model->W3 = &file_content[4+783*30+30+3+30*30+30+3-1];
    model->b3 = &file_content[4+783*30+30+3+30*30+30+3+30-1];
    return;
}

//free allocated memory
void unload_model_from_memory(neuralnetwork* model) {
    free(model->W1-3);
    return;
}

//perform inference
float forward_pass(neuralnetwork* model, int (*board)[783]) {
    //first layer
    float a1[30] = {0};
    for (int j=0; j<783; j++) {
        for (int i=0; i<30; i++) {
            if ((*board)[j]) {
                a1[i] += model->W1[30*j+i];
            }
        }
    }
    //printf("a1[0]=%f, a1[1]=%f, ..., a1[29]=%f\n", a1[0], a1[1], a1[29]);
    //Julia output (starting position): -0.105476685, -2.2275052, ... -1.1540238
    for (int i=0; i<30; i++) {
        a1[i] += model->b1[i];
        a1[i] = tanh(a1[i]);
    }
    //printf("a1[0]=%f, a1[1]=%f, ..., a1[29]=%f\n", a1[0], a1[1], a1[29]);
    //Julia output (starting position): 0.04751504, -0.9775075, ... -0.8468012

    //second layer
    float a2[30] = {0};
    for (int j=0; j<30; j++) {
        for (int i=0; i<30; i++) {
            a2[i] += (model->W2[30*j+i])*a1[j];
        }
    }
    for (int i=0; i<30; i++) {
        a2[i] += model->b2[i];
        a2[i] = tanh(a2[i]);
    }
    //printf("a2[0]=%f, a2[1]=%f, ..., a2[29]=%f\n", a2[0], a2[1], a2[29]);
    //Julia output (starting position): -0.7640187, -0.74702287, ... -0.8845295

    //third layer
    float a3 = 0;
    for (int i=0; i<30; i++) {
        a3 += (model->W3[i])*a2[i];
    }
    a3 += model->b3[0];
    a3 = tanh(a3);
    //printf("a3=%f\n",a3);
    //Julia output (starting position): 0.28675386
    return a3;
}

//calculate the score of the position in centipawns
int score(neuralnetwork* model, int (*board)[783]) {
    float model_output = forward_pass(model, board);
    return (int)floor(1500*pow(model_output,3));
}

//play the move that leads to the maximum score, without search
//the output is an int vector with 3 elements: starting square, target square, score
enginemove move_without_search(neuralnetwork* model, int (*moves)[64][64], int (*board)[783]) {
    //initialize variables
    const int player = 2*((*board)[769-1])-1;
    int best_score = -10000*player;
    int current_score = -10001*player;
    enginemove output_move = {0, 0, best_score};
    //const char columns[] = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'};

    //evaluate legal moves
    int number_of_legal_moves = count_legal_moves(moves);
    if (number_of_legal_moves==0) {
        return output_move;
    }
    int childboard[783];
    for (int i=0; i<64; i++) {
        for (int j=0; j<64; j++) {
            if ((*moves)[i][j]!=0) {
                duplicate_board(&childboard, board);
                make_move(&childboard, i, j, (*moves)[i][j]);
                current_score = score(model, &childboard);
                //printf("Score %c%i%c%i: %i\n", columns[i%8], 8-i/8, columns[j%8], 8-j/8, current_score);

                //compare with best move so far
                if (current_score*player > best_score*player) {
                    best_score = current_score;
                    output_move.start = i;
                    output_move.target = j;
                    output_move.score = best_score;
                    //printf("New best move: %c%i%c%i (%i)\n", columns[i%8], 8-i/8, columns[j%8], 8-j/8, current_score);
                }
            }
        }
    }
    //make_move(board, output_move[0], output_move[1], (*moves)[output_move[0]][output_move[1]]);
    return output_move;
}

//play the move that leads to the maximum score, with a search limited by a given depth
//the implemented algorithm is a simple minimax with alpha-beta pruning
//the output is an int vector with 3 elements: starting square, target square, score
enginemove minimax(neuralnetwork* model, int (*moves)[64][64], int (*board)[783], int depth, int alpha=-10000, int beta=10000) {
    //initialize variables
    const int player = 2*((*board)[769-1])-1;
    int best_score = -10000*player;
    enginemove minimax_output = {0, 0, best_score};
    bool break_outer = false;
    const char columns[] = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'};

    //return best move if no further search is allowed
    if (depth==0) {
        minimax_output.score = score(model, board);
        return minimax_output;
        //return play_without_search(model, moves, board);
    }

    //evaluate legal moves
    if (count_legal_moves(moves)==0) {
        minimax_output.score = score(model, board);
        return minimax_output;
    }
    int childboard[783];
    int childmoves[64][64];
    for (int i=0; i<64; i++) {
        for (int j=0; j<64; j++) {
            if ((*moves)[i][j]!=0) {
                //evaluate the move [i,j] by calling minimax recursively
                duplicate_board(&childboard, board);
                make_move(&childboard, i, j, (*moves)[i][j]);
                generate_legal_moves(&childmoves, &childboard);
                enginemove child_move = minimax(model, &childmoves, &childboard, depth-1, alpha, beta);
                //if (depth==2) {
                //    printf("Child Move %c%i%c%i: %i\n", columns[i%8], 8-i/8, columns[j%8], 8-j/8, child_move.score);
                //}

                //compare with best move so far
                if (child_move.score*player > best_score*player) {
                    best_score = child_move.score;
                    minimax_output.start = i;
                    minimax_output.target = j;
                    minimax_output.score = best_score;
                }

                //alpha-beta pruning
                if ((player==1 && best_score>beta) || (player==-1 && best_score<alpha)) {
                    //stop evaluating other moves from this branch
                    break_outer = true;
                    break;
                }

                //update the values of alpha and beta
                if (player==1 && best_score>alpha) {
                    alpha = best_score;
                }
                else if (player==-1 && best_score<beta) {
                    beta = best_score;
                }
            }
        }
        if (break_outer) {
            break;
        }
    }
    //make_move(board, minimax_output[0], minimax_output[1], (*moves)[minimax_output[0]][minimax_output[1]]);
    return minimax_output;
}
