import torch
import torchvision.models as models
 
def export_model(output_path: str = "model.pt"):
    print("[INFO] Loading pretrained MobileNetV2...")
    # Load pretrained MobileNetV2
    model = models.mobilenet_v2(pretrained=True)
    
    # Set to evaluation mode — REQUIRED before tracing/scripting
    model.eval()
 
    print("[INFO] Converting to TorchScript via tracing...")
    # Create a dummy input — same shape as ImageNet images (batch=1, 3 channels, 224x224)
    dummy_input = torch.rand(1, 3, 224, 224)
 
    # Trace the model with the dummy input
    traced_model = torch.jit.trace(model, dummy_input)
 
    print(f"[INFO] Saving TorchScript model to '{output_path}'...")
    traced_model.save(output_path)
 
    print(f"[SUCCESS] Model saved to '{output_path}'")
    print(f"[INFO] File size: {round(__import__('os').path.getsize(output_path) / (1024*1024), 2)} MB")
 
 
if __name__ == "__main__":
    export_model("model.pt")