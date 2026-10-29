---
name: theme-word-generator
description: >-
  Use this skill when generating, auditing, or pairing theme-based word lists
  (e.g., Farm, Jungle, Ocean, Weather, Vehicles) parameterized by theme,
  number of words, difficulty level (easy, medium, hard), and target age band.
  Also handles Google Drive .xlsx workbook synchronization with revision checks.
---

# Theme Word Generator (`theme-word-generator`)

Generates curated, age-appropriate vocabulary lists and thematic pairings for children's phonics and coloring books. Can either generate fresh thematic word sets from scratch or audit and update existing word tables in a Google Drive `.xlsx` workbook.

---

## 1. Input Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `theme` | `string` / `list` | *Required* | Theme name(s), e.g., `"farm"`, `"jungle"`, `"ocean"`, `"weather"`, `"vehicles"`. |
| `word_count` | `integer` | `10` | Number of words to generate (either total or per theme). |
| `difficulty` | `enum` | `"medium"` | `"easy"` (3–4 letters, 1 syllable, CVC/simple nouns), `"medium"` (3–6 letters, 1–2 syllables, common blends/digraphs), `"hard"` (5–8 letters, multi-syllable or compound). |
| `age_band` | `string` | `"4-6"` | Target child age range (e.g., `"3-4"`, `"4-5"`, `"4-6"`, `"6-8"`). Enforces concrete visual relatability. |
| `pair_related` | `boolean` | `true` | Groups output words into related pairs (2 words per page for dual-illustration writing/coloring pages). |
| `exclude_words` | `list[str]` | `[]` | Words to exclude (e.g., words already used in a companion 3-Act story or another theme table). |

---

## 2. Word Selection & Relatability Rubric (Checks & Balances)

Every generated or audited word must pass **5 mandatory gates**:

1. **Concrete Visual Drawability**: Must be a concrete noun, animal, or unmistakable physical action that a child in `age_band` can identify instantly from a black-and-white line drawing without labels.
2. **Difficulty & Phonetic Fit**:
   - `easy`: 3–4 letters, 1 syllable, short vowel CVC or basic ending blend (`pig`, `cow`, `hen`, `dog`, `cat`, `duck`).
   - `medium`: 3–6 letters, 1–2 syllables, child-familiar phonetic patterns (`sheep`, `horse`, `goat`, `goose`, `tiger`, `zebra`, `monkey`, `snake`, `sloth`, `toucan`).
   - `hard`: 5–9 letters, 2–3 syllables (`rooster`, `alpacas`, `chameleon`, `crocodile`, `orangutan`).
3. **Zero Silent-Letter Traps (When Used for Strict Phonetic Sorting)**: Flag words with silent consonants (`chalk`, `walk`, `calf`, `half`, `yolk`) unless the activity is thematic vocabulary rather than strict sound sorting.
4. **Zero Cross-Theme or Story Overlap**: Never duplicate a word across themes in the same book or reuse words reserved for the 3-Act story unless the story specifically stars those words.
5. **Natural Thematic Pairing**: When `pair_related=true`, pair every 2 words by habitat, behavior, or visual affinity (e.g., *Cow & Horse* as grazing pasture pals; *Monkey & Sloth* as treetop canopy climbers) so 2-per-page coloring layouts feel cohesive.

---

## 3. Standard Execution Workflow

### Step 1: Run Deterministic Generator / Auditor Script
Execute [`scripts/generate_theme_words.py`](./scripts/generate_theme_words.py) to produce a validated JSON manifest containing:
- The selected words with letter count, syllable count, phonetic notes, and concrete visual subject description (ready to feed into `atomic-illustration-generator`).
- Related pairs (2 words per page) for `activity-page-composer`.
- The flat `word_list` array (ready to feed directly into `word-find-generator`).

```bash
python3 .agents/skills/theme-word-generator/scripts/generate_theme_words.py \
  --themes farm jungle \
  --count-per-theme 5 \
  --difficulty medium \
  --age-band "4-6" \
  --output output/words/animal_words_manifest.json
```

### Step 2: Optional `.xlsx` Workbook Sync
If syncing word recommendations back to a Google Drive `.xlsx` planner:
1. Download the latest `.xlsx` and record its remote revision/timestamp before editing.
2. Run [`scripts/xlsx_planner_sync.py`](./scripts/xlsx_planner_sync.py) to apply `<strike>old</strike> - new1, new2` updates with automatic backup and namespace preservation.

---

## 4. References & Scripts
- [`scripts/generate_theme_words.py`](./scripts/generate_theme_words.py) — Deterministic theme word generator, validator, and pairing engine.
- [`scripts/xlsx_planner_sync.py`](./scripts/xlsx_planner_sync.py) — Safe OpenXML `.xlsx` updater with backup and loud error reporting.
- [`references/word-selection-rubric.md`](./references/word-selection-rubric.md) — Detailed age-band and phonics audit rules.
