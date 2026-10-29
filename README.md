# Phonics & Activity Book Generator (`phonics-book-generator`)

A modular, multi-level custom agent and skill suite for generating children's phonics and coloring books, Word Find puzzles, full-page story scenes, and animated story short videos.

---

## 1. Skill Architecture

| Skill | Level / Role | Description |
| :--- | :--- | :--- |
| [**`theme-word-generator`**](./.agents/skills/theme-word-generator/SKILL.md) | **Upstream Word Planner** | Generates curated, age-appropriate words by `theme`, `word_count`, `difficulty` (`easy`, `medium`, `hard`), and `age_band`, pairs related words (2 per page), and syncs `.xlsx` workbooks safely. |
| [**`word-find-generator`**](./.agents/skills/word-find-generator/SKILL.md) | **Puzzle & SVG Generator** | Builds a validated $M \times N$ character placement matrix (`easy` = across, `medium` = across + down, `hard` = across + down + diagonal) and renders print-ready `.svg` puzzle & answer-key files. |
| [**`atomic-illustration-generator`**](./.agents/skills/atomic-illustration-generator/SKILL.md) | **Level 1 Generator** | Generates isolated `1:1` B&W line-art characters, animals, words, and props using the 3-paragraph prompt standard. |
| [**`scene-illustration-generator`**](./.agents/skills/scene-illustration-generator/SKILL.md) | **Level 2 Generator** | Assembles multiple atomic characters and props into Full-Page (`3:4`) or Half-Page (`4:3`) scenes. |
| [**`story-sequence-generator`**](./.agents/skills/story-sequence-generator/SKILL.md) | **Level 3 Generator** | Creates 3-part cohesive storylines (`Act 1`, `Act 2`, `Act 3`) across scenes using a locked Story Continuity Bible. |
| [**`story-video-generator`**](./.agents/skills/story-video-generator/SKILL.md) | **Level 4 Generator** | Generates full-color 2D storybook variants of the 3 scenes and compiles them into an animated `.mp4` short video with camera motion and musical score (plus Veo 3.1 prompt packages). |
| [**`illustration-qa-inspector`**](./.agents/skills/illustration-qa-inspector/SKILL.md) | **Independent QA Gate** | Normalizes B&W line art to pure `#000000`/`#FFFFFF` PNGs and performs 6-point multimodal inspection. |
| [**`activity-page-composer`**](./.agents/skills/activity-page-composer/SKILL.md) | **Book & PDF Composer** | Composes 2-related-animals-per-page coloring + handwriting/tracing sheets, embeds Word Find puzzles, and compiles the ordered US Letter PDF coloring book. |

---

## 2. Prerequisites & Setup Instructions

### System Requirements
1. **Antigravity IDE / CLI (`agy`)**:
   - Open this repository root as your active workspace in Antigravity so [`AGENTS.md`](./AGENTS.md) and all workspace skills under [`.agents/skills/`](./.agents/skills/) are discovered automatically.
2. **Python 3.9+**:
   - Used for deterministic word generation, `.xlsx` planner synchronization, and Word Find matrix + SVG generation (uses standard library modules out of the box).
   - *(Optional)* If syncing directly with local Excel `.xlsx` files via `openpyxl`:
     ```bash
     python3 -m pip install openpyxl
     ```
3. **macOS Native Media & PDF Toolchain (Xcode Command Line Tools)**:
   - Used for pure B&W line-art thresholding, multi-character scene compositing, US Letter PDF book compilation (`CoreGraphics` / `CoreText` / `PDFKit`), and `1080x1440` `.mp4` story video rendering (`AVFoundation`).
   - Verify `swift` is available:
     ```bash
     swift --version
     ```
4. **Optional PDF Inspection Utilities**:
   - Install `poppler` (`pdfinfo`, `pdftoppm`) via Homebrew to render PDF pages to PNG for visual QA:
     ```bash
     brew install poppler
     ```

### Quick Start

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/smartsnails/phonics-book-generator.git
   cd phonics-book-generator
   ```

2. **Open in Antigravity**:
   - Set `phonics-book-generator` as your active workspace folder in Antigravity.
   - The agent will automatically load [`AGENTS.md`](./AGENTS.md) and the 7 modular skills in [`.agents/skills/`](./.agents/skills/).

---

## 3. Running Individual Skills & Pipeline Stages

### Stage 1: Generate Theme Words & 2-Per-Page Pairings (`theme-word-generator`)
```bash
python3 .agents/skills/theme-word-generator/scripts/generate_theme_words.py \
  --themes farm jungle \
  --total-words 12 \
  --difficulty medium \
  --age-band "4-6" \
  --output output/words/farm_jungle_words_manifest.json
```

### Stage 2: Generate Word Find Matrix JSON & Print-Ready SVGs (`word-find-generator`)
```bash
# Farm Word Find (8x8, Medium = Across + Down, Thick Border, Dotted Inner Grid)
python3 .agents/skills/word-find-generator/scripts/generate_word_find.py \
  --words COW HORSE SHEEP GOAT PIG DUCK \
  --rows 8 --cols 8 \
  --difficulty medium \
  --border-style thick \
  --inner-grid-style dotted \
  --title "Farm Animals Word Find" \
  --theme "Farm" \
  --output-prefix output/word_finds/farm_word_find

# Jungle Word Find (8x8, Medium = Across + Down, Rounded Border, Dotted Inner Grid)
python3 .agents/skills/word-find-generator/scripts/generate_word_find.py \
  --words TIGER LION MONKEY SLOTH SNAKE FROG \
  --rows 8 --cols 8 \
  --difficulty medium \
  --border-style rounded \
  --inner-grid-style dotted \
  --title "Jungle Animals Word Find" \
  --theme "Jungle" \
  --output-prefix output/word_finds/jungle_word_find
```

### Stage 3: Build Level 1 Atomic Prompts & Level 3 Story Continuity Bible
```bash
python3 .agents/skills/atomic-illustration-generator/scripts/build_atomic_prompts.py \
  --manifest output/words/farm_jungle_words_manifest.json \
  --output output/words/atomic_animal_prompts.json
```
- Invoke the `image-generator` subagent (or Imagen 3 / Gemini image generation) with the prompts in `output/words/atomic_animal_prompts.json` and `output/words/storylines_continuity_bible.json`.

### Stage 4: Normalize B&W Line Art & Compose Scenes / Color Keyframes
```bash
# Normalize B&W line art to pure #000000 ink on #FFFFFF white PNGs
swift -module-cache-path /tmp/swift-cache \
  .agents/skills/illustration-qa-inspector/scripts/verify_and_normalize_assets.swift

# Compose multi-character scenes and full-color storybook keyframes
swift -module-cache-path /tmp/swift-cache \
  .agents/skills/scene-illustration-generator/scripts/compose_scenes_and_color_keyframes.swift
```

### Stage 5: Compile the Ordered US Letter Coloring Book PDF (`activity-page-composer`)
Orders pages by theme (**Farm**, then **Jungle**), and within each theme places **individual 2-per-page animal writing/coloring pages first**, followed by the **Word Find puzzle**, and **full-page 3-part story coloring pages later**:
```bash
swift -module-cache-path /tmp/swift-cache \
  .agents/skills/activity-page-composer/scripts/build_coloring_book_pdf.swift \
  output/book/book_manifest.json
```

### Stage 6: Render Animated Theme Story Short Videos (`story-video-generator`)
Renders `1080x1440` `.mp4` videos with Ken Burns camera motion, cross-dissolve transitions, story captions, and synthesized background music:
```bash
swift -module-cache-path /tmp/swift-cache \
  .agents/skills/story-video-generator/scripts/render_story_video.swift \
  output/videos/farm_video_manifest.json

swift -module-cache-path /tmp/swift-cache \
  .agents/skills/story-video-generator/scripts/render_story_video.swift \
  output/videos/jungle_video_manifest.json
```

---

## 4. Generated Sample Outputs (`Farm & Jungle Edition`)

- **Word Manifest & Story Continuity Bible**:
  - [`output/words/farm_jungle_words_manifest.json`](./output/words/farm_jungle_words_manifest.json)
  - [`output/words/storylines_continuity_bible.json`](./output/words/storylines_continuity_bible.json)
- **Word Find Matrices & SVGs (`8x8`, `medium` difficulty)**:
  - Farm: [`farm_word_find_matrix.json`](./output/word_finds/farm_word_find_matrix.json) | [`farm_word_find.svg`](./output/word_finds/farm_word_find.svg) | [`farm_word_find_solution.svg`](./output/word_finds/farm_word_find_solution.svg)
  - Jungle: [`jungle_word_find_matrix.json`](./output/word_finds/jungle_word_find_matrix.json) | [`jungle_word_find.svg`](./output/word_finds/jungle_word_find.svg) | [`jungle_word_find_solution.svg`](./output/word_finds/jungle_word_find_solution.svg)
- **Atomic Animal Illustrations (Level 1)**: [`output/atomic_animals/`](./output/atomic_animals/)
- **Full-Page Story Coloring Scenes (Levels 2 & 3)**: [`output/full_page_scenes/`](./output/full_page_scenes/)
- **Full-Color Video Keyframes & Animated Shorts (Level 4)**:
  - [`output/color_keyframes/`](./output/color_keyframes/)
  - [`output/videos/farm_story_short.mp4`](./output/videos/farm_story_short.mp4)
  - [`output/videos/jungle_story_short.mp4`](./output/videos/jungle_story_short.mp4)
- **Compiled Sample Coloring Book PDF**:
  - [`output/book/Farm_and_Jungle_Phonics_Coloring_Book.pdf`](./output/book/Farm_and_Jungle_Phonics_Coloring_Book.pdf)
