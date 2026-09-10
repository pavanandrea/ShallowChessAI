#!/usr/bin/env python3
"""
Export the trained ShallowChessAI PyTorch model to ONNX and verify it
against the first batch of the validation set.

Usage:
    python 03_export_onnx.py \
             --input checkpoints/best.pt \
             --val data_2609_validation.npy \
             --batch-size 128 \
             --output checkpoints/best.onnx

Dependencies:
    pip install onnx onnxruntime
"""
from __future__ import annotations
import argparse
import importlib.util
import sys
from pathlib import Path
import numpy as np
import torch
import onnx
import onnxruntime as ort

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
#  Model helpers
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
#  Validation data helpers
# ──────────────────────────────────────────────────────────────────────────────

def load_first_batch(val_path: Path, n: int) -> np.ndarray:
    """Load and convert the first n samples from the validation .npy.

    Returns features [n, 783] float32.
    """
    arr = np.load(val_path, mmap_mode="r")
    raw = np.array(arr[:n])
    feat, _ = _train.ChunkedStream._convert(raw)
    return feat.numpy()

def torch_scores(model: ShallowChessAI, feat: np.ndarray) -> np.ndarray:
    with torch.no_grad():
        out = model(torch.from_numpy(feat))
    return out.numpy()

def onnx_scores(sess, input_name: str, output_name: str, feat: np.ndarray) -> np.ndarray:
    return sess.run([output_name], {input_name: feat.astype(np.float32)})[0]

def compare(a: np.ndarray, b: np.ndarray, label: str) -> None:
    a = a.reshape(-1)
    b = b.reshape(-1)
    assert a.shape == b.shape, f"{label}: shape mismatch {a.shape} vs {b.shape}"
    diff = np.abs(a - b)
    rel = diff / np.maximum(np.abs(a), 1e-8)
    print(f"  [{label}]  n={a.size}")
    print(f"    max|Δ|       = {diff.max():.3e}")
    print(f"    mean|Δ|      = {diff.mean():.3e}")
    print(f"    max rel. err = {rel.max():.3e}")
    print(f"    [0..3]  torch={a[:4]}")
    print(f"    [0..3]  other={b[:4]}")
    if diff.max() > 1e-4:
        print(f"  [FAIL] {label}: max diff {diff.max():.2e} > 1e-4", file=sys.stderr)
        sys.exit(1)


# ──────────────────────────────────────────────────────────────────────────────
#  Main
# ──────────────────────────────────────────────────────────────────────────────

def main() -> None:
    ap = argparse.ArgumentParser(description="Export ShallowChessAI to ONNX and verify.")
    ap.add_argument("--input", type=Path, required=True,
                    help="Path to best.pt or latest.pt")
    ap.add_argument("--val", type=Path, required=True,
                    help="Validation .npy for the comparison")
    ap.add_argument("--batch-size", type=int, default=128,
                    help="Number of val samples to compare")
    ap.add_argument("--output", type=Path, default=Path("checkpoints/best.onnx"),
                    help="Output .onnx path")
    args = ap.parse_args()

    # Load checkpoint & build model
    print(f"Loading checkpoint: {args.input}", flush=True)
    ckpt = torch.load(args.input, map_location="cpu", weights_only=False)

    model = build_model(ckpt)
    n_params = sum(p.numel() for p in model.parameters())
    hd = ckpt.get("args", {}).get("hidden_dim", 48)
    nl = ckpt.get("args", {}).get("num_hidden_layers", 2)
    print(f"  architecture : hidden_dim={hd}, num_hidden_layers={nl}, params={n_params:,}")
    print(f"  epoch        : {ckpt.get('epoch')}, best_val={ckpt.get('best_val')}", flush=True)

    # Export ONNX
    print("\nExporting ...", flush=True)
    dummy = torch.zeros(1, 783, dtype=torch.float32)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    torch.onnx.export(
        model,
        (dummy,),
        str(args.output),
        input_names=["x"],
        output_names=["score"],
        opset_version=18,
        dynamic_shapes={"x": {0: "batch_size"}},   # only inputs
    )

    # Re-serialise with data inlined
    onnx_model = onnx.load(str(args.output))
    onnx.save(onnx_model, str(args.output))

    # Verify
    feat = load_first_batch(args.val, args.batch_size)
    print(f"\nVerification on first {feat.shape[0]} val samples ({feat.shape[1]}-dim features)", flush=True)

    s_torch = torch_scores(model, feat)
    
    sess = ort.InferenceSession(str(args.output), providers=["CPUExecutionProvider"])
    s_onnx = onnx_scores(sess, "x", "score", feat)

    compare(s_torch, s_onnx, "torch vs onnx")

    size_kb = args.output.stat().st_size / 1024
    print(f"\nExported → {args.output}  ({size_kb:.2f} KB)", flush=True)
    print("Done.", flush=True)


if __name__ == "__main__":
    main()
