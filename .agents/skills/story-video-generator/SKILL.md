---
name: story-video-generator
description: >-
  Level 4 Full-Fledged Story Animation Generator. Use this skill when taking an
  approved ~10-second screenplay from story-screenplay-generator, preparing
  Google Flow (Veo 3.1) full-color keyframe + animation prompt packages, and
  rendering a true ~10-second 30fps multi-layer articulated 2D character and
  environment animation MP4 with synchronized spoken voiceover, foley sound
  effects, and background music (never a static Ken Burns slideshow).
---

# Level 4: Full-Fledged Story Animation Generator (`story-video-generator`)

Takes an evaluated **~10-second 3-Beat Screenplay JSON** from [`story-screenplay-generator`](../story-screenplay-generator/SKILL.md) and produces:
1. **Google Flow (`Veo 3.1`) Animation Package**: Full-color starting/ending keyframes + the validated 90–145 word single-paragraph Veo 3.1 animation & audio prompt ready for Google Flow.
2. **True ~10-Second Full-Fledged 2D Animation (`.mp4`, `1080x1080` or `1080x1440` at `30fps`)**: Rendered via [`scripts/render_garden_act1_animation.swift`](./scripts/render_garden_act1_animation.swift) (and [`scripts/render_story_video.swift`](./scripts/render_story_video.swift)) with **articulated character limbs, facial expressions (blinking eyes, talking/smiling mouth, flapping wings), multi-plane animated backdrop elements (swaying crops, drifting clouds, floating golden pollen), synchronized spoken narration voiceover, spot foley SFX, and musical score**.

> **Strict Anti-Slideshow Rule**: Static keyframes panned with a camera zoom do NOT qualify as an animation. Every rendered video must exhibit continuous frame-by-frame character articulation, prop physics, and environmental motion across all 3 screenplay beats (`0.0–3.0s`, `3.0–7.0s`, `7.0–10.0s`).

---

## 1. Execution Workflow

### Step 1: Verify Screenplay Passed All 5 Gates
Ensure [`story-screenplay-generator`](../story-screenplay-generator/SKILL.md) returned `"overall_status": "PASS"` on the screenplay JSON before rendering video.

### Step 2: Render the ~10-Second Full-Fledged 2D Animation (`.mp4`)
Run the native macOS CoreGraphics + AVFoundation + AVSpeechSynthesizer articulated animation renderer:
```bash
swift -module-cache-path /tmp/swift-cache \
  /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/.agents/skills/story-video-generator/scripts/render_garden_act1_animation.swift \
  /Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/screenplays/act1_in_the_garden_screenplay.json
```

### Step 3: Post-Render Animation QA Verification
1. Verify duration is `~10.0s` (`9.5s–10.5s`), frame rate is `30fps`, and audio track (voiceover + foley + music) is present.
2. Extract 4 sample frames across the timeline (`t=1.0s`, `t=4.0s`, `t=6.5s`, `t=9.0s`) and inspect via `read_file` to verify that character poses, limb positions, facial expressions, and props actively change from beat to beat (proving it is a real animation and not a static slideshow).
