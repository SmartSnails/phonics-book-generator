---
name: story-video-generator
description: >-
  Level 4 Story Video Generator. Use this skill when taking a 3-scene storyline,
  generating vibrant full-color animated variants of the 3 scenes, producing
  Google Flow (Veo 3.1) multi-scene video + audio prompts, and compiling a
  short animated MP4 video for each theme.
---

# Level 4: Story Video Generator (`story-video-generator`)

Takes the 3 scenes from **Level 3 (`story-sequence-generator`)**, generates **full-color 2D storybook keyframe variants** of all 3 scenes, prepares the **Veo 3.1 / Google Flow** animation & audio prompt package, and compiles a local **animated short `.mp4` video** (with smooth camera motion/pan-and-zoom, scene transitions, and synthesized/ambient audio score) using macOS native AVFoundation/CoreGraphics (`swift`) or Google Flow via `/browser`.

---

## 1. The 3-Step Video Pipeline

### Step 1: Full-Color Keyframe Generation (Preventing B&W Frame-0 Lock)
- Never pass a black-and-white line-art image directly into a video generator's locked "First Frame" slot if you want a colored movie.
- First, generate **3 vibrant full-color 2D storybook keyframes** (`Scene 1 Color`, `Scene 2 Color`, `Scene 3 Color`) matching the Story Continuity Bible's color palette while preserving bold black storybook outlines.

### Step 2: Veo 3.1 / Google Flow Prompt Package
For each 8-second scene clip (24 seconds total per theme), output a structured Veo 3.1 prompt following the **6-Pillar Flow Formula**:
1. **Camera Movement & Framing** (e.g., *Slow gentle push-in*, *Smooth lateral pan*, *Joyful pull-back finale*).
2. **Character & Animal Color Anchors** (matching Step 1 keyframes).
3. **Single Clear Physical Action** (e.g., *Cow rings her bell while Horse trots alongside*).
4. **Environment & Atmosphere** (swaying meadow grass, drifting clouds, or dappled jungle sunbeams).
5. **2D Storybook Animation Style** (vibrant 2D cartoon animation with bold ink outlines).
6. **Synchronized Audio & Score** (continuous instrumental score + cheerful animal/nature foley).

### Step 3: Automated Short Video Compilation (`.mp4`)
- **Local Native Renderer ([`scripts/render_story_video.swift`](./scripts/render_story_video.swift))**:
  - Uses macOS native `AVFoundation` + `CoreGraphics` + `AudioToolbox` (zero external dependencies required) to animate the 3 colored scene keyframes with smooth cinematic Ken Burns camera moves (push-in, pan, pull-back), title/caption overlays, cross-dissolve transitions, and a cheerful synthesized musical chime score into a ready-to-play `1080x1440` (or `1080x1920`) H.264 `.mp4` video.
- **Google Flow Browser Execution (Optional via `/browser`)**:
  - Uploads the 3 colored keyframes to Google Flow (`Veo 3.1`) and runs the 3 scene prompts to generate AI-interpolated video clips.
