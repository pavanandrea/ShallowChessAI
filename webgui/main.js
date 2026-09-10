//------------------------------------------------------------------------------
//  Web GUI demo - ShallowChessAI online
//
//  Author: Andrea Pavan
//  License: MIT
//------------------------------------------------------------------------------
import * as ort from "./third_party/onnxruntime-web/ort.min.mjs";

//UI constants
const square_white_color = window.getComputedStyle(document.getElementById("square0")).getPropertyValue("background-color");
const square_black_color = window.getComputedStyle(document.getElementById("square1")).getPropertyValue("background-color");
const HIGHLIGHT_COLOR_TARGET = "rgb(236, 203, 95)";
const HIGHLIGHT_COLOR_START  = "rgb(207, 167, 92)";
const HIGHLIGHT_COLOR_LEGAL  = "rgb(124, 136, 54)";
const CHESS_ICONS = ["♙","♘","♗","♖","♕","♔", "♟","♞","♝","♜","♛","♚"];

//WASM handles (filled after the Promise resolves)
let Module = null;
let restart_c, make_user_move_c, make_computer_move_c;
let is_game_over_c, is_white_moving_c, get_castling_c;
let get_legal_targets_c;
let get_last_move_start_c, get_last_move_target_c, get_last_move_flags_c;
let get_board_byte_c, get_legal_target_byte_c;
let set_engine_c, set_depth_c;
let set_fen_c;
let score2centipawn_c;

//ONNX session (filled after the model loads)
let onnx_session = null;

//DOM helpers
function highlight_square(id, color) {
    const square = document.getElementById(id);
    if (!square) {
        return;
    }
    if (!color) {
        square.style.backgroundColor = square.classList.contains("square-white") ? square_white_color : square_black_color;
    }
    else {
        square.style.background = color;
    }
}
function clear_highlights() {
    document.querySelectorAll(".square").forEach(s => highlight_square(s.id, null));
}
function set_draggable(enable) {
    document.querySelectorAll("[draggable]").forEach(el => el.setAttribute("draggable", enable));
}

//render board by reading each byte through cwrap
function render_board() {
    clear_highlights();
    document.querySelectorAll(".square").forEach(s => { s.innerHTML = ""; });

    for (let i=0; i<64; i++) {
        const piece = get_board_byte_c(i);
        if (piece === 0xFF) {
            //empty
            continue;
        }
        const isWhite = piece < 6;
        const el = document.getElementById("square" + i);
        el.innerHTML = isWhite
            ? `<div draggable="true">${CHESS_ICONS[piece]}</div>`
            : CHESS_ICONS[piece];
    }

    //castling label
    const c = get_castling_c();
    document.getElementById("castlingLabel").innerHTML =
        "Castling options: " +
        (c & 1 ? "K" : "-") + (c & 2 ? "Q" : "-") +
        (c & 4 ? "k" : "-") + (c & 8 ? "q" : "-");
}

//highlight moves
function highlight_last_move() {
    const s = get_last_move_start_c();
    const t = get_last_move_target_c();
    if (s >= 0) highlight_square("square" + s, HIGHLIGHT_COLOR_START);
    if (t >= 0) highlight_square("square" + t, HIGHLIGHT_COLOR_TARGET);
}
function highlight_legal_moves(start_square) {
    const count = get_legal_targets_c(start_square);
    for (let i = 0; i < count; i++) {
        const target = get_legal_target_byte_c(i);
        highlight_square("square" + target, HIGHLIGHT_COLOR_LEGAL);
    }
}

//handle game over
function check_game_over() {
    if (!is_game_over_c()) {
        return false;
    }
    clear_highlights();
    set_draggable(false);
    setTimeout(() => alert("Well played! The game is over."), 50);
    return true;
}

//handle player and computer moves
function on_user_dropped(start_square, target_square) {
    const ok = make_user_move_c(start_square, target_square);
    if (ok !== 0) {
        //console.warn(`Invalid move: ${start_square} → ${target_square}`);
        return;
    }
    render_board();
    setTimeout(highlight_last_move, 50);
    set_draggable(true);

    if (!is_white_moving_c()) {
        setTimeout(() => on_computer_turn().catch(err => {
            console.error("[Computer move failed]", err);
            set_draggable(true);          //re-enable so the player is not locked out
        }), 50);
    }
}
async function on_computer_turn() {
    set_draggable(false);
    const rc = await make_computer_move_c();
    if (rc === 0) {
        setTimeout(() => {
            render_board();
            highlight_last_move();
        }, 50);
        set_draggable(true);
    }
    check_game_over();
}


//change engine or depth
function applyEngineSettings() {
    const model = document.getElementById("modelSelector").value;
    const depth = parseInt(document.getElementById("depthSelector").value);

    let engine = 0;
    if (model === "random_move") {
        engine = 0;
    }
    else if (model === "minimax_material") {
        engine = 1;
    }
    else if (model === "shallowchessai_v2609_43k") {
        engine = 2;
    }

    set_engine_c(engine);
    set_depth_c(Number.isFinite(depth) ? depth : 2);

    console.log("Engine settings\nmodel =", model, "\ndepth =", depth);
}

//load ONNX model
async function initialize_onnx_model(modelUrl="./models/shallowchessai_v2609_43k.onnx") {
    if (onnx_session) {
        //already loaded
        return;
    }

    ort.env.wasm.numThreads = 1;
    onnx_session = await ort.InferenceSession.create(modelUrl, {
        executionProviders: ["wasm"],
    });
    console.log("[ONNX] Model loaded: " + modelUrl);
}

//run ONNX model
async function run_onnx_model(features) {
    if (!onnx_session) {
        throw new Error("run_onnx_model: model not ready. Call initialize_onnx_model() first.");
    }

    const flat = (features instanceof Float32Array)
        ? features
        : new Float32Array(features);

    if (flat.length !== 783) {
        throw new Error("run_onnx_model: expected 783 features, got " + flat.length);
    }

    const tensor = new ort.Tensor("float32", flat, [1, 783]);
    const result = await onnx_session.run({ x: tensor });
    return result.score.data[0];
}

//initialize WASM
ChessWasm().then(function (mod) {
    //wrap C functions
    Module = mod;
    restart_c = Module.cwrap("restart", null, []);
    make_user_move_c = Module.cwrap("make_user_move", "number", ["number","number"]);
    make_computer_move_c = Module.cwrap("make_computer_move", "number", []);
    is_game_over_c = Module.cwrap("is_game_over", "number", []);
    is_white_moving_c = Module.cwrap("is_white_moving", "number", []);
    get_castling_c = Module.cwrap("get_castling", "number", []);
    get_legal_targets_c = Module.cwrap("get_legal_targets", "number", ["number"]);
    get_last_move_start_c = Module.cwrap("get_last_move_start", "number", []);
    get_last_move_target_c = Module.cwrap("get_last_move_target", "number", []);
    get_last_move_flags_c = Module.cwrap("get_last_move_flags", "number", []);
    get_board_byte_c = Module.cwrap("get_board_byte", "number", ["number"]);
    get_legal_target_byte_c = Module.cwrap("get_legal_target_byte","number", ["number"]);
    set_engine_c = Module.cwrap("set_engine", null, ["number"]);
    set_depth_c = Module.cwrap("set_depth", null, ["number"]);
    set_fen_c = Module.cwrap("set_fen_position", "number", ["string"]);
    score2centipawn_c = Module.cwrap("score2centipawn", "number", ["number"]);

    
    //expose a helper for console debugging
    window.Module = Module;
    window.run_onnx_model = run_onnx_model;

    //load ONNX model in the background
    initialize_onnx_model().catch(err => {
        console.error("[ONNX] Failed to load model:", err);
    });

    //drag & drop
    document.querySelectorAll(".square").forEach(square => {
        square.addEventListener("dragstart", e => {
            e.dataTransfer.setData("text", square.id);
            clear_highlights();
            highlight_square(square.id, HIGHLIGHT_COLOR_START);
            highlight_legal_moves(parseInt(square.id.replace("square", "")));
        });

        square.addEventListener("dragover", e => e.preventDefault());

        square.addEventListener("drop", e => {
            e.preventDefault();
            const src = document.getElementById(e.dataTransfer.getData("text"));
            const dst = e.target.closest(".square");
            if (!src || !dst) return;
            clear_highlights();
            on_user_dropped(
                parseInt(src.id.replace("square", "")),
                parseInt(dst.id.replace("square", ""))
            );
        });
    });

    //model and depth selectors
    document.getElementById("modelSelector").addEventListener("change", applyEngineSettings);
    document.getElementById("depthSelector").addEventListener("change", applyEngineSettings);

    //restart button
    document.getElementById("restartButton").addEventListener("click", () => {
        restart_c();
        render_board();
        set_draggable(true);
    });

    //allow to set FEN position from the console
    window.setFEN = function (fen) {
        const rc = set_fen_c(fen);
        if (rc !== 0) {
            return "bad FEN";
        }
        render_board();
        return "ok";
    };

    //allow to evaluate current position from the console using the ONNX model
    window.getBoardFeatures = function () {
        const ptr = Module.cwrap("get_board_features", "number", [])();
        const src = new Float32Array(Module.HEAPF32.buffer, ptr, 783);
        return new Float32Array(src);
    };
    window.onnxScore = async function (fen) {
        if (fen) {
            const rc = set_fen_c(fen);
            if (rc !== 0) {
                throw new Error("Invalid FEN");
            }
        }

        const features = window.getBoardFeatures();
        const score = await window.runOnnxModel(features);
        const cp = score2centipawn_c(score);
        console.log(`ONNX score: ${score.toFixed(6)} (cp=${cp})`);
        return score;
    };

    //initial render (restart() was already called in main())
    applyEngineSettings();
    render_board();
});
