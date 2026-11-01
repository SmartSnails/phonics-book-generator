#!/usr/bin/env swift
// build_section1_pdf.swift
// Compiles the 12-page Section 1 (Act 1 — In the Garden) Phonics Coloring Book PDF (US Letter 8.5" x 11", 612 x 792 pt).
// Pages:
//   Page 1: Front Cover Page (cover_clem_plum.png)
//   Page 2: Stage 1 Character Introductions 1A (Clem & Plum)
//   Page 3: Stage 1 Character Introductions 1B (Mr. Spud & Little Grub)
//   Page 4: Stage 2 Story (Top, 18.5pt) + Half-Page Scene 1A (Bottom, scene_1a_crop.png)
//   Page 5: Stage 2 Story (Top, 18.5pt) + Half-Page Scene 1B (Bottom, scene_1b_spud.png)
//   Page 6: Stage 2 Story (Top, 18.5pt) + Half-Page Scene 1C (Bottom, scene_1c_grub.png)
//   Page 7: Stage 2 Story (Top, 18.5pt) + Half-Page Scene 1D (Bottom, scene_1d_snag.png)
//   Page 8: Stage 3 Blend Word Practice 1A (CLEM & PLUM)
//   Page 9: Stage 3 Blend Word Practice 1B (CROP & SPUD)
//   Page 10: Stage 3 Blend Word Practice 1C (GRUB & SNAG)
//   Page 11: Stage 3 Section 1 Blend Word Find Puzzle (CLEM, PLUM, CROP, SPUD, GRUB, SNAG)
//   Page 12: Stage 4 Section 1 Conclusion Full-Page Coloring Scene (scene_1_conclusion.png)

import Foundation
import AppKit
import CoreGraphics
import CoreText

let baseDir = "/Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/section1_garden"
let atomicDir = "\(baseDir)/atomic"
let scenesDir = "\(baseDir)/scenes"
let wordFindMatrixPath = "\(baseDir)/word_find/section1_garden_word_find_matrix.json"
let outputPDFPath = "\(baseDir)/book/Section_1_In_The_Garden_Phonics_Coloring_Book.pdf"

let pageWidth: CGFloat = 612.0   // 8.5 in * 72 pt/in
let pageHeight: CGFloat = 792.0  // 11.0 in * 72 pt/in
var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

let outURL = URL(fileURLWithPath: outputPDFPath)
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)

guard let consumer = CGDataConsumer(url: outURL as CFURL),
      let pdfCtx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
    fputs("ERROR: Cannot create PDF context at \(outputPDFPath)\n", stderr)
    exit(2)
}

func makeFont(size: CGFloat, bold: Bool) -> NSFont {
    let fontName = bold ? "ArialRoundedMTBold" : "HelveticaNeue"
    return NSFont(name: fontName, size: size) ?? (bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size))
}

func drawCenteredText(_ ctx: CGContext, _ text: String, x: CGFloat, y: CGFloat, size: CGFloat, bold: Bool = true, color: NSColor = .black, tracking: CGFloat = 0.0) {
    let font = makeFont(size: size, bold: bold)
    var attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    if tracking != 0 { attrs[.kern] = tracking }
    let attrStr = NSAttributedString(string: text, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attrStr)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.saveGState()
    ctx.textMatrix = .identity
    ctx.textPosition = CGPoint(x: x - bounds.width / 2.0, y: y)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

func drawLeftText(_ ctx: CGContext, _ text: String, x: CGFloat, y: CGFloat, size: CGFloat, bold: Bool = true, color: NSColor = .black, tracking: CGFloat = 0.0) {
    let font = makeFont(size: size, bold: bold)
    var attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    if tracking != 0 { attrs[.kern] = tracking }
    let attrStr = NSAttributedString(string: text, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attrStr)
    ctx.saveGState()
    ctx.textMatrix = .identity
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

// Supports **bold** markdown spans inside wrapped child-legible text, with automatic CoreText zero-truncation check!
func drawRichWrappedText(_ ctx: CGContext, _ rawText: String, rect: CGRect, size: CGFloat, lineSpacing: CGFloat = 6.0, alignment: NSTextAlignment = .left) {
    var currentSize = size
    let parts = rawText.components(separatedBy: "**")

    while currentSize >= 12.0 {
        let regFont = makeFont(size: currentSize, bold: false)
        let boldFont = makeFont(size: currentSize, bold: true)
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineSpacing = lineSpacing * (currentSize / size)
        style.paragraphSpacing = 6.0 * (currentSize / size)

        let result = NSMutableAttributedString()
        for (idx, part) in parts.enumerated() {
            if part.isEmpty { continue }
            let isBold = (idx % 2 == 1)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: isBold ? boldFont : regFont,
                .foregroundColor: NSColor.black,
                .paragraphStyle: style,
                .underlineStyle: isBold ? NSUnderlineStyle.single.rawValue : 0
            ]
            result.append(NSAttributedString(string: part, attributes: attrs))
        }

        let framesetter = CTFramesetterCreateWithAttributedString(result)
        let path = CGPath(rect: rect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, result.length), path, nil)
        let visibleRange = CTFrameGetVisibleStringRange(frame)

        if visibleRange.length >= result.length || currentSize <= 12.5 {
            ctx.saveGState()
            ctx.textMatrix = .identity
            CTFrameDraw(frame, ctx)
            ctx.restoreGState()
            return
        }
        currentSize -= 0.5
    }
}

func loadCGImage(_ path: String) -> CGImage? {
    let url = URL(fileURLWithPath: path)
    guard let nsImg = NSImage(contentsOf: url) else {
        fputs("WARNING: Missing image at \(path)\n", stderr)
        return nil
    }
    return nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

func drawImageAspectFit(_ ctx: CGContext, _ cgImg: CGImage, in targetRect: CGRect) {
    let imgW = CGFloat(cgImg.width)
    let imgH = CGFloat(cgImg.height)
    let scale = min(targetRect.width / imgW, targetRect.height / imgH)
    let drawW = imgW * scale
    let drawH = imgH * scale
    let drawX = targetRect.midX - drawW / 2.0
    let drawY = targetRect.midY - drawH / 2.0
    ctx.draw(cgImg, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
}

func drawPageFrame(_ ctx: CGContext, pageNumber: Int, sectionLabel: String) {
    ctx.saveGState()
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

    let frameRect = CGRect(x: 24, y: 24, width: pageWidth - 48, height: pageHeight - 48)
    let path = CGPath(roundedRect: frameRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setLineWidth(3.0)
    ctx.addPath(path)
    ctx.strokePath()

    drawCenteredText(ctx, "\(sectionLabel)  •  Page \(pageNumber) of 12", x: pageWidth / 2.0, y: 36, size: 10.5, bold: false)
    ctx.restoreGState()
}

func drawHandwritingLines(_ ctx: CGContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, traceText: String?) {
    ctx.saveGState()
    let topY = y + height
    let midY = y + height * 0.5
    let botY = y

    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setLineWidth(1.5)
    ctx.move(to: CGPoint(x: x, y: topY))
    ctx.addLine(to: CGPoint(x: x + width, y: topY))
    ctx.move(to: CGPoint(x: x, y: botY))
    ctx.addLine(to: CGPoint(x: x + width, y: botY))
    ctx.strokePath()

    ctx.setLineWidth(1.1)
    ctx.setLineDash(phase: 0, lengths: [5, 5])
    ctx.move(to: CGPoint(x: x, y: midY))
    ctx.addLine(to: CGPoint(x: x + width, y: midY))
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])

    if let word = traceText {
        let traceColor = NSColor(calibratedWhite: 0.70, alpha: 1.0)
        drawLeftText(ctx, word, x: x + 10, y: botY + 2, size: height * 0.86, bold: true, color: traceColor, tracking: 6.0)
    }
    ctx.restoreGState()
}

func drawBlendSoundBoxes(_ ctx: CGContext, x: CGFloat, y: CGFloat, onset: String, rime: String, wholeWord: String) {
    ctx.saveGState()
    let boxH: CGFloat = 28.0
    let onsetW: CGFloat = 46.0
    let rimeW: CGFloat = 48.0

    // Onset box
    let r1 = CGRect(x: x, y: y, width: onsetW, height: boxH)
    let p1 = CGPath(roundedRect: r1, cornerWidth: 6, cornerHeight: 6, transform: nil)
    ctx.setLineWidth(2.0)
    ctx.addPath(p1)
    ctx.strokePath()
    drawCenteredText(ctx, onset, x: r1.midX, y: y + 6, size: 15, bold: true)

    drawCenteredText(ctx, "+", x: x + onsetW + 11, y: y + 6, size: 15, bold: true)

    // Rime box
    let r2 = CGRect(x: x + onsetW + 22, y: y, width: rimeW, height: boxH)
    let p2 = CGPath(roundedRect: r2, cornerWidth: 6, cornerHeight: 6, transform: nil)
    ctx.addPath(p2)
    ctx.strokePath()
    drawCenteredText(ctx, rime, x: r2.midX, y: y + 6, size: 15, bold: false)

    drawLeftText(ctx, "=  \(wholeWord)", x: r2.maxX + 10, y: y + 6, size: 16, bold: true)
    ctx.restoreGState()
}

// ============================================================================
// PAGE 1: FRONT COVER PAGE
// ============================================================================
pdfCtx.beginPDFPage(nil)
drawPageFrame(pdfCtx, pageNumber: 1, sectionLabel: "Clem and Plum: Phonics Coloring Book")

let innerCover = CGPath(roundedRect: CGRect(x: 34, y: 34, width: pageWidth - 68, height: pageHeight - 68), cornerWidth: 10, cornerHeight: 10, transform: nil)
pdfCtx.setLineWidth(1.2)
pdfCtx.addPath(innerCover)
pdfCtx.strokePath()

drawCenteredText(pdfCtx, "CLEM AND PLUM", x: pageWidth / 2, y: 722, size: 28, bold: true, tracking: 1.5)
drawCenteredText(pdfCtx, "A Day by the Garden, Woods, and Pond", x: pageWidth / 2, y: 692, size: 18, bold: true)
drawCenteredText(pdfCtx, "Section 1: Act 1 — In the Garden  •  Consonant Blends Phonics Coloring Book", x: pageWidth / 2, y: 668, size: 12, bold: false)

let coverArtRect = CGRect(x: 66, y: 140, width: pageWidth - 132, height: 512)
if let coverImg = loadCGImage("\(scenesDir)/cover_clem_plum.png") {
    drawImageAspectFit(pdfCtx, coverImg, in: coverArtRect)
}

drawCenteredText(pdfCtx, "Target Blends:  cl- (Clem)  •  pl- (Plum)  •  cr- (crop)  •  sp- (spud)  •  gr- (grub)  •  sn- (snag)", x: pageWidth / 2, y: 112, size: 11, bold: true)
drawCenteredText(pdfCtx, "This Adventure Book Belongs To: ____________________________________", x: pageWidth / 2, y: 72, size: 13, bold: false)
pdfCtx.endPDFPage()

// ============================================================================
// PAGES 2–3: STAGE 1 — CHARACTER INTRODUCTIONS (2 Large Cards Per Page)
// ============================================================================
struct CharIntroCard {
    let name: String
    let blendBadge: String
    let imagePath: String
    let introText: String
}

let charIntroPages: [(pageNum: Int, subtitle: String, top: CharIntroCard, bottom: CharIntroCard)] = [
    (
        pageNum: 2,
        subtitle: "Stage 1: Meet Our Adventure Heroes — Color Clem and Plum!",
        top: CharIntroCard(
            name: "Meet Clem",
            blendBadge: "cl- blend:  cl + em = Clem",
            imagePath: "\(atomicDir)/clem.png",
            introText: "“Hi! I am **Clem**. Like all eager and cheerful little 5-year-olds, I am very curious and love to ask questions kids would actually ask! I am the ‘doer’ kind — one who touches and tries things, and gets a little muddy. Today, **Plum** and I are off on a brand-new adventure. Want to come along? Let’s go!”"
        ),
        bottom: CharIntroCard(
            name: "Meet Plum",
            blendBadge: "pl- blend:  pl + um = Plum",
            imagePath: "\(atomicDir)/plum.png",
            introText: "“Chirp! Meet **Plum** — I am a small, round bluebird and **Clem**’s dear friend! I am very cute, calm, and slightly wiser — a gentle guide rather than a bossy one. I notice special things in nature first and nudge **Clem** toward them!”"
        )
    ),
    (
        pageNum: 3,
        subtitle: "Stage 1: Meet the Garden Pals — Color Mr. Spud and Little Grub!",
        top: CharIntroCard(
            name: "Meet Mr. Spud",
            blendBadge: "sp- blend:  sp + ud = spud",
            imagePath: "\(atomicDir)/spud.png",
            introText: "“Hello! I am **Mr. Spud**! ‘**Spud**’ is a silly nickname for a potato — just like calling a dog a pup! I grow underground attached to lush green potato plant roots until gardeners dig me up!”"
        ),
        bottom: CharIntroCard(
            name: "Meet Little Grub",
            blendBadge: "gr- blend:  gr + ub = grub",
            imagePath: "\(atomicDir)/grub.png",
            introText: "“Peek-a-boo! I am **Little Grub**! A **grub** is a tiny, squishy baby bug that lives in the garden dirt. I’m a shy baby beetle, and one day I will grow a shell and wings and turn into a big beetle!”"
        )
    )
]

for cp in charIntroPages {
    pdfCtx.beginPDFPage(nil)
    drawPageFrame(pdfCtx, pageNumber: cp.pageNum, sectionLabel: "Section 1: Act 1 — In the Garden (Character Introductions)")

    drawCenteredText(pdfCtx, "ACT 1: IN THE GARDEN — MEET THE CHARACTERS", x: pageWidth / 2, y: 734, size: 18, bold: true)
    drawCenteredText(pdfCtx, cp.subtitle, x: pageWidth / 2, y: 710, size: 12, bold: false)

    let cards = [cp.top, cp.bottom]
    let cardYs: [CGFloat] = [390.0, 66.0]
    let cardH: CGFloat = 302.0
    let cardX: CGFloat = 42.0
    let cardW: CGFloat = pageWidth - 84.0

    for (idx, card) in cards.enumerated() {
        let cy = cardYs[idx]
        let cardRect = CGRect(x: cardX, y: cy, width: cardW, height: cardH)
        let cardPath = CGPath(roundedRect: cardRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
        pdfCtx.setStrokeColor(NSColor.black.cgColor)
        pdfCtx.setLineWidth(2.2)
        pdfCtx.addPath(cardPath)
        pdfCtx.strokePath()

        let imgBox = CGRect(x: cardX + 12, y: cy + 12, width: 245, height: cardH - 24)
        if let cgImg = loadCGImage(card.imagePath) {
            drawImageAspectFit(pdfCtx, cgImg, in: imgBox)
        }

        // Dashed vertical divider
        pdfCtx.setLineWidth(1.2)
        pdfCtx.setLineDash(phase: 0, lengths: [4, 4])
        pdfCtx.move(to: CGPoint(x: cardX + 268, y: cy + 16))
        pdfCtx.addLine(to: CGPoint(x: cardX + 268, y: cy + cardH - 16))
        pdfCtx.strokePath()
        pdfCtx.setLineDash(phase: 0, lengths: [])

        let rightX = cardX + 282.0
        let rightW = cardW - 296.0

        // Blend badge pill
        let pillRect = CGRect(x: rightX, y: cy + cardH - 42, width: rightW, height: 26)
        let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        pdfCtx.setLineWidth(1.5)
        pdfCtx.addPath(pillPath)
        pdfCtx.strokePath()
        drawCenteredText(pdfCtx, card.blendBadge, x: pillRect.midX, y: pillRect.minY + 6, size: 12.5, bold: true)

        // Character Heading
        drawLeftText(pdfCtx, card.name, x: rightX, y: cy + cardH - 74, size: 22, bold: true)

        // Big child-legible first-person intro text
        let textRect = CGRect(x: rightX, y: cy + 14, width: rightW, height: cardH - 96)
        drawRichWrappedText(pdfCtx, card.introText, rect: textRect, size: 15.0, lineSpacing: 4.5, alignment: .left)
    }

    pdfCtx.endPDFPage()
}

// ============================================================================
// PAGES 4–7: STAGE 2 — STORY (TOP, 18.5pt CHILD-LEGIBLE FONT) + HALF-PAGE SCENE (BOTTOM)
// ============================================================================
struct StoryHalfPage {
    let pageNum: Int
    let beatTitle: String
    let targetBlendLabel: String
    let storyText: String
    let sceneImagePath: String
}

let storyPages: [StoryHalfPage] = [
    StoryHalfPage(
        pageNum: 4,
        beatTitle: "Act 1, Part 1: The Leafy Green Crop",
        targetBlendLabel: "Blend Words:  cr-op (crop)  •  Cl-em  •  Pl-um",
        storyText: "**Plum** and **Clem** were in the garden. **Plum** fluttered down onto the garden fence. Together they walked past rows of green plants, ready to see what had grown this season.\n**Clem** stared at the long, leafy rows and tilted his head. “See all these matching spinach and cabbage plants?” **Plum** asked. “When we grow a whole field of the exact same plant, that big group of plants is called a **crop**! We owe a big thanks to our farmers, **Clem**.”\n**Plum** hopped along the fence. “I like sunflower seeds. What is your favorite food, strawberries or carrots?” **Clem** grinned and shouted, “Strawberries, and mud pies!”",
        sceneImagePath: "\(scenesDir)/scene_1a_crop.png"
    ),
    StoryHalfPage(
        pageNum: 5,
        beatTitle: "Act 1, Part 2: Hello, Mr. Spud!",
        targetBlendLabel: "Blend Words:  sp-ud (spud)  •  Cl-em  •  Pl-um",
        storyText: "**Clem** and **Plum** walked by the potato patch, where lush green plants swayed in the breeze. **Clem** knelt down and pulled up a whole plant — dusty potatoes dangled from its roots! “Look, I found potatoes!” he shouted. “You found **spuds**!” **Plum** chirped.\n“**Spuds**? What’s a **spud**?” **Clem** asked. “**Spud** is a silly nickname for a potato,” **Plum** said, “just like calling a dog a pup! A long time ago, gardeners used a little shovel called a **spud** to dig up treats from the ground, so people started calling potatoes **spuds** too!” **Clem** held up the plant and giggled, “Hello, Mr. **Spud**!”",
        sceneImagePath: "\(scenesDir)/scene_1b_spud.png"
    ),
    StoryHalfPage(
        pageNum: 6,
        beatTitle: "Act 1, Part 3: The Shy Little Grub",
        targetBlendLabel: "Blend Words:  gr-ub (grub)  •  Cl-em  •  Pl-um",
        storyText: "**Plum** hopped closer and peeked into the hole where the plant had been. Something wiggled! “A **grub**!” **Plum** said with a giggle. “He’s shy, so say hello gently.” **Clem** leaned in and whispered, “Hello, little **grub**.”\n“What’s a **grub**?” **Clem** asked, tilting his head. “A **grub** is a tiny, squishy baby bug that lives in the dirt,” **Plum** explained. “He’s a baby beetle, and one day he will grow a shell and wings and turn into a big beetle!” **Clem**’s eyes grew wide. “See you when you’re big, **grub**!”",
        sceneImagePath: "\(scenesDir)/scene_1c_grub.png"
    ),
    StoryHalfPage(
        pageNum: 7,
        beatTitle: "Act 1, Part 4: Caught on a Rose Bush Snag",
        targetBlendLabel: "Blend Words:  sn-ag (snag)  •  Cl-em  •  Pl-um",
        storyText: "**Clem** brushed the dirt off his overalls and walked over to a rose bush. He leaned in to smell a rose, but his sleeve caught on a thorny branch. Tug, tug! A little thread pulled out of his white shirt. “Oh no, what happened?” he asked.\n“That’s called a **snag**,” **Plum** said. “When a sharp point catches on fabric and pulls a thread, that’s a **snag**.” **Clem** tugged his sleeve free and laughed. “**Snag**!” he said. “Gotcha, you sneaky bush!”",
        sceneImagePath: "\(scenesDir)/scene_1d_snag.png"
    )
]

for sp in storyPages {
    pdfCtx.beginPDFPage(nil)
    drawPageFrame(pdfCtx, pageNumber: sp.pageNum, sectionLabel: "Section 1: Act 1 — In the Garden (Story & Scene)")

    // Top Header & Phonics Badge
    drawLeftText(pdfCtx, sp.beatTitle.uppercased(), x: 44, y: 734, size: 16, bold: true)
    drawLeftText(pdfCtx, sp.targetBlendLabel, x: 44, y: 714, size: 11.5, bold: true, color: NSColor(calibratedWhite: 0.25, alpha: 1.0))

    // TOP HALF: Big & Child-Legible Story Text Box (17.5pt font, generous line spacing, zero-clipping guarantee)
    let storyBoxRect = CGRect(x: 42, y: 410, width: pageWidth - 84, height: 294)
    let storyBoxPath = CGPath(roundedRect: storyBoxRect, cornerWidth: 12, cornerHeight: 12, transform: nil)
    pdfCtx.setLineWidth(1.8)
    pdfCtx.addPath(storyBoxPath)
    pdfCtx.strokePath()

    let textInsetRect = storyBoxRect.insetBy(dx: 14, dy: 12)
    drawRichWrappedText(pdfCtx, sp.storyText, rect: textInsetRect, size: 17.5, lineSpacing: 4.5, alignment: .left)

    // BOTTOM HALF: Half-Page Scene Illustration showcasing the scene/setup
    let sceneBoxRect = CGRect(x: 42, y: 54, width: pageWidth - 84, height: 344)
    if let sceneCG = loadCGImage(sp.sceneImagePath) {
        drawImageAspectFit(pdfCtx, sceneCG, in: sceneBoxRect)
    }

    pdfCtx.endPDFPage()
}

// ============================================================================
// PAGES 8–10: STAGE 3 — BLEND WORD PRACTICE PAGES (2 CCVC Words Per Page)
// ============================================================================
struct BlendPracticeWord {
    let wordLower: String
    let wordUpper: String
    let onset: String
    let rime: String
    let categoryLabel: String
    let imagePath: String
}

let practicePages: [(pageNum: Int, pairTitle: String, top: BlendPracticeWord, bottom: BlendPracticeWord)] = [
    (
        pageNum: 8,
        pairTitle: "Adventure Friends (cl- & pl- Blends)",
        top: BlendPracticeWord(wordLower: "clem", wordUpper: "CLEM", onset: "cl", rime: "em", categoryLabel: "CL- INITIAL BLEND", imagePath: "\(atomicDir)/clem.png"),
        bottom: BlendPracticeWord(wordLower: "plum", wordUpper: "PLUM", onset: "pl", rime: "um", categoryLabel: "PL- INITIAL BLEND", imagePath: "\(atomicDir)/plum.png")
    ),
    (
        pageNum: 9,
        pairTitle: "Garden Harvest (cr- & sp- Blends)",
        top: BlendPracticeWord(wordLower: "crop", wordUpper: "CROP", onset: "cr", rime: "op", categoryLabel: "CR- INITIAL BLEND", imagePath: "\(atomicDir)/crop.png"),
        bottom: BlendPracticeWord(wordLower: "spud", wordUpper: "SPUD", onset: "sp", rime: "ud", categoryLabel: "SP- INITIAL BLEND", imagePath: "\(atomicDir)/spud.png")
    ),
    (
        pageNum: 10,
        pairTitle: "Garden Surprises (gr- & sn- Blends)",
        top: BlendPracticeWord(wordLower: "grub", wordUpper: "GRUB", onset: "gr", rime: "ub", categoryLabel: "GR- INITIAL BLEND", imagePath: "\(atomicDir)/grub.png"),
        bottom: BlendPracticeWord(wordLower: "snag", wordUpper: "SNAG", onset: "sn", rime: "ag", categoryLabel: "SN- INITIAL BLEND", imagePath: "\(atomicDir)/snag.png")
    )
]

for pp in practicePages {
    pdfCtx.beginPDFPage(nil)
    drawPageFrame(pdfCtx, pageNumber: pp.pageNum, sectionLabel: "Section 1: Act 1 — In the Garden (Blend Word Practice)")

    drawCenteredText(pdfCtx, "ACT 1 BLEND WORD PRACTICE — SOUND, COLOR & TRACE", x: pageWidth / 2, y: 734, size: 17.5, bold: true)
    drawCenteredText(pdfCtx, "\(pp.pairTitle)  •  Say the blend sounds, color the picture, and trace each word!", x: pageWidth / 2, y: 710, size: 11.5, bold: false)

    let items = [pp.top, pp.bottom]
    let cardYs: [CGFloat] = [392.0, 68.0]
    let cardH: CGFloat = 300.0
    let cardX: CGFloat = 46.0
    let cardW: CGFloat = pageWidth - 92.0

    for (idx, item) in items.enumerated() {
        let cy = cardYs[idx]
        let cardRect = CGRect(x: cardX, y: cy, width: cardW, height: cardH)
        let cardPath = CGPath(roundedRect: cardRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
        pdfCtx.setStrokeColor(NSColor.black.cgColor)
        pdfCtx.setLineWidth(2.2)
        pdfCtx.addPath(cardPath)
        pdfCtx.strokePath()

        let imgBox = CGRect(x: cardX + 14, y: cy + 14, width: 255, height: cardH - 28)
        if let cgImg = loadCGImage(item.imagePath) {
            drawImageAspectFit(pdfCtx, cgImg, in: imgBox)
        }

        pdfCtx.setLineWidth(1.2)
        pdfCtx.setLineDash(phase: 0, lengths: [4, 4])
        pdfCtx.move(to: CGPoint(x: cardX + 280, y: cy + 18))
        pdfCtx.addLine(to: CGPoint(x: cardX + 280, y: cy + cardH - 18))
        pdfCtx.strokePath()
        pdfCtx.setLineDash(phase: 0, lengths: [])

        let rightX = cardX + 296.0
        let rightW = cardW - 314.0

        drawLeftText(pdfCtx, item.categoryLabel, x: rightX, y: cy + cardH - 32, size: 10.5, bold: true, color: NSColor(calibratedWhite: 0.35, alpha: 1.0), tracking: 1.2)
        drawLeftText(pdfCtx, item.wordUpper, x: rightX, y: cy + cardH - 72, size: 34, bold: true, tracking: 3.0)

        // Blend Sound Boxes: [cl] + [em] = clem
        drawBlendSoundBoxes(pdfCtx, x: rightX, y: cy + cardH - 110, onset: item.onset, rime: item.rime, wholeWord: item.wordLower)

        drawLeftText(pdfCtx, "1. Trace UPPERCASE:", x: rightX, y: cy + 156, size: 11, bold: true)
        drawHandwritingLines(pdfCtx, x: rightX, y: cy + 106, width: rightW, height: 42, traceText: item.wordUpper)

        drawLeftText(pdfCtx, "2. Trace lowercase & write:", x: rightX, y: cy + 78, size: 11, bold: true)
        drawHandwritingLines(pdfCtx, x: rightX, y: cy + 28, width: rightW, height: 42, traceText: item.wordLower)
    }

    pdfCtx.endPDFPage()
}

// ============================================================================
// PAGE 11: STAGE 3 — SECTION 1 BLEND WORD FIND PUZZLE PAGE
// ============================================================================
struct WordFindData: Codable {
    let rows: Int
    let cols: Int
    let difficulty: String
    let words: [String]
    let matrix: [[String]]
}

if let wfDataRaw = try? Data(contentsOf: URL(fileURLWithPath: wordFindMatrixPath)),
   let wf = try? JSONDecoder().decode(WordFindData.self, from: wfDataRaw) {
    pdfCtx.beginPDFPage(nil)
    drawPageFrame(pdfCtx, pageNumber: 11, sectionLabel: "Section 1: Act 1 — In the Garden (Blend Word Find)")

    drawCenteredText(pdfCtx, "IN THE GARDEN — BLEND WORD FIND", x: pageWidth / 2, y: 728, size: 22, bold: true)
    drawCenteredText(pdfCtx, "Look Across (→) and Down (↓) to find all 6 Garden Blend Words!", x: pageWidth / 2, y: 702, size: 12.5, bold: false)

    let rows = CGFloat(wf.rows)
    let cols = CGFloat(wf.cols)
    let maxGridW: CGFloat = 430.0
    let maxGridH: CGFloat = 430.0
    let cellSize = floor(min(maxGridW / cols, maxGridH / rows))
    let gridW = cellSize * cols
    let gridH = cellSize * rows
    let gridX = (pageWidth - gridW) / 2.0
    let gridY: CGFloat = 240.0

    let gridRect = CGRect(x: gridX, y: gridY, width: gridW, height: gridH)
    let gridPath = CGPath(roundedRect: gridRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
    pdfCtx.setLineWidth(3.5)
    pdfCtx.addPath(gridPath)
    pdfCtx.strokePath()

    pdfCtx.setLineWidth(1.2)
    pdfCtx.setLineDash(phase: 0, lengths: [2, 5])
    for r in 1..<wf.rows {
        let y = gridY + CGFloat(r) * cellSize
        pdfCtx.move(to: CGPoint(x: gridX, y: y))
        pdfCtx.addLine(to: CGPoint(x: gridX + gridW, y: y))
    }
    for c in 1..<wf.cols {
        let x = gridX + CGFloat(c) * cellSize
        pdfCtx.move(to: CGPoint(x: x, y: gridY))
        pdfCtx.addLine(to: CGPoint(x: x, y: gridY + gridH))
    }
    pdfCtx.strokePath()
    pdfCtx.setLineDash(phase: 0, lengths: [])

    let fontSize = cellSize * 0.52
    for r in 0..<wf.rows {
        for c in 0..<wf.cols {
            let ch = wf.matrix[r][c]
            let cx = gridX + (CGFloat(c) + 0.5) * cellSize
            let cy = gridY + gridH - (CGFloat(r) + 0.5) * cellSize - fontSize * 0.35
            drawCenteredText(pdfCtx, ch, x: cx, y: cy, size: fontSize, bold: true)
        }
    }

    let bankRect = CGRect(x: 68, y: 74, width: pageWidth - 136, height: 132)
    let bankPath = CGPath(roundedRect: bankRect, cornerWidth: 12, cornerHeight: 12, transform: nil)
    pdfCtx.setLineWidth(2.2)
    pdfCtx.addPath(bankPath)
    pdfCtx.strokePath()

    drawCenteredText(pdfCtx, "BLEND WORD BANK — CHECK OFF EACH WORD AS YOU FIND IT!", x: pageWidth / 2, y: 184, size: 12, bold: true)

    let numCols = 3
    let colW = (bankRect.width - 40) / CGFloat(numCols)
    for (idx, w) in wf.words.enumerated() {
        let rIdx = idx / numCols
        let cIdx = idx % numCols
        let wx = bankRect.minX + 28 + CGFloat(cIdx) * colW
        let wy = bankRect.maxY - 56 - CGFloat(rIdx) * 34

        pdfCtx.stroke(CGRect(x: wx, y: wy - 2, width: 16, height: 16), width: 1.8)
        drawLeftText(pdfCtx, w, x: wx + 24, y: wy, size: 15, bold: true, tracking: 1.5)
    }

    pdfCtx.endPDFPage()
}

// ============================================================================
// PAGE 12: STAGE 4 — SECTION 1 CONCLUSION FULL-PAGE COLORING SCENE
// ============================================================================
pdfCtx.beginPDFPage(nil)
drawPageFrame(pdfCtx, pageNumber: 12, sectionLabel: "Section 1: Act 1 — In the Garden (Section Conclusion)")

drawCenteredText(pdfCtx, "ACT 1 CONCLUSION — GOODBYE GARDEN, OFF TO THE WOODS!", x: pageWidth / 2, y: 732, size: 16.5, bold: true)
drawCenteredText(pdfCtx, "You learned 6 blend words:  Clem  •  Plum  •  crop  •  spud  •  grub  •  snag", x: pageWidth / 2, y: 708, size: 12, bold: false)

let conclusionArtRect = CGRect(x: 52, y: 124, width: pageWidth - 104, height: 568)
if let concImg = loadCGImage("\(scenesDir)/scene_1_conclusion.png") {
    drawImageAspectFit(pdfCtx, concImg, in: conclusionArtRect)
}

let capRect = CGRect(x: 52, y: 56, width: pageWidth - 104, height: 58)
drawRichWrappedText(
    pdfCtx,
    "**Clem** tugged his sleeve free from the **snag** and laughed. “Bye-bye, garden **crop**, **spuds**, and little **grub** — into the woods we go!”",
    rect: capRect,
    size: 14.5,
    lineSpacing: 4.0,
    alignment: .center
)

pdfCtx.endPDFPage()
pdfCtx.closePDF()
print("Compiled 12-page Section 1 PDF -> \(outputPDFPath)")
