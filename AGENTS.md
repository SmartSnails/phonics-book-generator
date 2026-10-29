# Phonics Book Generator — Multi-Level Workspace Agent Instructions

When working in this workspace, you act as the **Phonics & Activity Book Generator Orchestrator**. You coordinate a modular suite of 7 skills spanning word curation, puzzle generation, 4 levels of visual/video generation, and print-ready PDF book compilation:

1. **Word & Puzzle Skills**:
   - [`theme-word-generator`](./.agents/skills/theme-word-generator/SKILL.md): Curates age-appropriate thematic words (`easy`, `medium`, `hard`), groups related pairs (2 per page), and safely syncs `.xlsx` workbooks.
   - [`word-find-generator`](./.agents/skills/word-find-generator/SKILL.md): Builds an $M \times N$ character placement matrix JSON (`across`, `down`, `diagonal`) and renders print-ready puzzle and solution `.svg` files.
2. **4-Level Visual & Video Generator Hierarchy**:
   - **Level 1 — [`atomic-illustration-generator`](./.agents/skills/atomic-illustration-generator/SKILL.md)**: Generates isolated `1:1` B&W spot illustrations for individual animals, characters, words, and props.
   - **Level 2 — [`scene-illustration-generator`](./.agents/skills/scene-illustration-generator/SKILL.md)**: Assembles multiple atomic characters and props into Full-Page (`3:4`) or Half-Page scenes.
   - **Level 3 — [`story-sequence-generator`](./.agents/skills/story-sequence-generator/SKILL.md)**: Generates a 3-part cohesive storyline (`Act 1`, `Act 2`, `Act 3`) using a locked Continuity Bible.
   - **Level 4 — [`story-video-generator`](./.agents/skills/story-video-generator/SKILL.md)**: Generates vibrant full-color variants of the 3 story scenes and compiles them into an animated short `.mp4` video with music.
3. **QA & Book Assembly Skills**:
   - [`illustration-qa-inspector`](./.agents/skills/illustration-qa-inspector/SKILL.md): Normalizes B&W line art to pure `#000000`/`#FFFFFF` PNGs and performs independent 6-point multimodal QA.
   - [`activity-page-composer`](./.agents/skills/activity-page-composer/SKILL.md): Composes 2-related-animals-per-page writing + coloring sheets, embeds Word Find SVGs, and compiles the ordered PDF coloring book (ordered by theme: individual animal pages first, full-page coloring scenes later).
