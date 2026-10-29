---
name: word-find-generator
description: >-
  Use this skill when generating a Word Find / Word Search puzzle matrix and
  print-ready SVG file (plus optional answer-key SVG) parameterized by
  word_list, grid_size (M x N), difficulty_level (easy=across, medium=down+across,
  hard=down+across+diagonal), border_style (thin, thick, dotted, dashed, rounded),
  letter_case, allow_reverse, cell_shape, and word_bank_style.
---

# Word Find Generator (`word-find-generator`)

Generates deterministic, child-friendly **Word Find (Word Search) puzzles** in two stages:
1. **Stage 1 — Matrix Generation & Validation**: Places `word_list` into an $M \times N$ character matrix following the specified `difficulty_level` direction rules, fills empty cells without creating accidental forbidden words, and exports the structured placement matrix JSON.
2. **Stage 2 — Print-Ready SVG Rendering**: Renders the matrix and word bank into a crisp, high-contrast black-and-white `.svg` puzzle page (and an optional `*_solution.svg` answer key) ready for direct embedding into coloring books or PDF conversion.

---

## 1. Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `word_list` | `list[str]` | *Required* | Words to hide in the puzzle grid. |
| `grid_size` | `str` (`MxN`) | `"8x8"` | Rows (`M`) by Columns (`N`), e.g., `"8x8"`, `"9x9"`, `"10x10"`. Must be $\ge$ longest word length. |
| `difficulty_level` | `enum` | `"medium"` | `"easy"` = Across (L→R) only;<br>`"medium"` = Across (L→R) + Down (T→B);<br>`"hard"` = Across + Down + Diagonal (↘ and ↗). |
| `border_style` | `enum` | `"thick"` | Outer grid frame style: `"thin"`, `"thick"`, `"dotted"`, `"dashed"`, `"double"`, `"rounded"`. |
| `inner_grid_style` | `enum` | `"thin"` | Cell divider style: `"thin"`, `"dotted"`, `"dashed"`, `"none"`. |
| `letter_case` | `enum` | `"UPPER"` | `"UPPER"` or `"lower"` (useful for early phonics learners). |
| `allow_reverse` | `boolean` | `false` | Whether words can be spelled backwards (R→L or B→T). Keep `false` for ages 4–7. |
| `word_bank_style` | `enum` | `"checkboxes"` | `"checkboxes"`, `"pills"`, `"plain"`, or `"none"`. |
| `title` | `string` | `"Word Find"` | Header title rendered at the top of the SVG page. |
| `subtitle` | `string` | `""` | Optional instruction line under the title. |
| `seed` | `integer` | `42` | Random seed for 100% reproducible matrix and filler layout. |

---

## 2. Two-Stage Execution Workflow

### Stage 1 & 2 via [`scripts/generate_word_find.py`](./scripts/generate_word_find.py)

```bash
python3 .agents/skills/word-find-generator/scripts/generate_word_find.py \
  --words cow horse sheep goat pig \
  --grid-size 8x8 \
  --difficulty medium \
  --border-style thick \
  --inner-grid-style dotted \
  --letter-case UPPER \
  --word-bank-style checkboxes \
  --title "Farm Animals Word Find" \
  --subtitle "Find the farm animals across and down!" \
  --seed 101 \
  --output-prefix output/word_finds/farm_word_find
```

### Generated Outputs:
1. `<output-prefix>_matrix.json`: Full $M \times N$ character array, exact start/end $(r, c)$ coordinates, direction vectors for every placed word, and placement verification check.
2. `<output-prefix>.svg`: Print-ready US Letter (`8.5" × 11"`, `816 × 1056` viewBox) B&W activity page with header, styled $M \times N$ grid, and interactive-looking checkbox word bank.
3. `<output-prefix>_solution.svg`: Answer key SVG with highlighted capsule overlays showing every word's location.

---

## 3. Built-In Checks & Balances
- **Completeness Gate**: Script raises an error if any word in `word_list` cannot fit or fails placement after 2,000 backtracking attempts.
- **Direction Balance**: In `medium` mode (`across` + `down`), the placer actively alternates directions so a puzzle never ends up 100% horizontal by chance.
- **Accidental-Word Guard**: Random filler avoids duplicating any placed target word in the remaining cells.
