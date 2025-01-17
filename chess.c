//---------------------------------------------------------------------
//  ShallowChessAI running on WASM or on a command line
//  Simple minimax algorithm with alpha-beta pruning
//
//  Author: Andrea Pavan
//  License: MIT
//---------------------------------------------------------------------
#include <stdio.h>
#include <stdlib.h>

//BITBOARD FORMAT:
//elements 1-64 - white pawns
//elements 65-128 - white knights
//elements 129-192 - white bishops
//elements 193-256 - white rooks
//elements 257-320 - white queens
//elements 321-384 - white kings
//elements 385-448 - black pawns
//elements 449-512 - black knights
//elements 513-576 - black bishops
//elements 577-640 - black rooks
//elements 641-704 - black queens
//elements 705-783 - black kings
//element 769 - moving player
//elements 770-773 - available castling (KQkq)
//elements 774-775 - kings in check (Kk)
//elements 776-783 - available en-passant for each column


//MOVE INT FORMAT:
//move = 0: no legal move
//move = x1: simple move or capture
//move = 2: en-passant capture to the left
//move = 3: en-passant capture to the right
//move = 54: kingside castling
//move = 55: queenside castling
//move = 6: pawn move two squares
//move = 7: pawn promote
//move = 0x: pawn
//move = 1x: knight
//move = 2x: bishop or queen
//move = 3x: rook or queen
//move = 5x: king


//set bitboard to starting position
void set_starting_position(int (*board)[783]) {
    //clear all
    for (int i=0; i<783; i++) {
        (*board)[i] = 0;
    }

    //add white pawns
    for (int i=49-1; i<56; i++) {
        (*board)[i] = 1;
    }

    //add white knights
    (*board)[1*64+58-1] = 1;
    (*board)[1*64+63-1] = 1;

    //add white bishops
    (*board)[2*64+59-1] = 1;
    (*board)[2*64+62-1] = 1;

    //add white rocks
    (*board)[3*64+57-1] = 1;
    (*board)[3*64+64-1] = 1;

    //add white queen
    (*board)[4*64+60-1] = 1;

    //add white king
    (*board)[5*64+61-1] = 1;

    //add black pawns
    for (int i=6*64+9-1; i<6*64+16; i++) {
        (*board)[i] = 1;
    }

    //add black knights
    (*board)[7*64+2-1] = 1;
    (*board)[7*64+7-1] = 1;

    //add black bishops
    (*board)[8*64+3-1] = 1;
    (*board)[8*64+6-1] = 1;

    //add black rocks
    (*board)[9*64+1-1] = 1;
    (*board)[9*64+8-1] = 1;

    //add black queen
    (*board)[10*64+4-1] = 1;

    //add black king
    (*board)[11*64+5-1] = 1;

    //set moving player
    (*board)[769-1] = 1;

    //reset castling flags
    (*board)[770-1] = 1;
    (*board)[771-1] = 1;
    (*board)[772-1] = 1;
    (*board)[773-1] = 1;
}

//check if a square is empty
//if a piece is present, return 1 if white or -1 if black
int isempty(int (*board)[783], int square) {
    //check for white pieces
    for (int i=0; i<6; i++) {
        if ((*board)[i*64+square]!=0) {
            return 1;
        }
    }

    //check for black pieces
    for (int i=6; i<12; i++) {
        if ((*board)[i*64+square]!=0) {
            return -1;
        }
    }

    //square is empty
    return 0;
}

//check if a square is threatened by a player
bool isthreatened(int (*board)[783], int square, int player) {
    //check white pawns
    if (player==1 && ((square%8>=1 && square<=55 && (*board)[0*64+square+8-1]==1)           //check if there is a white pawn in [row+1,column-1]
                      || (square%8<=6 && square<=55 && (*board)[0*64+square+8+1]==1)) ) {   //check if there is a white pawn in [row+1,column+1]
        return true;
    }

    //check black pawns
    if (player==-1 && ((square%8>=1 && square>=8 && (*board)[6*64+square-8-1]==1)           //check if there is a black pawn in [row-1,column-1]
                       || (square%8<=6 && square>=8 && (*board)[6*64+square-8+1]==1)) ) {   //check if there is a black pawn in [row-1,column+1]
        return true;
    }

    //check knights
    int offset = (player==1) ? 1*64 : 7*64;     //starting index for player knights in the bitboard vector
    if ((square>=16 && square%8>=1 && (*board)[offset+square-16-1]==1)              //check if there is a player knight in [row-2,column-1]
        || (square>=16 && square%8<=6 && (*board)[offset+square-16+1]==1)           //check if there is a player knight in [row-2,column+1]
        || (square>=8 && square%8>=2 && (*board)[offset+square-8-2]==1)             //check if there is a player knight in [row-1,column-2]
        || (square>=8 && square%8<=5 && (*board)[offset+square-8+2]==1)             //check if there is a player knight in [row-1,column+2]
        || (square<=55 && square%8>=2 && (*board)[offset+square+8-2]==1)            //check if there is a player knight in [row+1,column-2]
        || (square<=55 && square%8<=5 && (*board)[offset+square+8+2]==1)            //check if there is a player knight in [row+1,column+2]
        || (square<=47 && square%8>=1 && (*board)[offset+square+16-1]==1)           //check if there is a player knight in [row+2,column-1]
        || (square<=47 && square%8<=6 && (*board)[offset+square+16+1]==1) ) {       //check if there is a player knight in [row+2,column+1]
        return true;
    }

    //check bishops and queens (upper-left diagonal)
    offset += 64;
    int jmax = square%8;
    if (square/8<jmax) {
        jmax = square/8;
    }
    for (int j=1; j<=jmax; j++) {
        if ((*board)[offset+square-8*j-j]==1 || (*board)[offset+2*64+square-8*j-j]==1) {
            return true;
        }
        if (isempty(board,square-8*j-j)!=0) {
            break;
        }
    }

    //check bishops and queens (upper-right diagonal)
    jmax = 7-square%8;
    if (square/8<jmax) {
        jmax = square/8;
    }
    for (int j=1; j<=jmax; j++) {
        if ((*board)[offset+square-8*j+j]==1 || (*board)[offset+2*64+square-8*j+j]==1) {
            return true;
        }
        if (isempty(board,square-8*j+j)!=0) {
            break;
        }
    }

    //check bishops and queens (lower-left diagonal)
    jmax = square%8;
    if (7-square/8<jmax) {
        jmax = 7-square/8;
    }
    for (int j=1; j<=jmax; j++) {
        if ((*board)[offset+square+8*j-j]==1 || (*board)[offset+2*64+square+8*j-j]==1) {
            return true;
        }
        if (isempty(board,square+8*j-j)!=0) {
            break;
        }
    }

    //check bishops and queens (lower-right diagonal)
    jmax = 7-square%8;
    if (7-square/8<jmax) {
        jmax = 7-square/8;
    }
    for (int j=1; j<=jmax; j++) {
        if ((*board)[offset+square+8*j+j]==1 || (*board)[offset+2*64+square+8*j+j]==1) {
            return true;
        }
        if (isempty(board,square+8*j+j)!=0) {
            break;
        }
    }

    //check rocks and queens (upper column)
    offset += 64;
    jmax = square/8;
    for (int j=1; j<=jmax; j++) {
        if ((*board)[offset+square-8*j]==1 || (*board)[offset+1*64+square-8*j]==1) {
            return true;
        }
        if (isempty(board,square-8*j)!=0) {
            break;
        }
    }

    //check rocks and queens (lower column)
    jmax = 7-square/8;
    for (int j=1; j<=jmax; j++) {
        if ((*board)[offset+square+8*j]==1 || (*board)[offset+1*64+square+8*j]==1) {
            return true;
        }
        if (isempty(board,square+8*j)!=0) {
            break;
        }
    }

    //check rocks and queens (left row)
    jmax = square%8;
    for (int j=1; j<=jmax; j++) {
        if ((*board)[offset+square-j]==1 || (*board)[offset+1*64+square-j]==1) {
            return true;
        }
        if (isempty(board,square-j)!=0) {
            break;
        }
    }

    //check rocks and queens (right row)
    jmax = 7-square%8;
    for (int j=1; j<=jmax; j++) {
        if ((*board)[offset+square+j]==1 || (*board)[offset+1*64+square+j]==1) {
            return true;
        }
        if (isempty(board,square+j)!=0) {
            break;
        }
    }

    //check kings
    offset += 2*64;
    if (square>=8 && square%8>=1 && (*board)[offset+square-8-1]==1) {
        return true;
    }
    if (square>=8 && (*board)[offset+square-8]==1) {
        return true;
    }
    if (square>=8 && square%8<=6 && (*board)[offset+square-8+1]==1) {
        return true;
    }
    if (square%8>=1 && (*board)[offset+square-1]==1) {
        return true;
    }
    if (square%8<=6 && (*board)[offset+square+1]==1) {
        return true;
    }
    if (square<=55 && square%8>=1 && (*board)[offset+square+8-1]==1) {
        return true;
    }
    if (square<=55 && (*board)[offset+square+8]==1) {
        return true;
    }
    if (square<=55 && square%8<=6 && (*board)[offset+square+8+1]==1) {
        return true;
    }

    //no threats
    return false;
}

//generate pseudolegal moves for white pawns
void generate_pseudolegal_moves_white_pawns(int (*moves)[64][64], int (*board)[783]) {
    //let i be the square of the pawn
    for (int i=8; i<56; i++) {
        if ((*board)[0*64+i]==1) {
            //check move one square forward
            if (isempty(board,i-8)==0) {
                (*moves)[i][i-8] = 1;
                if (i<16) {
                    //pawn is promoting
                    //note that promotion to knight/bishop/rook is encoded by moving pawn to [1/2/3,target_column]
                    (*moves)[i][i-8] = 7;       //queen
                    (*moves)[i][i+48] = 7;      //rook
                    (*moves)[i][i+40] = 7;      //knight
                    (*moves)[i][i+32] = 7;      //bishop
                }
            }
            //check move two squares forward
            if (i>=48 && isempty(board,i-8)==0 && isempty(board,i-16)==0) {
                (*moves)[i][i-16] = 6;
            }
            //check capture to the right
            if (i%8<=6 && isempty(board,i-8+1)==-1) {
                (*moves)[i][i-8+1] = 1;
                if (i<16) {
                    //pawn is promoting
                    //note that promotion to knight/bishop/rook is encoded by moving pawn to [1/2/3,target_column]
                    (*moves)[i][i-8+1] = 7;     //queen
                    (*moves)[i][i+48+1] = 7;    //rook
                    (*moves)[i][i+40+1] = 7;    //knight
                    (*moves)[i][i+32+1] = 7;    //bishop
                }
            }
            //check capture to the left
            if (i%8>=1 && isempty(board,i-8-1)==-1) {
                (*moves)[i][i-8-1] = 1;
                if (i<16) {
                    //pawn is promoting
                    //note that promotion to knight/bishop/rook is encoded by moving pawn to [1/2/3,target_column]
                    (*moves)[i][i-8-1] = 7;     //queen
                    (*moves)[i][i+48-1] = 7;    //rook
                    (*moves)[i][i+40-1] = 7;    //knight
                    (*moves)[i][i+32-1] = 7;    //bishop
                }
            }
            //check en-passant capture to the left
            if (i>=25 && i<=31 && (*board)[776+(i%8-1)-1]==1 && (*board)[6*64+i-1]==1) {
                (*moves)[i][i-8-1] = 2;
            }
            //check en-passant capture to the right
            if (i>=24 && i<=30 && (*board)[776+(i%8+1)-1]==1 && (*board)[6*64+i+1]==1) {
                (*moves)[i][i-8+1] = 3;
            }
        }
    }
}

//generate pseudolegal moves for black pawns
void generate_pseudolegal_moves_black_pawns(int (*moves)[64][64], int (*board)[783]) {
    //let i be the square of the pawn
    for (int i=8; i<56; i++) {
        if ((*board)[6*64+i]==1) {
            //check move one square forward
            if (isempty(board,i+8)==0) {
                (*moves)[i][i+8] = 1;
                if (i>=48) {
                    //pawn is promoting
                    //note that promotion to knight/bishop/rook is encoded by moving pawn to [8/7/6,target_column]
                    (*moves)[i][i+8] = 7;       //queen
                    (*moves)[i][i-48] = 7;      //rook
                    (*moves)[i][i-40] = 7;      //knight
                    (*moves)[i][i-32] = 7;      //bishop
                }
            }
            //check move two squares forward
            if (i<=15 && isempty(board,i+8)==0 && isempty(board,i+16)==0) {
                (*moves)[i][i+16] = 6;
            }
            //check capture to the right
            if (i%8<=6 && isempty(board,i+8+1)==1) {
                (*moves)[i][i+8+1] = 1;
                if (i>=48) {
                    //pawn is promoting
                    //note that promotion to knight/bishop/rook is encoded by moving pawn to [8/7/6,target_column]
                    (*moves)[i][i+8+1] = 7;     //queen
                    (*moves)[i][i-48+1] = 7;    //rook
                    (*moves)[i][i-40+1] = 7;    //knight
                    (*moves)[i][i-32+1] = 7;    //bishop
                }
            }
            //check capture to the left
            if (i%8>=1 && isempty(board,i+8-1)==1) {
                (*moves)[i][i+8-1] = 1;
                if (i>=48) {
                    //pawn is promoting
                    //note that promotion to knight/bishop/rook is encoded by moving pawn to [8/7/6,target_column]
                    (*moves)[i][i+8-1] = 7;     //queen
                    (*moves)[i][i-48-1] = 7;    //rook
                    (*moves)[i][i-40-1] = 7;    //knight
                    (*moves)[i][i-32-1] = 7;    //bishop
                }
            }
            //check en-passant capture to the left
            if (i>=33 && i<=39 && (*board)[776+(i%8-1)-1]==1 && (*board)[0*64+i-1]==1) {
                (*moves)[i][i+8-1] = 2;
            }
            //check en-passant capture to the right
            if (i>=32 && i<=38 && (*board)[776+(i%8+1)-1]==1 && (*board)[0*64+i+1]==1) {
                (*moves)[i][i+8+1] = 3;
            }
        }
    }
}

//generate pseudolegal moves for knights
void generate_pseudolegal_moves_knights(int (*moves)[64][64], int (*board)[783], int player) {
    //let i be the square of the knight
    for (int i=0; i<64; i++) {
        if ((player==1 && (*board)[1*64+i]==1) || (player==-1 && (*board)[7*64+i]==1)) {
            //check move to [row-2,column-1]
            if (i>=16 && i%8>=1 && isempty(board,i-16-1)!=player) {
                (*moves)[i][i-16-1] = 11;
            }
            //check move to [row-2,column+1]
            if (i>=16 && i%8<=6 && isempty(board,i-16+1)!=player) {
                (*moves)[i][i-16+1] = 11;
            }
            //check move to [row-1,column-2]
            if (i>=8 && i%8>=2 && isempty(board,i-8-2)!=player) {
                (*moves)[i][i-8-2] = 11;
            }
            //check move to [row-1,column+2]
            if (i>=8 && i%8<=5 && isempty(board,i-8+2)!=player) {
                (*moves)[i][i-8+2] = 11;
            }
            //check move to [row+1,column-2]
            if (i<56 && i%8>=2 && isempty(board,i+8-2)!=player) {
                (*moves)[i][i+8-2] = 11;
            }
            //check move to [row+1,column+2]
            if (i<56 && i%8<=5 && isempty(board,i+8+2)!=player) {
                (*moves)[i][i+8+2] = 11;
            }
            //check move to [row+2,column-1]
            if (i<48 && i%8>=1 && isempty(board,i+16-1)!=player) {
                (*moves)[i][i+16-1] = 11;
            }
            //check move to [row+2,column+1]
            if (i<48 && i%8<=6 && isempty(board,i+16+1)!=player) {
                (*moves)[i][i+16+1] = 11;
            }
        }
    }
}

//generate pseudolegal moves for bishops (and queens by diagonal)
void generate_pseudolegal_moves_bishops(int (*moves)[64][64], int (*board)[783], int player) {
    //let i be the square of the bishop/queen
    for (int i=0; i<64; i++) {
        if ((player==1 && ((*board)[2*64+i]==1 || (*board)[4*64+i]==1)) || (player==-1 && ((*board)[8*64+i]==1 || (*board)[10*64+i]==1))) {
            //upper-left diagonal
            int jmax = i%8;
            if (i/8<jmax) {
                jmax = i/8;
            }
            for (int j=1; j<=jmax; j++) {
                if (isempty(board,i-8*j-j)!=player) {
                    (*moves)[i][i-8*j-j] = 21;
                }
                if (isempty(board,i-8*j-j)!=0) {
                    break;
                }
            }

            //upper-right diagonal
            jmax = 7-i%8;
            if (i/8<jmax) {
                jmax = i/8;
            }
            for (int j=1; j<=jmax; j++) {
                if (isempty(board,i-8*j+j)!=player) {
                    (*moves)[i][i-8*j+j] = 21;
                }
                if (isempty(board,i-8*j+j)!=0) {
                    break;
                }
            }

            //lower-left diagonal
            jmax = i%8;
            if (7-i/8<jmax) {
                jmax = 7-i/8;
            }
            for (int j=1; j<=jmax; j++) {
                if (isempty(board,i+8*j-j)!=player) {
                    (*moves)[i][i+8*j-j] = 21;
                }
                if (isempty(board,i+8*j-j)!=0) {
                    break;
                }
            }

            //lower-right diagonal
            jmax = 7-i%8;
            if (7-i/8<jmax) {
                jmax = 7-i/8;
            }
            for (int j=1; j<=jmax; j++) {
                if (isempty(board,i+8*j+j)!=player) {
                    (*moves)[i][i+8*j+j] = 21;
                }
                if (isempty(board,i+8*j+j)!=0) {
                    break;
                }
            }
        }
    }
}

//generate pseudolegal moves for rooks (and queens by row/column)
void generate_pseudolegal_moves_rooks(int (*moves)[64][64], int (*board)[783], int player) {
    //let i be the square of the rook/queen
    for (int i=0; i<64; i++) {
        if ((player==1 && ((*board)[3*64+i]==1 || (*board)[4*64+i]==1)) || (player==-1 && ((*board)[9*64+i]==1 || (*board)[10*64+i]==1))) {
            //upper column
            int jmax = i/8;
            for (int j=1; j<=jmax; j++) {
                if (isempty(board,i-8*j)!=player) {
                    (*moves)[i][i-8*j] = 31;
                }
                if (isempty(board,i-8*j)!=0) {
                    break;
                }
            }

            //lower column
            jmax = 7-i/8;
            for (int j=1; j<=jmax; j++) {
                if (isempty(board,i+8*j)!=player) {
                    (*moves)[i][i+8*j] = 31;
                }
                if (isempty(board,i+8*j)!=0) {
                    break;
                }
            }

            //left row
            jmax = i%8;
            for (int j=1; j<=jmax; j++) {
                if (isempty(board,i-j)!=player) {
                    (*moves)[i][i-j] = 31;
                }
                if (isempty(board,i-j)!=0) {
                    break;
                }
            }

            //right row
            jmax = 7-i%8;
            for (int j=1; j<=jmax; j++) {
                if (isempty(board,i+j)!=player) {
                    (*moves)[i][i+j] = 31;
                }
                if (isempty(board,i+j)!=0) {
                    break;
                }
            }
        }
    }
}

//generate pseudolegal moves for kings
void generate_pseudolegal_moves_kings(int (*moves)[64][64], int (*board)[783], int player) {
    //let i be the square of the king
    for (int i=0; i<64; i++) {
        if ((player==1 && (*board)[5*64+i]==1) || (player==-1 && (*board)[11*64+i]==1)) {
            if (i>=8 && i%8>=1 && isempty(board,i-8-1)!=player) {
                (*moves)[i][i-8-1] = 51;
            }
            if (i>=8 && isempty(board,i-8)!=player) {
                (*moves)[i][i-8] = 51;
            }
            if (i>=8 && i%8<=6 && isempty(board,i-8+1)!=player) {
                (*moves)[i][i-8+1] = 51;
            }
            if (i%8>=1 && isempty(board,i-1)!=player) {
                (*moves)[i][i-1] = 51;
            }
            if (i%8<=6 && isempty(board,i+1)!=player) {
                (*moves)[i][i+1] = 51;
            }
            if (i<=55 && i%8>=1 && isempty(board,i+8-1)!=player) {
                (*moves)[i][i+8-1] = 51;
            }
            if (i<=55 && isempty(board,i+8)!=player) {
                (*moves)[i][i+8] = 51;
            }
            if (i<=55 && i%8<=6 && isempty(board,i+8+1)!=player) {
                (*moves)[i][i+8+1] = 51;
            }
            break;
        }
    }

    //castling
    if (player==1 && (*board)[770-1]==1 && (*board)[5*64+60]==1 && (*board)[3*64+63]==1 && isempty(board,61)==0 && isempty(board,62)==0 && !isthreatened(board,60,-1) && !isthreatened(board,61,-1) && !isthreatened(board,62,-1)) {
        //white kingside
        (*moves)[60][62] = 54;
    }
    if (player==1 && (*board)[771-1]==1 && (*board)[5*64+60]==1 && (*board)[3*64+56]==1 && isempty(board,58)==0 && isempty(board,59)==0 && !isthreatened(board,58,-1) && !isthreatened(board,59,-1) && !isthreatened(board,60,-1)) {
        //white queenside
        (*moves)[60][58] = 55;
    }
    if (player==-1 && (*board)[772-1]==1 && (*board)[11*64+4]==1 && (*board)[9*64+7]==1 && isempty(board,5)==0 && isempty(board,6)==0 && !isthreatened(board,4,1) && !isthreatened(board,5,1) && !isthreatened(board,6,1)) {
        //black kingside
        (*moves)[4][6] = 54;
    }
    if (player==-1 && (*board)[773-1]==1 && (*board)[11*64+4]==1 && (*board)[9*64+0]==1 && isempty(board,1)==0 && isempty(board,2)==0 && isempty(board,3)==0 && !isthreatened(board,2,1) && !isthreatened(board,3,1) && !isthreatened(board,4,1)) {
        //black queenside
        (*moves)[4][2] = 55;
    }
}

//generate pseudolegal moves
void generate_pseudolegal_moves(int (*moves)[64][64], int (*board)[783]) {
    //clear all
    for (int i=0; i<64; i++) {
        for (int j=0; j<64; j++) {
            (*moves)[i][j] = 0;
        }
    }

    //generate moves for each piece
    //const int player = ((*board)[769-1]==1) ? 1 : -1;
    const int player = 2*((*board)[769-1])-1;
    if (player==1) {
        //white is moving
        generate_pseudolegal_moves_white_pawns(moves, board);
    }
    else {
        //black is moving
        generate_pseudolegal_moves_black_pawns(moves, board);
    }
    generate_pseudolegal_moves_knights(moves, board, player);
    generate_pseudolegal_moves_bishops(moves, board, player);
    generate_pseudolegal_moves_rooks(moves, board, player);
    generate_pseudolegal_moves_kings(moves, board, player);
}

//make move (without any check)
void make_move(int (*board)[783], int square_start, int square_target, int move) {
    //note: to avoid recomputing all the checks done in move generation, the move variable encode a particular meaning
    if (move%10==1) {
        //simple move or capture
        for (int i=0; i<12; i++) {
            (*board)[i*64+square_target] = (*board)[i*64+square_start];
            (*board)[i*64+square_start] = 0;
        }
    }
    else if (move==6) {
        //pawn moves two squares
        //note: if promotions were forced to queen, this block could be always executed safely and it could be moved outside the if blocks
        (*board)[0*64+square_target] = (*board)[0*64+square_start];
        (*board)[6*64+square_target] = (*board)[6*64+square_start];
        (*board)[0*64+square_start] = 0;
        (*board)[6*64+square_start] = 0;
    }
    else if (move==54) {
        if ((*board)[769-1]==1) {
            //white king castling kingside
            (*board)[5*64+square_target] = 1;
            (*board)[5*64+square_start] = 0;
            (*board)[3*64+square_target-1] = 1;
            (*board)[3*64+square_target+1] = 0;
            (*board)[770-1] = 0;
            (*board)[771-1] = 0;
        }
        else {
            //black king castling kingside
            (*board)[11*64+square_target] = 1;
            (*board)[11*64+square_start] = 0;
            (*board)[9*64+square_target-1] = 1;
            (*board)[9*64+square_target+1] = 0;
            (*board)[772-1] = 0;
            (*board)[773-1] = 0;
        }
    }
    else if (move==55) {
        if ((*board)[769-1]==1) {
            //white king castling queenside
            (*board)[5*64+square_target] = 1;
            (*board)[5*64+square_start] = 0;
            (*board)[3*64+square_target+1] = 1;
            (*board)[3*64+square_target-2] = 0;
            (*board)[770-1] = 0;
            (*board)[771-1] = 0;
        }
        else {
            //black king castling queenside
            (*board)[11*64+square_target] = 1;
            (*board)[11*64+square_start] = 0;
            (*board)[9*64+square_target+1] = 1;
            (*board)[9*64+square_target-2] = 0;
            (*board)[772-1] = 0;
            (*board)[773-1] = 0;
        }
    }
    else if (move==7) {
        //pawn promoting
        if ((*board)[769-1]) {
            //white is moving
            const int real_target = square_target%8;
            if (square_target<=7) {
                //promote to queen
                (*board)[4*64+square_target] = 1;
            }
            else if (square_target>=56) {
                //promote to rook
                (*board)[3*64+real_target] = 1;
            }
            else if (square_target>=48) {
                //promote to knight
                (*board)[1*64+real_target] = 1;
            }
            else if (square_target>=40) {
                //promote to bishop
                (*board)[2*64+real_target] = 1;
            }

            //clear target square
            for (int i=6; i<=11; i++) {
                (*board)[i*64+real_target] = 0;
            }
        }
        else {
            //black is moving
            const int real_target = 56+square_target%8;
            if (square_target>=56) {
                //promote to queen
                (*board)[10*64+square_target] = 1;
            }
            else if (square_target<=7) {
                //promote to rook
                (*board)[9*64+real_target] = 1;
            }
            else if (square_target<=15) {
                //promote to knight
                (*board)[7*64+real_target] = 1;
            }
            else if (square_target<=23) {
                //promote to bishop
                (*board)[8*64+real_target] = 1;
            }

            //clear target square
            for (int i=0; i<=5; i++) {
                (*board)[i*64+real_target] = 0;
            }
        }
        (*board)[0*64+square_start] = 0;
        (*board)[6*64+square_start] = 0;
    }
    else if (move==2) {
        //en-passant capture to the left
        (*board)[0*64+square_target] = (*board)[0*64+square_start];
        (*board)[6*64+square_target] = (*board)[6*64+square_start];
        (*board)[0*64+square_start] = 0;
        (*board)[6*64+square_start] = 0;
        (*board)[0*64+square_start-1] = 0;
        (*board)[6*64+square_start-1] = 0;
    }
    else if (move==3) {
        //en-passant capture to the right
        (*board)[0*64+square_target] = (*board)[0*64+square_start];
        (*board)[6*64+square_target] = (*board)[6*64+square_start];
        (*board)[0*64+square_start] = 0;
        (*board)[6*64+square_start] = 0;
        (*board)[0*64+square_start+1] = 0;
        (*board)[6*64+square_start+1] = 0;
    }
    
    //if rook or king are moved or targeted, set castling bit to zero
    if ((*board)[770-1]==1 && (square_target==63 || square_start==63 || square_target==60 || square_start==60)) {
        (*board)[770-1] = 0;
    }
    if ((*board)[771-1]==1 && (square_target==56 || square_start==56 || square_target==60 || square_start==60)) {
        (*board)[771-1] = 0;
    }
    if ((*board)[772-1]==1 && (square_target==7 || square_start==7 || square_target==4 || square_start==4)) {
        (*board)[772-1] = 0;
    }
    if ((*board)[773-1]==1 && (square_target==0 || square_start==0 || square_target==4 || square_start==4)) {
        (*board)[773-1] = 0;
    }

    //reset en-passant flags
    (*board)[776-1] = 0;
    (*board)[777-1] = 0;
    (*board)[778-1] = 0;
    (*board)[779-1] = 0;
    (*board)[780-1] = 0;
    (*board)[781-1] = 0;
    (*board)[782-1] = 0;
    (*board)[783-1] = 0;
    if (move==6) {
        //set flag on the column where a pawn has moved two squares
        (*board)[776+(square_target%8)-1] = 1;
    }

    //set moving player
    (*board)[769-1] = !(*board)[769-1];
}

//find position of the king
int find_king_square(int (*board)[783], int player) {
    if (player==1) {
        for (int i=0; i<64; i++) {
            if ((*board)[5*64+i]==1) {
                return i;
            }
        }
    }
    else {
        for (int i=0; i<64; i++) {
            if ((*board)[11*64+i]==1) {
                return i;
            }
        }
    }
    return -1;
}

//check if the king of the player is in check
bool ischecked(int (*board)[783], int player) {
    return isthreatened(board, find_king_square(board,player), -player);
}

//converts a FEN string to bitboard
//see: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation
//WARNING: safety checks on user input are not implemented yet
void set_position_from_fen(int (*board)[783], const char (*fenstring)) {
    //clear all
    for (int i=0; i<783; i++) {
        (*board)[i] = 0;
    }

    //parse first field: piece placement
    const char *current_character = fenstring;
    int current_square = 0;
    const char chess_pieces[] = {'P', 'N', 'B', 'R', 'Q', 'K', 'p', 'n', 'b', 'r', 'q', 'k'};
    while ((*current_character)!=' ') {
        if ((*current_character)=='\0') {
            return;
        }
        if ((*current_character)>='1' && (*current_character)<='8') {
            //skip empty squares
            current_square += ((*current_character) - '0');
        }
        else if ((*current_character)!='/') {
            //insert piece
            //slash characters can be ignored
            for (int j=0; j<12; j++) {
                if ((*current_character)==chess_pieces[j]) {
                    (*board)[j*64+current_square] = 1;
                    current_square++;
                    break;
                }
            }
        }
        current_character++;    //move pointer to the next character
    }

    //parse second field: moving player
    current_character++;
    if ((*current_character)=='w') {
        (*board)[769-1] = 1;
    }
    current_character += 2;

    //parse third field: castling
    while ((*current_character)!=' ') {
        if ((*current_character)=='\0') {
            return;
        }
        if ((*current_character)=='K') {
            (*board)[770-1] = 1;
        }
        else if ((*current_character)=='Q') {
            (*board)[771-1] = 1;
        }
        else if ((*current_character)=='k') {
            (*board)[772-1] = 1;
        }
        else if ((*current_character)=='q') {
            (*board)[773-1] = 1;
        }
        current_character++;    //move pointer to the next character
    }
    current_character += 1;

    //check if white king or black king are in check
    //if (isthreatened(board,find_king_square(board,1),1)) {
    if (ischecked(board, 1)) {
        (*board)[774-1] = 1;
    }
    //if (isthreatened(board,find_king_square(board,-1),-1)) {
    if (ischecked(board, -1)) {
        (*board)[775-1] = 1;
    }

    //parse fourth field: en-passant
    if ((*current_character)!='-') {
        const char columns[] = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'};
        for (int j=0; j<8; j++) {
            if ((*current_character)==columns[j]) {
                (*board)[776+j-1] = 1;
                break;
            }
        }
    }

    //ignore fifth field: number of halfmoves since the last capture or pawn advance
    //ignore sixth field: number of moves played by the black
}

//duplicate board
void duplicate_board(int (*childboard)[783], int (*board)[783]) {
    for (int i=0; i<783; i++) {
        (*childboard)[i] = (*board)[i];
    }
    return;
}

//generate legal moves
void generate_legal_moves(int (*moves)[64][64], int (*board)[783]) {
    generate_pseudolegal_moves(moves, board);
    int childboard[783];
    //int kingsquare = -1;
    //const int player = ((*board)[769-1]==1) ? 1 : -1;
    const int player = 2*((*board)[769-1])-1;
    for (int i=0; i<64; i++) {
        for (int j=0; j<64; j++) {
            if ((*moves)[i][j]!=0) {
                //check if move [i,j] is legal
                //memcpy(&childboard, board, 783*sizeof(int));
                duplicate_board(&childboard, board);
                make_move(&childboard, i, j, (*moves)[i][j]);
                //kingsquare = find_king_square(&childboard, player);
                //if (isthreatened(&childboard, kingsquare, -player)) {
                if (ischecked(&childboard, player)) {
                    //king can be captured, the move is illegal
                    (*moves)[i][j] = 0;
                }
            }
        }
    }
}

//count the number of legal moves
int count_legal_moves(int (*moves)[64][64]) {
    int counter = 0;
    for (int i=0; i<64; i++) {
        for (int j=0; j<64; j++) {
            if ((*moves)[i][j]!=0) {
                counter++;
            }
        }
    }
    return counter;
}

//count the number of legal moves at a given depth
int perft(int (*board)[783], int depth=0, bool print_uci_output=false) {
    int moves[64][64];
    generate_legal_moves(&moves, board);
    if (depth==0) {
        return count_legal_moves(&moves);
    }
    int counter = 0;
    int childboard[783];
    for (int i=0; i<64; i++) {
        for (int j=0; j<64; j++) {
            if (moves[i][j]!=0) {
                //memcpy(&childboard, board, 783*sizeof(int));
                duplicate_board(&childboard, board);
                make_move(&childboard, i, j, moves[i][j]);
                //counter += perft(&childboard, depth-1);

                int current_move_counter = perft(&childboard, depth-1);
                if (print_uci_output) {
                    //output the perft result in the Stockfish format
                    const char columns[] = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'};
                    printf("%c%i%c%i: %i\n", columns[i%8], 8-i/8, columns[j%8], 8-j/8, current_move_counter);
                }
                counter += current_move_counter;
            }
        }
    }
    
    if (print_uci_output) {
        printf("Nodes searched: %i\n", counter);
    }
    return counter;
}

//check if the game is over
bool isgameover(int (*moves)[64][64]) {
    int number_of_legal_moves = count_legal_moves(moves);
    if (number_of_legal_moves==0) {
        return true;
    }
    return false;
}

//define a data structure for engine moves, inglobating a score for the target position
//this is especially useful for search algorithms
typedef struct {
    int start;
    int target;
    int score;
} enginemove;

//play random move
enginemove play_random_move(int (*moves)[64][64], int (*board)[783]) {
    //initialize variables
    enginemove output_move = {0, 0, 0};
    //srand(42)
    //srand(time(NULL));

    //check legal moves
    int number_of_legal_moves = count_legal_moves(moves);
    if (number_of_legal_moves==0) {
        return output_move;
    }

    //pick a random move
    int random_move_idx = rand()%number_of_legal_moves;
    int counter = 0;
    for (int i=0; i<64; i++) {
        for (int j=0; j<64; j++) {
            if ((*moves)[i][j]!=0) {
                counter++;
            }
            if (counter==random_move_idx+1) {
                //make_move(board, i, j, (*moves)[i][j]);
                output_move.start = i;
                output_move.target = j;
                return output_move;
            }
        }
    }
    return output_move;
}
