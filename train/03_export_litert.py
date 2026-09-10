#!/usr/bin/env python3
"""
Export the trained ShallowChessAI PyTorch model to LiteRT (.tflite)
and verify that the LiteRT inference output matches the PyTorch model
on the first batch of the validation set.

Usage:
    python 03_export_litert.py \
             --input checkpoints/best.pt \
             --val data_2609_validation.npy \
             --batch-size 128 \
             --output checkpoints/best.tflite

Dependencies:
    pip install litert-torch
"""
from __future__ import annotations
import argparse
import importlib.util
import sys
from pathlib import Path
import numpy as np
import torch
import litert_torch

# ──────────────────────────────────────────────────────────────────────────────
#  Load helpers from 02_train.py
# ──────────────────────────────────────────────────────────────────────────────

def _load_train_module(path: Path):
    spec = importlib.util.spec_from_file_location("train_module", path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Cannot load training module from {path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = mod
    spec.loader.exec_module(mod)
    return mod

_train = _load_train_module(Path(__file__).resolve().parent / "02_train.py")
ShallowChessAI = _train.ShallowChessAI


# ──────────────────────────────────────────────────────────────────────────────
#  Conversion
# ──────────────────────────────────────────────────────────────────────────────

def build_model(ckpt: dict) -> ShallowChessAI:
    saved = ckpt.get("args", {}) or {}
    model = ShallowChessAI(
        hidden_dim=saved.get("hidden_dim", 48),
        num_hidden_layers=saved.get("num_hidden_layers", 2),
    )
    model.load_state_dict(ckpt["model"])
    model.eval()
    for p in model.parameters():
        p.requires_grad_(False)
    return model


# ──────────────────────────────────────────────────────────────────────────────
#  Verification
# ──────────────────────────────────────────────────────────────────────────────

def load_first_batch(val_path: Path, n: int) -> tuple[np.ndarray, np.ndarray]:
    """Load and convert the first n samples from the validation .npy.

    Returns (features [n, 783] float32, scores [n, 1] float32).
    """
    arr = np.load(val_path, mmap_mode="r")
    raw = np.array(arr[:n])
    feat, score = _train.ChunkedStream._convert(raw)
    return feat.numpy(), score.numpy()

def torch_scores(model: ShallowChessAI, feat: np.ndarray) -> np.ndarray:
    with torch.no_grad():
        out = model(torch.from_numpy(feat))
    return out.numpy()

def litert_scores(edge_model, feat: np.ndarray) -> np.ndarray:
    """Run inference using the litert edge_model (callable, static batch=1)."""
    n = feat.shape[0]
    out = np.empty((n, 1), dtype=np.float32)
    for i in range(n):
        result = edge_model(torch.from_numpy(feat[i:i + 1]))
        # edge_model returns a tuple of tensors (one per output); take the first
        out[i] = np.asarray(result[0] if isinstance(result, tuple) else result).reshape(1)
    return out

def compare(a: np.ndarray, b: np.ndarray, label: str) -> None:
    a = a.reshape(-1)
    b = b.reshape(-1)
    assert a.shape == b.shape, f"{label}: shape mismatch {a.shape} vs {b.shape}"
    diff = np.abs(a - b)
    rel  = diff / np.maximum(np.abs(a), 1e-8)
    print(f"  [{label}]  n={a.size}")
    print(f"    max|Δ|       = {diff.max():.3e}")
    print(f"    mean|Δ|      = {diff.mean():.3e}")
    print(f"    max rel. err = {rel.max():.3e}")
    print(f"    [0..3]  torch={a[:4]}")
    print(f"    [0..3]  other={b[:4]}")
    if diff.max() > 1e-4:
        print(f"  [FAIL] {label}: max diff {diff.max():.2e} > 1e-4", file=sys.stderr)
        sys.exit(1)

def main() -> None:
    ap = argparse.ArgumentParser(description="Export ShallowChessAI to LiteRT and verify.")
    ap.add_argument("--input", type=Path, required=True,
                    help="Path to best.pt or latest.pt")
    ap.add_argument("--val",   type=Path, required=True,
                    help="Validation .npy for the comparison")
    ap.add_argument("--batch-size", type=int, default=128,
                    help="Number of val samples to compare (default 128)")
    ap.add_argument("--output", type=Path, default="checkpoints/best.tflite",
                    help="Output .tflite path")
    args = ap.parse_args()

    # ── Load checkpoint & build model ─────────────────────────────────────────
    print(f"Loading checkpoint: {args.input}", flush=True)
    ckpt = torch.load(args.input, map_location="cpu", weights_only=False)

    model = build_model(ckpt)
    n_params = sum(p.numel() for p in model.parameters())
    hd = ckpt.get("args", {}).get("hidden_dim", 48)
    nl = ckpt.get("args", {}).get("num_hidden_layers", 2)
    print(f"  architecture : hidden_dim={hd}, num_hidden_layers={nl}, params={n_params:,}")
    print(f"  epoch        : {ckpt.get('epoch')}, best_val={ckpt.get('best_val')}", flush=True)

    # ── Convert ───────────────────────────────────────────────────────────────
    sample_inputs = (torch.zeros(1, 783, dtype=torch.float32),)
    print("\nConverting ...", flush=True)
    edge_model = litert_torch.convert(model, sample_inputs)

    # ── Verify ────────────────────────────────────────────────────────────────
    feat, target = load_first_batch(args.val, args.batch_size)
    print(f"\nVerification on first {feat.shape[0]} val samples "
          f"({feat.shape[1]}-dim features)", flush=True)

    s_torch  = torch_scores(model, feat)
    s_litert = litert_scores(edge_model, feat)
    compare(s_torch,  s_litert, "torch vs litert")

    # ── Export ────────────────────────────────────────────────────────────────
    args.output.parent.mkdir(parents=True, exist_ok=True)
    edge_model.export(str(args.output))
    size_mb = args.output.stat().st_size / 1e6
    print(f"\nExported → {args.output}  ({size_mb:.2f} MB)", flush=True)
    print("Done.", flush=True)

if __name__ == "__main__":
    main()
