---
name: story-sequence-generator
description: >-
  Level 3 3-Part Story Generator. Use this skill when creating a 3-scene
  storyline (Act 1, Act 2, Act 3) with strict character, prop, and environmental
  continuity across all 3 scenes (in both black-and-white coloring page format
  and full-color storybook/video keyframe format).
---

# Level 3: 3-Part Story Generator (`story-sequence-generator`)

Creates a **3-part narrative arc** (`Scene 1: Beginning / Discovery`, `Scene 2: Middle / Playful Action`, `Scene 3: Finale / Celebration`) starring the characters/animals generated in Level 1, and invokes Level 2 (`scene-illustration-generator`) with a locked **Story Continuity Bible** so all 3 scenes stay visually consistent.

---

## 1. Mandatory Pre-Step: The Story Continuity Bible

Before generating any of the 3 scenes, lock a **Story Continuity Bible** JSON/table containing:

1. **Cast Visual Anchors**: Exact anatomical features for every animal/character appearing across the 3 scenes (pulled directly from their Level 1 atomic definitions so a spotted cow with a neck bell in Scene 1 has the exact same spots and neck bell in Scenes 2 and 3).
2. **Recurring Prop Anchor**: At least one signature prop that travels across scenes (e.g., a woven picnic basket of red apples on the Farm; a golden banana bunch and mossy vine bridge in the Jungle).
3. **Environment & Sky Anchor**: Consistent setting landmarks and sky elements (e.g., classic wooden barn, split-rail fence, and two fluffy clouds for Farm; big banyan trees, broad tropical leaves, and a gentle waterfall for Jungle).
4. **Color Palette Bible (For Full-Color Variants & Level 4 Video)**: Locked hex/color descriptions for every character, prop, and background element so colored variants match across all 3 scenes.

---

## 2. 3-Part Narrative Structure

| Scene | Narrative Beat | Continuity Rule |
| :--- | :--- | :--- |
| **Scene 1 (Act 1: Morning Gathering)** | Introduce the main characters/animals in the wide setting discovering the recurring prop or starting an activity. | Establish the setting landmarks, sky elements, and recurring prop. |
| **Scene 2 (Act 2: Playful Teamwork)** | Closer midground interaction where the remaining animals join in to help or play together. | Carry over the recurring prop and at least 1–2 characters from Scene 1 alongside new theme animals. |
| **Scene 3 (Act 3: Happy Finale)** | All theme animals celebrate or rest happily together with the completed goal/prop. | Combine the full cast and recurring prop in a joyful closing composition. |

---

## 3. Dual-Variant Output (B&W Coloring + Full-Color Keyframes)

For each of the 3 scenes in a theme storyline, `story-sequence-generator` can output:
- **B&W Full-Page Coloring Variant (`3:4`)**: Included in the printable PDF coloring book after the individual animal pages.
- **Full-Color Storybook Keyframe Variant (`3:4` / `9:16`)**: Used for full-color story previews and fed directly into **Level 4 (`story-video-generator`)** so animated shorts start in vibrant color from Frame 0.
