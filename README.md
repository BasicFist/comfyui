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
    - `illustrious_case_romantic.json` – romantic preset without ControlNet for softer compositions.
    - `illustrious_case_aftercare.json` – aftercare portrait using the IPAdapter Plus Face preset.
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

## Step-by-Step Guide

Below is the exact sequence used to build this workspace from a vanilla ComfyUI clone. Run commands from the repository root unless noted.

1. **Install IPAdapter+ and supporting managers**
   ```bash
   git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus custom_nodes/ComfyUI_IPAdapter_plus
   git clone https://github.com/ltdrdata/ComfyUI-Manager custom_nodes/ComfyUI-Manager
   git clone https://github.com/willmiao/ComfyUI-Lora-Manager custom_nodes/ComfyUI-Lora-Manager
   git clone https://github.com/kohya-ss/ComfyUI-EasyCivitai-XTNodes custom_nodes/ComfyUI-EasyCivitai-XTNodes
   ```
   Remove nested `.git` folders so the node suites live directly inside this repository.

2. **Download large model assets (kept out of Git)**
   - Optional pose libraries can be unzipped into `ComfyUI/input/pose_library/` (e.g. `posesPacksCollection_portraitV2`); the helper scripts will accept them via `--control-image`.
   ```bash
   # SDXL IPAdapter weights
   curl -L -o models/ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors \
        https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors
   curl -L -o models/ipadapter/ip-adapter-plus-face_sdxl_vit-h.safetensors \
        https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus-face_sdxl_vit-h.safetensors
   curl -L -o models/ipadapter/ip_plus_composition_sdxl.safetensors \
        https://huggingface.co/ostris/ip-composition-adapter/resolve/main/ip_plus_composition_sdxl.safetensors

   # CLIP vision encoders for SDXL IPAdapter
   curl -L -o models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors \
        https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors
   curl -L -o models/clip_vision/CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors \
        https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors

   # SDXL OpenPose ControlNet
   curl -L -o models/controlnet/OpenPoseXL2.safetensors \
        https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors
   ```
   Place checkpoints (Pony Diffusion V6 XL, ExpressiveH LoRA, etc.) inside the existing `models/` subdirectories.

3. **Update CASE prompt tooling** – edit the files under `workflows/recipes/`:
   - `case_prompt_pools.json`: add mature vocabulary and style presets.
   - `generate_case_prompt.py`: expose `--style-preset` and bias sampling toward the chosen modes.
   - `apply_case_prompt.py`: add LoRA/CLIP tuning, ControlNet, and IPAdapter automation flags.

4. **Create tailored workflows** – start from `workflows/illustrious_case_template.json` and run:
   ```bash
   workflows/recipes/apply_case_prompt.py \
     --workflow workflows/illustrious_case_template.json \
     --output workflows/my_explicit_scene.json \
     --style-preset hardcore --mature \
     --neg-groups body_artifacts fluid_control \
     --add-ipadapter --ipadapter-image ComfyUI/output/openwebui_00001_.png \
     --ipadapter-weight 0.9 --ipadapter-end 0.65 \
     --add-controlnet --controlnet OpenPoseXL2.safetensors \
     --control-image ComfyUI/input/control_reference.png
   ```
   The helper copies referenced images into `ComfyUI/input/` and rewires the sampler/conditioners.

5. **Document and commit** – update `.gitignore`, add README notes, then commit & push to GitHub.

Following these steps reproduces the configuration committed here from scratch.

## Recommended CivitAI References

- [Prompt Notebook](https://civitai.com/articles/3160/prompt-notebook)
- [ComfyUI Workflow: Study Case](https://civitai.com/articles/5366/comfyui-workflow-study-case)
- [Scene Composer: Overview & Usecases](https://civitai.com/articles/5760/comfyui-workflow-scene-composer)
- [OpenPose NSFW Pose Pack (Portrait V2)](https://civitai.com/models/574236) – portrait pose library unzipped into `ComfyUI/input/pose_library/`.

Explore the CivitAI workflows tab for additional explicit-focused templates (search terms like "Illustrious", "Pony", or "NSFW ComfyUI").


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

