#!/usr/bin/env bash
set -Eeuo pipefail

# HiDream-I1-FP8 Model Download Script
# Purpose: Download HiDream-I1-FP8 model (~30GB) with resume support
# Usage: ./download_hidream.sh

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MODELS_DIR="/run/media/miko/AYA/model-depot/store/models/comfyui"
CHECKPOINT_DIR="$MODELS_DIR/checkpoints"
MODEL_NAME="HiDream-I1-FP8"
MODEL_PATH="$CHECKPOINT_DIR/$MODEL_NAME"

echo "=== HiDream-I1-FP8 Download ==="
echo "Date: $(date -Iseconds)"
echo ""

# Check if external drive is mounted
if [ ! -d "$MODELS_DIR" ]; then
    echo -e "${RED}❌ External storage not mounted at $MODELS_DIR${NC}"
    echo "   Please mount the AYA drive before proceeding"
    exit 1
fi

# Show available space
echo "--- Disk Space ---"
df -h "$MODELS_DIR" | grep -v Filesystem
echo ""

AVAILABLE_GB=$(df -BG "$MODELS_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
REQUIRED_GB=35

if [ "$AVAILABLE_GB" -lt "$REQUIRED_GB" ]; then
    echo -e "${RED}❌ Insufficient disk space${NC}"
    echo "   Available: ${AVAILABLE_GB}GB"
    echo "   Required: ${REQUIRED_GB}GB (30GB model + 5GB buffer)"
    exit 1
fi

echo -e "${GREEN}✅ Sufficient space available (${AVAILABLE_GB}GB)${NC}"
echo ""

# Check if model already exists
if [ -d "$MODEL_PATH" ]; then
    CURRENT_SIZE=$(du -sh "$MODEL_PATH" | cut -f1)
    echo -e "${YELLOW}⚠️  Model directory already exists: $MODEL_PATH${NC}"
    echo "   Current size: $CURRENT_SIZE"
    echo ""
    read -p "Resume/overwrite download? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Download cancelled"
        exit 0
    fi
fi

# Create checkpoint directory
mkdir -p "$CHECKPOINT_DIR"

echo "--- Download Configuration ---"
echo "Repository: shuttleai/HiDream-I1-Full-FP8"
echo "Destination: $MODEL_PATH"
echo "Method: huggingface-cli with resume support"
echo ""

# Check if huggingface-cli is available
if ! command -v huggingface-cli &> /dev/null; then
    echo -e "${YELLOW}⚠️  huggingface-cli not found, installing...${NC}"

    # Check if pip/pip3 is available
    if command -v pip3 &> /dev/null; then
        pip3 install --user huggingface_hub[cli]
    elif command -v pip &> /dev/null; then
        pip install --user huggingface_hub[cli]
    else
        echo -e "${RED}❌ Neither pip nor pip3 found${NC}"
        echo "   Install Python pip first: sudo dnf install python3-pip"
        exit 1
    fi

    # Verify installation
    if ! command -v huggingface-cli &> /dev/null; then
        echo -e "${RED}❌ huggingface-cli installation failed${NC}"
        echo "   Try manually: pip3 install --user huggingface_hub[cli]"
        exit 1
    fi

    echo -e "${GREEN}✅ huggingface-cli installed${NC}"
fi

echo ""
echo -e "${BLUE}Starting download (this may take 1-2 hours)...${NC}"
echo "Press Ctrl+C to pause (resume by re-running this script)"
echo ""

# Download with resume support
cd "$CHECKPOINT_DIR"

huggingface-cli download shuttleai/HiDream-I1-Full-FP8 \
    --local-dir "$MODEL_NAME" \
    --local-dir-use-symlinks False \
    --repo-type model \
    --resume-download

# Verify download
echo ""
echo "--- Verification ---"

if [ -d "$MODEL_PATH" ]; then
    FINAL_SIZE=$(du -sh "$MODEL_PATH" | cut -f1)
    FILE_COUNT=$(find "$MODEL_PATH" -type f | wc -l)

    echo -e "${GREEN}✅ Download complete!${NC}"
    echo "   Location: $MODEL_PATH"
    echo "   Size: $FINAL_SIZE"
    echo "   Files: $FILE_COUNT"
    echo ""

    # Look for the main model file
    if [ -f "$MODEL_PATH/HiDream-I1.safetensors" ] || [ -f "$MODEL_PATH/model.safetensors" ] || ls "$MODEL_PATH"/*.safetensors &>/dev/null; then
        echo -e "${GREEN}✅ Model file(s) found${NC}"
        ls -lh "$MODEL_PATH"/*.safetensors 2>/dev/null || true
    else
        echo -e "${YELLOW}⚠️  No .safetensors files found${NC}"
        echo "   Directory contents:"
        ls -lh "$MODEL_PATH" | head -10
    fi

    echo ""
    echo "Next steps:"
    echo "  1. Verify all models: ./scripts/verify_all_models.sh"
    echo "  2. Download encoders: ./scripts/download_flux_encoders.sh"
    echo "  3. Setup symlinks: ./scripts/setup_model_symlinks.sh"
else
    echo -e "${RED}❌ Download failed - model directory not created${NC}"
    exit 1
fi
