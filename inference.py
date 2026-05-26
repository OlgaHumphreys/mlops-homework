import argparse
import json
import os
import urllib.request

import torch
from PIL import Image
from torchvision import transforms


# ── ImageNet class labels ────────────────────────────────────────────────────

LABELS_URL = (
    "https://raw.githubusercontent.com/anishathalye/imagenet-simple-labels"
    "/master/imagenet-simple-labels.json"
)
LABELS_FILE = "imagenet_labels.json"


def load_labels() -> list:
    """Download ImageNet labels if not cached, then return them."""
    if not os.path.exists(LABELS_FILE):
        print("[INFO] Downloading ImageNet labels...")
        urllib.request.urlretrieve(LABELS_URL, LABELS_FILE)
    with open(LABELS_FILE, "r") as f:
        return json.load(f)


# ── Image preprocessing ──────────────────────────────────────────────────────

def preprocess(image_path: str) -> torch.Tensor:
    """
    Apply standard ImageNet preprocessing:
      - Resize shortest edge to 256
      - Centre-crop to 224×224
      - Convert to tensor [0, 1]
      - Normalise with ImageNet mean / std
    Returns a (1, 3, 224, 224) tensor.
    """
    transform = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],
            std =[0.229, 0.224, 0.225],
        ),
    ])
    img = Image.open(image_path).convert("RGB")
    return transform(img).unsqueeze(0)          # add batch dimension


# ── Inference ────────────────────────────────────────────────────────────────

def run_inference(image_path: str, model_path: str = "model.pt") -> None:
    # ── Validate paths ──────────────────────────────────────────────────────
    if not os.path.exists(model_path):
        raise FileNotFoundError(
            f"Model file not found: '{model_path}'\n"
            "Run  python export_model.py  first."
        )
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Image file not found: '{image_path}'")

    # ── Load TorchScript model ──────────────────────────────────────────────
    print(f"[INFO] Loading TorchScript model from '{model_path}'...")
    model = torch.jit.load(model_path)
    model.eval()

    # ── Preprocess image ────────────────────────────────────────────────────
    print(f"[INFO] Preprocessing image '{image_path}'...")
    input_tensor = preprocess(image_path)

    # ── Forward pass ────────────────────────────────────────────────────────
    print("[INFO] Running inference...")
    with torch.no_grad():
        output = model(input_tensor)            # shape: (1, 1000)

    # ── Top-3 predictions ───────────────────────────────────────────────────
    probabilities = torch.nn.functional.softmax(output[0], dim=0)
    top3_prob, top3_idx = torch.topk(probabilities, 3)

    labels = load_labels()

    print("\n── Top-3 Predictions ─────────────────────────────────────────")
    for rank, (prob, idx) in enumerate(zip(top3_prob, top3_idx), start=1):
        label = labels[idx.item()] if idx.item() < len(labels) else f"class_{idx.item()}"
        print(f"  {rank}. {label:<30}  {prob.item() * 100:.2f}%")
    print("──────────────────────────────────────────────────────────────\n")


# ── CLI entry point ──────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run TorchScript MobileNetV2 inference on an image."
    )
    parser.add_argument(
        "--image",
        required=True,
        help="Path to the input image (JPEG / PNG / etc.)",
    )
    parser.add_argument(
        "--model",
        default="model.pt",
        help="Path to the TorchScript model file (default: model.pt)",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    run_inference(image_path=args.image, model_path=args.model)