#!/usr/bin/env bash
set -Eeuo pipefail

# FLUX Text Encoders Download Script
# Purpose: Download CLIP-L, T5-XXL FP16, and VAE (~17GB total) with resume support
# Usage: ./download_flux_encoders.sh

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MODELS_DIR="/run/media/miko/AYA/model-depot/store/models/comfyui"

echo "=== FLUX Text Encoders Download ==="
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
REQUIRED_GB=20

if [ "$AVAILABLE_GB" -lt "$REQUIRED_GB" ]; then
    echo -e "${RED}❌ Insufficient disk space${NC}"
    echo "   Available: ${AVAILABLE_GB}GB"
    echo "   Required: ${REQUIRED_GB}GB (17GB encoders + 3GB buffer)"
    exit 1
fi

echo -e "${GREEN}✅ Sufficient space available (${AVAILABLE_GB}GB)${NC}"
echo ""

# Create directories
mkdir -p "$MODELS_DIR/clip"
mkdir -p "$MODELS_DIR/vae"

# Check if huggingface-cli is available
if ! command -v huggingface-cli &> /dev/null; then
    echo -e "${YELLOW}⚠️  huggingface-cli not found, installing...${NC}"

    if command -v pip3 &> /dev/null; then
        pip3 install --user huggingface_hub[cli]
    elif command -v pip &> /dev/null; then
        pip install --user huggingface_hub[cli]
    else
        echo -e "${RED}❌ Neither pip nor pip3 found${NC}"
        echo "   Install Python pip first: sudo dnf install python3-pip"
        exit 1
    fi

    if ! command -v huggingface-cli &> /dev/null; then
        echo -e "${RED}❌ huggingface-cli installation failed${NC}"
        exit 1
    fi
fi

echo "=== Downloading 3 encoder files ==="
echo ""

TOTAL_FILES=3
CURRENT_FILE=0
ERRORS=0

# Function to download a single file
download_file() {
    local repo="$1"
    local filename="$2"
    local dest_dir="$3"
    local file_desc="$4"

    CURRENT_FILE=$((CURRENT_FILE + 1))

    echo -e "${BLUE}[$CURRENT_FILE/$TOTAL_FILES] $file_desc${NC}"
    echo "Repository: $repo"
    echo "File: $filename"
    echo "Destination: $dest_dir"

    # Check if file already exists
    if [ -f "$dest_dir/$filename" ]; then
        EXISTING_SIZE=$(du -sh "$dest_dir/$filename" | cut -f1)
        echo -e "${YELLOW}⚠️  File already exists ($EXISTING_SIZE)${NC}"
        read -p "Re-download? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping..."
            echo ""
            return 0
        fi
    fi

    # Download
    if huggingface-cli download "$repo" "$filename" \
        --local-dir "$dest_dir" \
        --local-dir-use-symlinks False \
        --resume-download; then

        if [ -f "$dest_dir/$filename" ]; then
            FILE_SIZE=$(du -sh "$dest_dir/$filename" | cut -f1)
            echo -e "${GREEN}✅ Download complete: $FILE_SIZE${NC}"
        else
            echo -e "${RED}❌ Download failed - file not found${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "${RED}❌ Download failed${NC}"
        ERRORS=$((ERRORS + 1))
    fi

    echo ""
}

# Download CLIP-L encoder
download_file \
    "comfyanonymous/flux_text_encoders" \
    "clip_l.safetensors" \
    "$MODELS_DIR/clip" \
    "CLIP-L Text Encoder (~700MB)"

# Download T5-XXL FP16 encoder
download_file \
    "comfyanonymous/flux_text_encoders" \
    "t5xxl_fp16.safetensors" \
    "$MODELS_DIR/clip" \
    "T5-XXL FP16 Text Encoder (~9GB)"

# Download FLUX VAE
download_file \
    "black-forest-labs/FLUX.1-schnell" \
    "ae.safetensors" \
    "$MODELS_DIR/vae" \
    "FLUX VAE (~300MB)"

# Summary
echo "--- Summary ---"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All encoders downloaded successfully!${NC}"
    echo ""
    echo "Downloaded files:"

    if [ -f "$MODELS_DIR/clip/clip_l.safetensors" ]; then
        ls -lh "$MODELS_DIR/clip/clip_l.safetensors"
    fi

    if [ -f "$MODELS_DIR/clip/t5xxl_fp16.safetensors" ]; then
        ls -lh "$MODELS_DIR/clip/t5xxl_fp16.safetensors"
    fi

    if [ -f "$MODELS_DIR/vae/ae.safetensors" ]; then
        ls -lh "$MODELS_DIR/vae/ae.safetensors"
    fi

    echo ""
    echo "Total size:"
    du -sh "$MODELS_DIR/clip" "$MODELS_DIR/vae" | awk '{print "  " $0}'

    echo ""
    echo "Next steps:"
    echo "  1. Verify all models: ./scripts/verify_all_models.sh"
    echo "  2. Setup symlinks: ./scripts/setup_model_symlinks.sh"
    exit 0
else
    echo -e "${RED}❌ $ERRORS download(s) failed${NC}"
    echo ""
    echo "Re-run this script to retry failed downloads"
    exit 1
fi
