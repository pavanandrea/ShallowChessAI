/**********************************************************************
    Web GUI demo to play with ShallowChessAI online

    Author: Andrea Pavan
    License: MIT
**********************************************************************/


//define global variables for the frontend
set_user_dragging(false);
const square_white_color = window.getComputedStyle(document.getElementById("square0")).getPropertyValue("background-color");
const square_black_color = window.getComputedStyle(document.getElementById("square1")).getPropertyValue("background-color");
//const highlight_color_target = window.getComputedStyle(document.getElementById("restartButton")).getPropertyValue("background-color");
const highlight_color_target = "rgb(236, 203, 95)";
const highlight_color_start = "rgb(207, 167, 92)";
const highlight_color_legal = "rgb(124, 136, 54)";
const restart_cpp = Module.cwrap("restart", null, [null]);
const highlight_legal_moves_cpp = Module.cwrap("highlight_legal_moves", null, ["number"]);
const request_move_cpp = Module.cwrap("request_move", null, ["number","number"]);
const request_engine_change_cpp = Module.cwrap("request_engine_change", null, ["number","number"]);
const chess_icons = ["♙", "♘", "♗", "♖", "♕", "♔", "♟", "♞", "♝", "♜", "♛", "♚"];


//highlight a square (for example when dragging a piece)
function highlight_square(square_id, color="default") {
    square = document.getElementById(square_id);
    //console.debug("Highlighting ", square.id);
    if (color == "default") {
        if (square.classList.contains("square-white")) {
            square.style.backgroundColor = square_white_color;
        }
        else {
            square.style.backgroundColor = square_black_color;
        }
    }
    else {
        square.style.background = color;
    }
}

//disable all highlights on the board
function disable_all_highlights() {
    document.querySelectorAll(".square").forEach((square) => {
        highlight_square(square.id, "default");
    });
}

//enable or disable dragging of the pieces
function set_user_dragging(enable=false) {
    document.querySelectorAll("[draggable]").forEach(element => {
        element.setAttribute("draggable", enable);
    });
    //console.debug("Dragging of pieces set to ", enable);
}

//drag and drop event listener for each square (user move)
document.querySelectorAll(".square").forEach((square) => {
    square.addEventListener("dragstart", (e) => {
        //when user is dragging a piece
        //highlight legal moves
        e.dataTransfer.setData("text", square.id);
        disable_all_highlights();
        highlight_square(square.id, highlight_color_start);
        const idx = parseInt(square.id.replace("square",""));
        highlight_legal_moves_cpp(idx);
    });

    square.addEventListener("dragover", (e) => {
        e.preventDefault();
    });

    square.addEventListener("drop", (e) => {
        e.preventDefault();
        const square_start = document.getElementById(e.dataTransfer.getData("text"));
        const square_target = e.target;
        disable_all_highlights();
        if (square_target.id) {
            const idx_start = parseInt(square_start.id.replace("square",""));
            const idx_target = parseInt(square_target.id.replace("square",""));
            request_move_cpp(idx_start, idx_target);
        }
    });
});

//change model selector
document.getElementById("modelSelector").addEventListener("change", () => {
    console.log("Requesting change of model");
    request_engine_change_cpp(document.getElementById("modelSelector").selectedIndex,-1);
});

//change depth
document.getElementById("depthSelector").addEventListener("change", () => {
    console.log("Requesting change of depth");
    request_engine_change_cpp(-1,document.getElementById("depthSelector").selectedIndex);
});

//reset to initial position
document.getElementById("restartButton").addEventListener("click", () => {
    console.log("Restart button clicked");
    document.getElementById("restartButton").value = "Restart";
    restart_cpp();
    //Module.ccall("restart", null, [null]);
});
