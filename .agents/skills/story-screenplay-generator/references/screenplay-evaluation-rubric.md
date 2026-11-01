# Screenplay Evaluation & Google Flow (`Veo 3.1`) Prompt Rubric

## 1. Why Slideshows Fail & What Makes a True 10-Second Animation

| Dimension | Static Slideshow (REJECT) | Full-Fledged 10s Animation (PASS) |
| :--- | :--- | :--- |
| **Character Motion** | Frozen pose; only the camera zooms in or pans across the image. | Articulated limbs (walking legs, reaching hands, flapping wings), head turns, eye blinks, and expressive mouth/beak movement. |
| **Environment / Backdrop** | Static painted background. | Multi-plane parallax + secondary motion (swaying spinach/potato leaves, drifting clouds, floating pollen/sunbeams, rippling soil/water). |
| **Temporal Structure** | 1 static state held for N seconds. | 3 distinct timed beats (`0–3s` Hook $\rightarrow$ `3–7s` Discovery Action $\rightarrow$ `7–10s` Joyful Reaction). |
| **Audio Design** | Generic background loop only. | Synchronized character narration/voiceover, spot foley (wing flutter, footsteps, dirt rustle, cheerful chirp), and warm instrumental score. |

---

## 2. Detailed 5-Gate Checklist

### Gate 1: Child Safety & Flow Policy Hygiene (`child_safe`)
- **No Scary or Harmful Depictions**: Insects (`grub`), thorns (`snag`), or wild animals (`stag`) must be depicted as cute, gentle, smiling storybook friends.
- **Google Flow Safety Filter Avoidance**:
  - In Google Flow (`Veo 3.1`), combining realistic/human child terms (`"5-year-old boy"`, `"young child"`, `"kids"`) with certain action verbs can trigger false-positive policy blocks.
  - **Rule**: Inside `google_flow_prompt`, refer to human kid characters either by their registered **Flow Character Name** (`Clem`) or as `"a cheerful little cartoon garden explorer in blue denim overalls and a white shirt"`.

### Gate 2: Child Friendliness & Spoken Pacing (`child_friendly`)
- **Duration**: `8.0` to `12.0` seconds (target `10.0s`).
- **Narration Word Budget**: $\le 24$ spoken words across the entire 10-second clip ($\le 2.4$ words/sec) so ages 4–6 can clearly hear the target phonics word (`crop`, `spud`).
- **Tone**: Encouraging, curious, warm, and conversational.

### Gate 3: Entertainment & Physical Vitality (`entertaining`)
- **Minimum Articulated Verbs**: At least 4 concrete motion verbs across the 3 beats (e.g., `flutters`, `hops`, `kneels`, `pulls`, `waves`, `chirps`, `grins`).
- **Minimum Environmental Motions**: At least 2 continuous backdrop animations (e.g., `swaying spinach leaves`, `drifting fluffy clouds`, `twinkling sunbeams`).

### Gate 4: Theme & Phonics Fidelity (`theme_true`)
- Every target theme landmark (`rustic wooden garden fence`, `rows of green crop plants`, `cozy cottage`) and target phonics word (`crop`, `spud`) must appear in both the visual action and the narration/caption.

### Gate 5: Well-Formed Google Flow Prompt (`flow_well_formed`)
- **Word Count**: `90–145` words in a single cohesive paragraph.
- **No Raw Formatting Artifacts**: Zero `[BRACKETS]`, zero hex codes (`#000000`), zero file names (`page-038.png`), and zero markdown bullet lists inside `google_flow_prompt`.
- **Mandatory `Audio:` Clause**: Must end with `Audio: ...` describing the voice/chirp tone, foley sound effects, and instrumental music.
