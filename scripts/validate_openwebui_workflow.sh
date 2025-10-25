#!/usr/bin/env bash
set -Eeuo pipefail

# ComfyUI Workflow Validation for OpenWebUI Integration
# Purpose: Validate workflow JSON for OpenWebUI compatibility
# Usage: ./validate_openwebui_workflow.sh <workflow.json>

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ $# -eq 0 ]; then
    echo "Usage: $0 <workflow.json>"
    echo ""
    echo "Example: $0 workflows/hidream_t2i_quality_api.json"
    exit 1
fi

WORKFLOW="$1"

if [ ! -f "$WORKFLOW" ]; then
    echo -e "${RED}❌ Workflow file not found: $WORKFLOW${NC}"
    exit 1
fi

echo "=== OpenWebUI Workflow Validation ==="
echo "File: $WORKFLOW"
echo "Date: $(date -Iseconds)"
echo ""

ERRORS=0
WARNINGS=0

# Check 1: Valid JSON syntax
echo "--- Checking JSON Syntax ---"
if jq empty "$WORKFLOW" 2>/dev/null; then
    echo -e "${GREEN}✅ Valid JSON syntax${NC}"
else
    echo -e "${RED}❌ Invalid JSON syntax${NC}"
    jq . "$WORKFLOW" 2>&1 | head -5
    exit 1
fi

# Check 2: Critical - Empty text fields for CLIPTextEncode nodes
echo ""
echo "--- Checking CLIPTextEncode Text Fields (CRITICAL!) ---"

CLIP_NODES=$(jq -r 'to_entries[] | select(.value.class_type == "CLIPTextEncode") | .key' "$WORKFLOW" 2>/dev/null || echo "")

if [ -z "$CLIP_NODES" ]; then
    echo -e "${YELLOW}⚠️  No CLIPTextEncode nodes found${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    NON_EMPTY_COUNT=0
    while IFS= read -r node_id; do
        text_value=$(jq -r ".\"$node_id\".inputs.text" "$WORKFLOW" 2>/dev/null)

        if [ "$text_value" != "" ] && [ "$text_value" != "null" ]; then
            echo -e "${RED}❌ Node $node_id has NON-EMPTY text field: \"$text_value\"${NC}"
            echo "   ⚠️  OpenWebUI prompts will be IGNORED!"
            ERRORS=$((ERRORS + 1))
            NON_EMPTY_COUNT=$((NON_EMPTY_COUNT + 1))
        else
            echo -e "${GREEN}✅ Node $node_id: text field is empty${NC}"
        fi
    done <<< "$CLIP_NODES"

    if [ $NON_EMPTY_COUNT -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Fix: Set text fields to empty string:${NC}"
        echo '  jq '"'"'.["node_id"].inputs.text = ""'"'"' workflow.json > workflow_fixed.json'
    fi
fi

# Check 3: Required nodes present
echo ""
echo "--- Checking Required Nodes ---"

REQUIRED_NODES=("CLIPTextEncode" "KSampler" "SaveImage" "CheckpointLoaderSimple")

for node_type in "${REQUIRED_NODES[@]}"; do
    node_count=$(jq -r "[.[] | select(.class_type == \"$node_type\")] | length" "$WORKFLOW" 2>/dev/null || echo 0)

    if [ "$node_count" -gt 0 ]; then
        echo -e "${GREEN}✅ $node_type: $node_count node(s) found${NC}"
    else
        echo -e "${RED}❌ $node_type: NOT FOUND${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check 4: Node ID mapping compatibility
echo ""
echo "--- Checking Node ID Format ---"

# All keys should be numeric strings
INVALID_IDS=$(jq -r 'keys[] | select(test("^[0-9]+$") | not)' "$WORKFLOW" 2>/dev/null || echo "")

if [ -z "$INVALID_IDS" ]; then
    echo -e "${GREEN}✅ All node IDs are numeric${NC}"
else
    echo -e "${YELLOW}⚠️  Found non-numeric node IDs:${NC}"
    echo "$INVALID_IDS"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 5: Workflow structure
echo ""
echo "--- Workflow Structure ---"

total_nodes=$(jq 'length' "$WORKFLOW" 2>/dev/null || echo 0)
echo "  Total nodes: $total_nodes"

if [ "$total_nodes" -lt 5 ]; then
    echo -e "${YELLOW}⚠️  Workflow has very few nodes (< 5)${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for connections (inputs referencing other nodes)
connected_nodes=$(jq '[.[] | .inputs | to_entries[] | select(.value | type == "array" and (.[0] | type == "string"))] | length' "$WORKFLOW" 2>/dev/null || echo 0)
echo "  Connected inputs: $connected_nodes"

# Check 6: API format vs UI format
echo ""
echo "--- Format Detection ---"

if jq -e '.last_node_id' "$WORKFLOW" >/dev/null 2>&1; then
    echo -e "${RED}❌ This appears to be UI format (has 'last_node_id')${NC}"
    echo "   OpenWebUI requires API format (workflow_api.json from ComfyUI)"
    echo "   Export from: ComfyUI UI → Save (API Format)"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✅ Appears to be API format (correct for OpenWebUI)${NC}"
fi

# Summary
echo ""
echo "--- Summary ---"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ Workflow is valid for OpenWebUI integration!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Workflow has $WARNINGS warning(s) but should work${NC}"
    exit 0
else
    echo -e "${RED}❌ Workflow has $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Critical issues must be fixed before OpenWebUI integration!"
    exit 1
fi
