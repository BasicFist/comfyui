#!/usr/bin/env bash
set -Eeuo pipefail

# ComfyUI Symlink Setup Script
# Purpose: Create symlinks from ComfyUI models directory to external storage
# Usage: ./setup_model_symlinks.sh

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MODELS_EXTERNAL="/run/media/miko/AYA/model-depot/store/models/comfyui"
COMFYUI_ROOT="$HOME/LAB/projects/ComfyUI"
MODELS_LOCAL="$COMFYUI_ROOT/models"

echo "=== ComfyUI Symlink Setup ==="
echo "Date: $(date -Iseconds)"
echo ""

# Pre-flight checks
echo "--- Pre-flight Checks ---"

# Check if ComfyUI directory exists
if [ ! -d "$COMFYUI_ROOT" ]; then
    echo -e "${RED}❌ ComfyUI not found at $COMFYUI_ROOT${NC}"
    echo "   Clone ComfyUI first:"
    echo "   cd ~/LAB/projects && git clone https://github.com/comfyanonymous/ComfyUI.git"
    exit 1
fi

echo -e "${GREEN}✅ ComfyUI directory found${NC}"

# Check if external storage is mounted
if [ ! -d "$MODELS_EXTERNAL" ]; then
    echo -e "${RED}❌ External storage not mounted at $MODELS_EXTERNAL${NC}"
    echo "   Please mount the AYA drive before proceeding"
    exit 1
fi

echo -e "${GREEN}✅ External storage accessible${NC}"

# Verify external storage has content
MODEL_COUNT=$(find "$MODELS_EXTERNAL" -type f -name "*.safetensors" 2>/dev/null | wc -l)

if [ "$MODEL_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No model files found in external storage${NC}"
    echo "   Download models first: ./scripts/download_all_models.sh"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
else
    echo -e "${GREEN}✅ Found $MODEL_COUNT model file(s) in external storage${NC}"
fi

echo ""
echo "--- Symlink Configuration ---"
echo "Source (external): $MODELS_EXTERNAL"
echo "Target (local):    $MODELS_LOCAL"
echo ""

# Create models directory if it doesn't exist
mkdir -p "$MODELS_LOCAL"

# Function to create symlink
create_symlink() {
    local link_name="$1"
    local source_dir="$2"
    local link_path="$MODELS_LOCAL/$link_name"

    echo -e "${BLUE}Setting up: $link_name${NC}"

    # Check if source directory exists
    if [ ! -d "$source_dir" ]; then
        echo -e "${YELLOW}⚠️  Source directory does not exist: $source_dir${NC}"
        echo "   Creating empty directory..."
        mkdir -p "$source_dir"
    fi

    # Handle existing target
    if [ -e "$link_path" ] || [ -L "$link_path" ]; then
        if [ -L "$link_path" ]; then
            EXISTING_TARGET=$(readlink -f "$link_path")

            if [ "$EXISTING_TARGET" = "$source_dir" ]; then
                echo -e "${GREEN}✅ Symlink already correct${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠️  Symlink exists but points to different location${NC}"
                echo "   Current: $EXISTING_TARGET"
                echo "   Expected: $source_dir"

                read -p "Replace? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm "$link_path"
                else
                    echo "   Skipped"
                    return 0
                fi
            fi
        else
            echo -e "${YELLOW}⚠️  Path exists but is not a symlink${NC}"
            echo "   Path: $link_path"

            # Check if it has content
            ITEM_COUNT=$(ls -A "$link_path" 2>/dev/null | wc -l)

            if [ "$ITEM_COUNT" -gt 0 ]; then
                echo -e "${RED}❌ Directory has $ITEM_COUNT items - manual intervention required${NC}"
                echo "   Move or backup: $link_path"
                return 1
            else
                read -p "Remove empty directory and create symlink? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm -r "$link_path"
                else
                    echo "   Skipped"
                    return 0
                fi
            fi
        fi
    fi

    # Create the symlink
    if ln -s "$source_dir" "$link_path"; then
        # Verify
        if [ -L "$link_path" ] && [ -e "$link_path" ]; then
            ITEM_COUNT=$(ls -A "$link_path" 2>/dev/null | wc -l)
            echo -e "${GREEN}✅ Symlink created ($ITEM_COUNT items)${NC}"
            echo "   $link_path → $source_dir"
        else
            echo -e "${RED}❌ Symlink creation verification failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to create symlink${NC}"
        return 1
    fi

    echo ""
}

echo "--- Creating Symlinks ---"
echo ""

ERRORS=0

create_symlink "checkpoints" "$MODELS_EXTERNAL/checkpoints" || ERRORS=$((ERRORS + 1))
create_symlink "clip" "$MODELS_EXTERNAL/clip" || ERRORS=$((ERRORS + 1))
create_symlink "vae" "$MODELS_EXTERNAL/vae" || ERRORS=$((ERRORS + 1))
create_symlink "unet" "$MODELS_EXTERNAL/unet" || ERRORS=$((ERRORS + 1))

echo "--- Verification ---"
echo ""

# Verify all symlinks
ls -lh "$MODELS_LOCAL/" | grep -E "checkpoints|clip|vae|unet" || true

echo ""
echo "--- Summary ---"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All symlinks created successfully!${NC}"
    echo ""
    echo "Model directories now accessible from ComfyUI:"
    echo "  $MODELS_LOCAL/checkpoints → $MODELS_EXTERNAL/checkpoints"
    echo "  $MODELS_LOCAL/clip → $MODELS_EXTERNAL/clip"
    echo "  $MODELS_LOCAL/vae → $MODELS_EXTERNAL/vae"
    echo "  $MODELS_LOCAL/unet → $MODELS_EXTERNAL/unet"
    echo ""
    echo "Next steps:"
    echo "  1. Verify symlinks: ./scripts/verify_symlinks.sh"
    echo "  2. Start ComfyUI:   cd ~/LAB/projects/ComfyUI && python main.py"
    exit 0
else
    echo -e "${RED}❌ $ERRORS error(s) occurred during symlink setup${NC}"
    echo ""
    echo "Fix errors and re-run: ./scripts/setup_model_symlinks.sh"
    exit 1
fi
