---
name: act-production-orchestrator
description: Master end-to-end driver workflow skill for producing a complete Phonics Book & Animated Story Act—from initial Act writeup and phonics dialogue to B&W/Colored storyline keyframes, 5-gate screenplay validation, multi-character neural voiceover synthesis, and final animated MP4 video + activity pages. Sits in the driver's seat, proactively prompts the user for required inputs at every step, notifies the user inline of progress, and pauses at 5 mandatory user checkpoints featuring a Dual-Mode Revision Loop (Mode 1: manual file edits by user; Mode 2: conversational edits by agent) until explicit user approval.
---

# Act Production Orchestrator (`act-production-orchestrator`)

You are in the **Driver's Seat** for the end-to-end production of a Phonics Story Act. Your job is to guide the user from an initial Act idea or draft writeup all the way to verified, production-ready artifacts—while keeping the user informed inline at every transition, proactively asking for required inputs before each stage, and enforcing **Interactive Checkpoints** with a **Dual-Mode Revision Loop**.

---

## Core Orchestration Principles

1. **Driver-Seat Proactive Guidance**:
   - Never wait passively or guess underspecified inputs. At the start of the workflow and before every stage transition, proactively tell the user where we are in the 5-Stage Pipeline and prompt them (using `ask_question` for structured options or concise inline prompts) for any inputs required for the next stage.
2. **Continuous Inline Status Notifications**:
   - Before invoking a child skill or background script, post a clear inline status banner (`[Stage X/5 — <Stage Name>]`) explaining what is running.
   - As soon as a stage completes, present clickable markdown links (`[filename](file:///absolute/path)`) to every generated artifact along with a concise validation summary.
3. **5 Mandatory User Checkpoints with Dual-Mode Revision Loops**:
   - The pipeline **MUST STOP** at the end of each stage (Checkpoints 1 through 5) so the user can inspect the artifacts that will feed into the next stage.
   - At every checkpoint, the user can fix issues or refine artifacts in **2 interchangeable modes** across as many loop iterations as needed:
     - **Mode 1 — Manual File Edit (User Updates Files Directly)**: The user edits the markdown/text/JSON/image/audio files directly in their editor and notifies you that they are done. You run `manage_act_pipeline.py --check-stage <N>` to detect the modified file hashes, synchronize any paired manifests (e.g., syncing `.txt` edits into `.json` or re-colorizing an edited `_bw.png`), re-run deterministic validation gates, and present the updated verification status.
     - **Mode 2 — Agent-Assisted Edit (User Asks Agent to Update Files)**: The user describes what they want changed in chat. You apply the edits (or re-invoke the child skill for the specific beat/scene), re-run deterministic validation, snapshot the updated hashes, and present the updated artifacts for review.
   - **Loop Exit Criteria**: Each checkpoint loop continues (allowing any mix of Mode 1 and Mode 2 iterations) until **both** (a) deterministic stage validation passes (`PASS`) **and** (b) the user explicitly approves the artifact to advance to the next stage.
4. **Hands-Off Prefix-Matchable Execution**:
   - Follow [`.agents/rules/hands-off-execution.md`](../../rules/hands-off-execution.md) strictly: never chain shell commands with `&&`, `;`, `||`, or `|`, and never use `$VAR` or `$(...)`. Invoke every Python or Swift script as a single standalone command with literal absolute paths.

---

## Pipeline Architecture & Child Skills Invoked

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                  ACT PRODUCTION ORCHESTRATOR (Driver Skill)                  │
│             scripts/manage_act_pipeline.py (State & Hash Tracker)            │
└──────────────────────────────────────┬───────────────────────────────────────┘
                                       │
       ┌───────────────────────────────▼───────────────────────────────┐
       │ STAGE 0: Proactive Intake & Kickoff                           │
       │ • Prompts user for Act #, Title, Setting, Target Phonics      │
       │   Words, Character Sheet locks, and Draft Writeup source.     │
       │ • Initializes output/pipeline/<act_slug>_pipeline_state.json  │
       └───────────────────────────────┬───────────────────────────────┘
                                       │
       ┌───────────────────────────────▼───────────────────────────────┐
       │ STAGE 1: Act Writeup, Phonics Dialogue & Continuity Bible     │
       │ • Invokes: theme-word-generator + story-sequence-generator    │
       │ • Output:  output/Blends/<Act>_Story_Writeup.md               │
       │ 🛑 CHECKPOINT 1 LOOP (Mode 1 Manual Edit ⇄ Mode 2 Agent Edit) │
       └───────────────────────────────┬───────────────────────────────┘
                                       │ (User Approves Checkpoint 1)
       ┌───────────────────────────────▼───────────────────────────────┐
       │ STAGE 2: Storyline B&W & 100% Pixel-Locked Color Keyframes    │
       │ • Invokes: scene-illustration-generator +                     │
       │            illustration-qa-inspector + Swift Flood-Fill       │
       │ • Output:  output/Blends/illustrations/<act>_scene*_bw/color  │
       │ 🛑 CHECKPOINT 2 LOOP (Mode 1 Manual Edit ⇄ Mode 2 Agent Edit) │
       └───────────────────────────────┬───────────────────────────────┘
                                       │ (User Approves Checkpoint 2)
       ┌───────────────────────────────▼───────────────────────────────┐
       │ STAGE 3: Screenplay, Animation Anchors & 5-Gate Evaluation    │
       │ • Invokes: story-screenplay-generator + evaluate_screenplay.py│
       │ • Output:  output/Blends/<Act>_Screenplay.txt                 │
       │            output/screenplays/<act>_screenplay.json           │
       │            output/screenplays/<act>_eval_report.json          │
       │ 🛑 CHECKPOINT 3 LOOP (Mode 1 Manual Edit ⇄ Mode 2 Agent Edit) │
       └───────────────────────────────┬───────────────────────────────┘
                                       │ (User Approves Checkpoint 3)
       ┌───────────────────────────────▼───────────────────────────────┐
       │ STAGE 4: Multi-Character Neural Voiceover Synthesis           │
       │ • Invokes: story-video-generator (synthesize_human_narration) │
       │ • Output:  output/audio/<act>_vo/*.wav + manifest.json        │
       │ 🛑 CHECKPOINT 4 LOOP (Mode 1 Manual Edit ⇄ Mode 2 Agent Edit) │
       └───────────────────────────────┬───────────────────────────────┘
                                       │ (User Approves Checkpoint 4)
       ┌───────────────────────────────▼───────────────────────────────┐
       │ STAGE 5: Final MP4 Video Render, Remux & Optional Book Pages  │
       │ • Invokes: story-video-generator (generate_video_from_...)    │
       │            + optional word-find-generator / activity-composer │
       │ • Output:  output/Blends/<Act>_Animation.mp4 (<50 MB)         │
       │            output/videos/<act>_animation.mp4                  │
       │ 🛑 CHECKPOINT 5 LOOP (Mode 1 Manual Edit ⇄ Mode 2 Agent Edit) │
       └───────────────────────────────────────────────────────────────┘
```

---

## Step-by-Step Driver Execution Protocol

### Stage 0: Proactive Intake & Kickoff

1. **Inspect Existing Workspace Assets First**:
   - Check `output/Blends/`, `output/screenplays/`, and any existing draft files so you can offer smart defaults rather than asking blank-slate questions.
2. **Proactively Prompt the User (`ask_question`)**:
   - Ask the user for any missing kickoff parameters needed to initialize the Act:
     1. **Act Identifier & Title/Setting** (e.g., `Act 3: Down at the Pond`, `Act 2: Into the Woods`).
     2. **Target Phonics Category & Words** (e.g., confirm the 5 target phonics words for the Act, or offer to curate them via [`theme-word-generator`](../theme-word-generator/SKILL.md)).
     3. **Character Continuity Lock** (e.g., `(Recommended) Lock to Clem & Plum Google Flow Character Sheet` vs adding new characters).
     4. **Story Writeup Source** (e.g., `(Recommended) Expand existing draft from story_draft_prompts.txt with interactive Clem & Plum phonics dialogue`, `Paste my own writeup`, or `Generate a fresh 5-scene writeup`).
3. **Initialize the Pipeline State File**:
   - Run the standalone command:
     ```bash
     python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/act-production-orchestrator/scripts/manage_act_pipeline.py --act <act_slug> --init --title "<Act Title>" --words "<w1,w2,w3,w4,w5>"
     ```

---

### Stage 1: Act Storyline Writeup, Phonics Dialogue & Continuity Bible

1. **Inline Notification**:
   - Notify the user: *"Starting **Stage 1/5 (Act Storyline Writeup & Continuity Bible)**..."*
2. **Generate or Format the Act Writeup Artifact**:
   - Following [`theme-word-generator`](../theme-word-generator/SKILL.md) and [`story-sequence-generator`](../story-sequence-generator/SKILL.md), create the structured, human-editable writeup file at:
     - `output/Blends/<Act_Prefix>_Story_Writeup.md`
   - This file MUST contain:
     - **Act Metadata**: Act number, title, setting backdrop, target phonics category, and ordered target words.
     - **Google Flow Character & Continuity Locks**: Exact visual & personality locks for Clem, Plum, and any recurring animals/props.
     - **Scene-by-Scene Breakdown (Beats 1..N)**: For each beat:
       - `Target Word`: `<word>` (with phonetic breakdown, e.g., `/f/ - /l/ - /a/ - /p/`)
       - `Visual Scene Description`: Exact composition for the B&W coloring page and colored keyframe.
       - `Utterances (Dialogue & Narration)`: Speaker-tagged lines (`Narrator`, `Clem`, `Plum`) preserving 100% of the core storyline sentences plus interactive phonics sound-out dialogue.
3. **Snapshot & Validate Stage 1**:
   ```bash
   python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/act-production-orchestrator/scripts/manage_act_pipeline.py --act <act_slug> --snapshot-stage 1
   ```
4. **🛑 CHECKPOINT 1 — Enter Dual-Mode Revision Loop**:
   - Present the clickable link to [`output/Blends/<Act_Prefix>_Story_Writeup.md`](file:///Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/Blends/) and prompt the user via `ask_question`:
     - **Option 1**: `Approve Story Writeup & proceed to Stage 2 (Storyline Keyframe Illustrations)`
     - **Option 2**: `I manually edited the Story Writeup file — re-read and validate my changes (Mode 1)`
     - **Option 3**: `Update the Story Writeup for me based on my feedback below (Mode 2)`
   - **If Mode 1**: Run `manage_act_pipeline.py --act <act_slug> --check-stage 1`, report the detected file modifications, verify all target words and speaker lines are valid, and repeat the Checkpoint 1 prompt.
   - **If Mode 2**: Apply the requested edits to `output/Blends/<Act_Prefix>_Story_Writeup.md`, run `--record-revision --stage 1 --mode agent`, and repeat the Checkpoint 1 prompt.
   - **When Approved**: Run `manage_act_pipeline.py --act <act_slug> --approve-stage 1` and advance to Stage 2.

---

### Stage 2: Storyline B&W Coloring Pages & 100% Pixel-Locked Colored Keyframes

1. **Proactive Step Input Prompt**:
   - Confirm with the user whether to generate all 5 scenes in `1:1` (`1080x1080`) square format using the locked Clem & Plum Character Sheet and deterministic flood-fill colorization, or if any scene needs custom visual styling.
2. **Inline Notification & Execution**:
   - Notify the user inline before spawning `image-generator` subagents for the B&W storyline illustrations (`act<N>_scene<1..5>_<word>_raw`).
   - Normalize and flood-fill colorize each B&W illustration using the Swift region colorizer so that:
     - `output/Blends/illustrations/<act>_scene<1..5>_<word>_flow_bw.png` is pure `#000000` ink on `#FFFFFF` white (`1080x1080`).
     - `output/Blends/illustrations/<act>_scene<1..5>_<word>_flow_color.png` is `1080x1080` vibrant color with 100% pixel-identical black ink outlines.
   - Run [`illustration-qa-inspector`](../illustration-qa-inspector/SKILL.md) visual verification (`read_file` on each generated PNG) to confirm character fidelity and zero unwanted text/watermarks.
3. **Snapshot & Validate Stage 2**:
   ```bash
   python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/act-production-orchestrator/scripts/manage_act_pipeline.py --act <act_slug> --snapshot-stage 2
   ```
4. **🛑 CHECKPOINT 2 — Enter Dual-Mode Revision Loop**:
   - Present clickable links to all 5 B&W and 5 Colored PNG keyframes and prompt the user (`ask_question`):
     - **Option 1**: `Approve all B&W and Colored Keyframes & proceed to Stage 3 (Screenplay & 5-Gate Evaluation)`
     - **Option 2**: `I manually updated/replaced one or more image files — re-scan and validate (Mode 1)`
     - **Option 3**: `Regenerate or adjust colors on specific scenes based on my feedback (Mode 2)`
   - **If Mode 1**: Run `manage_act_pipeline.py --act <act_slug> --check-stage 2`. If the user replaced a `_bw.png` file, offer to re-run deterministic flood-fill colorization so `_color.png` stays 100% pixel-locked. Repeat Checkpoint 2 until approved.
   - **If Mode 2**: Regenerate or re-colorize only the specified scene(s), run `--record-revision --stage 2 --mode agent`, and repeat Checkpoint 2 until approved.
   - **When Approved**: Run `manage_act_pipeline.py --act <act_slug> --approve-stage 2` and advance to Stage 3.

---

### Stage 3: Screenplay Generation, Animation Anchors & 5-Gate Evaluation

1. **Proactive Step Input Prompt**:
   - Ask if the user wants any specific camera motion, prop animation highlights, or voice direction emphasized in the screenplay, or `(Recommended) Generate screenplay directly from the approved Stage 1 Writeup & Stage 2 Keyframes`.
2. **Inline Notification & Execution**:
   - Invoke [`story-screenplay-generator`](../story-screenplay-generator/SKILL.md) to generate:
     - Human-readable screenplay: `output/Blends/<Act_Prefix>_Screenplay.txt`
     - Single-Source-of-Truth JSON manifest: `output/screenplays/<act_slug>_screenplay.json` (containing `utterances`, `source_scene_image_path`, `colored_scene_image_path`, and `animation_anchors` for every beat).
   - Run the 5-Gate Evaluator:
     ```bash
     python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/story-screenplay-generator/scripts/evaluate_screenplay.py --input /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/screenplays/<act_slug>_screenplay.json --output-report /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/screenplays/<act_slug>_eval_report.json
     ```
   - Snapshot Stage 3 artifacts:
     ```bash
     python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/act-production-orchestrator/scripts/manage_act_pipeline.py --act <act_slug> --snapshot-stage 3
     ```
3. **🛑 CHECKPOINT 3 — Enter Dual-Mode Revision Loop**:
   - Present the 5-Gate Evaluation Report table (`PASS`/`FAIL`), [`output/Blends/<Act_Prefix>_Screenplay.txt`](file:///Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/Blends/), and [`output/screenplays/<act_slug>_screenplay.json`](file:///Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/screenplays/).
   - Prompt the user (`ask_question`):
     - **Option 1**: `Approve Screenplay & proceed to Stage 4 (Neural Human Voiceover Synthesis)`
     - **Option 2**: `I manually edited the Screenplay (.txt or .json) — sync and re-evaluate all 5 gates (Mode 1)`
     - **Option 3**: `Update the Screenplay dialogue, action beats, or anchors for me (Mode 2)`
   - **If Mode 1**: Run `manage_act_pipeline.py --act <act_slug> --check-stage 3`. This automatically detects whether `.txt`, `.json`, or `.md` was manually edited, syncs `.txt` dialogue/narration updates into `<act_slug>_screenplay.json` if only `.txt` was modified, and re-runs `evaluate_screenplay.py`. Report the new 5-gate status and repeat Checkpoint 3.
   - **If Mode 2**: Apply the requested changes to both `.txt` and `.json`, re-run `evaluate_screenplay.py`, run `--record-revision --stage 3 --mode agent`, and repeat Checkpoint 3.
   - **When Approved**: Run `manage_act_pipeline.py --act <act_slug> --approve-stage 3` (which also sets `"status": "APPROVED"` inside `<act_slug>_screenplay.json`) and advance to Stage 4.

---

### Stage 4: Multi-Character Neural Human Voiceover Synthesis

1. **Proactive Step Input Prompt**:
   - Confirm voice casting (`Narrator: en-US-AvaNeural`, `Clem: en-US-AnaNeural`, `Plum: en-GB-MaisieNeural`) or allow the user to customize voice rates/pitches before synthesis.
2. **Inline Notification & Execution**:
   - Notify the user inline and run `synthesize_human_narration.py` (uses WAV caching so unchanged lines are instant):
     ```bash
     python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/story-video-generator/scripts/synthesize_human_narration.py --screenplay /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/screenplays/<act_slug>_screenplay.json --out-dir /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/audio/<act_slug>_vo
     ```
   - Snapshot Stage 4 artifacts:
     ```bash
     python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/act-production-orchestrator/scripts/manage_act_pipeline.py --act <act_slug> --snapshot-stage 4
     ```
3. **🛑 CHECKPOINT 4 — Enter Dual-Mode Revision Loop**:
   - Present the synthesized audio summary (total duration, per-scene durations, and clickable link to `output/audio/<act_slug>_vo/manifest.json`) and prompt the user (`ask_question`):
     - **Option 1**: `Approve Voiceover Audio & proceed to Stage 5 (Final Animated Video Render)`
     - **Option 2**: `I manually replaced WAV files or edited utterances in JSON — re-sync audio manifest (Mode 1)`
     - **Option 3**: `Adjust pronunciation, pacing, or dialogue lines and re-synthesize for me (Mode 2)`
   - **If Mode 1**: Run `manage_act_pipeline.py --act <act_slug> --check-stage 4`. If `<act_slug>_screenplay.json` utterances were edited, re-run `synthesize_human_narration.py` (cached WAVs stay untouched; only edited lines re-synthesize). If `.wav` files were manually replaced, recalculate WAV durations in `manifest.json`. Repeat Checkpoint 4.
   - **If Mode 2**: Update the target utterance(s) in `<act_slug>_screenplay.json`, re-run `synthesize_human_narration.py`, run `--record-revision --stage 4 --mode agent`, and repeat Checkpoint 4.
   - **When Approved**: Run `manage_act_pipeline.py --act <act_slug> --approve-stage 4` and advance to Stage 5.

---

### Stage 5: Final Animated MP4 Video Render, Lossless Remux & Optional Activity Pages

1. **Proactive Step Input Prompt**:
   - Ask the user whether to:
     - Render the `1080x1080` `30 fps` animated `.mp4` video (`output/Blends/<Act_Prefix>_Animation.mp4`) alone, or
     - Also generate the Act's printable Word Find puzzle ([`word-find-generator`](../word-find-generator/SKILL.md)) and printable coloring + handwriting activity pages ([`activity-page-composer`](../activity-page-composer/SKILL.md)).
2. **Inline Notification & Execution**:
   - Run the single master video orchestrator inside Standard Sandbox Mode (`BypassSandbox: false` once Stage 4 audio exists):
     ```bash
     python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/story-video-generator/scripts/generate_video_from_screenplay.py --screenplay /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/screenplays/<act_slug>_screenplay.json --out-mp4 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/Blends/<Act_Prefix>_Animation.mp4 --copy-mp4 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/videos/<act_slug>_animation.mp4
     ```
   - Snapshot Stage 5 artifacts:
     ```bash
     python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/act-production-orchestrator/scripts/manage_act_pipeline.py --act <act_slug> --snapshot-stage 5
     ```
3. **🛑 CHECKPOINT 5 — Final Deliverable Sign-Off Loop**:
   - Present clickable links to `output/Blends/<Act_Prefix>_Animation.mp4`, `output/videos/<act_slug>_animation.mp4`, file size (`<50 MB`), duration, and any activity page PDFs/SVGs.
   - Prompt the user (`ask_question`):
     - **Option 1**: `Approve final Act artifacts & mark Act COMPLETE`
     - **Option 2**: `I manually updated audio/screenplay/image files — remux or re-render (Mode 1)`
     - **Option 3**: `Tweak animation anchors, audio mix, or visuals and update the video for me (Mode 2)`
   - **Fast-Path Audio Remux Optimization**: In either Mode 1 or Mode 2, if only audio or narration timing/volume changed (and visual frames did not change), invoke `mux_narration_into_mp4.swift` to losslessly replace the audio track in **~2 seconds** without re-rendering video frames!
   - **When Approved**: Run `manage_act_pipeline.py --act <act_slug> --approve-stage 5` and present the final Act Completion Summary.
