---
name: scene-illustration-generator
description: >-
  Level 2 Full-Screen or Half-Screen Scene Illustration Generator. Use this
  skill when taking multiple atomic characters, animals, and props and
  assembling them into a cohesive Full-Page, Half-Page, or Split-Page scene
  (either black-and-white coloring pages or full-color story scenes).
---

# Level 2: Scene Illustration Generator (`scene-illustration-generator`)

Takes multiple atomic elements (**2–5 characters/animals + props + environment**) from Level 1 (`atomic-illustration-generator`) and assembles them into a structured **Full-Screen (`Full Page`)**, **Half-Screen (`Half Page`)**, or **Split-Page** scene.

---

## 1. Supported Page Layout Templates

| Template Style | Aspect Ratio | Layout & Framing Specification |
| :--- | :--- | :--- |
| **`full_page`** | `3:4` (Portrait) or `1:1` | Framed rectangular illustration box enclosed within a crisp medium-thick (`~4pt`) solid black outer border with clean uniform white margins outside the border. Background in top 1/3; characters and action in lower 2/3. Zero title/footer text inside the image. |
| **`half_page`** | `3:4` (Portrait) | Framed rectangular illustration in the upper 55% of the canvas; lower 45% left as blank pure white (`#FFFFFF`) space for story text or handwriting lines. |
| **`split_page`** | `3:4` (Portrait) | Vertical page divided horizontally into two distinct rectangular panels (Top Panel + Bottom Panel) separated by a clean white gutter. |

---

## 2. Scene Color Modes

1. **`bw_coloring` (For Print Coloring Book PDF)**:
   - Pure `#000000` black ink outlines on a `#FFFFFF` pure white background.
   - Extra-bold smooth outer contours (`~6–8pt`) on foreground characters/animals so they pop cleanly from the background environment (`~4pt` outlines).
   - Large, open unshaded white spaces easy for young children to color inside. Zero grayscale, zero cross-hatching, zero gradients.
2. **`full_color` (For Colored Storybook Pages & Level 4 Video Keyframes)**:
   - Preserves the exact same cute, bold black storybook outlines and spatial composition, filled with vibrant, rich 2D children's storybook colors.

---

## 3. Scene Composition Architecture (5 Layers)

Every Level 2 scene prompt is assembled from 5 non-overlapping layers:
1. **Template & Style Header**: Layout template (`full_page` / `half_page`), aspect ratio (`3:4`), and color mode (`bw_coloring` or `full_color`).
2. **Character & Animal Cast Anchors**: Exact visual anchors from Level 1 so the animals in the scene match their individual atomic character sheets (or direct Flow Character ingredient names when running in Google Flow).
3. **Foreground & Midground Action**: Clear, relatable physical interaction among the characters/animals.
4. **Background Setting (Top 1/3)**: Simple, uncluttered thematic environment (e.g., sunny barn & fence for `farm`; lush palm canopy & waterfall for `jungle`).
5. **Strict Exclusions**: Explicitly forbid text, titles, watermarks, speech bubbles, and unrequested clutter.
