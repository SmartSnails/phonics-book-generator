---
name: story-video-generator
description: >-
  Use this skill ONLY as Step 2 of the 2-step video generation workflow AFTER
  the human has reviewed and explicitly approved the text screenplay generated
  by story-screenplay-generator. Uses the characters and scene keyframes
  defined in Google Flow, enforces 100% adherence to the storyline coloring
  book images at the start/end of every scene, and requires engaging human
  voice narration following the exact Act script (basic robotic OS TTS is
  strictly forbidden).
---

# Level 4: Full-Fledged Story Animation Generator (`story-video-generator`) — Step 2 of 2

Converts a **Human-Approved Screenplay** (`.txt` in `output/Blends/` + `.json` manifest in `output/screenplays/`) produced by [`story-screenplay-generator`](../story-screenplay-generator/SKILL.md) into an animated storybook `.mp4` movie.

---

## 1. Mandatory Pre-Flight Gate: Human Approval & 5-Gate Screenplay Check

> [!CAUTION]
> **DO NOT TRIGGER VIDEO GENERATION UNLESS HUMAN APPROVAL IS CONFIRMED**:
> 1. Verify that Step 1 ([`story-screenplay-generator`](../story-screenplay-generator/SKILL.md)) passed all 5 rubric gates via `evaluate_screenplay.py`.
> 2. Verify that the human-readable `.txt` screenplay exists in `output/Blends/` (e.g., `output/Blends/Act1_In_The_Garden_Screenplay.txt`).
> 3. Verify that the user has explicitly approved the screenplay (or requested testing/rendering with the screenplay) and that `"human_approval": {"status": "APPROVED"}` is set in the screenplay JSON manifest.

---

## 2. Four Non-Negotiable Production Rules

### Rule 1 — Use Google Flow Defined Characters & Storyline Coloring Pages (`100% Image Lock`)
- Every character in the video MUST use the official **Google Flow Character DNA** (`@Clem` and `@Plum` defined in `Blends / Character sheet` Doc ID `1sfRUqjoxulOZhvXRqiIQPWVQ1qrBEk4w3Zt-u01YXlY`) as drawn in the official storyline coloring pages (`Theme A Beginning Blend.pdf` pages `page-038.png` and `page-043.png`, plus `scene_1c_grub.png` and `scene_1d_snag.png`, normalized to `1080x1080` in `output/Blends/illustrations/act1_scene1_crop_flow_bw.png` .. `act1_scene4_snag_flow_bw.png`).
- **Start & End Keyframe Lock (`100% Adherence`)**: Every scene MUST begin and end locked **100%** to the exact storyline coloring book illustration (`source_scene_image_path` / `colored_scene_image_path`). Never replace the storyline illustrations with synthetic geometric shapes.

### Rule 2 — Engaging Multi-Character Human Voice Narration Only (Strictly Ban Basic OS TTS)
- **BANNED**: `/usr/bin/say`, `AVSpeechSynthesizer`, `Samantha`, `Daniel`, `Fred`, `espeak`, or any compact/eloquence robotic OS TTS voice.
- **REQUIRED**: Expressive, warm human storytelling voices with distinct character casting:
  - **Google Flow (`Veo 3.1`) Native Expressive Multi-Character Human Audio** when rendering in the Google Flow UI, OR
  - **Microsoft Azure Neural Multi-Speaker Human Voices (`edge-tts`)** via [`scripts/synthesize_human_narration.py`](scripts/synthesize_human_narration.py) for local MP4 generation:
    - **Narrator**: `en-US-AriaNeural` (`rate=-4%`, `pitch=+0Hz` — warm, expressive children's audiobook storyteller)
    - **Plum**: `en-US-JennyNeural` (`rate=+2%`, `pitch=+10Hz` — bright, gentle, musical guide voice)
    - **Clem**: `en-US-AnaNeural` (`rate=+4%`, `pitch=+4Hz` — authentic, curious, joyful young child voice)

### Rule 3 — Follow the Exact Act Storyline Script Verbatim
- Spoken narration and character dialogue in every scene MUST follow the **exact storyline script** from the approved screenplay (`verbatim_storyline_script`) covering every target phonics word (`crop`, `spud`, `grub`, `snag`) and signature dialogue exchange:
  - **Scene 1 (`crop`)**:
    - *Narrator*: `"Plum fluttered down onto the garden fence."`
    - *Plum*: `"Follow me!"`
    - *Narrator*: `"she chirped. Clem grinned and hopped over the gate."`
    - *Clem*: `"I'm right behind you!"`
    - *Narrator*: `"Together they walked past rows of green plants, ready to see what the crop had grown this season."`
    - *Plum*: `"See all these matching spinach plants? When we grow a whole field of the exact same plant, that big group of plants is called a crop!"`
  - **Scene 2 (`spud`)**:
    - *Narrator*: `"Clem and Plum walk by the potato patch. Lovely green lush grown potato plants were swaying."`
    - *Plum*: `"A long time ago, gardeners used a little shovel called a spud to dig up treats from the ground. Because they used that shovel to find potatoes, people just started calling the potatoes spuds too!"`
    - *Clem*: `"Look! Well, spud is just a secret, silly nickname for a potato!"`
    - *Narrator*: `"said Clem, digging his hands into the soft dirt. Clem pulled out a round, dusty spud."`
    - *Clem*: `"Found one!"`
    - *Plum*: `"Whenever you eat French fries or mashed potatoes, you are actually eating delicious spuds!"`
  - **Scene 3 (`grub`)**:
    - *Narrator*: `"Plum hopped closer and peeked into the hole. Something wiggled."`
    - *Plum*: `"A grub!"`
    - *Narrator*: `"she said with a giggle."`
    - *Plum*: `"He's shy — say hello gently."`
  - **Scene 4 (`snag`)**:
    - *Narrator*: `"Clem reached out to pet a leaf, but his sleeve caught on a thorny branch."`
    - *Clem*: `"Snag!"`
    - *Narrator*: `"he laughed, tugging it free."`
    - *Clem*: `"Gotcha, you sneaky bush!"`

### Rule 4 — Seamless Full-Fledged Animation (Zero Rectangular Patch Cut-Lines)
- Never crop rectangular sub-patches that slice across background fences or soil lines. Instead, animate the unified inner storyline canvas (`28..1052`) with smooth camera breathing/focus locked to identity at the start and end of every scene, layered with verified organic feature overlays (phoneme-driven mouth/beak lip-sync, natural eyelid blinks, musical bird-chirp notes, falling soil crumbs, grub wiggle arcs, and rose-bush snag tug lines).

---

## 3. End-to-End Execution Pipeline

### Step 2A: Prepare & Colorize the Exact Google Flow Storyline Keyframes
Run [`scripts/colorize_flow_act1_scenes.swift`](scripts/colorize_flow_act1_scenes.swift) so each beat in the screenplay has both:
1. `source_scene_image_path`: Clean `1080x1080` B&W storyline coloring page (`output/Blends/illustrations/act1_scene<N>_<word>_flow_bw.png`).
2. `colored_scene_image_path`: `1080x1080` storybook-colored keyframe (`output/Blends/illustrations/act1_scene<N>_<word>_flow_color.png`) painted via connected-component flood-fill inside the exact black ink outlines of `source_scene_image_path` using the locked Google Flow Character DNA palette.

```bash
swift -module-cache-path /tmp/swift_cache \
  .agents/skills/story-video-generator/scripts/colorize_flow_act1_scenes.swift
```

### Step 2B: Synthesize Engaging Multi-Character Human Voice Narration
Run [`scripts/synthesize_human_narration.py`](scripts/synthesize_human_narration.py) to generate 44.1 kHz stereo PCM `.wav` files and a frame-accurate timing manifest (`output/audio/act1_human_vo/manifest.json`) for every narrator and character line in the screenplay:

```bash
python3 .agents/skills/story-video-generator/scripts/synthesize_human_narration.py \
  --screenplay output/screenplays/act1_in_the_garden_screenplay.json \
  --out-dir output/audio/act1_human_vo
```

> [!IMPORTANT]
> **Critical Safeguards in `synthesize_human_narration.py`**:
> 1. **Workspace Output Directory (`output/audio/...`)**: Always write `.wav` files inside the workspace (`output/audio/act1_human_vo`) rather than `/tmp`. On macOS, files created in `/tmp` by an unsandboxed process (`BypassSandbox: true`) are blocked (`Operation not permitted` / `NSCocoaErrorDomain Code=257`) when read by a subsequent sandboxed Swift process.
> 2. **Automatic UTC Clock-Skew Calibration**: Before connecting to the Edge Neural TTS WebSocket, `synthesize_human_narration.py` reads the live HTTP `Date` header from Microsoft/Bing/Google and sets `DRM.clock_skew_seconds` + overrides `edge_tts.communicate.date_to_string` so `Sec-MS-GEC` and `X-Timestamp` never fail even if the local machine clock is skewed.

### Step 2C: Render the Animated 2D Storybook Video & Interleaved Master Audio
Run the master orchestrator [`scripts/generate_video_from_screenplay.py`](scripts/generate_video_from_screenplay.py) (which validates all pre-flight gates and invokes [`scripts/render_screenplay_video.swift`](scripts/render_screenplay_video.swift)):

```bash
python3 .agents/skills/story-video-generator/scripts/generate_video_from_screenplay.py \
  --screenplay output/screenplays/act1_in_the_garden_screenplay.json \
  --vo-manifest output/audio/act1_human_vo/manifest.json \
  --out-mp4 output/Blends/Act1_In_The_Garden_Animation.mp4 \
  --copy-mp4 output/videos/act1_in_the_garden_animation.mp4
```

> [!IMPORTANT]
> **Critical Safeguards in `render_screenplay_video.swift`**:
> 1. **Lockstep Audio/Video Timestamp Interleaving (No `AVAssetWriter` Deadlocks)**: Never append all video frames before appending audio buffers on a single thread (which deadlocks `videoInput.isReadyForMoreMediaData` once `AVAssetWriter`'s internal interleaving queue fills). Always build `masterAudio` upfront and interleave video frames and audio sample buffers in presentation-timestamp (`CMTime`) order (`videoTime <= audioTime`) inside `autoreleasepool` blocks.
> 2. **Strict WAV Validation (No Silent `try?` Fallbacks)**: `loadWavFile` throws a `fatalError` if any `.wav` file is unreadable or <= 44 bytes instead of silently returning empty sample arrays `[]`.

### Step 2D: Fast Lossless Audio Remuxing (Without Re-Rendering Video Frames)
Whenever you need to update, re-balance, or replace the narration/music audio track on an already-rendered `.mp4` without regenerating the video frames, run [`scripts/mux_narration_into_mp4.swift`](scripts/mux_narration_into_mp4.swift):

```bash
swift -module-cache-path /tmp/swift_cache \
  .agents/skills/story-video-generator/scripts/mux_narration_into_mp4.swift \
  output/audio/act1_human_vo/manifest.json \
  output/Blends/Act1_In_The_Garden_Animation.mp4 \
  output/videos/act1_in_the_garden_animation.mp4
```

`mux_narration_into_mp4.swift` strictly verifies all 20 `.wav` files (`frameCount > 1000` and `peak > 0.01`), mixes the master `.m4a` track (`output/audio/act1_master_narration.m4a`), and uses `AVMutableComposition` + `AVAssetExportSession(presetName: AVAssetExportPresetPassthrough)` to copy the H.264 video stream byte-for-byte in ~2 seconds.

---

## 4. Post-Render Verification Checklist

Before presenting the finished video to the user, verify:
- [ ] Both `output/Blends/Act1_In_The_Garden_Animation.mp4` and `output/videos/act1_in_the_garden_animation.mp4` exist and contain 1 video track (`1080x1080` H.264) + 1 stereo audio track (44.1 kHz AAC).
- [ ] Every utterance `.wav` file logged non-zero sample counts and audible peak amplitude (`peak >= 0.30`).
- [ ] Every scene's start and end frames match the exact Google Flow storyline illustrations (`page-038` / `act1_scene1_crop_flow_color.png`, `page-043` / `act1_scene2_spud_flow_color.png`, `act1_scene3_grub_flow_color.png`, `act1_scene4_snag_flow_color.png`) with zero rectangular patch cut-lines.
- [ ] All 4 target words (`crop`, `spud`, `grub`, `snag`) are spoken clearly by engaging neural human voices following the verbatim Act 1 storyline script.
