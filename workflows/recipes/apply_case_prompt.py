#!/usr/bin/env python3
"""
Patch a ComfyUI workflow JSON with CASE prompts generated from the recipe pools.

Usage example:
    ./apply_case_prompt.py --workflow ../illustrious_case_template.json --seed 42
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from typing import Mapping

from generate_case_prompt import generate_prompt, _load_pools  # type: ignore


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Apply a generated CASE prompt to a workflow JSON."
    )
    parser.add_argument(
        "--workflow",
        required=True,
        type=Path,
        help="Path to the ComfyUI workflow JSON.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Optional output path; defaults to updating the workflow in place.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        help="Seed for reproducible sampling.",
    )
    parser.add_argument(
        "--pos-node",
        default="6",
        help="Node id for the positive CLIPTextEncode block.",
    )
    parser.add_argument(
        "--neg-node",
        default="7",
        help="Node id for the negative CLIPTextEncode block.",
    )
    parser.add_argument(
        "--flat",
        action="store_true",
        help="Store prompts without labels (recommended).",
    )
    parser.add_argument(
        "--delimiter",
        default=", ",
        help="Delimiter to join tokens inside each block.",
    )
    parser.add_argument(
        "--neg-groups",
        nargs="*",
        default=[],
        help="Optional negative prompt groups (see generate_case_prompt.py --list).",
    )
    parser.add_argument(
        "--mode",
        nargs="*",
        help="Pool modes to blend (e.g. general mature).",
    )
    parser.add_argument(
        "--mature",
        action="store_true",
        help="Shortcut for blending the mature pool with the general set.",
    )
    parser.add_argument(
        "--style-preset",
        help="Optional style preset for the CASE prompt (e.g. romantic, hardcore, aftercare).",
    )
    parser.add_argument(
        "--add-ipadapter",
        action="store_true",
        help="Insert an IPAdapter loader and apply node into the workflow.",
    )
    parser.add_argument(
        "--ipadapter-preset",
        default="PLUS (high strength)",
        help="Preset name for the IPAdapter unified loader.",
    )
    parser.add_argument(
        "--ipadapter-image",
        help="Reference image for IPAdapter; copied into ComfyUI/input/.",
    )
    parser.add_argument(
        "--ipadapter-weight",
        type=float,
        default=0.85,
        help="IPAdapter weight (default 0.85).",
    )
    parser.add_argument(
        "--ipadapter-weight-type",
        default="style and composition",
        help="IPAdapter weight type (see IPAdapter docs).",
    )
    parser.add_argument(
        "--ipadapter-combine",
        default="average",
        help="IPAdapter combine embeds mode (concat/add/average/etc.).",
    )
    parser.add_argument(
        "--ipadapter-start",
        type=float,
        default=0.0,
        help="IPAdapter start percent (0-1).",
    )
    parser.add_argument(
        "--ipadapter-end",
        type=float,
        default=0.7,
        help="IPAdapter end percent (0-1).",
    )
    parser.add_argument(
        "--ipadapter-embeds",
        default="K+mean(V) w/ C penalty",
        help="IPAdapter embeds scaling option.",
    )
    parser.add_argument(
        "--ipadapter-community",
        action="store_true",
        help="Use IPAdapter community loader presets (Composition, Kolors).",
    )
    parser.add_argument(
        "--ipadapter-community-preset",
        default="Composition",
        help="Community loader preset when --ipadapter-community is used.",
    )
    parser.add_argument(
        "--lora-strength-model",
        type=float,
        help="Override LoRA strength for the diffusion model.",
    )
    parser.add_argument(
        "--lora-strength-clip",
        type=float,
        help="Override LoRA strength for the CLIP encoder.",
    )
    parser.add_argument(
        "--clip-layer",
        type=int,
        help="Set CLIP stop layer (e.g. -2 for Pony XL, -1 for stronger LoRA influence).",
    )
    parser.add_argument(
        "--add-controlnet",
        action="store_true",
        help="Inject a ControlNet pipeline between prompts and sampler.",
    )
    parser.add_argument(
        "--controlnet",
        help="ControlNet model filename (must exist under models/controlnet).",
    )
    parser.add_argument(
        "--control-image",
        help="Path to reference image; will be copied into ComfyUI/input/.",
    )
    parser.add_argument(
        "--control-strength",
        type=float,
        default=0.9,
        help="ControlNet strength (default: 0.9).",
    )
    parser.add_argument(
        "--control-start",
        type=float,
        default=0.0,
        help="ControlNet start percent (0-1).",
    )
    parser.add_argument(
        "--control-end",
        type=float,
        default=1.0,
        help="ControlNet end percent (0-1).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the generated text without writing the workflow.",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    workflow_path: Path = args.workflow
    if not workflow_path.exists():
        raise SystemExit(f"Workflow not found: {workflow_path}")

    modes = args.mode
    if args.mature:
        base_modes = list(modes) if modes else ["general"]
        if "mature" not in base_modes:
            base_modes.append("mature")
        modes = base_modes
    if not modes:
        modes = ["general"]

    pools = _load_pools(modes)
    prompt = generate_prompt(
        pools=pools,
        modes=modes,
        seed=args.seed,
        negative_groups=args.neg_groups,
        style_preset=args.style_preset,
    )
    lines = prompt.as_lines(flat=True, delimiter=args.delimiter)
    positive_text = "\n".join(lines[:4])
    negative_text = lines[4]

    if args.dry_run:
        print("# Positive Prompt")
        print(positive_text)
        print("\n# Negative Prompt")
        print(negative_text)
        return 0

    data: Mapping[str, Mapping] = json.loads(workflow_path.read_text(encoding="utf-8"))
    pos_node = data.get(args.pos_node)
    neg_node = data.get(args.neg_node)
    if not isinstance(pos_node, dict) or pos_node.get("class_type") != "CLIPTextEncode":
        raise SystemExit(f"Node {args.pos_node} is not a CLIPTextEncode block.")
    if not isinstance(neg_node, dict) or neg_node.get("class_type") != "CLIPTextEncode":
        raise SystemExit(f"Node {args.neg_node} is not a CLIPTextEncode block.")

    pos_node = dict(pos_node)
    neg_node = dict(neg_node)
    pos_inputs = dict(pos_node.get("inputs", {}))
    neg_inputs = dict(neg_node.get("inputs", {}))
    pos_inputs["text"] = positive_text
    neg_inputs["text"] = negative_text
    pos_node["inputs"] = pos_inputs
    neg_node["inputs"] = neg_inputs

    data = dict(data)
    data[args.pos_node] = pos_node
    data[args.neg_node] = neg_node

    def find_node_id(class_type: str) -> str | None:
        for node_id, node in data.items():
            if isinstance(node, dict) and node.get("class_type") == class_type:
                return node_id
        return None

    if args.lora_strength_model is not None or args.lora_strength_clip is not None:
        lora_id = find_node_id("LoraLoader")
        if not lora_id:
            raise SystemExit("LoRA loader node not found; cannot set strengths.")
        lora_node = dict(data[lora_id])
        lora_inputs = dict(lora_node.get("inputs", {}))
        if args.lora_strength_model is not None:
            lora_inputs["strength_model"] = args.lora_strength_model
        if args.lora_strength_clip is not None:
            lora_inputs["strength_clip"] = args.lora_strength_clip
        lora_node["inputs"] = lora_inputs
        data[lora_id] = lora_node

    if args.clip_layer is not None:
        clip_id = find_node_id("CLIPSetLastLayer")
        if not clip_id:
            raise SystemExit("CLIPSetLastLayer node not found; cannot set stop layer.")
        clip_node = dict(data[clip_id])
        clip_inputs = dict(clip_node.get("inputs", {}))
        clip_inputs["stop_at_clip_layer"] = args.clip_layer
        clip_node["inputs"] = clip_inputs
        data[clip_id] = clip_node

    if args.add_controlnet:
        if not args.controlnet or not args.control_image:
            raise SystemExit("--add-controlnet requires --controlnet and --control-image")

        control_id = find_node_id("ControlNetLoader")
        image_id = find_node_id("LoadImage")
        apply_id = find_node_id("ControlNetApplyAdvanced")

        existing_ids = {int(k) for k in data.keys()}

        def next_id() -> str:
            new_id = max(existing_ids) + 1 if existing_ids else 1
            existing_ids.add(new_id)
            return str(new_id)

        if not control_id:
            control_id = next_id()
            data[control_id] = {
                "class_type": "ControlNetLoader",
                "inputs": {
                    "control_net_name": args.controlnet
                }
            }
        else:
            control_node = dict(data[control_id])
            control_inputs = dict(control_node.get("inputs", {}))
            control_inputs["control_net_name"] = args.controlnet
            control_node["inputs"] = control_inputs
            data[control_id] = control_node

        input_root = workflow_path.parent.parent / "input"
        input_root.mkdir(exist_ok=True)
        source_image = Path(args.control_image).expanduser()
        if not source_image.exists():
            raise SystemExit(f"Control image not found: {source_image}")
        dest_name = source_image.name
        dest_path = input_root / dest_name
        if source_image.resolve() != dest_path.resolve():
            shutil.copy2(source_image, dest_path)

        if not image_id:
            image_id = next_id()
            data[image_id] = {
                "class_type": "LoadImage",
                "inputs": {
                    "image": dest_name
                }
            }
        else:
            image_node = dict(data[image_id])
            image_inputs = dict(image_node.get("inputs", {}))
            image_inputs["image"] = dest_name
            image_node["inputs"] = image_inputs
            data[image_id] = image_node

        if not apply_id:
            apply_id = next_id()
            data[apply_id] = {
                "class_type": "ControlNetApplyAdvanced",
                "inputs": {
                    "positive": [args.pos_node, 0],
                    "negative": [args.neg_node, 0],
                    "control_net": [control_id, 0],
                    "image": [image_id, 0],
                    "strength": args.control_strength,
                    "start_percent": args.control_start,
                    "end_percent": args.control_end
                }
            }
        else:
            apply_node = dict(data[apply_id])
            apply_inputs = dict(apply_node.get("inputs", {}))
            apply_inputs.update({
                "positive": [args.pos_node, 0],
                "negative": [args.neg_node, 0],
                "control_net": [control_id, 0],
                "image": [image_id, 0],
                "strength": args.control_strength,
                "start_percent": args.control_start,
                "end_percent": args.control_end
            })
            apply_node["inputs"] = apply_inputs
            data[apply_id] = apply_node

        sampler_id = find_node_id("KSampler")
        if not sampler_id:
            raise SystemExit("KSampler node not found; cannot insert ControlNet.")
        sampler_node = dict(data[sampler_id])
        sampler_inputs = dict(sampler_node.get("inputs", {}))
        sampler_inputs["positive"] = [apply_id, 0]
        sampler_inputs["negative"] = [apply_id, 1]
        sampler_node["inputs"] = sampler_inputs
        data[sampler_id] = sampler_node

    if args.add_ipadapter:
        if not args.ipadapter_image:
            raise SystemExit("--add-ipadapter requires --ipadapter-image")
        lora_id = find_node_id("LoraLoader")
        if not lora_id:
            raise SystemExit("LoRA loader node not found; cannot add IPAdapter.")
        input_root = workflow_path.parent.parent / "input"
        input_root.mkdir(exist_ok=True)
        source_image = Path(args.ipadapter_image).expanduser()
        if not source_image.exists():
            raise SystemExit(f"IPAdapter image not found: {source_image}")
        dest_path = input_root / source_image.name
        if source_image.resolve() != dest_path.resolve():
            shutil.copy2(source_image, dest_path)
        dest_name = dest_path.name

        existing_ids = {int(k) for k in data.keys()}

        def next_id():
            new_id = max(existing_ids) + 1 if existing_ids else 1
            existing_ids.add(new_id)
            return str(new_id)

        loader_class = "IPAdapterUnifiedLoaderCommunity" if args.ipadapter_community else "IPAdapterUnifiedLoader"
        loader_id = None
        for node_id, node in data.items():
            if isinstance(node, dict) and node.get("class_type") == loader_class:
                loader_id = node_id
                break
        loader_inputs = {"model": [lora_id, 0]}
        if loader_class == "IPAdapterUnifiedLoaderCommunity":
            loader_inputs["preset"] = args.ipadapter_community_preset
        else:
            loader_inputs["preset"] = args.ipadapter_preset
        if loader_id:
            loader_node = dict(data[loader_id])
            loader_node["inputs"] = loader_inputs
            data[loader_id] = loader_node
        else:
            loader_id = next_id()
            data[loader_id] = {"class_type": loader_class, "inputs": loader_inputs}

        image_id = next_id()
        data[image_id] = {"class_type": "LoadImage", "inputs": {"image": dest_name}}

        advanced_id = find_node_id("IPAdapterAdvanced")
        advanced_inputs = {
            "model": [loader_id, 0],
            "ipadapter": [loader_id, 1],
            "image": [image_id, 0],
            "weight": args.ipadapter_weight,
            "weight_type": args.ipadapter_weight_type,
            "combine_embeds": args.ipadapter_combine,
            "start_at": args.ipadapter_start,
            "end_at": args.ipadapter_end,
            "embeds_scaling": args.ipadapter_embeds,
        }
        if advanced_id:
            advanced_node = dict(data[advanced_id])
            advanced_node["inputs"] = advanced_inputs
            data[advanced_id] = advanced_node
        else:
            advanced_id = next_id()
            data[advanced_id] = {"class_type": "IPAdapterAdvanced", "inputs": advanced_inputs}

        sampler_id = find_node_id("KSampler")
        if not sampler_id:
            raise SystemExit("KSampler node not found; cannot add IPAdapter.")
        sampler_node = dict(data[sampler_id])
        sampler_inputs = dict(sampler_node.get("inputs", {}))
        sampler_inputs["model"] = [advanced_id, 0]
        sampler_node["inputs"] = sampler_inputs
        data[sampler_id] = sampler_node

    output_path = args.output or workflow_path
    output_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"Updated workflow saved to {output_path}")
    return 0


if __name__ == "__main__":  # pragma: no cover - CLI entrypoint
    raise SystemExit(main())
