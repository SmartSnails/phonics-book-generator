#!/usr/bin/env python3
"""
generate_theme_words.py
Curated, deterministic theme word generator and validator for children's coloring & phonics books.
Outputs a structured JSON manifest with:
  - Per-theme word entries (word, length, syllables, difficulty, age_band, atomic_subject_prompt)
  - Related 2-word page pairs (for 2-animals-per-page coloring + writing pages)
  - Flat word lists for word-find-generator
"""

import argparse
import json
from pathlib import Path

CURATED_BANK = {
    "farm": {
        "easy": [
            {"word": "cow", "syllables": 1, "pair_group": "Pasture Friends", "subject": "A friendly, cute cartoon dairy cow standing happily on a small tuft of grass, featuring large rounded spots on its back, floppy ears, small curved horns, a cheerful wide smile, and a simple bell around its neck"},
            {"word": "pig", "syllables": 1, "pair_group": "Barnyard Pals", "subject": "A chubby, cheerful cartoon farm pig sitting happily with a big round snout, floppy ears, a cute curly tail, and a joyful smile"},
            {"word": "hen", "syllables": 1, "pair_group": "Coop Friends", "subject": "A plump, friendly cartoon farm hen standing proudly with a cute scalloped comb on top of its head, simple wing feathers, and tail feathers"},
            {"word": "dog", "syllables": 1, "pair_group": "Farm Helpers", "subject": "A friendly, playful cartoon farm puppy dog sitting with floppy ears, a wagging tail, and a happy smile"},
        ],
        "medium": [
            {
                "word": "cow",
                "syllables": 1,
                "pair_group": "Meadow Grazers",
                "subject": "A friendly, cute cartoon farm cow standing happily, featuring large, simple rounded patches on its body, soft floppy ears, two small rounded horns, a big cheerful snout, and a simple farm bell on a collar around its neck"
            },
            {
                "word": "horse",
                "syllables": 1,
                "pair_group": "Meadow Grazers",
                "subject": "A cheerful, friendly cartoon farm horse trotting happily with a flowing, thick-lined mane, a bushy tail, big expressive eyes, and sturdy hooves"
            },
            {
                "word": "sheep",
                "syllables": 1,
                "pair_group": "Woolly & Meadow Friends",
                "subject": "A cute, fluffy cartoon farm sheep standing happily with a cloud-like scalloped woolly coat, a sweet smiling face, floppy ears, and cuatro sturdy little legs"
            },
            {
                "word": "goat",
                "syllables": 1,
                "pair_group": "Woolly & Meadow Friends",
                "subject": "A playful, friendly cartoon farm goat standing cheerfully with two short curved ridged horns, a cute little chin tuft beard, floppy ears, and a happy upright tail"
            },
            {
                "word": "pig",
                "syllables": 1,
                "pair_group": "Barnyard & Pond Pals",
                "subject": "A plump, joyful cartoon farm pig sitting happily with a big oval button snout, floppy ears, chubby cheeks, a cute curly tail, and a wide friendly grin"
            },
            {
                "word": "duck",
                "syllables": 1,
                "pair_group": "Barnyard & Pond Pals",
                "subject": "A cute, cheerful cartoon farm duck waddling happily with a smooth rounded bill, big friendly eyes, simple folded wing feathers, and webbed feet"
            },
            {
                "word": "goose",
                "syllables": 1,
                "pair_group": "Pond & Coop Friends",
                "subject": "A friendly cartoon farm goose with a long graceful curved neck, a rounded bill, simple large wing feathers, and webbed feet"
            },
            {
                "word": "chick",
                "syllables": 1,
                "pair_group": "Pond & Coop Friends",
                "subject": "An adorable, round baby farm chick with a tiny tuft of feathers on top of its head, tiny wings flapping happily, and a sweet little beak"
            },
            {
                "word": "llama",
                "syllables": 2,
                "pair_group": "Pasture Guardians",
                "subject": "A cute, friendly cartoon farm llama with a fluffy coat, long banana-shaped ears, a long neck, and a cheerful smile"
            },
            {
                "word": "donkey",
                "syllables": 2,
                "pair_group": "Pasture Guardians",
                "subject": "A sweet, friendly cartoon farm donkey with extra-tall upright ears, a short tufted mane, a tasseled tail, and a big gentle smile"
            }
        ]
    },
    "jungle": {
        "easy": [
            {"word": "ape", "syllables": 1, "pair_group": "Canopy Friends", "subject": "A friendly, cute cartoon jungle ape sitting happily with big rounded ears and long arms"},
            {"word": "bat", "syllables": 1, "pair_group": "Night Flyers", "subject": "A cute, smiling cartoon fruit bat hanging or flying with wide scalloped wings and big friendly eyes"},
        ],
        "medium": [
            {
                "word": "tiger",
                "syllables": 2,
                "pair_group": "Jungle Big Cats",
                "subject": "A cute, friendly cartoon jungle tiger cub sitting happily with bold, simple black tiger stripes on its body and cheeks, rounded ears, a long striped tail, and a big cheerful smile"
            },
            {
                "word": "lion",
                "syllables": 2,
                "pair_group": "Jungle Big Cats",
                "subject": "A cheerful, friendly cartoon lion cub sitting proudly with a big, fluffy scalloped mane framing its smiling face, rounded ears, and a tufted tail"
            },
            {
                "word": "monkey",
                "syllables": 2,
                "pair_group": "Treetop Climbers",
                "subject": "A playful, cute cartoon jungle monkey waving happily with big round ears, a sweet smiling face, and a long, bouncy curled tail"
            },
            {
                "word": "sloth",
                "syllables": 1,
                "pair_group": "Treetop Climbers",
                "subject": "A peaceful, cute cartoon jungle sloth hanging happily from a simple thick tree branch with long curved arms, big gentle eyes with cute eye-patches, and a warm relaxed smile"
            },
            {
                "word": "snake",
                "syllables": 1,
                "pair_group": "Jungle Explorers",
                "subject": "A friendly, cute cartoon jungle snake coiled neatly in a smooth S-curve with big cheerful eyes, simple rounded decorative belly bands, and a happy smile"
            },
            {
                "word": "frog",
                "syllables": 1,
                "pair_group": "Jungle Explorers",
                "subject": "A cheerful, cute cartoon jungle tree frog sitting on a wide lily pad leaf with big round popping eyes, a wide happy smile, and large webbed toes"
            },
            {
                "word": "toucan",
                "syllables": 2,
                "pair_group": "Jungle Canopy Friends",
                "subject": "A cheerful cartoon jungle toucan perched on a simple branch, featuring an extra-large, unmistakable curved toucan beak with a simple stripe, big friendly eyes, and neat tail feathers"
            },
            {
                "word": "panda",
                "syllables": 2,
                "pair_group": "Jungle Canopy Friends",
                "subject": "A chubby, cute cartoon panda bear sitting happily holding a simple bamboo stalk, with round ears, big eye patches, and a joyful smile"
            },
            {
                "word": "hippo",
                "syllables": 2,
                "pair_group": "River Friends",
                "subject": "A chubby, smiling cartoon river hippo with tiny rounded ears, a huge friendly snout with two nostrils, and a happy expression"
            },
            {
                "word": "zebra",
                "syllables": 2,
                "pair_group": "River Friends",
                "subject": "A cheerful, cute cartoon zebra standing happily with bold, simple stripes across its body, a spiky upright mane, and a tufted tail"
            }
        ]
    }
}


def generate_manifest(themes, count_per_theme, difficulty, age_band, exclude_words):
    exclude_set = {w.lower().strip() for w in (exclude_words or [])}
    result = {
        "difficulty": difficulty,
        "age_band": age_band,
        "count_per_theme": count_per_theme,
        "themes": {}
    }
    global_seen = set(exclude_set)

    for theme in themes:
        t_key = theme.lower().strip()
        if t_key not in CURATED_BANK:
            raise ValueError(f"Unsupported theme '{theme}'. Available: {list(CURATED_BANK.keys())}")
        pool = CURATED_BANK[t_key].get(difficulty, CURATED_BANK[t_key]["medium"])
        selected = []
        for entry in pool:
            w = entry["word"].lower()
            if w in global_seen:
                continue
            global_seen.add(w)
            selected.append({
                "word": entry["word"],
                "word_upper": entry["word"].upper(),
                "length": len(entry["word"]),
                "syllables": entry["syllables"],
                "difficulty": difficulty,
                "age_band": age_band,
                "pair_group": entry["pair_group"],
                "subject": entry["subject"]
            })
            if len(selected) >= count_per_theme:
                break

        # Pair consecutive items (2 related animals per page)
        pairs = []
        for i in range(0, len(selected), 2):
            chunk = selected[i:i + 2]
            pairs.append({
                "pair_index": (i // 2) + 1,
                "pair_title": chunk[0]["pair_group"],
                "words": [item["word"] for item in chunk],
                "items": chunk
            })

        result["themes"][t_key] = {
            "theme": t_key,
            "theme_title": f"{t_key.capitalize()} Animals",
            "word_count": len(selected),
            "word_list": [item["word"] for item in selected],
            "words": selected,
            "pairs": pairs
        }

    return result


def main():
    parser = argparse.ArgumentParser(description="Generate curated theme words for phonics/coloring books.")
    parser.add_argument("--themes", nargs="+", required=True, help="Theme names (e.g., farm jungle)")
    parser.add_argument("--count-per-theme", type=int, default=5, help="Number of words per theme")
    parser.add_argument("--difficulty", choices=["easy", "medium", "hard"], default="medium")
    parser.add_argument("--age-band", default="4-6")
    parser.add_argument("--exclude", nargs="*", default=[])
    parser.add_argument("--output", required=True, help="Output JSON manifest path")
    args = parser.parse_args()

    manifest = generate_manifest(
        themes=args.themes,
        count_per_theme=args.count_per_theme,
        difficulty=args.difficulty,
        age_band=args.age_band,
        exclude_words=args.exclude
    )

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Saved word manifest ({sum(t['word_count'] for t in manifest['themes'].values())} total words) to {out_path}")


if __name__ == "__main__":
    main()
