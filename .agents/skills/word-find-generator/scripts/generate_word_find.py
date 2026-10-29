#!/usr/bin/env python3
"""
generate_word_find.py
Two-stage Word Find (Word Search) generator for children's activity & coloring books:
  Stage 1: Generates a validated M x N character matrix with direction constraints
           (easy = across, medium = down + across, hard = down + across + diagonal)
  Stage 2: Renders both a print-ready puzzle SVG and an answer-key SVG.
"""

import argparse
import json
import random
import string
from pathlib import Path
from xml.sax.saxutils import escape


def get_directions(difficulty: str, allow_reverse: bool):
    # (dr, dc, name)
    dirs = [(0, 1, "across")]
    if difficulty in ("medium", "hard"):
        dirs.append((1, 0, "down"))
    if difficulty == "hard":
        dirs.append((1, 1, "diag_down_right"))
        dirs.append((-1, 1, "diag_up_right"))

    if allow_reverse:
        rev = [(-dr, -dc, f"{name}_rev") for (dr, dc, name) in dirs]
        dirs.extend(rev)
    return dirs


def build_word_find_matrix(words, rows: int, cols: int, difficulty: str, allow_reverse: bool, letter_case: str, seed: int):
    rng = random.Random(seed)
    clean_words = []
    for w in words:
        w_clean = "".join(ch for ch in w.strip() if ch.isalpha())
        if not w_clean:
            continue
        w_fmt = w_clean.upper() if letter_case == "UPPER" else w_clean.lower()
        if len(w_fmt) > max(rows, cols):
            raise ValueError(f"Word '{w_fmt}' (len {len(w_fmt)}) exceeds grid dimensions {rows}x{cols}")
        clean_words.append(w_fmt)

    # Sort longest first for reliable packing, but alternate preferred directions
    sorted_words = sorted(clean_words, key=len, reverse=True)
    directions = get_directions(difficulty, allow_reverse)

    for attempt in range(500):
        grid = [["" for _ in range(cols)] for _ in range(rows)]
        placements = []
        success = True

        for idx, word in enumerate(sorted_words):
            wlen = len(word)
            # Encourage balanced directions (e.g. alternate across and down in medium mode)
            preferred_dir_idx = idx % len(directions)
            ordered_dirs = [directions[preferred_dir_idx]] + [
                d for i, d in enumerate(directions) if i != preferred_dir_idx
            ]

            candidates = []
            for dr, dc, dname in ordered_dirs:
                for r in range(rows):
                    for c in range(cols):
                        end_r = r + dr * (wlen - 1)
                        end_c = c + dc * (wlen - 1)
                        if not (0 <= end_r < rows and 0 <= end_c < cols):
                            continue
                        ok = True
                        overlaps = 0
                        for k, ch in enumerate(word):
                            nr, nc = r + dr * k, c + dc * k
                            cell = grid[nr][nc]
                            if cell != "" and cell != ch:
                                ok = False
                                break
                            if cell == ch:
                                overlaps += 1
                        if ok:
                            # Priority score: prefer preferred direction + occasional clean intersection
                            dir_bonus = 10 if (dr, dc, dname) == ordered_dirs[0] else 0
                            candidates.append((dir_bonus + overlaps, r, c, dr, dc, dname))

            if not candidates:
                success = False
                break

            # Pick among top-scoring candidates with randomness
            max_bonus = max(c[0] for c in candidates)
            top_cands = [c for c in candidates if c[0] >= max_bonus - 2]
            _, r, c, dr, dc, dname = rng.choice(top_cands)

            for k, ch in enumerate(word):
                grid[r + dr * k][c + dc * k] = ch

            placements.append({
                "word": word,
                "start": [r, c],
                "end": [r + dr * (wlen - 1), c + dc * (wlen - 1)],
                "direction": dname,
                "dr": dr,
                "dc": dc
            })

        if success:
            # Fill remaining empty cells with child-friendly alphabet characters
            alphabet = string.ascii_uppercase if letter_case == "UPPER" else string.ascii_lowercase
            for r in range(rows):
                for c in range(cols):
                    if grid[r][c] == "":
                        grid[r][c] = rng.choice(alphabet)

            # Restore original input word order in placements metadata
            order_map = {w: i for i, w in enumerate(clean_words)}
            placements.sort(key=lambda p: order_map.get(p["word"], 999))
            return {
                "rows": rows,
                "cols": cols,
                "difficulty": difficulty,
                "allow_reverse": allow_reverse,
                "letter_case": letter_case,
                "seed": seed,
                "words": clean_words,
                "placements": placements,
                "matrix": grid
            }

    raise RuntimeError(f"Could not place all words {clean_words} in {rows}x{cols} grid after 500 attempts.")


def render_word_find_svg(
    matrix_data: dict,
    title: str,
    subtitle: str,
    border_style: str = "thick",
    inner_grid_style: str = "thin",
    word_bank_style: str = "checkboxes",
    show_solution: bool = False
) -> str:
    width, height = 816, 1056  # Standard 8.5 x 11 inches at 96 DPI
    rows = matrix_data["rows"]
    cols = matrix_data["cols"]
    grid = matrix_data["matrix"]
    words = matrix_data["words"]

    # Grid geometry
    max_grid_w = 560
    max_grid_h = 540
    cell_size = int(min(max_grid_w / cols, max_grid_h / rows))
    grid_w = cell_size * cols
    grid_h = cell_size * rows
    grid_x = (width - grid_w) // 2
    grid_y = 185

    # Outer border styling
    border_attrs = {
        "thin": 'stroke="#000000" stroke-width="2.5" fill="#FFFFFF" rx="6" ry="6"',
        "thick": 'stroke="#000000" stroke-width="6" fill="#FFFFFF" rx="12" ry="12"',
        "dotted": 'stroke="#000000" stroke-width="5" stroke-dasharray="3,9" stroke-linecap="round" fill="#FFFFFF" rx="12" ry="12"',
        "dashed": 'stroke="#000000" stroke-width="5" stroke-dasharray="14,10" stroke-linecap="round" fill="#FFFFFF" rx="12" ry="12"',
        "rounded": 'stroke="#000000" stroke-width="5" fill="#FFFFFF" rx="24" ry="24"',
        "double": 'stroke="#000000" stroke-width="6" fill="#FFFFFF" rx="10" ry="10"'
    }.get(border_style, 'stroke="#000000" stroke-width="5" fill="#FFFFFF" rx="10" ry="10"')

    # Inner grid line styling
    inner_attrs = {
        "thin": 'stroke="#000000" stroke-width="1.5"',
        "thick": 'stroke="#000000" stroke-width="3"',
        "dotted": 'stroke="#000000" stroke-width="2" stroke-dasharray="2,6" stroke-linecap="round"',
        "dashed": 'stroke="#000000" stroke-width="2" stroke-dasharray="8,6"'
    }.get(inner_grid_style, "")

    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">',
        f'  <rect x="0" y="0" width="{width}" height="{height}" fill="#FFFFFF"/>',
        '  <!-- Page Outer Decorative Frame -->',
        f'  <rect x="36" y="36" width="{width - 72}" height="{height - 72}" fill="none" stroke="#000000" stroke-width="4" rx="18" ry="18"/>',
        '  <!-- Header -->',
        f'  <text x="{width // 2}" y="102" text-anchor="middle" font-family="Arial Rounded MT Bold, Helvetica, Arial, sans-serif" font-size="38" font-weight="bold" fill="#000000">{escape(title)}</text>',
    ]
    if subtitle:
        svg.append(
            f'  <text x="{width // 2}" y="142" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="20" fill="#222222">{escape(subtitle)}</text>'
        )

    # Grid background & outer frame
    svg.append(f'  <rect x="{grid_x}" y="{grid_y}" width="{grid_w}" height="{grid_h}" {border_attrs}/>')
    if border_style == "double":
        svg.append(
            f'  <rect x="{grid_x - 8}" y="{grid_y - 8}" width="{grid_w + 16}" height="{grid_h + 16}" fill="none" stroke="#000000" stroke-width="2.5" rx="16" ry="16"/>'
        )

    # Inner grid lines
    if inner_grid_style != "none" and inner_attrs:
        for r in range(1, rows):
            y = grid_y + r * cell_size
            svg.append(f'  <line x1="{grid_x}" y1="{y}" x2="{grid_x + grid_w}" y2="{y}" {inner_attrs}/>')
        for c in range(1, cols):
            x = grid_x + c * cell_size
            svg.append(f'  <line x1="{x}" y1="{grid_y}" x2="{x}" y2="{grid_y + grid_h}" {inner_attrs}/>')

    # Solution highlights (if answer key)
    if show_solution:
        svg.append('  <!-- Answer Key Highlights -->')
        for p in matrix_data["placements"]:
            r1, c1 = p["start"]
            r2, c2 = p["end"]
            x1 = grid_x + c1 * cell_size + cell_size / 2
            y1 = grid_y + r1 * cell_size + cell_size / 2
            x2 = grid_x + c2 * cell_size + cell_size / 2
            y2 = grid_y + r2 * cell_size + cell_size / 2
            stroke_w = int(cell_size * 0.68)
            svg.append(
                f'  <line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
                f'stroke="#CCCCCC" stroke-width="{stroke_w}" stroke-linecap="round" opacity="0.55"/>'
            )
            svg.append(
                f'  <line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
                f'stroke="#000000" stroke-width="3" stroke-dasharray="6,4" stroke-linecap="round"/>'
            )

    # Matrix Characters
    font_size = int(cell_size * 0.54)
    svg.append('  <!-- Matrix Letters -->')
    for r in range(rows):
        for c in range(cols):
            cx = grid_x + c * cell_size + cell_size / 2
            cy = grid_y + r * cell_size + cell_size / 2 + font_size * 0.36
            ch = escape(grid[r][c])
            svg.append(
                f'  <text x="{cx:.1f}" y="{cy:.1f}" text-anchor="middle" '
                f'font-family="Arial Rounded MT Bold, Helvetica, Arial, sans-serif" '
                f'font-size="{font_size}" font-weight="bold" fill="#000000">{ch}</text>'
            )

    # Word Bank Section
    if word_bank_style != "none" and words:
        bank_y = grid_y + grid_h + 40
        bank_h = height - bank_y - 65
        bank_x = 88
        bank_w = width - 176

        svg.append('  <!-- Word Bank -->')
        svg.append(
            f'  <rect x="{bank_x}" y="{bank_y}" width="{bank_w}" height="{bank_h}" '
            f'fill="#FFFFFF" stroke="#000000" stroke-width="3.5" rx="14" ry="14"/>'
        )
        svg.append(
            f'  <rect x="{width // 2 - 110}" y="{bank_y - 18}" width="220" height="34" fill="#FFFFFF" stroke="#000000" stroke-width="2.5" rx="10" ry="10"/>'
        )
        svg.append(
            f'  <text x="{width // 2}" y="{bank_y + 6}" text-anchor="middle" '
            f'font-family="Arial Rounded MT Bold, Helvetica, Arial, sans-serif" font-size="20" font-weight="bold" fill="#000000">WORD BANK</text>'
        )

        num_cols = min(3, max(2, (len(words) + 1) // 2))
        num_rows = (len(words) + num_cols - 1) // num_cols
        col_w = bank_w / num_cols
        row_h = max(42, min(58, (bank_h - 40) / max(1, num_rows)))

        for idx, w in enumerate(words):
            r_idx = idx // num_cols
            c_idx = idx % num_cols
            item_x = bank_x + c_idx * col_w + 36
            item_y = bank_y + 52 + r_idx * row_h

            if word_bank_style == "checkboxes":
                svg.append(
                    f'  <rect x="{item_x:.1f}" y="{item_y - 22:.1f}" width="24" height="24" fill="#FFFFFF" stroke="#000000" stroke-width="2.5" rx="4" ry="4"/>'
                )
                if show_solution:
                    svg.append(
                        f'  <path d="M {item_x + 4:.1f} {item_y - 10:.1f} L {item_x + 10:.1f} {item_y - 3:.1f} L {item_x + 20:.1f} {item_y - 18:.1f}" fill="none" stroke="#000000" stroke-width="3" stroke-linecap="round"/>'
                    )
                text_x = item_x + 36
            elif word_bank_style == "pills":
                svg.append(
                    f'  <rect x="{item_x - 8:.1f}" y="{item_y - 26:.1f}" width="{col_w - 56:.1f}" height="34" fill="none" stroke="#000000" stroke-width="2" rx="17" ry="17"/>'
                )
                text_x = item_x + 12
            else:
                text_x = item_x

            svg.append(
                f'  <text x="{text_x:.1f}" y="{item_y - 2:.1f}" text-anchor="start" '
                f'font-family="Arial Rounded MT Bold, Helvetica, Arial, sans-serif" font-size="24" font-weight="bold" letter-spacing="2" fill="#000000">{escape(w)}</text>'
            )

    svg.append('</svg>')
    return "\n".join(svg)


def main():
    parser = argparse.ArgumentParser(description="Generate Word Find matrix JSON and print-ready SVG.")
    parser.add_argument("--words", nargs="+", required=True, help="List of words to place")
    parser.add_argument("--grid-size", default="8x8", help="Grid dimensions MxN (e.g. 8x8)")
    parser.add_argument("--difficulty", choices=["easy", "medium", "hard"], default="medium")
    parser.add_argument("--border-style", choices=["thin", "thick", "dotted", "dashed", "rounded", "double"], default="thick")
    parser.add_argument("--inner-grid-style", choices=["thin", "thick", "dotted", "dashed", "none"], default="dotted")
    parser.add_argument("--letter-case", choices=["UPPER", "lower"], default="UPPER")
    parser.add_argument("--allow-reverse", action="store_true")
    parser.add_argument("--word-bank-style", choices=["checkboxes", "pills", "plain", "none"], default="checkboxes")
    parser.add_argument("--title", default="Word Find Puzzle")
    parser.add_argument("--subtitle", default="Find all the hidden words in the grid!")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--output-prefix", required=True, help="Output file path prefix (without extension)")
    args = parser.parse_args()

    parts = args.grid_size.lower().split("x")
    if len(parts) != 2:
        raise ValueError(f"Invalid --grid-size '{args.grid_size}'. Expected MxN (e.g. 8x8).")
    rows, cols = int(parts[0]), int(parts[1])

    matrix_data = build_word_find_matrix(
        words=args.words,
        rows=rows,
        cols=cols,
        difficulty=args.difficulty,
        allow_reverse=args.allow_reverse,
        letter_case=args.letter_case,
        seed=args.seed
    )

    prefix = Path(args.output_prefix)
    prefix.parent.mkdir(parents=True, exist_ok=True)

    matrix_path = prefix.with_name(f"{prefix.name}_matrix.json")
    svg_path = prefix.with_suffix(".svg")
    sol_svg_path = prefix.with_name(f"{prefix.name}_solution.svg")

    matrix_path.write_text(json.dumps(matrix_data, indent=2), encoding="utf-8")
    svg_path.write_text(
        render_word_find_svg(
            matrix_data=matrix_data,
            title=args.title,
            subtitle=args.subtitle,
            border_style=args.border_style,
            inner_grid_style=args.inner_grid_style,
            word_bank_style=args.word_bank_style,
            show_solution=False
        ),
        encoding="utf-8"
    )
    sol_svg_path.write_text(
        render_word_find_svg(
            matrix_data=matrix_data,
            title=f"{args.title} (Answer Key)",
            subtitle=args.subtitle,
            border_style=args.border_style,
            inner_grid_style=args.inner_grid_style,
            word_bank_style=args.word_bank_style,
            show_solution=True
        ),
        encoding="utf-8"
    )
    print(f"Generated matrix JSON ({matrix_path}), puzzle SVG ({svg_path}), and solution SVG ({sol_svg_path}).")


if __name__ == "__main__":
    main()
