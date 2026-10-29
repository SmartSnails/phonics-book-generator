#!/usr/bin/env python3
"""
build_atomic_prompts.py
Builds and lints 3-paragraph atomic illustration prompts from a theme-word-generator manifest.
"""

import argparse
import json
from pathlib import Path

BANNED_TOKENS = ["zzz", "crunch", "bzz", ".pdf"]


def build_atomic_prompt(word: str, age_band: str, subject: str) -> str:
    p1 = f'Please generate exactly 1 image to illustrate for teaching word “{word}” in a coloring book for children aged {age_band}.'
    p2 = (
        f"Black and white line art coloring page for young children, ages {age_band}. "
        "Bold, easily recognizable, friendly, thick, uniform black outlines (no thin or wavy lines), "
        "no shading, no gray tones, no cross-hatching, no color fill. Flat white background. "
        "Simple, large, clearly separated shapes — minimal fine detail. Cute, friendly, rounded cartoon style. "
        "At this age, kids learn best through clear, engaging, visual contrasts and relatable examples."
    )
    p3 = (
        f"{subject.rstrip('.')}. Centered, 1:1 square composition, flat #FFFFFF white background, "
        "no text, no letters, no watermark, no outer border, no box, no frame. "
        "Pure black line art on solid pure white background."
    )
    full = f"{p1}\n\n{p2}\n\n{p3}"
    for tok in BANNED_TOKENS:
        if tok in full.lower():
            raise ValueError(f"Prompt for '{word}' contains banned token '{tok}'")
    return full


def main():
    parser = argparse.ArgumentParser(description="Build 3-paragraph atomic prompts from word manifest.")
    parser.add_argument("--manifest", required=True, help="Input word manifest JSON")
    parser.add_argument("--output", required=True, help="Output atomic prompts JSON")
    args = parser.parse_args()

    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    age_band = manifest.get("age_band", "4 to 6")
    prompts_out = {"age_band": age_band, "themes": {}}

    for theme_key, t_data in manifest["themes"].items():
        items = []
        for entry in t_data["words"]:
            w = entry["word"]
            prompt = build_atomic_prompt(w, age_band, entry["subject"])
            items.append({
                "word": w,
                "theme": theme_key,
                "pair_group": entry.get("pair_group", ""),
                "subject": entry["subject"],
                "prompt": prompt
            })
        prompts_out["themes"][theme_key] = items

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(prompts_out, indent=2), encoding="utf-8")
    print(f"Built and linted atomic prompts for {sum(len(v) for v in prompts_out['themes'].values())} words -> {out_path}")


if __name__ == "__main__":
    main()
