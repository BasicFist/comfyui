#!/usr/bin/env bash
set -Eeuo pipefail

# ComfyUI Broken Symlink Repair Script
# Purpose: Detect and remove broken symlinks
# Usage: ./fix_broken_symlinks.sh

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

COMFYUI_ROOT="$HOME/LAB/projects/ComfyUI"
MODELS_LOCAL="$COMFYUI_ROOT/models"

echo "=== ComfyUI Broken Symlink Repair ==="
echo "Date: $(date -Iseconds)"
echo ""

if [ ! -d "$MODELS_LOCAL" ]; then
    echo -e "${RED}❌ Models directory not found: $MODELS_LOCAL${NC}"
    echo "   Run setup_model_symlinks.sh first"
    exit 1
fi

echo "Scanning: $MODELS_LOCAL"
echo ""

# Find all broken symlinks
BROKEN_LINKS=$(find "$MODELS_LOCAL" -type l ! -exec test -e {} \; -print 2>/dev/null || echo "")

if [ -z "$BROKEN_LINKS" ]; then
    echo -e "${GREEN}✅ No broken symlinks found${NC}"
    exit 0
fi

echo -e "${YELLOW}⚠️  Found broken symlinks:${NC}"
echo ""

COUNT=0
while IFS= read -r broken_link; do
    COUNT=$((COUNT + 1))
    TARGET=$(readlink "$broken_link" 2>/dev/null || echo "unknown")
    echo "  $COUNT. $broken_link"
    echo "      → $TARGET (missing)"
done <<< "$BROKEN_LINKS"

echo ""
echo "Total broken symlinks: $COUNT"
echo ""

read -p "Remove all broken symlinks? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "No changes made"
    exit 0
fi

echo ""
echo "--- Removing Broken Symlinks ---"
echo ""

REMOVED=0
while IFS= read -r broken_link; do
    if rm "$broken_link"; then
        echo -e "${GREEN}✅ Removed: $broken_link${NC}"
        REMOVED=$((REMOVED + 1))
    else
        echo -e "${RED}❌ Failed to remove: $broken_link${NC}"
    fi
done <<< "$BROKEN_LINKS"

echo ""
echo "--- Summary ---"

echo "Removed $REMOVED broken symlink(s)"
echo ""
echo "Next steps:"
echo "  1. Recreate symlinks: ./scripts/setup_model_symlinks.sh"
echo "  2. Verify: ./scripts/verify_symlinks.sh"
