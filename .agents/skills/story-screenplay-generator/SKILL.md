---
name: story-screenplay-generator
description: >-
  Use this skill as Step 1 of the 2-step video generation workflow: transforms
  an Act's exact storyline script, Google Flow Character/Asset definitions,
  character personality traits, and storyline coloring book scene images into a
  detailed, human-readable screenplay in text format (.txt / .md) plus a
  structured JSON manifest, evaluates it across 5 mandatory gates (including
  Google Flow asset linkage, verbatim Act script fidelity, engaging human voice
  spec, and 100% storyline image lock), saves the screenplay to the Blends
  folder, and STOPS to wait for explicit human approval before any video
  generation is triggered.
---

# Story Screenplay Generator & Evaluator (`story-screenplay-generator`) — Step 1 of 2

Transforms an Act's storyline script, character sheet, Google Flow defined character/scene assets, and backdrop setting into a **detailed, human-reviewable text screenplay (`.txt` / `.md`)** and **Google Flow (`Veo 3.1`) animation specification**, enforced by a deterministic **5-Gate Evaluation Rubric**.

---

## Mandatory 2-Step Human-in-the-Loop Process

> [!IMPORTANT]
> **STRICT 2-STEP GATE — NEVER AUTO-TRIGGER VIDEO GENERATION**:
> - **Step 1 (`story-screenplay-generator`)**: Generate the detailed screenplay in a human-readable text format (`.txt` and `.md`, plus companion `.json` manifest), run the 5-gate evaluator (`evaluate_screenplay.py`), save the screenplay in the `Blends` folder (parent of `illustrations`), and present it to the human reviewer. **STOP IMMEDIATELY after Step 1.**
> - **Step 2 ([`story-video-generator`](../story-video-generator/SKILL.md))**: Only when the human explicitly approves the screenplay (`human_approval.status == "APPROVED"`), trigger video generation.

---

## How to Generate the Screenplay (Step-by-Step Procedure)

Follow these 6 steps whenever generating a screenplay for any Act (Act 1: *In the Garden*, Act 2: *Into the Woods*, Act 3: *By the Pond*):

### Step 1: Ingest the 4 Required Source Inputs from `Blends`
Before writing a single line of the screenplay, read and extract:
1. **Google Flow Defined Character Assets & Character Sheet (`Blends / Character sheet`, Doc ID: `1sfRUqjoxulOZhvXRqiIQPWVQ1qrBEk4w3Zt-u01YXlY`)**:
   - Extract each character's **Google Flow Ingredient Name** (`@Clem`, `@Plum`), **Visual DNA** (hair, eyes, clothing, proportions), **Expression Sheet** (`Happy closed-mouth smile`, `Happy open-mouth laugh`, `Surprised O-mouth`, `Thinking/Curious`, `Proud/Confident`), and **Personality Traits**:
     - **Clem (`@Clem`)**: Curious, joyful, cheerful, adventurous 5-year-old boy in white button-down shirt, blue denim overalls, and brown ankle boots; the hands-on *"doer"* who asks questions kids would ask, touches things, tries things, and gets a little muddy.
     - **Plum (`@Plum`)**: Small round sky-blue songbird with oversized head and speckled crown/breast feathers; cute, calm, slightly wiser gentle guide who notices things first, points with her wing, and nudges Clem toward each discovery.
2. **Canonical Act Storyline Script (`Blends / Story draft and Prompts for 01 Animals & Nature.pdf`, Doc ID: `19JZC1N88zJilarY7d7cSt9x4lnuJwgib`)**:
   - Extract the **exact storyline narration and character dialogue** for every phonics target word in the Act (normalizing any legacy draft character names such as `"Milo"` $\rightarrow$ `"Clem"` and `"Coco"` $\rightarrow$ `"Plum"`):
     - **Act 1 (`In the Garden`)**: `crop`, `spud`, `grub`, `snag`
     - **Act 2 (`Into the Woods`)**: `stag`, `trot`, `twig`, `skin`, `flap`
     - **Act 3 (`By the Pond`)**: `frog`, `drip`, `clam`, `crab`, `slug`, `snug`
3. **Full-Page Storyline Coloring Book Illustrations (`Theme A Beginning Blend.pdf` / `Blends / illustrations`)**:
   - Locate the exact coloring book scene illustration for each target word (or, when a source PDF page is a blank placeholder as in Act 2/3, generate the B&W storyline illustration using `@Clem` and `@Plum`'s Google Flow character sheet lock and deterministically flood-fill colorize it so the B&W and color keyframes match 100% pixel-for-pixel).
   - Record the foreground, midground, and background landmarks plus the `1080x1080` top-down character coordinates (`animation_anchors`: `clem_eyes`, `clem_mouth`, `plum_beak`, `plum_notes_origin`, `focus_prop`) so Step 2 (`story-video-generator`) is 100% data-driven from the screenplay JSON.

### Step 2: Map Character Personality Traits & Backdrop to Physical Choreography
For every scene in the Act, translate the static illustration and character personality traits into **3 contiguous timed animation beats** across an `~10.0s` (`8–10s`) clip:
- **Beat 1 (`0.0s – 3.0s` | Establish & Hook)**:
  - Lock Frame 0 (`0.0s`) 100% to the storyline coloring book illustration.
  - Choreograph the guide character (`@Plum`) noticing the landmark first (e.g., fluttering down onto the fencepost, hopping closer to the dirt hole, pointing her wing) and inviting `@Clem` in.
- **Beat 2 (`3.0s – 7.0s` | Core Discovery Action on the Target Word)**:
  - Choreograph `@Clem` acting as the hands-on *"doer"* (walking up to inspect the matching rows of `crop`, dropping to his knees in the soil to tug up a leafy potato plant with dangling `spuds`, leaning down on hands and knees to wave gently at the wiggling `grub`, or tugging his white sleeve free from the bush `snag` with a laugh).
  - Add **secondary environmental motion** to the backdrop landmarks from the coloring page (swaying spinach/potato leaves, drifting fluffy clouds above the cottage, tumbling dirt specks, shimmering sunbeams).
- **Beat 3 (`7.0s – 10.0s` | Joyful Reaction & Keyframe Lock)**:
  - Choreograph a warm shared reaction (nodding, laughing, bouncing, waving) and settle at `10.0s` with **100% pixel/pose adherence** to the target storyline coloring book illustration.

### Step 3: Lock Verbatim Storyline Script & Engaging Human Voice Direction
1. **Verbatim Script Rule**:
   - Copy the Narrator, Plum, and Clem lines **verbatim** from the Act's storyline script into each scene's dialogue block. Never paraphrase or invent substitute lines.
2. **Engaging Human Voice Casting Rule (`allow_basic_os_tts: false`)**:
   - Strictly forbid basic robotic OS TTS (`/usr/bin/say`, `AVSpeechSynthesizer`, `Samantha`, `espeak`).
   - Specify **Google Flow (`Veo 3.1`) Native Expressive Multi-Character Human Audio** or **Studio/Neural Expressive Human Voice Actors** with three distinct vocal profiles:
     - **Narrator**: Warm, engaging human children's audiobook storyteller with a smiling cadence and natural emphasis on the phonics blend.
     - **Plum**: Bright, musical, warm, and encouraging young female human character voice with a gentle lilt and soft bird chirps.
     - **Clem**: Authentic, joyful, curious young child voice full of wonder and natural giggles.

### Step 4: Compile the 6-Pillar Google Flow (`Veo 3.1`) Prompt per Scene
For each ~10-second scene (and the master Act overview), write a **single cohesive prose paragraph (`90–145` words)** with zero newlines, zero `[BRACKETS]`, zero hex codes, and zero raw filenames, combining all 6 mandatory pillars in order:
1. **Pillar 1 — Visual Style & Keyframe Lock Anchor**:
   `"Vibrant full-color 2D animated storybook cartoon movie with bold black ink outlines and warm golden afternoon sunlight, strictly locked to the attached storyline reference frame and defined Google Flow characters Clem and Plum so the shot begins and ends on the exact coloring book illustration."`
2. **Pillar 2 — Environment & Backdrop Motion**:
   Describe the exact setting from the coloring page (`rustic wooden garden fence`, `cozy country cottage`, `two shade trees`) with active secondary motion (`swaying rows of emerald-green spinach crop`, `drifting fluffy clouds`, `shimmering sunbeams`).
3. **Pillar 3 — Character 1 (`@Plum`) Articulated Action**:
   Describe Plum's physical actions (`flutters her sky-blue wings`, `perches on the wooden fencepost`, `hops closer`, `points her wing`).
4. **Pillar 4 — Character 2 (`@Clem`) Articulated Action (Policy-Safe Phrasing)**:
   Refer to Clem by his Google Flow character name (`Clem, a cheerful garden explorer in a white shirt, blue denim overalls, and brown boots`) and describe his hands-on actions (`hops in`, `kneels in the soft brown soil`, `pulls up a leafy potato plant revealing round golden spuds`, `laughs and tugs his sleeve free from a bush snag`)—never using minor-filter trigger strings (`"5-year-old boy"`).
5. **Pillar 5 — Camera & Lighting Choreography**:
   Specify smooth storybook camera motion (`gentle storybook push-in`, `warm close-up framing`) that resolves cleanly onto the reference keyframe.
6. **Pillar 6 — Expressive Human Voice `Audio:` Clause**:
   End with `Audio: Engaging, warm human narration and expressive character voices saying "<verbatim storyline lines>", accompanied by <spot foley SFX> and <acoustic guitar / marimba score>.`

### Step 5: Write the Human-Reviewable Text Screenplay to `Blends/` & JSON Manifest
Save two synchronized files:
1. **Plain-Text Screenplay in `Blends/` (parent of `illustrations`)**:
   - Path: `/Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/Blends/Act<N>_<Act_Name>_Screenplay.txt` (and upload to Google Drive `Blends` folder `1W7Ehm6Uj4lYzf2qDJzLWs7iLTzK31Dt-` when Drive OAuth is active).
   - Must contain 5 structured sections:
     - **Section 1**: Production Header & Workflow Status (`STEP 1 OF 2 — PENDING_HUMAN_REVIEW`)
     - **Section 2**: Google Flow Defined Characters (`@Clem`, `@Plum`) & Storyline Keyframe Registry
     - **Section 3**: Engaging Human Voice & Audio Direction (`allow_basic_os_tts: false`)
     - **Section 4**: Scene-by-Scene Master Screenplay (Target Duration, Locked Google Flow Assets, Setting & Backdrop Enhancement, Verbatim Storyline Script & Dialogue, Timed 3-Beat Visual Choreography, and Compiled Google Flow `Veo 3.1` Prompt)
     - **Section 5**: 5-Gate Evaluation Scorecard & Human Approval Sign-Off Checklist
2. **Structured JSON Manifest (Single Source of Truth for Step 2)**:
   - Path: `/Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/screenplays/act<N>_<act_name>_screenplay.json`
   - Every beat in `beats[]` MUST include:
     - `source_scene_image_path` (B&W coloring page PNG) and `colored_scene_image_path` (100% line-art-preserving colored keyframe PNG)
     - `utterances`: ordered list of `{"speaker": "Narrator"|"Plum"|"Clem", "text": "...", "pause_after": 0.2}` combining the verbatim story text with interactive Clem & Plum phonics sound-out dialogue for the target word
     - `animation_anchors`: `{"clem_eyes": [[x1, y1], [x2, y2]], "clem_mouth": [x, y], "plum_beak": [x, y], "plum_notes_origin": [x, y], "focus_prop": [x, y]}` in `1080x1080` top-down coordinates so Step 2 scripts require zero hardcoded paths or coordinates.

### Step 6: Run the Deterministic 5-Gate Evaluator & STOP for Human Review
Run [`scripts/evaluate_screenplay.py`](./scripts/evaluate_screenplay.py) to verify all 5 gates pass (`exit code 0`):
```bash
python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/story-screenplay-generator/scripts/evaluate_screenplay.py \
  --input /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/screenplays/act1_in_the_garden_screenplay.json \
  --output-report /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/screenplays/act1_in_the_garden_eval_report.json
```
- See [`references/screenplay-evaluation-rubric.md`](./references/screenplay-evaluation-rubric.md) for the complete 5-gate specification.
- **Once all 5 gates return `"PASS"`, present the `.txt` screenplay to the human reviewer and STOP. Do not invoke `story-video-generator` until the user explicitly replies with approval.**
