# OpenWebUI + ComfyUI Native Integration Guide

**Status**: ✅ ComfyUI Running on http://127.0.0.1:8188
**Date**: 2025-10-06
**Workflow**: openwebui_basic_api.json

---

## Quick Start (5 Minutes)

### Step 1: Access OpenWebUI Admin Panel

1. Open OpenWebUI: http://localhost:5000
2. Click your profile icon (top right)
3. Navigate to: **Admin Panel** → **Settings** → **Images**

### Step 2: Configure ComfyUI Integration

In the **Images** settings page:

**Image Generation Engine**: Select `ComfyUI`

**API Base URL**: 
```
http://127.0.0.1:8188
```

**Workflow Upload**:
- Click "Upload Workflow" button
- Select file: `/home/miko/LAB/projects/ComfyUI/workflows/openwebui_basic_api.json`
- Workflow will be auto-validated

### Step 3: Map Node IDs

After uploading the workflow, configure these node mappings:

| Setting | Node ID | Description |
|---------|---------|-------------|
| **Prompt Node ID** | `6` | Positive prompt (CLIPTextEncode) |
| **Negative Prompt Node ID** | `7` | Negative prompt (CLIPTextEncode) |
| **Seed Node ID** | `3` | Random seed (KSampler) |
| **Steps Node ID** | `3` | Generation steps (KSampler) |
| **CFG Node ID** | `3` | CFG scale (KSampler) |
| **Sampler Node ID** | `3` | Sampler name (KSampler) |
| **Scheduler Node ID** | `3` | Scheduler (KSampler) |
| **Width Node ID** | `5` | Image width (EmptyLatentImage) |
| **Height Node ID** | `5` | Image height (EmptyLatentImage) |

### Step 4: Test Image Generation

In any OpenWebUI chat:

```
Generate an image of a majestic dragon flying over snow-capped mountains, photorealistic, detailed
```

Expected behavior:
- ⏱️ Generation time: ~30-60 seconds (first run may be slower due to model loading)
- 📸 Image size: 1024x1024px
- 💾 Saved to: `/home/miko/LAB/projects/ComfyUI/output/openwebui_*.png`

---

## Workflow Details

### Node Structure

```
CheckpointLoader (10) → HiDream-I1-FP8
         ↓
CLIPTextEncode (6)   → Positive prompt (user input)
CLIPTextEncode (7)   → Negative prompt (fixed)
         ↓
EmptyLatentImage (5) → 1024x1024
         ↓
KSampler (3)         → 20 steps, CFG 7.0, Euler sampler
         ↓
VAEDecode (8)        → Latent to image
         ↓
SaveImage (9)        → Save to output/
```

### Key Parameters

| Parameter | Default | Editable via OpenWebUI |
|-----------|---------|------------------------|
| Model | HiDream-I1-FP8 | ❌ No (fixed in workflow) |
| Steps | 20 | ✅ Yes (via Steps field) |
| CFG Scale | 7.0 | ✅ Yes (via CFG field) |
| Sampler | euler | ✅ Yes (via Sampler dropdown) |
| Scheduler | normal | ✅ Yes (via Scheduler dropdown) |
| Width/Height | 1024x1024 | ✅ Yes (via Width/Height fields) |
| Seed | Random | ✅ Yes (via Seed field, -1 = random) |

---

## Advanced Configuration (Optional)

### Customize Negative Prompt

Edit `openwebui_basic_api.json`, find node `7`:

```json
"7": {
  "class_type": "CLIPTextEncode",
  "inputs": {
    "text": "YOUR CUSTOM NEGATIVE PROMPT HERE",
    "clip": ["10", 1]
  }
}
```

Re-upload workflow to OpenWebUI.

### Change Default Image Size

Edit node `5`:

```json
"5": {
  "class_type": "EmptyLatentImage",
  "inputs": {
    "width": 1280,   // Change this
    "height": 768,   // And this
    "batch_size": 1
  }
}
```

**Recommended Sizes** (for 16GB VRAM):
- **Standard**: 1024x1024 (default)
- **Landscape**: 1280x768
- **Portrait**: 768x1280
- **Widescreen**: 1536x640

### Increase Quality (Slower)

Edit node `3`, increase steps:

```json
"3": {
  "class_type": "KSampler",
  "inputs": {
    "steps": 40,  // Default: 20, Higher = better quality but slower
    "cfg": 8.0,   // Default: 7.0, Higher = more prompt adherence
    ...
  }
}
```

**Performance Impact**:
- 20 steps: ~30s
- 40 steps: ~60s
- 60 steps: ~90s

---

## Troubleshooting

### "ComfyUI server not responding"

**Check service status**:
```bash
systemctl --user status comfyui.service
```

**Verify port listening**:
```bash
ss -tlnp | grep 8188
# Should show: LISTEN 127.0.0.1:8188
```

**Check logs**:
```bash
journalctl --user -u comfyui.service -f
```

**Restart service**:
```bash
systemctl --user restart comfyui.service
```

### "Model not found: HiDream-I1-FP8"

**Verify model symlink**:
```bash
ls -la ~/LAB/projects/ComfyUI/models/checkpoints/
# Should show: HiDream-I1-FP8 -> /run/media/miko/AYA/...
```

**Fix symlink** (if broken):
```bash
cd ~/LAB/projects/ComfyUI/models/checkpoints
ln -sf /run/media/miko/AYA/model-depot/store/models/comfyui/checkpoints/HiDream-I1-FP8 .
```

### "CUDA out of memory"

HiDream requires ~15-16GB VRAM. Free up GPU memory:

```bash
# Stop llama.cpp (frees ~1.8GB)
systemctl --user stop llamacpp-python.service

# Verify VRAM
nvidia-smi
# Should show: ~13-14GB used by ComfyUI

# Restart llama.cpp when done
systemctl --user start llamacpp-python.service
```

### Image generation very slow (>2 minutes)

**Check GPU usage**:
```bash
nvidia-smi
# GPU-Util should be 90-100% during generation
```

**If GPU-Util is low** (model loading on CPU):
```bash
journalctl --user -u comfyui.service | grep -i "cpu\|cuda"
# Should show: "Device: cuda:0 Quadro RTX 5000"
```

**Restart service** to reload GPU:
```bash
systemctl --user restart comfyui.service
```

---

## Service Management

### Start/Stop ComfyUI

```bash
# Start
systemctl --user start comfyui.service

# Stop
systemctl --user stop comfyui.service

# Restart
systemctl --user restart comfyui.service

# Status
systemctl --user status comfyui.service
```

### Auto-start on Boot

```bash
# Enable (already done)
systemctl --user enable comfyui.service

# Disable
systemctl --user disable comfyui.service
```

### View Logs

```bash
# Follow live logs
journalctl --user -u comfyui.service -f

# Last 50 lines
journalctl --user -u comfyui.service -n 50

# Today's logs
journalctl --user -u comfyui.service --since today
```

---

## Performance Tips

### Optimal Settings for 16GB VRAM

| Scenario | Steps | CFG | Size | Expected Time |
|----------|-------|-----|------|---------------|
| **Quick Draft** | 15-20 | 6.0-7.0 | 768x768 | ~20-30s |
| **Balanced** (default) | 20-25 | 7.0-8.0 | 1024x1024 | ~30-45s |
| **High Quality** | 40-50 | 8.0-9.0 | 1024x1024 | ~60-90s |
| **Maximum Detail** | 60-80 | 9.0-10.0 | 1280x1280 | ~2-3min |

### GPU Temperature Monitoring

```bash
# Real-time monitoring
watch -n1 nvidia-smi

# Temperature alert (>80°C)
nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader
```

---

## Next Steps

After confirming basic integration works:

1. **Create custom workflows** for different styles
   - See: `docs/comfyui/WORKFLOW-GUIDE.md`

2. **Add ComfyUI pipeline** for advanced control
   - See: `docs/comfyui/INTEGRATION-PATTERNS.md` (Pattern 2)

3. **Optimize model loading** with LoRAs
   - See: `docs/comfyui/MODEL-MANAGEMENT.md`

4. **Add monitoring to health checks**
   - Add ComfyUI to `scripts/health_check.sh`

---

## Quick Reference

**ComfyUI Web UI**: http://127.0.0.1:8188
**OpenWebUI**: http://localhost:5000
**Workflow File**: `/home/miko/LAB/projects/ComfyUI/workflows/openwebui_basic_api.json`
**Output Directory**: `/home/miko/LAB/projects/ComfyUI/output/`
**Service Name**: `comfyui.service`

---

**Last Updated**: 2025-10-06
**Status**: ✅ Ready for Integration
**Next**: Configure OpenWebUI Admin Panel
