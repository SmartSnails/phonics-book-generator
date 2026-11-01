---
name: story-screenplay-generator
description: >-
  Use this skill when transforming a story act or scene storyline, character
  traits, and backdrop setting into an enhanced, time-coded ~10-second animated
  screenplay, evaluating the draft across 5 mandatory quality gates (child-safe,
  child-friendly, entertaining, true to theme, and Google Flow / Veo 3.1
  ready), and compiling the approved screenplay into a Google Flow animation
  prompt and multi-layer animation manifest.
---

# Story Screenplay Generator & Evaluator (`story-screenplay-generator`)

Transforms a raw children's story beat, character bible, and backdrop setting into a **richly choreographed, ~10-second animated screenplay** and **Google Flow (`Veo 3.1`) animation prompt**, enforced by a deterministic **5-Gate Evaluation Rubric** and independent adversarial review.

> **Anti-Slideshow Mandate**: A screenplay must NEVER describe a static picture with a camera pan. Every beat must choreograph **articulated character body motion** (walking, kneeling, reaching, wing-flapping, head-tilting), **facial animation** (blinking, grinning, talking/chirping), and **secondary environmental motion** (swaying crops, drifting clouds, fluttering leaves).

---

## 1. Input & Output JSON Schema

Provide (or extract from the project's Story Continuity Bible / story draft):
1. **`title`, `act`, & `target_phonics_words`**: The narrative title and target phonics/vocabulary words (e.g., *Act 1: In the Garden* — `["crop", "spud"]`).
2. **`characters`**: List of characters, each with:
   - `name` (e.g., `Clem`, `Plum`)
   - `visual_anchor` (physical appearance, clothing/colors, proportions)
   - `personality_traits` (e.g., Clem: `["curious", "joyful", "hands-on doer"]`; Plum: `["calm", "observant", "gentle guide", "notices things first"]`)
   - `trait_to_action_mapping` (explicit mapping of how their personality traits drive their physical actions in the scene)
3. **`backdrop`**: Setting description (`background_top_third`, `midground`, `foreground`) plus `required_landmarks` (e.g., `["cottage", "fence", "crop"]`).
4. **`target_duration_sec`**: Default `10.0` seconds (`8.0–12.0s` allowed).
5. **`beats`**: Array of 3 contiguous timed beats (`0.0–3.2s`, `3.2–7.0s`, `7.0–10.0s`), each specifying `start_sec`, `end_sec`, `character_motion`, `facial_expression`, `backdrop_motion`, `camera_motion`, `narration_or_dialogue`, and `sfx_and_music`.
6. **`google_flow_prompt`**: Single-paragraph `90–145` word natural prose prompt for Google Flow (`Veo 3.1`).

---

## 2. Stage 1: Narration & Visual Choreography Enhancement

Enhance the raw storyline using two systematic mappings before drafting the screenplay:

### A. Character-Trait-to-Action Mapper
Every character trait must be expressed visually through **specific articulated physical actions**, not abstract adjectives:
- *"Curious hands-on doer"* (e.g., Clem) $\rightarrow$ leans forward with wide sparkling eyes, kneels in the soft garden soil, reaches out with both hands to gently touch/lift the plant or spud, grins from ear to ear.
- *"Calm, observant guide"* (e.g., Plum) $\rightarrow$ flutters down to perch on the rustic wooden fencepost, tilts head inquisitively, points with one stubby blue wing toward the discovery, hops closer with a cheerful chirp.

### B. Backdrop Sensory & Secondary Motion Enricher
Enrich the scene narration and visual background with **2–3 continuous secondary motions** that make the world feel alive:
- **Flora & Props**: Rows of emerald-green spinach crops and leafy potato plants swaying in a gentle afternoon breeze.
- **Atmosphere & Light**: Warm golden afternoon sunbeams, soft drifting clouds, and tiny golden pollen/dust motes floating in the air.
- **Acoustic Ambience**: Gentle garden breeze, soft rustling leaves, cheerful bird chirps, and warm acoustic storybook instrumentation.

---

## 3. Stage 2: The 3-Beat Time-Coded 10-Second Screenplay Structure

Structure every ~10-second animation into **3 distinct, continuous animated beats**:

| Beat | Time Window | Narrative Function | Required Articulated Motion |
| :--- | :--- | :--- | :--- |
| **Beat 1: Establish & Hook** | `0.0s – 3.0s` (`3.0s`) | Set the living backdrop and initiate character movement/curiosity. | Character 1 (e.g., Plum) flutters/lands and gestures; Character 2 (e.g., Clem) walks/hops in looking around; backdrop foliage sways. |
| **Beat 2: Core Discovery Action** | `3.0s – 7.0s` (`4.0s`) | Active physical interaction with the theme's core subject/word (`crop` / `spud`). | Hands-on physical action (e.g., kneeling, parting leaves, lifting a dusty spud or pointing across the matching spinach crop); clear lip-sync/chirp narration. |
| **Beat 3: Joyful Reaction & Payoff** | `7.0s – 10.0s` (`3.0s`) | Emotional payoff, shared delight, and memorable phonetic word reinforcement. | Both characters react (happy bounce, wing-wave, bright laugh/giggle) as the camera settles on the discovery. |

---

## 4. Stage 3: Mandatory 5-Gate Screenplay Evaluation Rubric

Run [`scripts/evaluate_screenplay.py`](./scripts/evaluate_screenplay.py) AND an independent adversarial review against these **5 mandatory gates**:

1. **Gate 1 — Child Safety & Flow Policy Compliance (`child_safe`)**:
   - Zero frightening imagery, violence, sharp hazards, or distress (e.g., if a sleeve snags on a bush, frame it as a gentle, funny tug with a smile—never a scratch or scare).
   - **Flow Filter Hygiene**: When compiling the Google Flow (`Veo 3.1`) prompt, avoid words that trigger automated minor-safety filters (`"children"`, `"5-year-old boy"`, `"young kid"`); use Flow Character ingredient names (`Clem`) or storybook phrasing (`"cheerful little cartoon garden explorer in blue denim overalls"`).
2. **Gate 2 — Child Friendliness & Pacing (`child_friendly`)**:
   - Spoken dialogue/narration across the 10-second clip must be **$\le 24$ words total** ($\le 2.4$ words/sec) so young listeners ages 4–6 can easily absorb the target phonics word without rushed speech.
   - Vocabulary is concrete, warm, and encouraging.
3. **Gate 3 — Entertainment & Anti-Slideshow Vitality (`entertaining`)**:
   - Verifies **per-beat vitality** (every single beat must contain non-empty `character_motion`, `facial_expression`, `backdrop_motion`, and $\ge 1$ articulated motion verb), at least **4 distinct articulated character movements** and **2 secondary environmental motions** across the 3 beats, plus $\ge 3$ articulated motion verbs and $\ge 2$ backdrop motion cues inside `google_flow_prompt`. Rejects any draft that relies solely on camera pans/zooms.
4. **Gate 4 — Theme & Phonics Fidelity (`theme_true`)**:
   - Explicitly showcases the target theme (`In the Garden`) and visibly + auditorily highlights the target phonics word(s) (`crop`, `spud`).
5. **Gate 5 — Google Flow (`Veo 3.1`) Structural Readiness (`flow_well_formed`)**:
   - Compiles into a **single-paragraph natural prose prompt (`90–145 words`)** containing all 6 Flow Animation Pillars:
     1. *Full-Color 2D Storybook Animation Style Anchor* (preserving bold black ink outlines, zero uncolored B&W areas).
     2. *Character Visual & Color Anchors + Articulated Motion*.
     3. *Dynamic Backdrop & Secondary Environmental Motion*.
     4. *Smooth Camera Choreography*.
     5. *Warm Lighting & Palette*.
     6. *Synchronized Audio Clause (`Audio: ...`)* specifying voice/chirp cues, foley SFX, and musical score.
   - Zero `[BRACKETED HEADERS]`, zero raw hex codes (`#FFFFFF`), and zero file extensions (`.png`, `.pdf`) inside the compiled Flow prompt.

---

## 5. Execution Commands

### Step 1: Validate & Score a Draft Screenplay JSON
```bash
python3 /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/story-screenplay-generator/scripts/evaluate_screenplay.py \
  --input output/screenplays/act1_in_the_garden_screenplay.json \
  --output-report output/screenplays/act1_in_the_garden_eval_report.json
```

### Step 2: Hand Off to `story-video-generator`
Once all 5 gates return `PASS` and adversarial review findings are resolved, pass the approved screenplay JSON to [`story-video-generator`](../story-video-generator/SKILL.md) to render the full-fledged 10-second animation.
