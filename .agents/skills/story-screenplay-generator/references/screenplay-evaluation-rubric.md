# Screenplay Evaluation & Google Flow (`Veo 3.1`) Prompt Rubric

## 1. Why Slideshows & Robotic TTS Fail vs. Full-Fledged Storybook Animation

| Dimension | Reject (Failure Mode) | Pass (Production Standard) |
| :--- | :--- | :--- |
| **Workflow Gate** | Auto-triggering video generation before human review. | **2-Step Gate**: Step 1 generates `.txt` screenplay in `Blends/` and pauses (`PENDING_HUMAN_REVIEW`); Step 2 runs only after human approval (`APPROVED`). |
| **Character & Scene Assets** | Redrawing synthetic/geometric characters or ignoring the coloring pages. | **100% Google Flow Asset Lock**: Uses `@Clem` and `@Plum` (`Character sheet` `1sfRUqjoxulOZhvXRqiIQPWVQ1qrBEk4w3Zt-u01YXlY`) and locks the start/end of every scene to the exact storyline coloring book pages. |
| **Voice & Narration** | Basic robotic OS TTS (`/usr/bin/say`, `Samantha`, `AVSpeechSynthesizer`) or paraphrased lines. | **Engaging Human Voice + Verbatim Script**: Expressive human storyteller & character voices (`allow_basic_os_tts: false`) delivering the exact lines from the Act's storyline script. |
| **Character Motion** | Frozen pose; only the camera pans or zooms. | Articulated limbs (walking legs, kneeling, pulling spuds, flapping wings), head turns, eye blinks, and expressive mouth/beak movement mapped from character personality traits. |
| **Environment / Backdrop** | Static painted background. | Multi-plane depth + secondary motion (swaying spinach/potato leaves, drifting clouds, tumbling dirt specks, shimmering sunbeams). |

---

## 2. Detailed 5-Gate Checklist (Enforced by `scripts/evaluate_screenplay.py`)

### Gate 1: Child Safety & Flow Policy Hygiene (`gate_1_child_safe_and_flow_hygiene`)
- **No Scary or Harmful Depictions**: Insects (`grub`), thorns (`snag`), or wild animals (`stag`) must be depicted as cute, gentle, harmless storybook moments (`snag` is a gentle fabric tug with a cheerful laugh; `grub` is a cute smiling baby beetle).
- **Google Flow Safety Filter Hygiene**:
  - In Google Flow (`Veo 3.1`), combining literal human minor age phrases (`"5-year-old boy"`, `"young child"`, `"little boy"`) with action verbs can trigger false-positive minor-safety blocks.
  - **Rule**: Inside `google_flow_prompt` and `scene_google_flow_prompt`, always refer to Clem by his registered **Google Flow Character Ingredient name** (`Clem, a cheerful garden explorer in a white shirt, blue denim overalls, and brown boots`).

### Gate 2: Verbatim Storyline Script & Engaging Human Voice Fidelity (`gate_2_storyline_script_and_human_voice_fidelity`)
- **Verbatim Storyline Script**: All canonical lines and teaching beats from the Act's storyline (`Story draft and Prompts for 01 Animals & Nature.pdf`) must appear verbatim across the screenplay scenes.
- **Engaging Human Voice Spec**: `voice_casting_spec` must define human voice profiles for the Narrator, Clem, and Plum, require expressive human narration, and set `"allow_basic_os_tts": false`.

### Gate 3: Entertainment & Anti-Slideshow Vitality (`gate_3_entertaining_anti_slideshow`)
- **Per-Scene Vitality**: Every scene/beat must include articulated character motion verbs, facial expression changes, and environmental backdrop motion.
- **Minimum Articulated Verbs**: At least 6 distinct motion verbs across the scene beats and at least 5 motion verbs inside the compiled Google Flow prompts.
- **Minimum Environmental Motions**: At least 2 distinct backdrop motion cues (e.g., `swaying`, `breeze`, `clouds drift`, `sunbeams`).

### Gate 4: Google Flow Asset Linkage, Theme & 100% Storyline Image Lock (`gate_4_google_flow_assets_and_theme_fidelity`)
- **Google Flow Character Registry**: Every character in `characters` must include `google_flow_character_id` (`@Clem`, `@Plum`), `character_sheet_doc_id` (`1sfRUqjoxulOZhvXRqiIQPWVQ1qrBEk4w3Zt-u01YXlY`), `visual_dna`, `personality_traits`, and `trait_to_action_mapping`.
- **100% Storyline Image Lock**: Every scene beat must specify an existing `source_scene_image_path` on disk and set `keyframe_lock_mode` to `"start_and_end_exact_image"`, `"start_exact_image"`, or `"end_exact_image"`.
- **Target Phonics Words**: Every target phonics word for the Act (`crop`, `spud`, `grub`, `snag`) must be spoken in dialogue and depicted in the visual choreography.

### Gate 5: Well-Formed Google Flow (`Veo 3.1`) Prompt & 2-Step Approval Gate (`gate_5_google_flow_and_two_step_human_gate`)
- **6-Pillar Single Paragraph (`90–145` words)**: Must include (1) full-color 2D storybook style preserving bold black ink outlines, (2) setting & backdrop motion, (3) `@Plum` articulated motion, (4) `@Clem` articulated motion, (5) camera & lighting choreography, and (6) `Audio:` clause with expressive human voice direction.
- **2-Step Human Gate Verification**: Verifies that `human_readable_screenplay_txt_path` exists in the `Blends` folder and `workflow_step` is `"STEP_1_AWAITING_HUMAN_APPROVAL"` (`"PENDING_HUMAN_REVIEW"`).
