# ComfyUI Setup Status

**Last Updated**: 2025-10-05 12:30

## ✅ Completed

1. **Automation Scripts Created** (8 scripts, ~/LAB/projects/ComfyUI/scripts/)
   - ✅ verify_all_models.sh
   - ✅ validate_openwebui_workflow.sh
   - ✅ verify_symlinks.sh
   - ✅ download_hidream.sh
   - ✅ download_flux_encoders.sh
   - ✅ download_all_models.sh
   - ✅ setup_model_symlinks.sh
   - ✅ fix_broken_symlinks.sh

2. **ComfyUI Repository Cloned**
   - Location: ~/LAB/projects/ComfyUI
   - Commit: 187f4369 (latest from comfyanonymous/ComfyUI)

3. **Dependencies Installed**
   - Python venv: .venv/
   - PyTorch: 2.6.0+cu124
   - Packages: 73 total (torch, transformers, safetensors, etc.)

4. **HiDream-I1-FP8 Model Downloaded** ✅
   - Location: /run/media/miko/AYA/model-depot/store/models/comfyui/checkpoints/HiDream-I1-FP8/
   - Size: ~30GB
   - Status: Complete

## ⚠️ Pending

5. **FLUX Encoders Download** ❌ Failed
   - CLIP-L encoder (~700MB)
   - T5-XXL FP16 encoder (~9GB)
   - FLUX VAE (~300MB)
   - **Resume with**: `cd ~/LAB/projects/ComfyUI && bash scripts/download_flux_encoders.sh`

## 📋 Next Steps After Restart

1. **Complete Downloads**
   ```bash
   cd ~/LAB/projects/ComfyUI
   bash scripts/download_flux_encoders.sh  # Resume encoder downloads
   bash scripts/verify_all_models.sh       # Verify all models present
   ```

2. **Setup Symlinks**
   ```bash
   bash scripts/setup_model_symlinks.sh    # Link external storage to ComfyUI
   bash scripts/verify_symlinks.sh         # Verify links valid
   ```

3. **Create Systemd Service**
   - Service file: ~/.config/systemd/user/comfyui.service
   - Bind: 127.0.0.1:8188 (localhost only)
   - GPU: CUDA_VISIBLE_DEVICES=all

4. **Create Workflow**
   - HiDream workflow in API format
   - Empty text fields for OpenWebUI integration
   - Save as: workflows/hidream_t2i_quality_api.json

5. **Configure OpenWebUI**
   - Admin Panel → Settings → Images
   - Add ComfyUI: http://127.0.0.1:8188
   - Upload workflow JSON

## 🔧 Configuration

**Storage Paths:**
- External: `/run/media/miko/AYA/model-depot/store/models/comfyui/`
- Local: `~/LAB/projects/ComfyUI/models/` (symlinks)
- Available: 1.4TB

**Integration Mode:** Native OpenWebUI (via Admin Panel)

**Models:** HiDream-I1-FP8 only (no FLUX.1-dev/schnell for now)

## 📊 Progress

- [x] Automation scripts
- [x] ComfyUI clone
- [x] Dependencies
- [x] HiDream model
- [ ] FLUX encoders (resume needed)
- [ ] Symlinks
- [ ] Systemd service
- [ ] Workflow creation
- [ ] OpenWebUI config
- [ ] End-to-end test

**Estimated Remaining Time**: 1-2 hours
