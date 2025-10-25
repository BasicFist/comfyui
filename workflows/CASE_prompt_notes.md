# CASE Prompt Template Notes

This template follows the Composition / Action / Subject / Environment structure highlighted in the CivitAI “Prompt Notebook” article (ID 3160). Each block collects the minimum necessary tags so the CLIP encoder can stay focused without diluting token weights.

## How to Use the Template

1. **Composition** – keep the lead line focused on global quality, lighting, camera, and art direction. Swap in sampler-friendly cues such as `dramatic lighting`, `wide angle`, or `painterly brushwork` to steer the overall feel.
2. **Action** – describe what the subject is doing with explicit, visual verbs. When experimenting, swap this line first; it has the strongest influence over pose and motion cues.
3. **Subject** – describe identity traits, anatomy, accessories, and expressions. Avoid repeating global style terms here unless they materially change the character.
4. **Environment** – anchor the background, time of day, and atmosphere. This line should capture scene storytelling without re-stating composition details.

Keep the lines short; long comma-separated chains erode attention. When you need variants, duplicate the workflow tab and iterate per line rather than stacking dozens of tokens.

## Negative Prompt Checklist

The companion negative prompt merges the “Quality++” and “Negative+” lists from the same article. Start with the provided set and only add task-specific defects (e.g. `multiple breasts`) when they appear; removing terms keeps contrast high.

## Extending the Workflow

- For style locking, connect an IPAdapter node between the checkpoint loader and KSampler, then feed a reference image captured during your exploration round (CivitAI article 5366).
- To batch scenes, introduce random primitive or wildcard nodes upstream of the CLIP encoders so each CASE line can pull from curated tag lists (CivitAI article 5760).
- Pair this template with the Easy Civitai XT nodes to preview checkpoint/LoRA metadata directly in ComfyUI before swapping models.

### Automation Helpers

- `workflows/recipes/generate_case_prompt.py` clears writer's block: run it with `--seed` (plus `--flat` when pasting straight into CLIP nodes) to sample fresh CASE lines from curated pools. New subcategories cover mood, narrative, body details, accessories, sensory ambience, and the obligatory `Expressiveh` trigger. Use `--style-preset romantic|hardcore|aftercare` to layer scene-wide flavour.
- `workflows/recipes/apply_case_prompt.py --workflow <path>` applies a generated prompt directly to a workflow JSON (defaults to node IDs 6/7 from the template). Add `--output` to keep the original untouched or `--neg-groups` (e.g. `nsfw_cleanup`) when you need extra suppression.
- Mature / explicit flows: pass `--mature` to either helper (or `--mode general mature`) to prioritise the boudoir/NSFW vocabulary while retaining the base tags as fallback.
- Optional negative groups now include `body_artifacts` and `fluid_control` for taming anatomy glitches or messy highlights when explicit renders push the sampler.
- `apply_case_prompt.py` also tweaks the graph: `--lora-strength-model/--lora-strength-clip` adjust ExpressiveH intensity, `--clip-layer` toggles the CLIP stop layer, and `--add-controlnet` wires in a ControlNet loader plus reference image (`--control-image` is copied into `ComfyUI/input/`).

- Available IPAdapter weights: `PLUS (high strength)` (style), `PLUS FACE (portraits)`, and community `Composition` adapter (via `--ipadapter-community`). Models live in `ComfyUI/models/ipadapter/`.
### ExpressiveH LoRA Integration

- Node `12` (LoRALoader) applies `Pony/anime/Expressive_H-000001.safetensors` directly after the checkpoint. Start around `strength_model=0.75` / `strength_clip=0.65`; raise toward 1.0 if you need the full ExpressiveH punch, or drop toward 0.5 for subtler line work. (CivitAI gallery pieces often run 1.7+, but that easily overwhelms Illustrious XL.)
- The template and generator inject the trigger token `Expressiveh` automatically—keep it in the lead composition block for consistent activation.
- Best pairing is Pony Diffusion V6 XL (modelVersion 290640). The template now points `CheckpointLoaderSimple.ckpt_name` to `ponyDiffusionV6XL_v6StartWithThisOne.safetensors`; download that checkpoint into `models/checkpoints/` before running. Illustrious XL remains a workable hybrid interim if you revert the loader.
- When stacking more LoRAs, chain additional `LoraLoader` nodes after ExpressiveH and taper strengths (e.g. ExpressiveH at 0.65, add character LoRA at 0.5) to avoid clip saturation. Use the `body_artifacts` / `fluid_control` negative groups if anatomy or sheen breaks down.

Record interesting line substitutions in `workflows/recipes/` so you can reuse them without bloating the main prompt.

### ControlNet Hook

- The repo includes `OpenPoseXL2.safetensors` (thibaud/controlnet-openpose-sdxl-1.0). Place any additional SDXL ControlNets under `ComfyUI/models/controlnet/` and rerun the helper so the workflow references them.
- Portrait pose PNGs from `posesPacksCollection_portraitV2` are mirrored in `input/pose_library/`; pass any of them via `--control-image input/pose_library/pv2_X.png`.
- Run `apply_case_prompt.py --add-controlnet --controlnet <model.safetensors> --control-image /path/to/reference.png` to clone the workflow with a ControlNet pipeline. The script copies the reference into `ComfyUI/input/` and re-targets the sampler so you can fine-tune strength/start/end inside ComfyUI.
- Swap poses by replacing the file under `ComfyUI/input/` (or rerun the script) and reload; the ControlNet loader caches the selected model for fast iteration.
- For depth/canny maps generated within ComfyUI, drop them into `ComfyUI/input/` and refresh—no graph surgery required.
