#!/usr/bin/env swift
// build_coloring_book_pdf.swift
// Compiles the ordered US Letter (8.5 x 11 in, 612 x 792 pt) Sample Coloring & Phonics Activity Book PDF.
// Ordering Rule:
//   Ordered by Theme (1. Farm, 2. Jungle).
//   Within each Theme:
//     a) Theme Divider & Word Find Activity Page / Individual Animal Pages First (2 related animals per page with primary handwriting/tracing lines)
//     b) Full-Page Story Coloring Pages Later (3-Scene Storyline)

import Foundation
import AppKit
import CoreGraphics
import CoreText

struct WordItem: Codable {
    let word: String
    let word_upper: String
    let pair_group: String
    let image_path: String
}

struct AnimalPairPage: Codable {
    let pair_title: String
    let top_animal: WordItem
    let bottom_animal: WordItem
}

struct StoryScenePage: Codable {
    let scene_number: Int
    let title: String
    let caption: String
    let image_path: String
}

struct WordFindData: Codable {
    let rows: Int
    let cols: Int
    let difficulty: String
    let words: [String]
    let matrix: [[String]]
}

struct ThemeSection: Codable {
    let theme_key: String
    let theme_title: String
    let subtitle: String
    let animal_pair_pages: [AnimalPairPage]
    let word_find_matrix_path: String
    let story_title: String
    let story_scenes: [StoryScenePage]
}

struct BookManifest: Codable {
    let book_title: String
    let book_subtitle: String
    let output_pdf_path: String
    let themes: [ThemeSection]
}

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: build_coloring_book_pdf.swift <book_manifest.json>\n", stderr)
    exit(1)
}

let manifestURL = URL(fileURLWithPath: CommandLine.arguments[1])
let data = try Data(contentsOf: manifestURL)
let manifest = try JSONDecoder().decode(BookManifest.self, from: data)

let pageWidth: CGFloat = 612.0   // 8.5 in * 72 pt/in
let pageHeight: CGFloat = 792.0  // 11.0 in * 72 pt/in
var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

let outURL = URL(fileURLWithPath: manifest.output_pdf_path)
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)

guard let consumer = CGDataConsumer(url: outURL as CFURL),
      let pdfCtx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
    fputs("ERROR: Cannot create PDF context at \(manifest.output_pdf_path)\n", stderr)
    exit(2)
}

func drawCenteredText(_ ctx: CGContext, _ text: String, x: CGFloat, y: CGFloat, size: CGFloat, bold: Bool = true, color: NSColor = .black, tracking: CGFloat = 0.0) {
    let fontName = bold ? "ArialRoundedMTBold" : "Helvetica"
    let font = NSFont(name: fontName, size: size) ?? (bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size))
    var attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    if tracking != 0 {
        attrs[.kern] = tracking
    }
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
    let fontName = bold ? "ArialRoundedMTBold" : "Helvetica"
    let font = NSFont(name: fontName, size: size) ?? (bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size))
    var attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    if tracking != 0 {
        attrs[.kern] = tracking
    }
    let attrStr = NSAttributedString(string: text, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attrStr)
    ctx.saveGState()
    ctx.textMatrix = .identity
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

func drawWrappedText(_ ctx: CGContext, _ text: String, rect: CGRect, size: CGFloat, bold: Bool = false, alignment: NSTextAlignment = .center) {
    let fontName = bold ? "ArialRoundedMTBold" : "Helvetica"
    let font = NSFont(name: fontName, size: size) ?? NSFont.systemFont(ofSize: size)
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineSpacing = 3.0
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.black,
        .paragraphStyle: style
    ]
    let attrStr = NSAttributedString(string: text, attributes: attrs)
    let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
    let path = CGPath(rect: rect, transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrStr.length), path, nil)
    ctx.saveGState()
    ctx.textMatrix = .identity
    CTFrameDraw(frame, ctx)
    ctx.restoreGState()
}

func loadCGImage(_ path: String) -> CGImage? {
    let url = URL(fileURLWithPath: path)
    guard let nsImg = NSImage(contentsOf: url) else { return nil }
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

func drawPageFrame(_ ctx: CGContext, pageNumber: Int, footerLabel: String) {
    ctx.saveGState()
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

    // Outer rounded border
    let frameRect = CGRect(x: 28, y: 28, width: pageWidth - 56, height: pageHeight - 56)
    let path = CGPath(roundedRect: frameRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setLineWidth(3.0)
    ctx.addPath(path)
    ctx.strokePath()

    if pageNumber > 0 {
        drawCenteredText(ctx, "\(footerLabel)  •  Page \(pageNumber)", x: pageWidth / 2.0, y: 40, size: 10.5, bold: false)
    }
    ctx.restoreGState()
}

func drawHandwritingLines(_ ctx: CGContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, traceText: String?) {
    ctx.saveGState()
    let topY = y + height
    let midY = y + height * 0.5
    let botY = y

    // Top & bottom solid lines
    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setLineWidth(1.5)
    ctx.move(to: CGPoint(x: x, y: topY))
    ctx.addLine(to: CGPoint(x: x + width, y: topY))
    ctx.move(to: CGPoint(x: x, y: botY))
    ctx.addLine(to: CGPoint(x: x + width, y: botY))
    ctx.strokePath()

    // Dashed midline
    ctx.setLineWidth(1.1)
    ctx.setLineDash(phase: 0, lengths: [5, 5])
    ctx.move(to: CGPoint(x: x, y: midY))
    ctx.addLine(to: CGPoint(x: x + width, y: midY))
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])

    // Optional light-gray traceable word
    if let word = traceText {
        let traceColor = NSColor(calibratedWhite: 0.72, alpha: 1.0)
        drawLeftText(ctx, word, x: x + 10, y: botY + 2, size: height * 0.88, bold: true, color: traceColor, tracking: 6.0)
    }
    ctx.restoreGState()
}

var pageNum = 0

// ============================================================================
// 1. BOOK COVER PAGE
// ============================================================================
pdfCtx.beginPDFPage(nil)
drawPageFrame(pdfCtx, pageNumber: 0, footerLabel: "")

// Inner decorative double border on cover
let innerCover = CGPath(roundedRect: CGRect(x: 38, y: 38, width: pageWidth - 76, height: pageHeight - 76), cornerWidth: 10, cornerHeight: 10, transform: nil)
pdfCtx.setLineWidth(1.2)
pdfCtx.addPath(innerCover)
pdfCtx.strokePath()

drawCenteredText(pdfCtx, manifest.book_title.uppercased(), x: pageWidth / 2, y: 690, size: 22, bold: true)
drawCenteredText(pdfCtx, manifest.book_subtitle, x: pageWidth / 2, y: 655, size: 12.5, bold: false)

// Draw a 2x2 showcase of 4 featured animals on the cover
var coverImages: [CGImage] = []
for th in manifest.themes {
    if let firstPair = th.animal_pair_pages.first {
        if let img1 = loadCGImage(firstPair.top_animal.image_path) { coverImages.append(img1) }
        if let img2 = loadCGImage(firstPair.bottom_animal.image_path) { coverImages.append(img2) }
    }
}
let gridBox = CGRect(x: 96, y: 185, width: pageWidth - 192, height: 430)
let gridPath = CGPath(roundedRect: gridBox, cornerWidth: 16, cornerHeight: 16, transform: nil)
pdfCtx.setLineWidth(2.5)
pdfCtx.addPath(gridPath)
pdfCtx.strokePath()

for (idx, cgImg) in coverImages.prefix(4).enumerated() {
    let r = idx / 2
    let c = idx % 2
    let cellW = (gridBox.width - 36) / 2.0
    let cellH = (gridBox.height - 36) / 2.0
    let cellX = gridBox.minX + 12 + CGFloat(c) * (cellW + 12)
    let cellY = gridBox.minY + 12 + CGFloat(1 - r) * (cellH + 12)
    drawImageAspectFit(pdfCtx, cgImg, in: CGRect(x: cellX + 8, y: cellY + 8, width: cellW - 16, height: cellH - 16))
}

drawCenteredText(pdfCtx, "Includes: Animal Name Tracing  •  2-Per-Page Coloring  •  Word Find Puzzles  •  Full-Page Stories", x: pageWidth / 2, y: 135, size: 11.5, bold: true)
drawCenteredText(pdfCtx, "This Book Belongs To: ____________________________________", x: pageWidth / 2, y: 82, size: 13, bold: false)
pdfCtx.endPDFPage()

// ============================================================================
// 2. THEME SECTIONS (Ordered by Theme: Individual Animal Pages -> Word Find -> Full-Page Story Scenes)
// ============================================================================
for theme in manifest.themes {
    // ------------------------------------------------------------------------
    // A. INDIVIDUAL ANIMAL WRITING & COLORING PAGES (2 Related Animals Per Page)
    // ------------------------------------------------------------------------
    for pairPage in theme.animal_pair_pages {
        pageNum += 1
        pdfCtx.beginPDFPage(nil)
        drawPageFrame(pdfCtx, pageNumber: pageNum, footerLabel: theme.theme_title)

        // Page Header Banner
        drawCenteredText(pdfCtx, "\(theme.theme_title.uppercased()) — COLOR, TRACE & WRITE", x: pageWidth / 2, y: 730, size: 18, bold: true)
        drawCenteredText(pdfCtx, "Related Pair: \(pairPage.pair_title)  •  Color the animals and practice writing their names!", x: pageWidth / 2, y: 707, size: 11.5, bold: false)

        let animals = [pairPage.top_animal, pairPage.bottom_animal]
        let cardYs: [CGFloat] = [392.0, 68.0]
        let cardH: CGFloat = 300.0
        let cardX: CGFloat = 46.0
        let cardW: CGFloat = pageWidth - 92.0

        for (idx, animal) in animals.enumerated() {
            let cy = cardYs[idx]
            let cardRect = CGRect(x: cardX, y: cy, width: cardW, height: cardH)
            let cardPath = CGPath(roundedRect: cardRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
            pdfCtx.setStrokeColor(NSColor.black.cgColor)
            pdfCtx.setLineWidth(2.2)
            pdfCtx.addPath(cardPath)
            pdfCtx.strokePath()

            // Left side: Animal B&W Illustration Box
            let imgBox = CGRect(x: cardX + 14, y: cy + 14, width: 255, height: cardH - 28)
            if let cgImg = loadCGImage(animal.image_path) {
                drawImageAspectFit(pdfCtx, cgImg, in: imgBox)
            }

            // Vertical divider between illustration and writing station
            pdfCtx.setLineWidth(1.2)
            pdfCtx.setLineDash(phase: 0, lengths: [4, 4])
            pdfCtx.move(to: CGPoint(x: cardX + 280, y: cy + 18))
            pdfCtx.addLine(to: CGPoint(x: cardX + 280, y: cy + cardH - 18))
            pdfCtx.strokePath()
            pdfCtx.setLineDash(phase: 0, lengths: [])

            // Right side: Word Display + Tracing & Writing Lines
            let rightX = cardX + 296.0
            let rightW = cardW - 314.0

            // Category pill
            drawLeftText(pdfCtx, animal.pair_group.uppercased(), x: rightX, y: cy + cardH - 36, size: 10.5, bold: true, color: NSColor(calibratedWhite: 0.35, alpha: 1.0), tracking: 1.2)

            // Big bold word model
            drawLeftText(pdfCtx, animal.word_upper, x: rightX, y: cy + cardH - 80, size: 36, bold: true, tracking: 3.0)
            drawLeftText(pdfCtx, "(\(animal.word.lowercased())  •  \(animal.word.count) letters)", x: rightX, y: cy + cardH - 102, size: 12, bold: false)

            // Line 1: Trace the word (UPPERCASE)
            drawLeftText(pdfCtx, "1. Trace the word:", x: rightX, y: cy + 165, size: 11, bold: true)
            drawHandwritingLines(pdfCtx, x: rightX, y: cy + 115, width: rightW, height: 42, traceText: animal.word_upper)

            // Line 2: Trace lowercase & write your own
            drawLeftText(pdfCtx, "2. Write the word on your own:", x: rightX, y: cy + 86, size: 11, bold: true)
            drawHandwritingLines(pdfCtx, x: rightX, y: cy + 34, width: rightW, height: 42, traceText: animal.word.lowercased())
        }

        pdfCtx.endPDFPage()
    }

    // ------------------------------------------------------------------------
    // B. THEME WORD FIND PUZZLE PAGE (Vector Rendered from Matrix JSON)
    // ------------------------------------------------------------------------
    if let wfDataRaw = try? Data(contentsOf: URL(fileURLWithPath: theme.word_find_matrix_path)),
       let wf = try? JSONDecoder().decode(WordFindData.self, from: wfDataRaw) {
        pageNum += 1
        pdfCtx.beginPDFPage(nil)
        drawPageFrame(pdfCtx, pageNumber: pageNum, footerLabel: theme.theme_title)

        drawCenteredText(pdfCtx, "\(theme.theme_title.uppercased()) WORD FIND", x: pageWidth / 2, y: 726, size: 22, bold: true)
        drawCenteredText(pdfCtx, "Difficulty: \(wf.difficulty.capitalized) (Look Across → and Down ↓ to find all \(wf.words.count) animals!)", x: pageWidth / 2, y: 700, size: 12, bold: false)

        let rows = CGFloat(wf.rows)
        let cols = CGFloat(wf.cols)
        let maxGridW: CGFloat = 430.0
        let maxGridH: CGFloat = 430.0
        let cellSize = floor(min(maxGridW / cols, maxGridH / rows))
        let gridW = cellSize * cols
        let gridH = cellSize * rows
        let gridX = (pageWidth - gridW) / 2.0
        let gridY: CGFloat = 240.0

        // Outer thick rounded grid border
        let gridRect = CGRect(x: gridX, y: gridY, width: gridW, height: gridH)
        let gridPath = CGPath(roundedRect: gridRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        pdfCtx.setLineWidth(3.5)
        pdfCtx.addPath(gridPath)
        pdfCtx.strokePath()

        // Inner dotted grid lines
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

        // Matrix Letters
        let fontSize = cellSize * 0.52
        for r in 0..<wf.rows {
            for c in 0..<wf.cols {
                let ch = wf.matrix[r][c]
                let cx = gridX + (CGFloat(c) + 0.5) * cellSize
                let cy = gridY + gridH - (CGFloat(r) + 0.5) * cellSize - fontSize * 0.35
                drawCenteredText(pdfCtx, ch, x: cx, y: cy, size: fontSize, bold: true)
            }
        }

        // Word Bank Box at Bottom
        let bankRect = CGRect(x: 68, y: 74, width: pageWidth - 136, height: 132)
        let bankPath = CGPath(roundedRect: bankRect, cornerWidth: 12, cornerHeight: 12, transform: nil)
        pdfCtx.setLineWidth(2.2)
        pdfCtx.addPath(bankPath)
        pdfCtx.strokePath()

        drawCenteredText(pdfCtx, "WORD BANK — CHECK OFF EACH ANIMAL AS YOU FIND IT!", x: pageWidth / 2, y: 184, size: 12, bold: true)

        let numCols = 3
        let colW = (bankRect.width - 40) / CGFloat(numCols)
        for (idx, w) in wf.words.enumerated() {
            let rIdx = idx / numCols
            let cIdx = idx % numCols
            let wx = bankRect.minX + 28 + CGFloat(cIdx) * colW
            let wy = bankRect.maxY - 56 - CGFloat(rIdx) * 34

            // Checkbox
            pdfCtx.stroke(CGRect(x: wx, y: wy - 2, width: 16, height: 16), width: 1.8)
            drawLeftText(pdfCtx, w, x: wx + 24, y: wy, size: 15, bold: true, tracking: 1.5)
        }

        pdfCtx.endPDFPage()
    }

    // ------------------------------------------------------------------------
    // C. FULL-PAGE STORY COLORING PAGES (3-Scene Cohesive Storyline Later)
    // ------------------------------------------------------------------------
    for scene in theme.story_scenes {
        pageNum += 1
        pdfCtx.beginPDFPage(nil)
        drawPageFrame(pdfCtx, pageNumber: pageNum, footerLabel: "\(theme.theme_title) Story")

        drawCenteredText(pdfCtx, "\(theme.story_title.uppercased()) — SCENE \(scene.scene_number) OF \(theme.story_scenes.count)", x: pageWidth / 2, y: 732, size: 15, bold: true)
        drawCenteredText(pdfCtx, scene.title, x: pageWidth / 2, y: 708, size: 19, bold: true)

        // Large Full-Page Coloring Frame
        let artRect = CGRect(x: 52, y: 136, width: pageWidth - 104, height: 556)
        let artBorder = CGPath(rect: artRect, transform: nil)
        pdfCtx.setLineWidth(3.0)
        pdfCtx.addPath(artBorder)
        pdfCtx.strokePath()

        if let cgImg = loadCGImage(scene.image_path) {
            drawImageAspectFit(pdfCtx, cgImg, in: artRect.insetBy(dx: 6, dy: 6))
        }

        // Story Caption Box below the illustration
        let capRect = CGRect(x: 56, y: 62, width: pageWidth - 112, height: 62)
        drawWrappedText(pdfCtx, scene.caption, rect: capRect, size: 13.0, bold: false, alignment: .center)

        pdfCtx.endPDFPage()
    }
}

pdfCtx.closePDF()
print("Compiled \(pageNum + 1)-page coloring book PDF -> \(manifest.output_pdf_path)")
