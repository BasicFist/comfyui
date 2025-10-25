#!/usr/bin/env python3
"""
Generate CASE-structured prompts aligned with CivitAI creative freedom guidance.

Sources:
- Prompt Notebook (CivitAI article 3160): introduces CASE and minimal tagging.
- ComfyUI Workflow Study Case (article 5366): emphasizes iterative style locking.
- Scene Composer Overview (article 5760): recommends variable-driven scene swaps.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Mapping, Sequence


def _load_pools(modes: Sequence[str] | None = None) -> Mapping[str, object]:
    pools_path = Path(__file__).with_name("case_prompt_pools.json")
    try:
        data = json.loads(pools_path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:  # pragma: no cover - guard for manual use
        raise SystemExit(f"Pool file not found: {pools_path}") from exc

    sets = data.get("sets")
    if not sets:
        return data

    if not modes:
        modes = ("general",)

    combined: Dict[str, Dict[str, List[str]]] = {}
    sources: Dict[str, Dict[str, Dict[str, List[str]]]] = {}

    def merge_section(
        section_name: str, additions: Mapping[str, List[str]], mode_name: str
    ) -> None:
        dest_section = combined.setdefault(section_name, {})
        source_section = sources.setdefault(section_name, {})
        for key, values in additions.items():
            dest_list = dest_section.setdefault(key, [])
            source_modes = source_section.setdefault(key, {})
            mode_list = source_modes.setdefault(mode_name, [])
            for value in values:
                if value not in dest_list:
                    dest_list.append(value)
                if value not in mode_list:
                    mode_list.append(value)

    for mode in modes:
        try:
            additions = sets[mode]
        except KeyError as exc:
            raise SystemExit(f"Pool mode '{mode}' not found in {pools_path}") from exc
        for section_name, section_values in additions.items():
            merge_section(section_name, section_values, mode)

    combined["negative_base"] = list(data["negative_base"])
    combined["negative_optional"] = data["negative_optional"]
    combined["style_presets"] = data.get("style_presets", {})
    combined["_sources"] = sources
    return combined


def _parse_overrides(values: Iterable[str], subcategories: Iterable[str]) -> Dict[str, int]:
    if not values:
        return {}
    overrides: Dict[str, int] = {}
    valid = set(subcategories)
    for pair in values:
        if "=" not in pair:
            raise SystemExit(f"Invalid override '{pair}'. Use key=value syntax.")
        key, raw = pair.split("=", 1)
        key = key.strip()
        if key not in valid:
            raise SystemExit(f"Unknown subcategory '{key}'. Valid keys: {sorted(valid)}")
        try:
            overrides[key] = max(0, int(raw))
        except ValueError as exc:
            raise SystemExit(f"Override '{pair}' must be an integer.") from exc
    return overrides


def _pick_items(options: Sequence[str], count: int, preferred: Sequence[str]) -> List[str]:
    if count <= 0:
        return []
    chosen: List[str] = []
    available_preferred = [item for item in preferred if item in options]
    if available_preferred:
        take = min(count, len(available_preferred))
        chosen.extend(random.sample(available_preferred, take))
        count -= take
    if count <= 0:
        return chosen
    remaining_pool = [item for item in options if item not in chosen]
    if not remaining_pool:
        return chosen
    if count >= len(remaining_pool):
        chosen.extend(remaining_pool)
    else:
        chosen.extend(random.sample(remaining_pool, count))
    return chosen


def _sample_section(
    section: Mapping[str, List[str]],
    overrides: Mapping[str, int],
    default: int,
    preferred: Mapping[str, Sequence[str]] | None = None,
) -> List[str]:
    selections: List[str] = []
    for key, options in section.items():
        count = overrides.get(key, default)
        if count <= 0:
            continue
        pref_values = []
        if preferred:
            pref_values = list(preferred.get(key, []))
        selections.extend(_pick_items(options, count, pref_values))
    return selections


def _format_line(name: str, items: Sequence[str], flat: bool, delimiter: str) -> str:
    joined = delimiter.join(items)
    return f"{name}: {joined}" if not flat else joined


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Produce CASE prompts with optional randomisation.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--seed", type=int, help="Seed for reproducible sampling.")
    parser.add_argument(
        "--composition",
        nargs="*",
        help="Overrides (e.g. quality=2 lighting=1).",
    )
    parser.add_argument("--action", nargs="*", help="Overrides for action subcategories.")
    parser.add_argument("--subject", nargs="*", help="Overrides for subject subcategories.")
    parser.add_argument(
        "--environment", nargs="*", help="Overrides for environment subcategories."
    )
    parser.add_argument(
        "--flat",
        action="store_true",
        help="Emit prompts without headers, ready for CLIP input.",
    )
    parser.add_argument(
        "--delimiter",
        default=", ",
        help="Delimiter used when joining tokens inside each CASE block.",
    )
    parser.add_argument(
        "--neg-groups",
        nargs="*",
        default=[],
        help="Optional negative prompt groups to include (comma separated).",
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
        help="Optional style preset name (e.g. romantic, hardcore, aftercare).",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List available subcategories and exit.",
    )
    return parser


@dataclass(frozen=True)
class CasePrompt:
    composition: Sequence[str]
    action: Sequence[str]
    subject: Sequence[str]
    environment: Sequence[str]
    negatives: Sequence[str]

    def as_lines(self, flat: bool, delimiter: str) -> List[str]:
        lines = [
            _format_line("Composition", self.composition, flat=flat, delimiter=delimiter),
            _format_line("Action", self.action, flat=flat, delimiter=delimiter),
            _format_line("Subject", self.subject, flat=flat, delimiter=delimiter),
            _format_line(
                "Environment", self.environment, flat=flat, delimiter=delimiter
            ),
        ]
        neg_label = "" if flat else "Negative Prompt"
        lines.append(_format_line(neg_label, self.negatives, flat=flat, delimiter=delimiter))
        return lines


def generate_prompt(  # noqa: PLR0913 - intentional explicit signature for CLI use
    *,
    pools: Mapping[str, object] | None = None,
    modes: Sequence[str] | None = None,
    seed: int | None = None,
    composition_overrides: Mapping[str, int] | None = None,
    action_overrides: Mapping[str, int] | None = None,
    subject_overrides: Mapping[str, int] | None = None,
    environment_overrides: Mapping[str, int] | None = None,
    negative_groups: Sequence[str] | None = None,
    style_preset: str | None = None,
    default_count: int = 1,
) -> CasePrompt:
    """Produce a CASE prompt bundle using the configured pools."""

    pools = pools or _load_pools(modes)
    sources = pools.get("_sources", {})
    preferred_modes = [mode for mode in modes or [] if mode != "general"]

    def build_preferred(section_name: str) -> Dict[str, List[str]]:
        if not preferred_modes:
            return {}
        section_sources = sources.get(section_name, {})
        preferred_map: Dict[str, List[str]] = {}
        for key, mode_map in section_sources.items():
            selections: List[str] = []
            for mode in preferred_modes:
                selections.extend(mode_map.get(mode, []))
            if selections:
                preferred_map[key] = selections
        return preferred_map

    composition_pref = build_preferred("composition")
    action_pref = build_preferred("action")
    subject_pref = build_preferred("subject")
    environment_pref = build_preferred("environment")

    if seed is not None:
        random.seed(seed)

    composition = _sample_section(
        pools["composition"],
        composition_overrides or {},
        default=default_count,
        preferred=composition_pref,
    )
    action = _sample_section(
        pools["action"],
        action_overrides or {},
        default=default_count,
        preferred=action_pref,
    )
    subject = _sample_section(
        pools["subject"],
        subject_overrides or {},
        default=default_count,
        preferred=subject_pref,
    )
    environment = _sample_section(
        pools["environment"],
        environment_overrides or {},
        default=default_count,
        preferred=environment_pref,
    )

    preset_data = None
    if style_preset:
        presets = pools.get("style_presets", {})
        if style_preset not in presets:
            raise KeyError(f"Unknown style preset '{style_preset}'.")
        preset_data = presets[style_preset]

        def extend_unique(target: List[str], additions):
            for item in additions:
                if item not in target:
                    target.append(item)

        extend_unique(composition, preset_data.get("composition", []))
        extend_unique(action, preset_data.get("action", []))
        extend_unique(subject, preset_data.get("subject", []))
        extend_unique(environment, preset_data.get("environment", []))

    negatives = list(pools["negative_base"])
    optional_pool = pools["negative_optional"]
    for group in negative_groups or []:
        if group not in optional_pool:
            raise KeyError(f"Unknown negative group '{group}'")
        negatives.extend(optional_pool[group])

    if preset_data:
        negatives.extend(preset_data.get("negative", []))

    return CasePrompt(
        composition=composition,
        action=action,
        subject=subject,
        environment=environment,
        negatives=negatives,
    )


def main(argv: List[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    modes: Sequence[str] | None = args.mode
    if args.mature:
        base_modes = list(modes) if modes else ["general"]
        if "mature" not in base_modes:
            base_modes.append("mature")
        modes = base_modes
    if not modes:
        modes = ["general"]
    pools = _load_pools(modes)

    if args.list:
        for section in ("composition", "action", "subject", "environment"):
            keys = sorted(pools[section].keys())
            print(f"{section}: {', '.join(keys)}")
        optional = sorted(pools["negative_optional"].keys())
        print(f"negative optional groups: {', '.join(optional)}")
        return 0

    comp_overrides = _parse_overrides(args.composition, pools["composition"].keys())
    act_overrides = _parse_overrides(args.action, pools["action"].keys())
    sub_overrides = _parse_overrides(args.subject, pools["subject"].keys())
    env_overrides = _parse_overrides(args.environment, pools["environment"].keys())

    flat = bool(args.flat)
    delimiter = args.delimiter

    try:
        prompt = generate_prompt(
            pools=pools,
            modes=modes,
            seed=args.seed,
            composition_overrides=comp_overrides,
            action_overrides=act_overrides,
            subject_overrides=sub_overrides,
            environment_overrides=env_overrides,
            negative_groups=args.neg_groups,
            style_preset=args.style_preset,
        )
    except KeyError as exc:
        raise SystemExit(str(exc)) from exc

    if not flat:
        print("# CASE prompt")
    for line in prompt.as_lines(flat=flat, delimiter=delimiter):
        print(line)
    return 0


if __name__ == "__main__":  # pragma: no cover - manual utility
    sys.exit(main())
