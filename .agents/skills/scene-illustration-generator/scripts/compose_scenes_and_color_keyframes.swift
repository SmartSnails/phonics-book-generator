#!/usr/bin/env swift
// compose_scenes_and_color_keyframes.swift
// Deterministically composes missing Level 2/3 scenes and Level 4 full-color keyframes
// from the validated Level 1 atomic animal PNGs using CoreGraphics + flood-fill region colorization.

import Foundation
import AppKit
import CoreGraphics

let repoRoot = URL(fileURLWithPath: "/Users/harshad/.gemini/antigravity/scratch/phonics-book-generator")
let atomicDir = repoRoot.appendingPathComponent("output/atomic_animals")
let scenesDir = repoRoot.appendingPathComponent("output/full_page_scenes")
let colorDir = repoRoot.appendingPathComponent("output/color_keyframes")

try FileManager.default.createDirectory(at: atomicDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: scenesDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: colorDir, withIntermediateDirectories: true)

func savePNG(_ cgImage: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "PNG", code: 1)
    }
    try data.write(to: url)
}

func loadCG(_ url: URL) -> CGImage? {
    guard let ns = NSImage(contentsOf: url) else { return nil }
    return ns.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

// ----------------------------------------------------------------------------
// 1. Render Cute Cartoon FROG (1024x1024 B&W Atomic Illustration)
// ----------------------------------------------------------------------------
func renderFrogAtomic() throws {
    let w = 1024, h = 1024
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }

    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    func fillAndStrokeEllipse(_ rect: CGRect, lineWidth: CGFloat = 14) {
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: rect)
        ctx.setLineWidth(lineWidth)
        ctx.strokeEllipse(in: rect)
    }

    // Wide Lily Pad with V-Notch at bottom
    ctx.saveGState()
    let padPath = CGMutablePath()
    padPath.addArc(center: CGPoint(x: 512, y: 245), radius: 340, startAngle: 0.18, endAngle: 2.0 * .pi - 0.18, clockwise: false)
    padPath.addLine(to: CGPoint(x: 580, y: 235))
    padPath.closeSubpath()
    ctx.saveGState()
    ctx.scaleBy(x: 1.0, y: 0.42)
    let scaledPad = CGMutablePath()
    scaledPad.addArc(center: CGPoint(x: 512, y: 560), radius: 370, startAngle: 0.25, endAngle: 2.0 * .pi - 0.25, clockwise: false)
    scaledPad.addLine(to: CGPoint(x: 540, y: 560))
    scaledPad.closeSubpath()
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.addPath(scaledPad)
    ctx.fillPath()
    ctx.setLineWidth(20)
    ctx.addPath(scaledPad)
    ctx.strokePath()
    ctx.restoreGState()
    ctx.restoreGState()

    // Back folded legs
    fillAndStrokeEllipse(CGRect(x: 205, y: 260, width: 170, height: 190), lineWidth: 15)
    fillAndStrokeEllipse(CGRect(x: 649, y: 260, width: 170, height: 190), lineWidth: 15)

    // Webbed back feet
    fillAndStrokeEllipse(CGRect(x: 175, y: 220, width: 150, height: 68), lineWidth: 14)
    fillAndStrokeEllipse(CGRect(x: 699, y: 220, width: 150, height: 68), lineWidth: 14)

    // Frog chubby body
    fillAndStrokeEllipse(CGRect(x: 292, y: 255, width: 440, height: 360), lineWidth: 16)
    // Belly oval
    fillAndStrokeEllipse(CGRect(x: 356, y: 275, width: 312, height: 250), lineWidth: 11)

    // Front legs
    let leftArm = CGPath(roundedRect: CGRect(x: 350, y: 215, width: 76, height: 195), cornerWidth: 36, cornerHeight: 36, transform: nil)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.addPath(leftArm); ctx.fillPath()
    ctx.setLineWidth(14); ctx.addPath(leftArm); ctx.strokePath()

    let rightArm = CGPath(roundedRect: CGRect(x: 598, y: 215, width: 76, height: 195), cornerWidth: 36, cornerHeight: 36, transform: nil)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.addPath(rightArm); ctx.fillPath()
    ctx.setLineWidth(14); ctx.addPath(rightArm); ctx.strokePath()

    // Wide cheerful frog head
    fillAndStrokeEllipse(CGRect(x: 242, y: 500, width: 540, height: 310), lineWidth: 16)

    // Big popping eyes on top of head
    fillAndStrokeEllipse(CGRect(x: 285, y: 710, width: 165, height: 165), lineWidth: 16)
    fillAndStrokeEllipse(CGRect(x: 574, y: 710, width: 165, height: 165), lineWidth: 16)

    // Pupils + white catchlights
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillEllipse(in: CGRect(x: 332, y: 745, width: 76, height: 86))
    ctx.fillEllipse(in: CGRect(x: 616, y: 745, width: 76, height: 86))
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: 348, y: 792, width: 26, height: 26))
    ctx.fillEllipse(in: CGRect(x: 632, y: 792, width: 26, height: 26))

    // Cute nostrils & big wide smile
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillEllipse(in: CGRect(x: 472, y: 678, width: 16, height: 12))
    ctx.fillEllipse(in: CGRect(x: 536, y: 678, width: 16, height: 12))

    ctx.setLineWidth(14)
    ctx.beginPath()
    ctx.addArc(center: CGPoint(x: 512, y: 645), radius: 145, startAngle: 1.15 * .pi, endAngle: 1.85 * .pi, clockwise: false)
    ctx.strokePath()

    // Cheek dimples
    fillAndStrokeEllipse(CGRect(x: 295, y: 585, width: 58, height: 38), lineWidth: 10)
    fillAndStrokeEllipse(CGRect(x: 671, y: 585, width: 58, height: 38), lineWidth: 10)

    if let cg = ctx.makeImage() {
        try savePNG(cg, to: atomicDir.appendingPathComponent("frog.png"))
        print("Rendered frog.png")
    }
}

// ----------------------------------------------------------------------------
// 2. Helper: Draw animal image with white background transparent so layered animals never box-occlude
// ----------------------------------------------------------------------------
func makeWhiteTransparent(_ cgImg: CGImage) -> CGImage? {
    let w = cgImg.width, h = cgImg.height
    var data = [UInt8](repeating: 0, count: w * h * 4)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: w, height: h))

    // Flood-fill exterior background from the 4 corners so internal white body stays opaque white!
    var visited = [Bool](repeating: false, count: w * h)
    var queue: [Int] = [0, w - 1, (h - 1) * w, (h - 1) * w + (w - 1)]
    for idx in queue { visited[idx] = true }

    var head = 0
    while head < queue.count {
        let p = queue[head]
        head += 1
        let base = p * 4
        data[base] = 0
        data[base + 1] = 0
        data[base + 2] = 0
        data[base + 3] = 0

        let r = p / w
        let c = p % w
        let neighbors = [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]
        for (nr, nc) in neighbors {
            if nr >= 0 && nr < h && nc >= 0 && nc < w {
                let np = nr * w + nc
                if !visited[np] {
                    let nb = np * 4
                    let lum = (Int(data[nb]) + Int(data[nb + 1]) + Int(data[nb + 2])) / 3
                    if lum > 200 {
                        visited[np] = true
                        queue.append(np)
                    }
                }
            }
        }
    }
    return ctx.makeImage()
}

// ----------------------------------------------------------------------------
// 3. Helper: Colorize any B&W Line Art Scene into Vibrant 2D Storybook Art
// ----------------------------------------------------------------------------
func colorizeLineArtScene(_ bwImg: CGImage, theme: String, sceneNum: Int) -> CGImage? {
    let w = bwImg.width, h = bwImg.height
    var data = [UInt8](repeating: 255, count: w * h * 4)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.draw(bwImg, in: CGRect(x: 0, y: 0, width: w, height: h))

    // Segment connected white regions and color them with rich storybook palette
    var visited = [Bool](repeating: false, count: w * h)
    let farmPalette: [(UInt8, UInt8, UInt8)] = [
        (255, 224, 178), (255, 204, 128), (239, 154, 154), (255, 245, 157),
        (165, 214, 167), (144, 202, 249), (206, 147, 216), (255, 171, 145),
        (215, 204, 200), (255, 236, 179), (129, 199, 132), (244, 143, 177)
    ]
    let junglePalette: [(UInt8, UInt8, UInt8)] = [
        (255, 183, 77), (255, 213, 79), (129, 199, 132), (102, 187, 106),
        (161, 136, 127), (255, 241, 118), (77, 182, 172), (174, 213, 129),
        (255, 138, 101), (149, 117, 205), (220, 231, 117), (128, 222, 234)
    ]
    let palette = (theme == "jungle") ? junglePalette : farmPalette

    var regionId = 0
    var queue = [Int]()
    queue.reserveCapacity(w * h / 4)

    for startP in 0..<(w * h) {
        if visited[startP] { continue }
        let b = startP * 4
        let lum = (Int(data[b]) + Int(data[b + 1]) + Int(data[b + 2])) / 3
        if lum < 140 {
            visited[startP] = true
            continue
        }

        // Flood fill this enclosed white region
        queue.removeAll(keepingCapacity: true)
        queue.append(startP)
        visited[startP] = true
        var minY = startP / w, maxY = startP / w
        var minX = startP % w, maxX = startP % w
        var touchesOuterMargin = false

        var head = 0
        while head < queue.count {
            let p = queue[head]
            head += 1
            let r = p / w
            let c = p % w
            if r < minY { minY = r }
            if r > maxY { maxY = r }
            if c < minX { minX = c }
            if c > maxX { maxX = c }
            if r <= 4 || r >= h - 5 || c <= 4 || c >= w - 5 {
                touchesOuterMargin = true
            }

            let nbs = [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]
            for (nr, nc) in nbs {
                if nr >= 0 && nr < h && nc >= 0 && nc < w {
                    let np = nr * w + nc
                    if !visited[np] {
                        let nb = np * 4
                        let nlum = (Int(data[nb]) + Int(data[nb + 1]) + Int(data[nb + 2])) / 3
                        if nlum >= 140 {
                            visited[np] = true
                            queue.append(np)
                        }
                    }
                }
            }
        }

        if touchesOuterMargin {
            // Keep outer page margin warm cream-white
            for p in queue {
                let pb = p * 4
                data[pb] = 252; data[pb + 1] = 250; data[pb + 2] = 242
            }
            continue
        }

        let area = queue.count
        let avgY = Double(minY + maxY) / (2.0 * Double(h)) // 0 = top, 1 = bottom in CG buffer

        var col: (UInt8, UInt8, UInt8)
        if area > (w * h) / 7 {
            // Large background sky or ground region
            if avgY < 0.45 {
                // Upper sky / canopy
                col = (theme == "jungle") ? (178, 235, 242) : (187, 222, 251)
            } else {
                // Lower meadow / jungle ground
                col = (theme == "jungle") ? (165, 214, 167) : (197, 225, 165)
            }
        } else {
            col = palette[(regionId + sceneNum * 3) % palette.count]
            regionId += 1
        }

        for p in queue {
            let r = p / w
            // Subtle vertical gradient for storybook richness
            let grad = 0.94 + 0.10 * (1.0 - Double(r) / Double(h))
            let pb = p * 4
            data[pb] = UInt8(min(255.0, Double(col.0) * grad))
            data[pb + 1] = UInt8(min(255.0, Double(col.1) * grad))
            data[pb + 2] = UInt8(min(255.0, Double(col.2) * grad))
        }
    }

    return ctx.makeImage()
}

// ----------------------------------------------------------------------------
// 4. Compose Full-Page B&W Scenes (960x1280, 3:4 Portrait) for Farm 2 & 3 and Jungle 2 & 3
// ----------------------------------------------------------------------------
func composeBWScene(
    filename: String,
    theme: String,
    sceneNum: Int,
    placements: [(animal: String, rect: CGRect, flipX: Bool)]
) throws {
    let w = 960, h = 1280
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }

    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Outer frame border (matching farm_scene_1_bw and jungle_scene_1_bw)
    let frameRect = CGRect(x: 42, y: 42, width: w - 84, height: h - 84)
    ctx.saveGState()
    ctx.clip(to: frameRect)

    if theme == "farm" {
        // Gentle rolling meadow horizon line
        ctx.setLineWidth(8)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 42, y: 740))
        ctx.addQuadCurve(to: CGPoint(x: w - 42, y: 730), control: CGPoint(x: w / 2, y: 810))
        ctx.strokePath()

        // Two fluffy scalloped clouds in upper sky
        func drawCloud(cx: CGFloat, cy: CGFloat, scale: CGFloat) {
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.scaleBy(x: scale, y: scale)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -70, y: -25))
            p.addQuadCurve(to: CGPoint(x: -85, y: 20), control: CGPoint(x: -105, y: -5))
            p.addQuadCurve(to: CGPoint(x: -35, y: 55), control: CGPoint(x: -75, y: 55))
            p.addQuadCurve(to: CGPoint(x: 35, y: 55), control: CGPoint(x: 0, y: 85))
            p.addQuadCurve(to: CGPoint(x: 85, y: 20), control: CGPoint(x: 75, y: 55))
            p.addQuadCurve(to: CGPoint(x: 70, y: -25), control: CGPoint(x: 105, y: -5))
            p.closeSubpath()
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.addPath(p)
            ctx.fillPath()
            ctx.setLineWidth(7)
            ctx.addPath(p)
            ctx.strokePath()
            ctx.restoreGState()
        }
        drawCloud(cx: 230, cy: 1105, scale: 1.0)
        drawCloud(cx: 690, cy: 1135, scale: 0.85)

        // Wooden split-rail fence along horizon
        ctx.setLineWidth(7)
        for fx in stride(from: 90, through: 860, by: 150) {
            let post = CGRect(x: CGFloat(fx), y: 745, width: 22, height: 120)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(post)
            ctx.stroke(post)
        }
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 42, y: 820, width: w - 84, height: 18))
        ctx.stroke(CGRect(x: 42, y: 820, width: w - 84, height: 18))
        ctx.fill(CGRect(x: 42, y: 775, width: w - 84, height: 18))
        ctx.stroke(CGRect(x: 42, y: 775, width: w - 84, height: 18))

        if sceneNum == 3 {
            // Calm farm pond in lower right foreground
            let pondRect = CGRect(x: 490, y: 85, width: 390, height: 190)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: pondRect)
            ctx.setLineWidth(8)
            ctx.strokeEllipse(in: pondRect)
        }

        // Recurring Prop: Woven Apple Basket in center foreground
        let bx: CGFloat = (sceneNum == 2) ? 480 : 450
        let by: CGFloat = (sceneNum == 2) ? 140 : 120
        let basketRect = CGRect(x: bx - 95, y: by, width: 190, height: 125)
        ctx.setFillColor(NSColor.white.cgColor)
        // Apples peeking out top of basket
        for ax in [-55, -18, 18, 55] {
            let aRect = CGRect(x: bx + CGFloat(ax) - 28, y: by + 95, width: 56, height: 52)
            ctx.fillEllipse(in: aRect)
            ctx.setLineWidth(7)
            ctx.strokeEllipse(in: aRect)
        }
        ctx.fill(basketRect)
        ctx.setLineWidth(8)
        ctx.stroke(basketRect)
        // Basket weave lines
        ctx.setLineWidth(5)
        ctx.stroke(CGRect(x: bx - 102, y: by + 100, width: 204, height: 26))
        for wy in stride(from: Int(by) + 25, to: Int(by) + 100, by: 25) {
            ctx.move(to: CGPoint(x: bx - 95, y: CGFloat(wy)))
            ctx.addLine(to: CGPoint(x: bx + 95, y: CGFloat(wy)))
            ctx.strokePath()
        }
    } else {
        // Jungle background: tropical canopy leaves, palm trunks, and waterfall (scene 3)
        ctx.setLineWidth(8)
        // Ground trail curve
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 42, y: 680))
        ctx.addQuadCurve(to: CGPoint(x: w - 42, y: 700), control: CGPoint(x: w / 2, y: 740))
        ctx.strokePath()

        // Overhead tree branch for monkey/canopy
        ctx.setFillColor(NSColor.white.cgColor)
        let branchPath = CGMutablePath()
        branchPath.move(to: CGPoint(x: 42, y: 1090))
        branchPath.addQuadCurve(to: CGPoint(x: w - 42, y: 1020), control: CGPoint(x: w / 2, y: 970))
        branchPath.addLine(to: CGPoint(x: w - 42, y: 1075))
        branchPath.addQuadCurve(to: CGPoint(x: 42, y: 1145), control: CGPoint(x: w / 2, y: 1025))
        branchPath.closeSubpath()
        ctx.addPath(branchPath)
        ctx.fillPath()
        ctx.addPath(branchPath)
        ctx.strokePath()

        // Big tropical pointed palm leaves in top corners
        func drawTropicalLeaf(cx: CGFloat, cy: CGFloat, angle: CGFloat) {
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: angle)
            let lp = CGMutablePath()
            lp.move(to: CGPoint(x: 0, y: -80))
            lp.addQuadCurve(to: CGPoint(x: 0, y: 80), control: CGPoint(x: -85, y: 0))
            lp.addQuadCurve(to: CGPoint(x: 0, y: -80), control: CGPoint(x: 85, y: 0))
            lp.closeSubpath()
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.addPath(lp)
            ctx.fillPath()
            ctx.setLineWidth(7)
            ctx.addPath(lp)
            ctx.strokePath()
            // Center leaf vein
            ctx.move(to: CGPoint(x: 0, y: -70))
            ctx.addLine(to: CGPoint(x: 0, y: 65))
            ctx.strokePath()
            ctx.restoreGState()
        }
        drawTropicalLeaf(cx: 120, cy: 1135, angle: 0.45)
        drawTropicalLeaf(cx: 255, cy: 1150, angle: 0.20)
        drawTropicalLeaf(cx: 705, cy: 1145, angle: -0.20)
        drawTropicalLeaf(cx: 840, cy: 1130, angle: -0.45)

        if sceneNum == 3 {
            // Waterfall pool at bottom
            let pool = CGRect(x: 110, y: 75, width: 740, height: 170)
            ctx.fillEllipse(in: pool)
            ctx.strokeEllipse(in: pool)
        }

        // Recurring Prop: Big Bunch of Curved Bananas on a Broad Leaf Tray
        let bx: CGFloat = 480, by: CGFloat = 135
        let leafTray = CGRect(x: bx - 135, y: by - 25, width: 270, height: 85)
        ctx.fillEllipse(in: leafTray)
        ctx.setLineWidth(7)
        ctx.strokeEllipse(in: leafTray)
        for bOffset in [-50, -18, 14, 46] {
            ctx.saveGState()
            ctx.translateBy(x: bx + CGFloat(bOffset), y: by + 48)
            ctx.rotate(by: CGFloat(bOffset) * -0.005)
            let bp = CGMutablePath()
            bp.move(to: CGPoint(x: 0, y: 52))
            bp.addQuadCurve(to: CGPoint(x: 6, y: -42), control: CGPoint(x: -36, y: 5))
            bp.addQuadCurve(to: CGPoint(x: 0, y: 52), control: CGPoint(x: 24, y: 5))
            bp.closeSubpath()
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.addPath(bp)
            ctx.fillPath()
            ctx.setLineWidth(7)
            ctx.addPath(bp)
            ctx.strokePath()
            ctx.restoreGState()
        }
        // Banana bunch stem crown at top
        let stemRect = CGRect(x: bx - 24, y: by + 90, width: 48, height: 22)
        ctx.fill(stemRect)
        ctx.stroke(stemRect)
    }

    // Draw placed atomic animals with transparent outer backgrounds
    for item in placements {
        let animalURL = atomicDir.appendingPathComponent("\(item.animal).png")
        if let rawCG = loadCG(animalURL), let cleanCG = makeWhiteTransparent(rawCG) {
            ctx.saveGState()
            if item.flipX {
                ctx.translateBy(x: item.rect.midX, y: item.rect.midY)
                ctx.scaleBy(x: -1.0, y: 1.0)
                ctx.translateBy(x: -item.rect.midX, y: -item.rect.midY)
            }
            ctx.draw(cleanCG, in: item.rect)
            ctx.restoreGState()
        }
    }

    ctx.restoreGState()

    // Crisp outer rectangular border
    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setLineWidth(10)
    ctx.stroke(frameRect)

    if let outCG = ctx.makeImage() {
        try savePNG(outCG, to: scenesDir.appendingPathComponent(filename))
        print("Composed B&W scene \(filename)")
    }
}

try renderFrogAtomic()

// Compose Farm Scene 2 (Sheep, Goat, and Cow along the farm trail with apple basket)
try composeBWScene(
    filename: "farm_scene_2_bw.png",
    theme: "farm",
    sceneNum: 2,
    placements: [
        (animal: "cow", rect: CGRect(x: 310, y: 490, width: 340, height: 340), flipX: false),
        (animal: "sheep", rect: CGRect(x: 65, y: 185, width: 390, height: 390), flipX: false),
        (animal: "goat", rect: CGRect(x: 525, y: 190, width: 380, height: 380), flipX: true)
    ]
)

// Compose Farm Scene 3 (Pig, Duck, Cow, and Sheep celebrating around the apple basket by the pond)
try composeBWScene(
    filename: "farm_scene_3_bw.png",
    theme: "farm",
    sceneNum: 3,
    placements: [
        (animal: "cow", rect: CGRect(x: 90, y: 470, width: 340, height: 340), flipX: false),
        (animal: "sheep", rect: CGRect(x: 520, y: 470, width: 340, height: 340), flipX: true),
        (animal: "pig", rect: CGRect(x: 75, y: 140, width: 340, height: 340), flipX: false),
        (animal: "duck", rect: CGRect(x: 565, y: 135, width: 310, height: 310), flipX: true)
    ]
)

// Compose Jungle Scene 2 (Tiger, Lion, and Monkey parading down the jungle trail with bananas)
try composeBWScene(
    filename: "jungle_scene_2_bw.png",
    theme: "jungle",
    sceneNum: 2,
    placements: [
        (animal: "monkey", rect: CGRect(x: 310, y: 720, width: 330, height: 330), flipX: false),
        (animal: "tiger", rect: CGRect(x: 65, y: 225, width: 385, height: 385), flipX: false),
        (animal: "lion", rect: CGRect(x: 515, y: 225, width: 385, height: 385), flipX: true)
    ]
)

// Compose Jungle Scene 3 (Frog, Snake, Tiger, and Lion at the waterfall banana party)
try composeBWScene(
    filename: "jungle_scene_3_bw.png",
    theme: "jungle",
    sceneNum: 3,
    placements: [
        (animal: "tiger", rect: CGRect(x: 85, y: 465, width: 350, height: 350), flipX: false),
        (animal: "lion", rect: CGRect(x: 525, y: 465, width: 350, height: 350), flipX: true),
        (animal: "snake", rect: CGRect(x: 70, y: 135, width: 330, height: 330), flipX: false),
        (animal: "frog", rect: CGRect(x: 560, y: 125, width: 330, height: 330), flipX: false)
    ]
)

// Generate Vibrant Full-Color Storybook Keyframes for Farm Scenes 1, 2, 3 and Jungle Scenes 2, 3
let colorTargets: [(bwFile: String, colorFile: String, theme: String, sceneNum: Int)] = [
    ("farm_scene_1_bw.png", "farm_scene_1_color.png", "farm", 1),
    ("farm_scene_2_bw.png", "farm_scene_2_color.png", "farm", 2),
    ("farm_scene_3_bw.png", "farm_scene_3_color.png", "farm", 3),
    ("jungle_scene_2_bw.png", "jungle_scene_2_color.png", "jungle", 2),
    ("jungle_scene_3_bw.png", "jungle_scene_3_color.png", "jungle", 3)
]

for item in colorTargets {
    let bwURL = scenesDir.appendingPathComponent(item.bwFile)
    if let bwCG = loadCG(bwURL),
       let colCG = colorizeLineArtScene(bwCG, theme: item.theme, sceneNum: item.sceneNum) {
        try savePNG(colCG, to: colorDir.appendingPathComponent(item.colorFile))
        print("Colorized keyframe \(item.colorFile)")
    }
}
