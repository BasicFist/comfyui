# CumfyUI Workflow Enhancements

This repository hosts a tuned ComfyUI workspace optimized for explicit/mature image generation workflows. It includes ready-to-run nodes, scripts, and reference workflows focused on IPAdapter, ControlNet, and CASE-prompt tooling.

## Contents

- `custom_nodes/ComfyUI_IPAdapter_plus/`
  - Upstream IPAdapter+ extension for style/subject transfer.
  - Additional SDXL models downloaded into `ComfyUI/models/ipadapter/`:
    - `ip-adapter-plus_sdxl_vit-h.safetensors`
    - `ip-adapter-plus-face_sdxl_vit-h.safetensors`
    - `ip_plus_composition_sdxl.safetensors`
- `custom_nodes/ComfyUI-Manager/`, `ComfyUI-Lora-Manager/`, `ComfyUI-EasyCivitai-XTNodes/`
  - Utilities for model management within ComfyUI.

- `models/` *(ignored by Git)*
  - Large assets, including checkpoints, CLIP vision encoders, ControlNet weights.
  - Currently populated with:
    - `models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors`
    - `models/clip_vision/CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors`
    - `models/ipadapter` weights listed above.
    - `models/controlnet/OpenPoseXL2.safetensors` (SDXL openpose ControlNet)

- `workflows/`
  - Ready-to-run JSON workflows and recipe scripts.
  - Key entries:
    - `illustrious_case_template.json` – base workflow anchored on Pony Diffusion V6 XL + ExpressiveH.
    - `illustrious_case_ipadapter.json`, `illustrious_case_ipadapter_controlnet.json`, `my_explicit_scene.json` – generated variants demonstrating IPAdapter & ControlNet integrations.
    - `recipes/case_prompt_pools.json` – curated CASE vocab and style presets.
    - `recipes/generate_case_prompt.py` – CLI helper for building CASE prompts (`--style-preset romantic|hardcore|aftercare`).
    - `recipes/apply_case_prompt.py` – workflow patcher with flags:
      - `--style-preset`, `--mature`, `--neg-groups ...`
      - `--add-ipadapter`, `--ipadapter-image`, `--ipadapter-weight`, `--ipadapter-community`
      - `--add-controlnet`, `--controlnet`, `--control-image`, strength/start/end windows
      - LoRA/CLIP tuning (`--lora-strength-model`, `--lora-strength-clip`, `--clip-layer`)

- `workflows/CASE_prompt_notes.md`
  - Documentation on CASE prompting, style presets, LoRA and ControlNet usage.
  - Highlights command examples and locations for necessary assets.

- `scripts/`
  - Helper shell scripts from upstream ComfyUI for downloading or verifying models.

- `user/`
  - Per-ComfyUI settings/database (included for completeness).

## Quick Start

1. Install dependencies (Python, ComfyUI runtime) per upstream ComfyUI instructions or use the provided scripts.
2. Populate `ComfyUI/models/` with checkpoints/LoRAs as needed (see `.gitignore` for directories expected to remain local).
3. Generate a workflow tailored to your references:
   ```bash
   workflows/recipes/apply_case_prompt.py \
     --workflow workflows/illustrious_case_template.json \
     --output workflows/my_scene.json \
     --style-preset hardcore --mature \
     --neg-groups body_artifacts fluid_control \
     --add-ipadapter --ipadapter-image /path/to/style.png \
     --ipadapter-weight 0.9 --ipadapter-end 0.65 \
     --add-controlnet --controlnet OpenPoseXL2.safetensors \
     --control-image /path/to/pose.png
   ```
4. Import the resulting JSON in ComfyUI and tweak LoRA/IPAdapter/ControlNet weights via the node UI.

## Notes

- Large assets (`*.safetensors`, checkpoints, embeddings, etc.) are ignored from Git and must be downloaded manually with the provided scripts or commands.
- Macro-level `gitignore` excludes output/input directories to keep repo size manageable.
- The commit history includes the full ComfyUI node suites cloned from upstream repositories.
- Ensure you have appropriate hardware (GPU with sufficient VRAM) for SDXL checkpoints and IPAdapter operations.

