---
name: atomic-illustration-generator
description: >-
  Level 1 Atomic Illustration Generator. Use this skill when generating isolated
  1:1 black-and-white coloring book spot illustrations for individual words,
  animal characters, or props using the 3-paragraph prompt structure, parallel
  subagent batching, quota recovery, and 1024x1024 PNG normalization.
---

# Level 1: Atomic Illustration Generator (`atomic-illustration-generator`)

Generates single, isolated, child-friendly black-and-white (`#000000` on `#FFFFFF`) coloring book assets—such as **individual animals, characters, phonics sorting icons, or props**—that serve both as standalone coloring/sorting elements and as the visual building blocks for Level 2 (Scene Composer) and Level 3 (3-Part Story Generator).

---

## 1. The 3-Paragraph Atomic Prompt Architecture

Every atomic illustration prompt must follow this 3-paragraph structure:

```text
Paragraph 1 (Task & Target Age):
Please generate exactly 1 image to illustrate “[TARGET_WORD]” in a coloring book for children aged [AGE_BAND].

Paragraph 2 (Core Line-Art Style — Invariant):
Black and white line art coloring page for young children, ages [AGE_BAND]. Bold, easily recognizable, friendly, thick, uniform black outlines (no thin or wavy lines), no shading, no gray tones, no cross-hatching, no color fill. Flat white background. Simple, large, clearly separated shapes — minimal fine detail. Cute, friendly, rounded cartoon style. At this age, kids learn best through clear, engaging, visual contrasts and relatable examples.

Paragraph 3 (Subject & Strict Compositional Guardrails):
[CONCRETE SUBJECT DESCRIPTION WITH CHARACTER/OBJECT DETAILS]. Centered, 1:1 square composition, flat #FFFFFF white background, no text, no letters, no watermark, no outer border, no box, no frame. Pure black line art on solid pure white background.
```

### Mandatory Disambiguation & Anti-Leak Rules
1. **Zero Text or Symbolic Glyphs**: Strictly prohibit words, labels, letters, or comic sound effects (`"Zzz"`, `"Moo"`, `"Roar"`, `"Pop"`).
2. **Zero Outer Borders on Atomic Assets**: Atomic illustrations must sit on an unframed pure `#FFFFFF` canvas so they can be cleanly placed into multi-animal activity pages or dashed sorting cards without double borders.
3. **Unmistakable B&W Silhouette**: Emphasize defining features in Paragraph 3 (e.g., bold stripes on a `tiger`, fluffy scalloped mane on a `lion`, spotted patches + bell on a `cow`, coiled S-curve on a `snake`, curled tail + big ears on a `monkey`).

---

## 2. Execution & Batching Procedure

1. **Build Validated Prompts**:
   - Run [`scripts/build_atomic_prompts.py`](./scripts/build_atomic_prompts.py) on the word manifest from `theme-word-generator` to generate and lint all 3-paragraph atomic prompts.
2. **Parallel Subagent Dispatch**:
   - Group items into batches of 2–4 words per `image-generator` subagent (`AspectRatio: "1:1"`, `ImageName: "<word>"`).
3. **Rolling Quota Recovery (`429 RESOURCE_EXHAUSTED`)**:
   - If an image model hits a rate/capacity limit, parse the reset duration and schedule a one-shot wakeup timer via `schedule` (`TimerCondition: "never"`). Never spin or poll.
4. **Normalize & Verify (`1024x1024` PNG)**:
   - Convert generated `.jpg` outputs to `1024x1024` `.png` files and pass every image through `illustration-qa-inspector`.
