# Lesson 3 — Containerization of ML Models

MLOps Homework: TorchScript model inference, Docker fat/slim images, and environment setup automation.

---

## Project Structure

```
lesson-3/
├── inference.py          # Runs top-3 prediction on an input image
├── export_model.py       # Downloads MobileNetV2 and saves as model.pt
├── model.pt              # TorchScript model (generated — not committed to Git)
├── Dockerfile.fat        # Unoptimised Ubuntu-based image (>1 GB)
├── Dockerfile.slim       # Optimised multi-stage image
├── install_dev_tools.sh  # Idempotent bash setup script
├── comparison.txt        # Fat vs slim image analysis
└── README.md             # This file
```

---

## Requirements

- Python 3.9+
- Docker Desktop running
- pip

---

## Step 1 — Install Python Dependencies Locally

```bash
pip install torch torchvision pillow
```

---

## Step 2 — Generate the TorchScript Model

```bash
python export_model.py
```

This downloads a pretrained MobileNetV2, converts it to TorchScript,
and saves it as `model.pt` (~14 MB).

---

## Step 3 — Test Inference Locally

```bash
python inference.py --image path/to/your/image.jpg
```

Example output:
```
── Top-3 Predictions ─────────────────────────────────────────
  1. golden retriever                94.21%
  2. Labrador retriever              3.14%
  3. tennis ball                     0.87%
──────────────────────────────────────────────────────────────
```

---

## Step 4 — Build Docker Images

Make sure Docker Desktop is running first.

### Fat Image (~2 GB)
```bash
docker build -f Dockerfile.fat -t model-fat .
```

### Slim Image (~900 MB)
```bash
docker build -f Dockerfile.slim -t model-slim .
```

---

## Step 5 — Run Inference in Docker

```bash
# Fat image
docker run --rm -v $(pwd):/data model-fat --image /data/your_image.jpg

# Slim image
docker run --rm -v $(pwd):/data model-slim --image /data/your_image.jpg
```

> The `-v $(pwd):/data` flag mounts your current folder into the container
> so the container can read your local image file.

---

## Step 6 — Compare Image Sizes

```bash
docker images | grep model-
```

```bash
# See layer counts
docker history model-fat
docker history model-slim
```

---

## Step 7 — Run the Environment Setup Script (Linux/Mac)

```bash
chmod +x install_dev_tools.sh
./install_dev_tools.sh
```

Logs are saved to `install.log`.

---

## Notes

- The model is saved in **TorchScript** format so it can be loaded
  without the original model class definition.
- For a production-ready image, consider switching the slim base to
  `gcr.io/distroless/python3` and using the CPU-only PyTorch wheel.
- See `comparison.txt` for full fat vs slim analysis.