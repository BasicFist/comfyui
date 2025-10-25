#!/usr/bin/env bash
set -Eeuo pipefail

# ComfyUI Symlink Verification Script
# Purpose: Verify all symlinks to external storage are valid
# Usage: ./verify_symlinks.sh

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

MODELS_EXTERNAL="/run/media/miko/AYA/model-depot/store/models/comfyui"
MODELS_LOCAL="$HOME/LAB/projects/ComfyUI/models"

echo "=== ComfyUI Symlink Verification ==="
echo "Date: $(date -Iseconds)"
echo ""

ERRORS=0
WARNINGS=0

# Check if local models directory exists
if [ ! -d "$MODELS_LOCAL" ]; then
    echo -e "${YELLOW}⚠️  Local models directory does not exist: $MODELS_LOCAL${NC}"
    echo "   Run setup_model_symlinks.sh to create it"
    exit 1
fi

echo "Models directory: $MODELS_LOCAL"
echo ""

# Function to check symlink
check_symlink() {
    local link_path="$1"
    local link_name="$2"
    local expected_target="$3"

    if [ ! -e "$link_path" ] && [ ! -L "$link_path" ]; then
        echo -e "${YELLOW}⚠️  $link_name: NOT FOUND${NC}"
        echo "   Expected: $link_path → $expected_target"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi

    if [ ! -L "$link_path" ]; then
        echo -e "${RED}❌ $link_name: EXISTS but is NOT a symlink${NC}"
        echo "   Path: $link_path"
        echo "   This will prevent external storage usage"
        ERRORS=$((ERRORS + 1))
        return 1
    fi

    local target=$(readlink -f "$link_path")

    if [ ! -e "$target" ]; then
        echo -e "${RED}❌ $link_name: BROKEN symlink${NC}"
        echo "   Link: $link_path"
        echo "   Target: $target (does not exist)"
        ERRORS=$((ERRORS + 1))
        return 1
    fi

    if [ "$target" != "$expected_target" ]; then
        echo -e "${YELLOW}⚠️  $link_name: Points to unexpected location${NC}"
        echo "   Link: $link_path"
        echo "   Current: $target"
        echo "   Expected: $expected_target"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi

    # Check if target is accessible and has content
    local item_count=$(ls -A "$target" 2>/dev/null | wc -l)

    if [ "$item_count" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  $link_name: Valid symlink but target is EMPTY${NC}"
        echo "   Target: $target"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}✅ $link_name: Valid symlink ($item_count items)${NC}"
        echo "   → $target"
    fi

    return 0
}

echo "--- Checking Critical Symlinks ---"
echo ""

check_symlink "$MODELS_LOCAL/checkpoints" "checkpoints" "$MODELS_EXTERNAL/checkpoints"
check_symlink "$MODELS_LOCAL/clip" "clip" "$MODELS_EXTERNAL/clip"
check_symlink "$MODELS_LOCAL/vae" "vae" "$MODELS_EXTERNAL/vae"
check_symlink "$MODELS_LOCAL/unet" "unet" "$MODELS_EXTERNAL/unet"

echo ""
echo "--- Scanning for Broken Symlinks ---"

BROKEN_LINKS=$(find "$MODELS_LOCAL" -type l ! -exec test -e {} \; -print 2>/dev/null || echo "")

if [ -z "$BROKEN_LINKS" ]; then
    echo -e "${GREEN}✅ No broken symlinks found${NC}"
else
    echo -e "${RED}❌ Found broken symlinks:${NC}"
    while IFS= read -r broken_link; do
        target=$(readlink "$broken_link")
        echo "   $broken_link → $target"
        ERRORS=$((ERRORS + 1))
    done <<< "$BROKEN_LINKS"
fi

echo ""
echo "--- External Storage Status ---"

if [ -d "$MODELS_EXTERNAL" ]; then
    df -h "$MODELS_EXTERNAL" | grep -v Filesystem
    echo ""

    # Show what's in external storage
    echo "External storage contents:"
    for dir in checkpoints clip vae unet; do
        if [ -d "$MODELS_EXTERNAL/$dir" ]; then
            count=$(ls -A "$MODELS_EXTERNAL/$dir" 2>/dev/null | wc -l)
            size=$(du -sh "$MODELS_EXTERNAL/$dir" 2>/dev/null | cut -f1)
            echo "  $dir/: $count items, $size"
        fi
    done
else
    echo -e "${RED}❌ External storage not accessible: $MODELS_EXTERNAL${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "--- Summary ---"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All symlinks are valid!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Found $WARNINGS warning(s)${NC}"
    echo ""
    echo "Symlinks are functional but may need attention"
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Fixes:"
    if [ -n "$BROKEN_LINKS" ]; then
        echo "  • Remove broken symlinks: ./scripts/fix_broken_symlinks.sh"
    fi
    echo "  • Recreate symlinks: ./scripts/setup_model_symlinks.sh"
    echo "  • Re-verify: ./scripts/verify_symlinks.sh"
    exit 1
fi
