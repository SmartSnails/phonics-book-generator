# Phonics & Activity Book Generator (`phonics-book-generator`)

A modular, multi-level custom agent and skill suite for generating children's phonics and coloring books, Word Find puzzles, full-page story scenes, and animated story short videos.

---

## 1. Skill Architecture

| Skill | Level / Role | Description |
| :--- | :--- | :--- |
| [**`theme-word-generator`**](./.agents/skills/theme-word-generator/SKILL.md) | **Upstream Word Planner** | Generates curated, age-appropriate words by `theme`, `word_count`, `difficulty` (`easy`, `medium`, `hard`), and `age_band`, pairs related words (2 per page), and syncs `.xlsx` workbooks safely. |
| [**`word-find-generator`**](./.agents/skills/word-find-generator/SKILL.md) | **Puzzle & SVG Generator** | Builds a validated $M \times N$ character placement matrix (`easy` = across, `medium` = across + down, `hard` = across + down + diagonal) and renders print-ready `.svg` puzzle & answer-key files. |
| [**`atomic-illustration-generator`**](./.agents/skills/atomic-illustration-generator/SKILL.md) | **Level 1 Generator** | Generates isolated `1:1` B&W line-art characters, animals, words, and props using the 3-paragraph prompt standard. |
| [**`scene-illustration-generator`**](./.agents/skills/scene-illustration-generator/SKILL.md) | **Level 2 Generator** | Assembles multiple atomic characters and props into Full-Page (`3:4`) or Half-Page scenes. |
| [**`story-sequence-generator`**](./.agents/skills/story-sequence-generator/SKILL.md) | **Level 3 Generator** | Creates 3-part cohesive storylines (`Act 1`, `Act 2`, `Act 3`) across scenes using a locked Story Continuity Bible. |
| [**`story-video-generator`**](./.agents/skills/story-video-generator/SKILL.md) | **Level 4 Generator** | Generates full-color 2D storybook variants of the 3 scenes and compiles them into an animated `.mp4` short video with camera motion and musical score (plus Veo 3.1 prompt packages). |
| [**`illustration-qa-inspector`**](./.agents/skills/illustration-qa-inspector/SKILL.md) | **Independent QA Gate** | Normalizes B&W line art to pure `#000000`/`#FFFFFF` PNGs and performs 6-point multimodal inspection. |
| [**`activity-page-composer`**](./.agents/skills/activity-page-composer/SKILL.md) | **Book & PDF Composer** | Composes 2-related-animals-per-page coloring + handwriting/tracing sheets, embeds Word Find puzzles, and compiles the ordered US Letter PDF coloring book. |

---

## 2. Generated Sample Outputs (`Farm & Jungle Edition`)

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
