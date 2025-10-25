#!/usr/bin/env bash
set -Eeuo pipefail

# ComfyUI Complete Model Download Orchestrator
# Purpose: Download all required models for HiDream-I1-FP8 workflow
# Usage: ./download_all_models.sh

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="/run/media/miko/AYA/model-depot/store/models/comfyui"

echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  ComfyUI Model Download Orchestrator         ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo "Date: $(date -Iseconds)"
echo ""

# Pre-flight checks
echo "--- Pre-flight Checks ---"

# Check external storage
if [ ! -d "$MODELS_DIR" ]; then
    echo -e "${RED}❌ External storage not mounted at $MODELS_DIR${NC}"
    echo "   Please mount the AYA drive before proceeding"
    exit 1
fi

echo -e "${GREEN}✅ External storage accessible${NC}"

# Check available space
AVAILABLE_GB=$(df -BG "$MODELS_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
REQUIRED_GB=50

if [ "$AVAILABLE_GB" -lt "$REQUIRED_GB" ]; then
    echo -e "${RED}❌ Insufficient disk space${NC}"
    echo "   Available: ${AVAILABLE_GB}GB"
    echo "   Required: ${REQUIRED_GB}GB minimum"
    exit 1
fi

echo -e "${GREEN}✅ Sufficient space available (${AVAILABLE_GB}GB)${NC}"

# Check scripts exist
if [ ! -f "$SCRIPT_DIR/download_hidream.sh" ] || [ ! -f "$SCRIPT_DIR/download_flux_encoders.sh" ]; then
    echo -e "${RED}❌ Download scripts not found in $SCRIPT_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Download scripts available${NC}"

echo ""
echo "--- Download Plan ---"
echo ""
echo "This will download:"
echo "  1. HiDream-I1-FP8 checkpoint (~30GB)"
echo "  2. CLIP-L text encoder (~700MB)"
echo "  3. T5-XXL FP16 text encoder (~9GB)"
echo "  4. FLUX VAE (~300MB)"
echo ""
echo -e "${YELLOW}Total download: ~47GB${NC}"
echo -e "${YELLOW}Estimated time: 1-2 hours (depending on connection speed)${NC}"
echo ""
echo "Downloads support resume - you can Ctrl+C and re-run anytime"
echo ""

read -p "Continue with download? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Download cancelled"
    exit 0
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Phase 1: HiDream-I1-FP8 Checkpoint          ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

START_TIME=$(date +%s)

if bash "$SCRIPT_DIR/download_hidream.sh"; then
    echo ""
    echo -e "${GREEN}✅ Phase 1 complete${NC}"
    PHASE1_SUCCESS=1
else
    echo ""
    echo -e "${RED}❌ Phase 1 failed${NC}"
    echo "   Fix errors and re-run: ./scripts/download_all_models.sh"
    exit 1
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Phase 2: FLUX Text Encoders & VAE           ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

if bash "$SCRIPT_DIR/download_flux_encoders.sh"; then
    echo ""
    echo -e "${GREEN}✅ Phase 2 complete${NC}"
    PHASE2_SUCCESS=1
else
    echo ""
    echo -e "${RED}❌ Phase 2 failed${NC}"
    echo "   HiDream model is downloaded, but encoders are missing"
    echo "   Re-run: ./scripts/download_flux_encoders.sh"
    exit 1
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))
DURATION_SEC=$((DURATION % 60))

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           Download Complete!                   ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ All models downloaded successfully${NC}"
echo ""
echo "Download statistics:"
echo "  Time elapsed: ${DURATION_MIN}m ${DURATION_SEC}s"
echo ""

# Show what was downloaded
echo "Downloaded models:"
echo ""

if [ -d "$MODELS_DIR/checkpoints/HiDream-I1-FP8" ]; then
    SIZE=$(du -sh "$MODELS_DIR/checkpoints/HiDream-I1-FP8" | cut -f1)
    echo -e "  ${GREEN}✓${NC} HiDream-I1-FP8: $SIZE"
fi

if [ -f "$MODELS_DIR/clip/clip_l.safetensors" ]; then
    SIZE=$(du -sh "$MODELS_DIR/clip/clip_l.safetensors" | cut -f1)
    echo -e "  ${GREEN}✓${NC} CLIP-L encoder: $SIZE"
fi

if [ -f "$MODELS_DIR/clip/t5xxl_fp16.safetensors" ]; then
    SIZE=$(du -sh "$MODELS_DIR/clip/t5xxl_fp16.safetensors" | cut -f1)
    echo -e "  ${GREEN}✓${NC} T5-XXL FP16 encoder: $SIZE"
fi

if [ -f "$MODELS_DIR/vae/ae.safetensors" ]; then
    SIZE=$(du -sh "$MODELS_DIR/vae/ae.safetensors" | cut -f1)
    echo -e "  ${GREEN}✓${NC} FLUX VAE: $SIZE"
fi

echo ""
TOTAL_SIZE=$(du -sh "$MODELS_DIR" | cut -f1)
echo "Total size: $TOTAL_SIZE"

echo ""
echo "Next steps:"
echo "  1. Verify downloads: ./scripts/verify_all_models.sh"
echo "  2. Clone ComfyUI:    cd ~/LAB/projects && git clone https://github.com/comfyanonymous/ComfyUI.git"
echo "  3. Setup symlinks:   ./scripts/setup_model_symlinks.sh"
echo "  4. Install ComfyUI:  cd ComfyUI && pip install -e ."
echo ""
