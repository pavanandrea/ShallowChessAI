#!/usr/bin/env python3
"""
Train the residual MLP.
Designed for AMD Radeon R9700 (32 GB VRAM) with ROCm.
Streams data in chunks from an mmap'd .npy file - peak RAM ≈ one converted chunk.
All computation in FP32 (parameters, activations, inputs, outputs).

Usage:
    python 02_train.py \
             --train data_2609_train.npy \
             --val data_2609_validation.npy \
             --epochs 50 \
             --lr 3e-4 \
             --batch-size 16384 \
             --chunk-size 262144 \
             --val-every 250 \
             --out-dir checkpoints

Dependencies:
    pip install numpy torch tqdm matplotlib
"""
from __future__ import annotations
import argparse
import csv
import math
import os
import queue
import signal
import sys
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional
from tqdm import tqdm
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.optim import AdamW
from torch.optim.lr_scheduler import LambdaLR
import matplotlib
matplotlib.use("Agg")   # headless / no display
import matplotlib.pyplot as plt


# ══════════════════════════════════════════════════════════════════════════════
#  Model
# ══════════════════════════════════════════════════════════════════════════════

class HiddenLayer(nn.Module):
    """One hidden layer with a residual (skip) connection.

        x ──► Linear ──► LayerNorm ──► ReLU ───┐
        │                                      ├──► (+) ──► ReLU ──► out
        └──────────────── (skip) ──────────────┘

    """

    def __init__(self, width: int):
        super().__init__()
        self.linear = nn.Linear(width, width)
        self.layer_norm = nn.LayerNorm(width)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        shortcut = x
        x = self.linear(x)
        x = self.layer_norm(x)
        x = F.relu(x)
        x = x + shortcut
        x = F.relu(x)
        return x

class ShallowChessAI(nn.Module):
    """Small MLP that maps a chess position to a scalar score in [-3,+3].
    Default parameter count (hidden_dim=48, num_hidden_layers=2): 42'577.

    Input:
        x : [B, 783]
            Flattened features: 12x64 board bits + 7 metadata + 8 enpassant.

    Output:
        [B, 1] predicted evaluation, bounded to [-3,+3].
    """

    def __init__(self, hidden_dim: int = 48, num_hidden_layers: int = 2):
        super().__init__()
        self.input_projection = nn.Linear(783, hidden_dim)
        self.hidden_layers = nn.ModuleList(
            HiddenLayer(hidden_dim) for _ in range(num_hidden_layers)
        )
        self.output_layer = nn.Linear(hidden_dim, 1)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """x: [B, 783] → [B, 1]"""
        h = self.input_projection(x)
        for layer in self.hidden_layers:
            h = layer(h)
        return 3.0 * torch.tanh(self.output_layer(h))


# ══════════════════════════════════════════════════════════════════════════════
#  Bitboard → tensor helpers (vectorised, operate on whole chunks)
# ══════════════════════════════════════════════════════════════════════════════

BOARD_FIELDS = [
    "white_pawns", "white_knights", "white_bishops",
    "white_rooks", "white_queens", "white_kings",
    "black_pawns", "black_knights", "black_bishops",
    "black_rooks", "black_queens", "black_kings",
]

_SHIFTS_64 = np.arange(64, dtype=np.uint64)

def _expand_bitboard(arr_uint64: np.ndarray) -> np.ndarray:
    """[N] uint64 → [N, 64] float32  (0=a8 ... 63=h1)."""
    bits = ((arr_uint64[:, None] >> _SHIFTS_64[None, :]) & 1).astype(np.float32)
    return bits  # already [N, 64]

def _expand_byte(arr_uint8: np.ndarray, nbits: int = 8) -> np.ndarray:
    """[N] uint8 → [N, nbits] float32."""
    shifts = np.arange(nbits, dtype=np.uint64)
    bits = ((arr_uint8[:, None].astype(np.uint64) >> shifts[None, :]) & 1).astype(np.float32)
    return bits

def _score_to_cp(score: torch.Tensor) -> torch.Tensor:
    """Invert  score = 2·tanh(cp/364)  →  cp = 364·atanh(score/2).

    Computed in float32.
    """
    s = torch.clamp(score.to(torch.float32) / 2.0, -0.999_999, 0.999_999)
    return 364.0 * torch.atanh(s)


# ══════════════════════════════════════════════════════════════════════════════
#  Chunked streaming iterator with background prefetch
# ══════════════════════════════════════════════════════════════════════════════

class ChunkedStream:
    """
    Yields (board, meta, ep, score) CPU tensors for successive chunks of a
    memory-mapped structured .npy.  A daemon thread converts the *next*
    chunk while the main thread feeds the current one to the GPU, so the
    GPU is never starved.

    Peak extra RAM ≈ one converted chunk:
        1 M samples x 783 x 4 B ≈ 3.1 GB
    """

    _SENTINEL = None

    def __init__(self, mmap:np.ndarray, chunk_size:int, prefetch:int=2):
        self._mmap = mmap
        self._chunk_size = chunk_size
        self._q: queue.Queue = queue.Queue(maxsize=prefetch)
        self._stop_event = threading.Event()
        self._thread = threading.Thread(target=self._producer, daemon=True)
        self._thread.start()

    def _producer(self):
        N = len(self._mmap)
        for start in range(0, N, self._chunk_size):
            if self._stop_event.is_set():
                break
            end = min(start + self._chunk_size, N)
            raw = self._mmap[start:end]
            chunk = self._convert(raw)
            while not self._stop_event.is_set():
                try:
                    self._q.put(chunk, timeout=1.0)
                    break
                except queue.Full:
                    continue
        if not self._stop_event.is_set():
            try:
                self._q.put(self._SENTINEL, timeout=5.0)
            except queue.Full:
                pass

    @staticmethod
    def _convert(raw: np.ndarray) -> tuple[torch.Tensor, torch.Tensor]:
        """Structured [C] → (features [C, 783], score [C, 1])."""
        # 12 bitboards → [C, 768]
        boards = np.concatenate(
            [_expand_bitboard(raw[f]) for f in BOARD_FIELDS], axis=1
        ).astype(np.float32, copy=False)   # [C, 768]

        meta = _expand_byte(raw["metadata"], nbits=7)   # [C, 7]
        ep   = _expand_byte(raw["enpassant"],  nbits=8)  # [C, 8]
        score = raw["score"].astype(np.float32).reshape(-1, 1)

        # Flatten all inputs into a single [C, 783] vector
        features = np.concatenate([boards, meta, ep], axis=1).astype(np.float32, copy=False)

        return (
            torch.from_numpy(features),
            torch.from_numpy(score),
        )

    def __iter__(self):
        while True:
            try:
                chunk = self._q.get(timeout=30.0)
            except queue.Empty:
                if self._stop_event.is_set():
                    return
                continue
            if chunk is self._SENTINEL:
                return
            yield chunk

    def stop(self):
        """Signal the producer to stop and drain the queue."""
        self._stop_event.set()
        try:
            while True:
                self._q.get_nowait()
        except queue.Empty:
            pass

def open_npy_stream(path:Path, chunk_size:int, prefetch:int=2) -> ChunkedStream:
    """mmap the .npy and wrap it in a ChunkedStream."""
    arr = np.load(path, mmap_mode="r")
    return ChunkedStream(arr, chunk_size, prefetch=prefetch)


# ══════════════════════════════════════════════════════════════════════════════
#  Save and plot training logs
# ══════════════════════════════════════════════════════════════════════════════

def save_csv(arrs: dict, n: int, path: Path) -> None:
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["step", "epoch", "learning_rate", "train_loss", "quick_val_loss", "val_loss"])
        steps, epochs, lrs = arrs["steps"][:n], arrs["epochs"][:n], arrs["lr"][:n]
        tl, qv, fv = arrs["train_loss"][:n], arrs["quick_val"][:n], arrs["full_val"][:n]
        for i in range(n):
            w.writerow([
                steps[i], epochs[i], f"{lrs[i]:.6e}", f"{tl[i]:.6e}",
                f"{qv[i]:.6e}" if not math.isnan(qv[i]) else "",
                f"{fv[i]:.6e}" if not math.isnan(fv[i]) else "",
            ])

def save_plot(arrs: dict, n: int, out_path: Path) -> None:
    steps      = arrs["steps"][:n]
    epochs     = arrs["epochs"][:n]
    train_loss = arrs["train_loss"][:n]
    quick_val  = arrs["quick_val"][:n]
    full_val   = arrs["full_val"][:n]

    def _first_occurrences(vals):
        seen, ss, vv = set(), [], []
        for s, v in zip(steps, vals):
            if not math.isnan(v) and v not in seen:
                seen.add(v)
                ss.append(s)
                vv.append(v)
        return ss, vv

    qv_s, qv_v = _first_occurrences(quick_val)
    fv_s, fv_v = _first_occurrences(full_val)

    fig, ax = plt.subplots(figsize=(13, 5.5))
    ax.plot(steps, train_loss, color="crimson", linewidth=1.0, label="Train loss")
    if qv_v:
        ax.plot(qv_s, qv_v, color="#6cb4ee", linewidth=0.8, alpha=0.65, label="Val loss (quick)")
    if fv_v:
        ax.scatter(fv_s, fv_v, color="navy", s=35, zorder=5,
                   edgecolors="white", linewidths=0.5, label="Val loss (complete)")

    ax.set_xlabel("Step")
    ax.set_ylabel("Loss")
    ax.set_title("ShallowChessAI - Training & Validation Loss")
    ax.legend(loc="upper right", fontsize=9)
    ax.set_xlim(left=0)
    ax.set_ylim(0.2, 0.8)
    ax.set_yscale('log')
    ax.grid(axis="y", which="both", alpha=0.3)

    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)
    print(f"Plot → {out_path}", flush=True)


# ══════════════════════════════════════════════════════════════════════════════
#  Validation helpers
# ══════════════════════════════════════════════════════════════════════════════

def quick_validate(
    model: nn.Module,
    val_path: Path,
    criterion: nn.Module,
    device: torch.device,
    batch_size: int,
) -> tuple[float, float]:
    """
    Evaluate only the first `batch_size` positions from the validation set.
    No progress bar - designed to be cheap enough to call every N steps.
    Returns (loss, mae).
    """
    model.eval()
    arr = np.load(val_path, mmap_mode="r")
    raw = arr[:batch_size]
    feat, score = ChunkedStream._convert(raw)

    x = feat.to(device, non_blocking=True)
    s = score.to(device, non_blocking=True)

    with torch.no_grad():
        pred = model(x)
        loss = criterion(pred, s)

    loss_val = loss.item()
    mae = (pred - s).abs().mean().item()

    model.train(True)
    return loss_val, mae

def run_validation(
    model: nn.Module,
    val_path: Path,
    criterion: nn.Module,
    device: torch.device,
    batch_size: int,
    chunk_size: int,
    prefetch: int,
) -> tuple[float, float, float]:
    """Run full validation pass; return (mean_loss, score_mae, cp_mae_nonmate)."""
    model.eval()
    total_loss = 0.0
    total_abs_err = 0.0
    total_cp_err = 0.0
    n_samples = 0
    n_non_mate = 0

    val_stream = open_npy_stream(val_path, chunk_size, prefetch)
    n_val = len(val_stream._mmap)
    total_batches = math.ceil(n_val / batch_size)

    pbar = tqdm(
        total=total_batches,
        desc="  Validation",
        unit="batch",
        leave=True,
        bar_format="{l_bar}{bar:20}{r_bar}",
    )

    with torch.no_grad():
        for feat_c, score_c in val_stream:
            C = feat_c.shape[0]
            for i in range(0, C, batch_size):
                x = feat_c[i:i + batch_size].to(device, non_blocking=True)
                s = score_c[i:i + batch_size].to(device, non_blocking=True)

                pred = model(x)
                loss = criterion(pred, s)

                total_loss += loss.item() * x.shape[0]
                total_abs_err += (pred - s).abs().sum().item()
                n_samples += x.shape[0]

                # ── Centipawn MAE on non-mate positions only ──
                non_mate = (s.abs() < 2.0)  # [B, 1] bool
                n_nm = non_mate.sum().item()
                if n_nm > 0:
                    cp_pred   = _score_to_cp(pred[non_mate])
                    cp_target = _score_to_cp(s[non_mate])
                    total_cp_err += (cp_pred - cp_target).abs().sum().item()
                    n_non_mate += n_nm

                pbar.update(1)

    pbar.close()
    val_stream.stop()

    model.train(True)
    score_mae = total_abs_err / max(n_samples, 1)
    cp_mae    = total_cp_err / max(n_non_mate, 1)
    return total_loss / max(n_samples, 1), score_mae, cp_mae


# ══════════════════════════════════════════════════════════════════════════════
#  Global state for signal handler
# ══════════════════════════════════════════════════════════════════════════════

@dataclass
class _ShutdownState:
    model: Optional[nn.Module] = None
    optimizer: Optional[object] = None
    scheduler: Optional[object] = None
    out_dir: Optional[Path] = None
    current_epoch: int = 0
    current_step: int = 0
    best_val: float = float("inf")
    args: Optional[argparse.Namespace] = None
    shutting_down: bool = False
    log_arrs: Optional[dict] = None

_shutdown = _ShutdownState()

def _sigint_handler(signum, frame):
    if _shutdown.shutting_down:
        sys.exit(130)
    _shutdown.shutting_down = True
    print("\n\n[INTERRUPT] Saving checkpoint and CSV ...", flush=True)
    _safe_save_checkpoint()
    if _shutdown.log_arrs is not None and _shutdown.out_dir is not None:
        save_csv(_shutdown.log_arrs, _shutdown.current_step,
                   _shutdown.out_dir / "training_log.csv")
        print(f"  → CSV saved ({_shutdown.current_step} rows)", flush=True)
    print(f"[INTERRUPT] Saved. Epoch {_shutdown.current_epoch}, step {_shutdown.current_step}.",
          flush=True)
    sys.exit(130)

def _safe_save_checkpoint():
    if _shutdown.model is None or _shutdown.out_dir is None:
        return
    try:
        _shutdown.out_dir.mkdir(parents=True, exist_ok=True)
        ckpt = {
            "epoch": _shutdown.current_epoch,
            "model": _shutdown.model.state_dict(),
            "optimizer": _shutdown.optimizer.state_dict() if _shutdown.optimizer else None,
            "scheduler": _shutdown.scheduler.state_dict() if _shutdown.scheduler else None,
            "best_val": _shutdown.best_val,
            "args": vars(_shutdown.args) if _shutdown.args else None,
        }
        torch.save(ckpt, _shutdown.out_dir / "latest.pt")
        print(f"  → checkpoint saved to {_shutdown.out_dir / 'latest.pt'}", flush=True)
    except Exception as exc:
        print(f"  [WARN] checkpoint save failed: {exc}", flush=True)


# ══════════════════════════════════════════════════════════════════════════════
#  Main
# ══════════════════════════════════════════════════════════════════════════════

def main():
    ap = argparse.ArgumentParser(description="Train ShallowChessAI MLP (chunked streaming, FP32)")
    ap.add_argument("--train", default="train.npy", type=Path)
    ap.add_argument("--val",   default="val.npy",   type=Path)
    ap.add_argument("--epochs",        type=int,   default=50)
    ap.add_argument("--batch-size",    type=int,   default=8192)
    ap.add_argument("--chunk-size",    type=int,   default=131_072,
                    help="Samples per conversion chunk (default 131_072)")
    ap.add_argument("--prefetch",      type=int,   default=2,
                    help="Max chunks in the prefetch queue")
    ap.add_argument("--lr",            type=float, default=3e-4)
    ap.add_argument("--warmup-steps",  type=int,   default=200)
    ap.add_argument("--patience",      type=int,   default=10)
    ap.add_argument("--out-dir",       default="checkpoints", type=Path)
    ap.add_argument("--seed",          type=int,   default=42)
    ap.add_argument("--val-every",     type=int,  default=0,
                    help="Run quick validation (first batch) every N training steps (default 0 = disabled)")
    ap.add_argument("--val-batch-size", type=int, default=32768,
                    help="Batch size to use for validation and quick validation (default 32768)")
    ap.add_argument("--hidden-dim",    type=int,  default=48,
                    help="Hidden dimension of the MLP (default 48)")
    ap.add_argument("--num-hidden-layers", type=int,  default=2,
                    help="Number of hidden layers (default 2)")
    args = ap.parse_args()

    # ── Reproducibility ──
    torch.manual_seed(args.seed)
    np.random.seed(args.seed)

    # ── Signal handling ──
    signal.signal(signal.SIGINT, _sigint_handler)
    signal.signal(signal.SIGTERM, _sigint_handler)

    # ── Device ──
    use_cuda = torch.cuda.is_available()
    device = torch.device("cuda" if use_cuda else "cpu")
    if use_cuda:
        props = torch.cuda.get_device_properties(0)
        print(f"Device : {props.name}  ({props.total_memory / 1e9:.1f} GB VRAM)")
        print(f"PyTorch {torch.__version__}  |  "
              f"HIP/CUDA {torch.version.hip or torch.version.cuda}")
    else:
        print(f"Device : CPU  |  PyTorch {torch.__version__}")
    print(f"Dtype  : float32 (all computation in FP32)")
    print(f"Chunk  : {args.chunk_size:,} samples  "
          f"(≈{args.chunk_size * 783 * 4 / 1e9:.1f} GB converted)")
    if args.val_every > 0:
        print(f"Quick  : every {args.val_every} steps  (first {args.batch_size} val samples)")
    print(f"Val    : full pass at end of each epoch", flush=True)

    # ── Model (FP32 parameters) ──
    model = ShallowChessAI(hidden_dim=args.hidden_dim, num_hidden_layers=args.num_hidden_layers)
    model.float()  # explicit: ensure all parameters are float32
    model = model.to(device)
    n_params = sum(p.numel() for p in model.parameters())
    print(f"Model  : {n_params:,} params  (hidden_dim={args.hidden_dim}, num_hidden_layers={args.num_hidden_layers})")

    # ── Loss ──
    criterion = nn.L1Loss()
    best_val = float("inf")

    # ── Optimizer ──
    optimizer = AdamW(model.parameters(), lr=args.lr)

    # ── LR schedule (linear warmup → cosine OR constant) ──
    N_train = len(np.load(args.train, mmap_mode="r"))
    N_val   = len(np.load(args.val,   mmap_mode="r"))
    steps_per_epoch = math.ceil(N_train / args.batch_size)
    total_steps = steps_per_epoch * args.epochs
    warmup = min(args.warmup_steps, total_steps)

    def lr_lambda(step):
        if step < warmup:
            return (step + 1) / warmup
        progress = (step - warmup) / max(total_steps - warmup, 1)
        #return 0.5 * (1.0 + math.cos(math.pi * progress))       #cosine
        return 1.0                                              #constant

    scheduler = LambdaLR(optimizer, lr_lambda)

    # ── Resume ──

    # ── Output directory & log arrays ──
    args.out_dir.mkdir(parents=True, exist_ok=True)
    max_steps = steps_per_epoch * args.epochs
    log_arrs = {
        "steps":      np.empty(max_steps, dtype=np.int32),
        "epochs":     np.empty(max_steps, dtype=np.int32),
        "lr":         np.empty(max_steps, dtype=np.float32),
        "train_loss": np.empty(max_steps, dtype=np.float32),
        "quick_val":  np.full(max_steps, np.nan, dtype=np.float32),
        "full_val":   np.full(max_steps, np.nan, dtype=np.float32),
    }
    _shutdown.log_arrs = log_arrs
    csv_path = args.out_dir / "training_log.csv"

    # ── Populate shutdown state ──
    _shutdown.model = model
    _shutdown.optimizer = optimizer
    _shutdown.scheduler = scheduler
    _shutdown.out_dir = args.out_dir
    _shutdown.best_val = best_val
    _shutdown.args = args

    # ── Training loop ──
    print(f"\n== Training  {args.epochs} epochs  "
          f"(train {N_train:,} / val {N_val:,}, "
          f"batch {args.batch_size}, chunk {args.chunk_size:,}) ==", flush=True)
    print(f"Logging → {csv_path}", flush=True)

    patience = 0
    last_val_loss: Optional[float] = None          # full epoch-end val
    last_quick_val_loss: Optional[float] = None    # mid-epoch quick val

    if args.val_every > 0:
        # initial quick validation
        last_quick_val_loss, _ = quick_validate(
            model, args.val, criterion, device, args.val_batch_size,
        )
        log_arrs["quick_val"][0] = last_quick_val_loss

    # Training logs
    all_steps: list[int] = []
    all_epochs: list[int] = []
    all_train_loss: list[float] = []
    all_quick_val: list[float | None] = []
    all_full_val: list[float | None] = []

    global_step = 0
    for epoch in range(0, args.epochs):
        if _shutdown.shutting_down:
            break

        t0 = time.time()
        _shutdown.current_epoch = epoch

        epoch_loss_sum = 0.0
        epoch_n_samples = 0
        epoch_n_batches = 0
        last_batch_loss: float = 0.0

        train_iter = open_npy_stream(args.train, args.chunk_size, args.prefetch)

        pbar = tqdm(
            total=steps_per_epoch,
            desc=f"  Epoch {epoch:03d}",
            unit="batch",
            leave=True,
            bar_format="{l_bar}{bar:20}{r_bar}",
        )

        for feat_c, score_c in train_iter:
            if _shutdown.shutting_down:
                break
            C = feat_c.shape[0]
            for i in range(0, C, args.batch_size):
                if _shutdown.shutting_down:
                    break

                x = feat_c[i:i + args.batch_size].to(device, non_blocking=True)
                s = score_c[i:i + args.batch_size].to(device, non_blocking=True)

                optimizer.zero_grad(set_to_none=True)
                pred = model(x)
                loss = criterion(pred, s)
                loss.backward()
                optimizer.step()

                scheduler.step()

                loss_val = loss.item()
                last_batch_loss = loss_val
                bs = x.shape[0]
                epoch_loss_sum += loss_val * bs
                epoch_n_samples += bs
                epoch_n_batches += 1
                global_step += 1
                _shutdown.current_step = global_step

                # ── Quick validation ──
                if args.val_every > 0 and global_step % args.val_every == 0:
                    last_quick_val_loss, _ = quick_validate(
                        model, args.val, criterion, device, args.val_batch_size,
                    )
                    log_arrs["quick_val"][global_step - 1] = last_quick_val_loss

                # ── Progress bar ──
                postfix = {"loss": f"{loss_val:.4f}"}
                if last_quick_val_loss is not None:
                    postfix["qval"] = f"{last_quick_val_loss:.4f}"
                elif last_val_loss is not None:
                    postfix["val"] = f"{last_val_loss:.4f}"
                pbar.set_postfix(postfix)

                # ── Training logs ──
                log_arrs["steps"][global_step - 1]        = global_step
                log_arrs["epochs"][global_step - 1]       = epoch
                log_arrs["lr"][global_step - 1]           = optimizer.param_groups[0]["lr"]
                log_arrs["train_loss"][global_step - 1]   = loss_val

                pbar.update(1)

        train_iter.stop()
        pbar.close()

        if _shutdown.shutting_down:
            break

        # ── End-of-epoch full validation ──
        val_loss, _score_mae, cp_mae = run_validation(
            model, args.val, criterion, device,
            args.val_batch_size, args.chunk_size, args.prefetch,
        )
        log_arrs["full_val"][global_step - 1] = val_loss
        last_val_loss = val_loss

        elapsed = time.time() - t0
        lr_now = optimizer.param_groups[0]["lr"]

        improved = val_loss < best_val
        if improved:
            best_val = val_loss
            patience = 0
            _shutdown.best_val = best_val
            torch.save({
                "epoch": epoch, "model": model.state_dict(),
                "optimizer": optimizer.state_dict(), "scheduler": scheduler.state_dict(),
                "best_val": best_val, "args": vars(args),
            }, args.out_dir / "best.pt")
            status = "★ best"
        else:
            patience += 1
            status = f"patience {patience}/{args.patience}"

        torch.save({
            "epoch": epoch, "model": model.state_dict(),
            "optimizer": optimizer.state_dict(), "scheduler": scheduler.state_dict(),
            "best_val": best_val, "args": vars(args),
        }, args.out_dir / "latest.pt")

        quick_str = f" | qval {last_quick_val_loss:.6f}" if last_quick_val_loss is not None else ""
        print(f"Epoch {epoch:03d} | train {last_batch_loss:.6f} | "
              f"val {val_loss:.6f} (cp mae {cp_mae:.1f}){quick_str} | "
              f"lr {lr_now:.2e} | {elapsed:.1f}s | {status}", flush=True)

        if patience >= args.patience:
            print(f"\nEarly stopping at epoch {epoch}.", flush=True)
            break

    save_csv(log_arrs, global_step, csv_path)
    save_plot(log_arrs, global_step, args.out_dir / "training_loss.png")
    print(f"\nDone. Log: {csv_path}", flush=True)

if __name__ == "__main__":
    main()
