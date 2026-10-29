---
name: illustration-qa-inspector
description: >-
  Use this skill to run deterministic and multimodal QA checks on generated
  coloring book illustrations, colored video keyframes, Word Find SVGs, and
  compiled PDFs. Also normalizes JPEGs into pure black-and-white PNGs.
---

# Illustration QA Inspector & B&W Normalizer (`illustration-qa-inspector`)

Provides independent verification and deterministic image normalization across all 4 generator levels so no gray shading, off-spec resolution, or corrupt asset enters the final book or video.

---

## 1. Two-Layer QA Gate

### Gate A: Deterministic Script Inspection & Pure B&W Normalization ([`scripts/verify_and_normalize_assets.swift`](./scripts/verify_and_normalize_assets.swift))
1. **Format & Dimension Check**: Verifies readable raster image, converts `.jpg` to `.png`, and checks target aspect ratio (`1:1` for atomic icons, `3:4` for full-page scenes).
2. **Pure B&W Adaptive Thresholding (For Coloring Book Assets)**:
   - AI image generators often leave subtle `#F8F8F8` off-white paper grain or anti-aliased gray pixels.
   - The normalizer cleans the luminance channel so backgrounds are 100% pure `#FFFFFF` white and outlines are crisp `#000000` black ink, reporting the exact black-ink coverage percentage (`target: 3%–35%`).
3. **Color Saturation Check (For Level 4 Colored Video Keyframes)**:
   - Verifies that full-color keyframes actually contain rich chromatic saturation rather than accidentally remaining black-and-white.

### Gate B: Multimodal Visual Scorecard (`read_file`)
Inspect every generated image via `read_file` against the **6-Point QA Checklist**:
1. **Line Uniformity**: Bold, friendly, closed black outlines with no sketchy hairlines.
2. **Zero Shading / Gray Fill**: Large open white areas easy for children to color.
3. **Zero Unwanted Text / Symbols**: No hallucinated words, watermarks, or `"Zzz"` glyphs.
4. **Framing Compliance**: No outer box on Level 1 atomic icons; clean rectangular border on Level 2/3 full-page scenes.
5. **Subject & Count Accuracy**: Matches the exact animal/character anatomy and storyline count.
6. **Child Relatability**: Cute, friendly cartoon expression suitable for ages 4–6.
