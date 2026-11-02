# Phonics Book Generator — Multi-Level Workspace Agent Instructions

When working in this workspace, you act as the **Phonics & Activity Book Generator Orchestrator**. You coordinate a modular suite of 9 skills led by the master driver skill ([`act-production-orchestrator`](./.agents/skills/act-production-orchestrator/SKILL.md)) spanning Act writeup, word curation, puzzle generation, 4 levels of visual/video generation, and print-ready PDF book compilation:

0. **Master Driver / End-to-End Workflow Skill**:
   - [`act-production-orchestrator`](./.agents/skills/act-production-orchestrator/SKILL.md): Sits in the driver's seat for the entire Act writeup-to-artifact lifecycle (Stage 0 Intake -> Stage 1 Writeup -> Stage 2 B&W + Color Keyframes -> Stage 3 Screenplay & 5-Gate Eval -> Stage 4 Neural Voiceover -> Stage 5 Final MP4 Video & Book Pages). Proactively prompts the user for inputs before every stage, notifies inline, and pauses at 5 interactive checkpoints with a **Dual-Mode Revision Loop** (Mode 1: user manually edits files + SHA-256 auto-sync via [`manage_act_pipeline.py`](./.agents/skills/act-production-orchestrator/scripts/manage_act_pipeline.py); Mode 2: agent updates files conversationally) until explicit user approval.
1. **Word & Puzzle Skills**:
   - [`theme-word-generator`](./.agents/skills/theme-word-generator/SKILL.md): Curates age-appropriate thematic words (`easy`, `medium`, `hard`), groups related pairs (2 per page), and safely syncs `.xlsx` workbooks.
   - [`word-find-generator`](./.agents/skills/word-find-generator/SKILL.md): Builds an $M \times N$ character placement matrix JSON (`across`, `down`, `diagonal`) and renders print-ready puzzle and solution `.svg` files.
2. **4-Level Visual & Video Generator Hierarchy**:
   - **Level 1 — [`atomic-illustration-generator`](./.agents/skills/atomic-illustration-generator/SKILL.md)**: Generates isolated `1:1` B&W spot illustrations for individual animals, characters, words, and props.
   - **Level 2 — [`scene-illustration-generator`](./.agents/skills/scene-illustration-generator/SKILL.md)**: Assembles multiple atomic characters and props into Full-Page (`3:4`) or Half-Page scenes.
   - **Level 3 — [`story-sequence-generator`](./.agents/skills/story-sequence-generator/SKILL.md)**: Generates a 3-part cohesive storyline (`Act 1`, `Act 2`, `Act 3`) using a locked Continuity Bible.
   - **Level 3.5 (Step 1 of 2-Step Video Workflow) — [`story-screenplay-generator`](./.agents/skills/story-screenplay-generator/SKILL.md)**: Transforms an Act's exact storyline script, Google Flow Character/Asset definitions, character personality traits, and storyline coloring book scene images into a detailed human-readable screenplay (`output/Blends/<Act>_Screenplay.txt`) + JSON manifest, evaluates it across 5 mandatory gates ([`evaluate_screenplay.py`](./.agents/skills/story-screenplay-generator/scripts/evaluate_screenplay.py)), and **STOPS** for explicit human approval before any video rendering occurs.
   - **Level 4 (Step 2 of 2-Step Video Workflow) — [`story-video-generator`](./.agents/skills/story-video-generator/SKILL.md)**: Triggered ONLY after human approval of the Step 1 screenplay. Enforces 100% adherence to the storyline coloring book images at the start/end of every scene ([`colorize_flow_act1_scenes.swift`](./.agents/skills/story-video-generator/scripts/colorize_flow_act1_scenes.swift)), synthesizes multi-character neural human voice narration following the verbatim Act script ([`synthesize_human_narration.py`](./.agents/skills/story-video-generator/scripts/synthesize_human_narration.py)), renders full-duration 30fps animations with lockstep audio/video interleaving ([`render_screenplay_video.swift`](./.agents/skills/story-video-generator/scripts/render_screenplay_video.swift)), and supports 2-second lossless audio remuxing ([`mux_narration_into_mp4.swift`](./.agents/skills/story-video-generator/scripts/mux_narration_into_mp4.swift)).
3. **QA & Book Assembly Skills**:
   - [`illustration-qa-inspector`](./.agents/skills/illustration-qa-inspector/SKILL.md): Normalizes B&W line art to pure `#000000`/`#FFFFFF` PNGs and performs independent 6-point multimodal QA.
   - [`activity-page-composer`](./.agents/skills/activity-page-composer/SKILL.md): Composes 2-related-animals-per-page writing + coloring sheets, embeds Word Find SVGs, and compiles the ordered PDF coloring book (ordered by theme: individual animal pages first, full-page coloring scenes later).

---

## Hands-Free Execution & Auto-Run Rules ([`.agents/rules/hands-off-execution.md`](./.agents/rules/hands-off-execution.md))

To ensure all skills run 100% hands-free without re-prompting the user for manual permission:

1. **Always Use Single, Prefix-Matchable Commands (Zero `&&`, `;`, `||`, `$VAR`, or `$(...)`)**:
   - Do **not** chain commands with `&&`, `;`, `||`, pipes `|`, command substitutions `$(...)`, or shell variables `$VAR`.
   - Always invoke each binary as its own standalone command from the repository root using literal paths so any user "Always Allow" rule prefix-matches permanently:
     - `python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/<skill>/scripts/<script>.py ...`
     - `swift -module-cache-path /tmp/swift_cache /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/<skill>/scripts/<script>.swift ...`
     - `git -C /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator <subcommand> ...`
2. **Use the Single Master Orchestrator for Step 2 Video Generation**:
   - Invoke `python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/story-video-generator/scripts/generate_video_from_screenplay.py --screenplay <screenplay.json> --out-mp4 <primary.mp4> --copy-mp4 <secondary.mp4>` so voice synthesis (with automatic WAV caching), video rendering, and GitHub file-size optimization run inside a single Python process.
3. **Write Generated Assets Only to Workspace `output/`**:
   - Store all generated audio (`output/audio/`), illustrations (`output/Blends/illustrations/`), screenplays (`output/screenplays/`, `output/Blends/`), and videos (`output/Blends/`, `output/videos/`) inside the workspace (never `/tmp` for cross-step assets) to prevent cross-sandbox `NSCocoaErrorDomain Code=257` permission blocks.
