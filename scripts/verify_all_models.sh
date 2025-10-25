#!/usr/bin/env bash
set -Eeuo pipefail

# ComfyUI Model Verification Script
# Purpose: Verify all required models are present and valid
# Usage: ./verify_all_models.sh

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

MODELS_EXTERNAL="/run/media/miko/AYA/model-depot/store/models/comfyui"
MODELS_LOCAL="$HOME/LAB/projects/ComfyUI/models"

echo "=== ComfyUI Model Verification ==="
echo "Date: $(date -Iseconds)"
echo ""

# Track overall status
ERRORS=0

# Function to check file/directory existence and size
check_model() {
    local model_path="$1"
    local model_name="$2"
    local min_size_gb="$3"

    if [ -e "$model_path" ]; then
        # Get size in GB
        local size_bytes=$(du -sb "$model_path" 2>/dev/null | cut -f1 || echo 0)
        local size_gb=$(echo "scale=2; $size_bytes / 1024 / 1024 / 1024" | bc)

        if (( $(echo "$size_gb >= $min_size_gb" | bc -l) )); then
            echo -e "${GREEN}✅ $model_name: ${size_gb}GB${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  $model_name: ${size_gb}GB (expected >= ${min_size_gb}GB)${NC}"
            ERRORS=$((ERRORS + 1))
            return 1
        fi
    else
        echo -e "${RED}❌ $model_name: NOT FOUND${NC}"
        echo "   Expected: $model_path"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Function to verify symlink
check_symlink() {
    local link_path="$1"
    local link_name="$2"

    if [ -L "$link_path" ]; then
        local target=$(readlink -f "$link_path")
        if [ -e "$target" ]; then
            echo -e "${GREEN}✅ Symlink $link_name → $target${NC}"
            return 0
        else
            echo -e "${RED}❌ Symlink $link_name → BROKEN (target: $target)${NC}"
            ERRORS=$((ERRORS + 1))
            return 1
        fi
    elif [ -e "$link_path" ]; then
        echo -e "${YELLOW}⚠️  $link_name exists but is not a symlink${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Symlink $link_name: NOT CREATED YET${NC}"
        return 0
    fi
}

echo "--- Checking External Storage ---"

# Check if external drive is mounted
if [ ! -d "$MODELS_EXTERNAL" ]; then
    echo -e "${RED}❌ External storage not mounted at $MODELS_EXTERNAL${NC}"
    echo "   Please mount the AYA drive before proceeding"
    exit 1
else
    echo -e "${GREEN}✅ External storage accessible${NC}"

    # Show disk usage
    df -h "$MODELS_EXTERNAL" | grep -v Filesystem
fi

echo ""
echo "--- Checking HiDream-I1-FP8 Model ---"

check_model "$MODELS_EXTERNAL/checkpoints/HiDream-I1-FP8" "HiDream-I1-FP8" 25

echo ""
echo "--- Checking FLUX Text Encoders ---"

check_model "$MODELS_EXTERNAL/clip/clip_l.safetensors" "CLIP-L encoder" 0.5
check_model "$MODELS_EXTERNAL/clip/t5xxl_fp16.safetensors" "T5-XXL FP16 encoder" 8
check_model "$MODELS_EXTERNAL/vae/ae.safetensors" "FLUX VAE" 0.3

echo ""
echo "--- Checking Symlinks (if created) ---"

if [ -d "$MODELS_LOCAL" ]; then
    check_symlink "$MODELS_LOCAL/checkpoints" "checkpoints"
    check_symlink "$MODELS_LOCAL/clip" "clip"
    check_symlink "$MODELS_LOCAL/vae" "vae"
else
    echo -e "${YELLOW}⚠️  Local models directory not created yet${NC}"
    echo "   Run setup_model_symlinks.sh after ComfyUI installation"
fi

echo ""
echo "--- Summary ---"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All models verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS issue(s)${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Download missing models: ./scripts/download_all_models.sh"
    echo "  2. Setup symlinks: ./scripts/setup_model_symlinks.sh"
    echo "  3. Re-run verification: ./scripts/verify_all_models.sh"
    exit 1
fi
