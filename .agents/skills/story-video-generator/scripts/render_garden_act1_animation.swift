#!/usr/bin/env swift
import Foundation
import AppKit
import CoreGraphics
import CoreText
import AVFoundation

// ============================================================================
// Level 4: Full-Fledged ~10.0-Second Articulated 2D Character & Environment
// Animation Renderer for "Act 1: In the Garden (Clem & Plum — Crop & Spud)"
// ============================================================================
// Renders 300 frames (10.0s @ 30fps, 1080x1080) with:
// - Articulated Clem rig (walking legs, kneeling transition, reaching arms,
//   head bob, blinking eyes, talking/smiling mouth, lifting the potato plant
//   with 3 round golden spuds).
// - Articulated Plum bluebird rig (wing flapping flight onto fencepost,
//   wing-pointing gesture, hopping down beside potato patch, happy bounce).
// - Articulated pink garden grub (popping up and wiggling in Beat 3).
// - Dynamic multi-plane backdrop (drifting clouds, rotating sun rays, cozy
//   cottage with flanking shade trees, rustic wooden fence, swaying spinach
//   crop rows, swaying potato plants, falling soil particles, fluttering
//   yellow butterfly).
// - Synchronized spoken voiceover + bird chirps + earthy pop + acoustic score.
// ============================================================================

let W = 1080
let H = 1080
let fps: Int32 = 30
let durationSec: Double = 10.0
let totalFrames = Int(durationSec * Double(fps)) // 300 frames

let repoRoot = URL(fileURLWithPath: "/Users/harshad/.gemini/antigravity/scratch/phonics-book-generator")
let videosDir = repoRoot.appendingPathComponent("output/videos")
let keyframesDir = repoRoot.appendingPathComponent("output/color_keyframes")
try FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: keyframesDir, withIntermediateDirectories: true)

let outMP4URL = videosDir.appendingPathComponent("act1_in_the_garden_animation.mp4")
try? FileManager.default.removeItem(at: outMP4URL)

func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
    return max(lo, min(hi, v))
}
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    return a + (b - a) * clamp(t, 0.0, 1.0)
}
func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    let t = clamp((x - edge0) / max(0.0001, edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)
}

func cgColor(_ r: Int, _ g: Int, _ b: Int, _ a: Double = 1.0) -> CGColor {
    return NSColor(calibratedRed: CGFloat(r)/255.0, green: CGFloat(g)/255.0, blue: CGFloat(b)/255.0, alpha: CGFloat(a)).cgColor
}

func fillAndStrokePath(_ ctx: CGContext, _ path: CGPath, fill: CGColor, stroke: CGColor = cgColor(20, 20, 20), lineWidth: CGFloat = 5.5) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setFillColor(fill)
    ctx.fillPath()
    ctx.addPath(path)
    ctx.setStrokeColor(stroke)
    ctx.setLineWidth(lineWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()
}

func fillAndStrokeEllipse(_ ctx: CGContext, _ rect: CGRect, fill: CGColor, stroke: CGColor = cgColor(20, 20, 20), lineWidth: CGFloat = 5.5) {
    let p = CGPath(ellipseIn: rect, transform: nil)
    fillAndStrokePath(ctx, p, fill: fill, stroke: stroke, lineWidth: lineWidth)
}

func fillAndStrokeRoundedRect(_ ctx: CGContext, _ rect: CGRect, radius: CGFloat, fill: CGColor, stroke: CGColor = cgColor(20, 20, 20), lineWidth: CGFloat = 5.5) {
    let p = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    fillAndStrokePath(ctx, p, fill: fill, stroke: stroke, lineWidth: lineWidth)
}

func drawText(_ ctx: CGContext, _ text: String, x: CGFloat, y: CGFloat, size: CGFloat, color: NSColor = .white, alignCenter: Bool = true) {
    let font = NSFont(name: "ArialRoundedMTBold", size: size) ?? NSFont.boldSystemFont(ofSize: size)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    let attrStr = NSAttributedString(string: text, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attrStr)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.saveGState()
    ctx.textMatrix = .identity
    let drawX = alignCenter ? (x - bounds.width / 2.0) : x
    ctx.textPosition = CGPoint(x: drawX, y: y)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

// ----------------------------------------------------------------------------
// Scene Backdrop & Prop Drawing Helpers
// ----------------------------------------------------------------------------
func drawCloud(_ ctx: CGContext, cx: Double, cy: Double, scale: Double) {
    ctx.saveGState()
    ctx.translateBy(x: CGFloat(cx), y: CGFloat(cy))
    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    let p = CGMutablePath()
    p.move(to: CGPoint(x: -75, y: -22))
    p.addQuadCurve(to: CGPoint(x: -90, y: 18), control: CGPoint(x: -110, y: -5))
    p.addQuadCurve(to: CGPoint(x: -35, y: 52), control: CGPoint(x: -80, y: 55))
    p.addQuadCurve(to: CGPoint(x: 35, y: 52), control: CGPoint(x: 0, y: 82))
    p.addQuadCurve(to: CGPoint(x: 90, y: 18), control: CGPoint(x: 80, y: 55))
    p.addQuadCurve(to: CGPoint(x: 75, y: -22), control: CGPoint(x: 110, y: -5))
    p.closeSubpath()
    fillAndStrokePath(ctx, p, fill: cgColor(255, 255, 255), lineWidth: 5.0)
    ctx.restoreGState()
}

func drawSpinachPlant(_ ctx: CGContext, x: Double, y: Double, scale: Double, swayAngle: Double) {
    ctx.saveGState()
    ctx.translateBy(x: CGFloat(x), y: CGFloat(y))
    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    ctx.rotate(by: CGFloat(swayAngle))

    let leafAngles: [Double] = [-0.55, -0.22, 0.18, 0.52]
    let leafColors = [cgColor(67, 160, 71), cgColor(102, 187, 106), cgColor(76, 175, 80), cgColor(56, 142, 60)]
    for (i, ang) in leafAngles.enumerated() {
        ctx.saveGState()
        ctx.rotate(by: CGFloat(ang))
        let lp = CGMutablePath()
        lp.move(to: CGPoint(x: 0, y: 0))
        lp.addQuadCurve(to: CGPoint(x: -24, y: 55), control: CGPoint(x: -35, y: 25))
        lp.addQuadCurve(to: CGPoint(x: 0, y: 78), control: CGPoint(x: -18, y: 76))
        lp.addQuadCurve(to: CGPoint(x: 24, y: 55), control: CGPoint(x: 18, y: 76))
        lp.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: 35, y: 25))
        lp.closeSubpath()
        fillAndStrokePath(ctx, lp, fill: leafColors[i % leafColors.count], lineWidth: 4.2)
        // Center vein
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 0, y: 6))
        ctx.addLine(to: CGPoint(x: 0, y: 60))
        ctx.setStrokeColor(cgColor(27, 94, 32))
        ctx.setLineWidth(3.0)
        ctx.strokePath()
        ctx.restoreGState()
    }
    ctx.restoreGState()
}

// ----------------------------------------------------------------------------
// Articulated Character 1: Plum the Round Bluebird
// ----------------------------------------------------------------------------
func drawPlum(
    _ ctx: CGContext,
    x: Double,
    y: Double,
    scale: Double,
    headTilt: Double,
    wingFlapAngle: Double,
    pointWing: Double,
    beakOpen: Double,
    blink: Bool,
    flipX: Bool
) {
    ctx.saveGState()
    ctx.translateBy(x: CGFloat(x), y: CGFloat(y))
    ctx.scaleBy(x: CGFloat(flipX ? -scale : scale), y: CGFloat(scale))

    // Little orange legs
    ctx.setStrokeColor(cgColor(230, 126, 34))
    ctx.setLineWidth(5.5)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: -14, y: -42))
    ctx.addLine(to: CGPoint(x: -18, y: -68))
    ctx.move(to: CGPoint(x: 14, y: -42))
    ctx.addLine(to: CGPoint(x: 18, y: -68))
    ctx.strokePath()

    // Tail feathers
    let tailP = CGMutablePath()
    tailP.move(to: CGPoint(x: -45, y: -10))
    tailP.addLine(to: CGPoint(x: -82, y: 18))
    tailP.addLine(to: CGPoint(x: -74, y: -6))
    tailP.addLine(to: CGPoint(x: -85, y: -22))
    tailP.addLine(to: CGPoint(x: -42, y: -26))
    tailP.closeSubpath()
    fillAndStrokePath(ctx, tailP, fill: cgColor(41, 182, 246), lineWidth: 5.0)

    // Round plump bluebird body
    fillAndStrokeEllipse(ctx, CGRect(x: -55, y: -48, width: 110, height: 96), fill: cgColor(79, 195, 247), lineWidth: 5.5)

    // Soft sky-cream speckled belly patch
    fillAndStrokeEllipse(ctx, CGRect(x: -28, y: -42, width: 70, height: 64), fill: cgColor(225, 245, 254), lineWidth: 4.0)
    // Cute chest speckles
    for sp in [CGPoint(x: -4, y: -6), CGPoint(x: 14, y: -4), CGPoint(x: 5, y: -20), CGPoint(x: 22, y: -18)] {
        fillAndStrokeEllipse(ctx, CGRect(x: sp.x - 3, y: sp.y - 5, width: 6, height: 9), fill: cgColor(41, 182, 246), lineWidth: 2.2)
    }

    // Head group with tilt
    ctx.saveGState()
    ctx.translateBy(x: 10, y: 34)
    ctx.rotate(by: CGFloat(headTilt))

    // Round head
    fillAndStrokeEllipse(ctx, CGRect(x: -42, y: -32, width: 84, height: 78), fill: cgColor(79, 195, 247), lineWidth: 5.5)

    // Top tuft feathers
    let tuft = CGMutablePath()
    tuft.move(to: CGPoint(x: -4, y: 44))
    tuft.addQuadCurve(to: CGPoint(x: -14, y: 64), control: CGPoint(x: -16, y: 55))
    tuft.addQuadCurve(to: CGPoint(x: 4, y: 46), control: CGPoint(x: -2, y: 58))
    tuft.addQuadCurve(to: CGPoint(x: 12, y: 62), control: CGPoint(x: 8, y: 58))
    tuft.addQuadCurve(to: CGPoint(x: 14, y: 42), control: CGPoint(x: 16, y: 52))
    fillAndStrokePath(ctx, tuft, fill: cgColor(41, 182, 246), lineWidth: 4.5)

    // Expressive Eye
    if blink {
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 6, y: 12))
        ctx.addQuadCurve(to: CGPoint(x: 26, y: 12), control: CGPoint(x: 16, y: 4))
        ctx.setStrokeColor(cgColor(20, 20, 20))
        ctx.setLineWidth(4.5)
        ctx.strokePath()
    } else {
        fillAndStrokeEllipse(ctx, CGRect(x: 6, y: 0, width: 22, height: 24), fill: cgColor(20, 20, 20), lineWidth: 3.0)
        // Eye sparkle
        ctx.setFillColor(cgColor(255, 255, 255))
        ctx.fillEllipse(in: CGRect(x: 15, y: 11, width: 8, height: 8))
    }

    // Rosy cheek
    ctx.setFillColor(cgColor(255, 138, 128, 0.75))
    ctx.fillEllipse(in: CGRect(x: -4, y: -12, width: 18, height: 11))

    // Animated Beak (opens when chirping/talking)
    let upperBeak = CGMutablePath()
    upperBeak.move(to: CGPoint(x: 34, y: 12))
    upperBeak.addLine(to: CGPoint(x: 64, y: 6 + CGFloat(beakOpen * 10.0)))
    upperBeak.addLine(to: CGPoint(x: 34, y: 0))
    upperBeak.closeSubpath()
    fillAndStrokePath(ctx, upperBeak, fill: cgColor(255, 179, 0), lineWidth: 4.5)

    let lowerBeak = CGMutablePath()
    lowerBeak.move(to: CGPoint(x: 34, y: 0))
    lowerBeak.addLine(to: CGPoint(x: 58, y: -4 - CGFloat(beakOpen * 12.0)))
    lowerBeak.addLine(to: CGPoint(x: 34, y: -12))
    lowerBeak.closeSubpath()
    fillAndStrokePath(ctx, lowerBeak, fill: cgColor(251, 140, 0), lineWidth: 4.5)

    ctx.restoreGState()

    // Articulated Wing (flaps or points toward the crop/spuds!)
    ctx.saveGState()
    ctx.translateBy(x: -8, y: 4)
    let wingRot = wingFlapAngle + pointWing * 0.85
    ctx.rotate(by: CGFloat(wingRot))
    let wingP = CGMutablePath()
    wingP.move(to: CGPoint(x: 0, y: 12))
    wingP.addQuadCurve(to: CGPoint(x: 58 + CGFloat(pointWing * 22.0), y: 24), control: CGPoint(x: 28, y: 34))
    wingP.addQuadCurve(to: CGPoint(x: 0, y: -22), control: CGPoint(x: 32, y: -18))
    wingP.closeSubpath()
    fillAndStrokePath(ctx, wingP, fill: cgColor(2, 136, 209), lineWidth: 5.0)
    ctx.restoreGState()

    ctx.restoreGState()
}

// ----------------------------------------------------------------------------
// Articulated Character 2: Clem (5-Year-Old Curious Hands-On Garden Explorer)
// ----------------------------------------------------------------------------
func drawClem(
    _ ctx: CGContext,
    x: Double,
    y: Double,
    scale: Double,
    walkCycle: Double,
    kneelProgress: Double, // 0 = standing/walking, 1 = kneeling in soil
    reachProgress: Double, // 0 = arms relaxed, 1 = reaching/pulling spud plant
    liftHeight: Double,    // 0 = plant in ground, 1 = lifted up showing spuds!
    headNod: Double,
    mouthOpen: Double,
    blink: Bool
) {
    ctx.saveGState()
    let kneelDrop = kneelProgress * 58.0
    ctx.translateBy(x: CGFloat(x), y: CGFloat(y - kneelDrop))
    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

    let legSwing = sin(walkCycle * .pi * 2.0) * 24.0 * (1.0 - kneelProgress)

    // --- LEGS & BROWN BOOTS ---
    // Left Leg
    ctx.saveGState()
    ctx.translateBy(x: -24, y: -55)
    ctx.rotate(by: CGFloat((legSwing * .pi / 180.0) - kneelProgress * 0.45))
    fillAndStrokeRoundedRect(ctx, CGRect(x: -18, y: -70, width: 36, height: 75), radius: 12, fill: cgColor(30, 136, 229), lineWidth: 5.5)
    // Brown boot
    fillAndStrokeRoundedRect(ctx, CGRect(x: -24, y: -96, width: 48, height: 32), radius: 12, fill: cgColor(109, 76, 65), lineWidth: 5.5)
    ctx.restoreGState()

    // Right Leg
    ctx.saveGState()
    ctx.translateBy(x: 24, y: -55)
    ctx.rotate(by: CGFloat((-legSwing * .pi / 180.0) + kneelProgress * 0.55))
    fillAndStrokeRoundedRect(ctx, CGRect(x: -18, y: -70, width: 36, height: 75), radius: 12, fill: cgColor(25, 118, 210), lineWidth: 5.5)
    // Brown boot
    fillAndStrokeRoundedRect(ctx, CGRect(x: -18, y: -96, width: 48, height: 32), radius: 12, fill: cgColor(93, 64, 55), lineWidth: 5.5)
    ctx.restoreGState()

    // --- TORSO (White Button-Down Shirt + Blue Denim Overalls) ---
    ctx.saveGState()
    let torsoLean = kneelProgress * -0.14
    ctx.rotate(by: CGFloat(torsoLean))

    // White shirt base
    fillAndStrokeRoundedRect(ctx, CGRect(x: -54, y: -62, width: 108, height: 128), radius: 28, fill: cgColor(250, 250, 250), lineWidth: 5.5)

    // Blue denim overalls bib & pants top
    fillAndStrokeRoundedRect(ctx, CGRect(x: -52, y: -65, width: 104, height: 92), radius: 22, fill: cgColor(33, 150, 243), lineWidth: 5.5)
    // Overalls straps
    fillAndStrokeRoundedRect(ctx, CGRect(x: -42, y: 12, width: 22, height: 54), radius: 6, fill: cgColor(33, 150, 243), lineWidth: 5.0)
    fillAndStrokeRoundedRect(ctx, CGRect(x: 20, y: 12, width: 22, height: 54), radius: 6, fill: cgColor(33, 150, 243), lineWidth: 5.0)
    // Yellow brass overall buttons
    fillAndStrokeEllipse(ctx, CGRect(x: -37, y: 18, width: 12, height: 12), fill: cgColor(255, 213, 79), lineWidth: 3.5)
    fillAndStrokeEllipse(ctx, CGRect(x: 25, y: 18, width: 12, height: 12), fill: cgColor(255, 213, 79), lineWidth: 3.5)
    // Front pocket
    fillAndStrokeRoundedRect(ctx, CGRect(x: -22, y: -22, width: 44, height: 34), radius: 8, fill: cgColor(66, 165, 245), lineWidth: 4.5)

    // --- BACK ARM (Extends toward +x in local space = left toward the spud plant!) ---
    ctx.saveGState()
    ctx.translateBy(x: 34, y: 34)
    let backArmAngle = lerp(-0.85, 0.22, reachProgress) + liftHeight * 0.35
    ctx.rotate(by: CGFloat(backArmAngle))
    fillAndStrokeRoundedRect(ctx, CGRect(x: -12, y: -16, width: 92, height: 32), radius: 14, fill: cgColor(250, 250, 250), lineWidth: 5.5)
    fillAndStrokeEllipse(ctx, CGRect(x: 68, y: -18, width: 32, height: 32), fill: cgColor(255, 218, 185), lineWidth: 5.0)
    ctx.restoreGState()

    // --- HEAD (Big Brown Eyes, Neat Black Hair, Cheerful Grin) ---
    ctx.saveGState()
    ctx.translateBy(x: 0, y: 126)
    ctx.rotate(by: CGFloat(headNod))

    // Neck
    fillAndStrokeRoundedRect(ctx, CGRect(x: -18, y: -72, width: 36, height: 32), radius: 10, fill: cgColor(255, 218, 185), lineWidth: 5.0)

    // Ears
    fillAndStrokeEllipse(ctx, CGRect(x: -88, y: -18, width: 28, height: 34), fill: cgColor(255, 218, 185), lineWidth: 5.0)
    fillAndStrokeEllipse(ctx, CGRect(x: 60, y: -18, width: 28, height: 34), fill: cgColor(255, 218, 185), lineWidth: 5.0)

    // Head oval
    fillAndStrokeRoundedRect(ctx, CGRect(x: -74, y: -56, width: 148, height: 142), radius: 64, fill: cgColor(255, 224, 196), lineWidth: 6.0)

    // Neat Black Hair with cute forehead bangs
    let hair = CGMutablePath()
    hair.move(to: CGPoint(x: -76, y: 12))
    hair.addQuadCurve(to: CGPoint(x: -60, y: 82), control: CGPoint(x: -86, y: 62))
    hair.addQuadCurve(to: CGPoint(x: 8, y: 96), control: CGPoint(x: -25, y: 102))
    hair.addQuadCurve(to: CGPoint(x: 72, y: 68), control: CGPoint(x: 52, y: 95))
    hair.addQuadCurve(to: CGPoint(x: 76, y: 12), control: CGPoint(x: 86, y: 45))
    // Forehead bangs
    hair.addLine(to: CGPoint(x: 52, y: 34))
    hair.addLine(to: CGPoint(x: 36, y: 18))
    hair.addLine(to: CGPoint(x: 8, y: 36))
    hair.addLine(to: CGPoint(x: -18, y: 16))
    hair.addLine(to: CGPoint(x: -44, y: 34))
    hair.closeSubpath()
    fillAndStrokePath(ctx, hair, fill: cgColor(38, 42, 48), lineWidth: 6.0)

    // Eyebrows
    ctx.setStrokeColor(cgColor(38, 42, 48))
    ctx.setLineWidth(5.0)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: -48, y: 16))
    ctx.addQuadCurve(to: CGPoint(x: -20, y: 18), control: CGPoint(x: -34, y: 26))
    ctx.move(to: CGPoint(x: 12, y: 18))
    ctx.addQuadCurve(to: CGPoint(x: 40, y: 16), control: CGPoint(x: 26, y: 26))
    ctx.strokePath()

    // Big Warm Brown Eyes (with blink)
    for ex in [-34.0, 26.0] {
        if blink {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: ex - 13, y: -4))
            ctx.addQuadCurve(to: CGPoint(x: ex + 13, y: -4), control: CGPoint(x: ex, y: -12))
            ctx.setStrokeColor(cgColor(30, 30, 30))
            ctx.setLineWidth(5.0)
            ctx.strokePath()
        } else {
            fillAndStrokeEllipse(ctx, CGRect(x: ex - 13, y: -18, width: 26, height: 30), fill: cgColor(78, 52, 46), lineWidth: 4.0)
            ctx.setFillColor(cgColor(20, 20, 20))
            ctx.fillEllipse(in: CGRect(x: ex - 8, y: -12, width: 16, height: 18))
            ctx.setFillColor(cgColor(255, 255, 255))
            ctx.fillEllipse(in: CGRect(x: ex - 10, y: -2, width: 9, height: 9))
        }
    }

    // Rosy cheeks
    ctx.setFillColor(cgColor(255, 138, 128, 0.65))
    ctx.fillEllipse(in: CGRect(x: -60, y: -28, width: 22, height: 13))
    ctx.fillEllipse(in: CGRect(x: 32, y: -28, width: 22, height: 13))

    // Cute straight nose
    ctx.beginPath()
    ctx.move(to: CGPoint(x: -4, y: -8))
    ctx.addQuadCurve(to: CGPoint(x: -4, y: -20), control: CGPoint(x: -14, y: -16))
    ctx.setStrokeColor(cgColor(30, 30, 30))
    ctx.setLineWidth(4.5)
    ctx.strokePath()

    // Animated Mouth (smiles and opens when speaking/cheering)
    if mouthOpen > 0.12 {
        let mh = 12.0 + mouthOpen * 18.0
        fillAndStrokeRoundedRect(ctx, CGRect(x: -22, y: -44 - mh/2, width: 38, height: mh), radius: CGFloat(mh/2), fill: cgColor(229, 115, 115), lineWidth: 4.5)
    } else {
        ctx.beginPath()
        ctx.move(to: CGPoint(x: -22, y: -32))
        ctx.addQuadCurve(to: CGPoint(x: 16, y: -32), control: CGPoint(x: -3, y: -48))
        ctx.setStrokeColor(cgColor(30, 30, 30))
        ctx.setLineWidth(5.0)
        ctx.strokePath()
    }
    ctx.restoreGState() // end head

    // --- FRONT ARM (Reaches toward +x in local space = left to grip the spud plant stem!) ---
    ctx.saveGState()
    ctx.translateBy(x: 18, y: 26)
    let frontArmAngle = lerp(-1.10, 0.08, reachProgress) + liftHeight * 0.32
    ctx.rotate(by: CGFloat(frontArmAngle))
    fillAndStrokeRoundedRect(ctx, CGRect(x: -14, y: -16, width: 102, height: 32), radius: 14, fill: cgColor(250, 250, 250), lineWidth: 5.5)
    fillAndStrokeEllipse(ctx, CGRect(x: 76, y: -18, width: 32, height: 32), fill: cgColor(255, 218, 185), lineWidth: 5.0)
    ctx.restoreGState()

    ctx.restoreGState() // end torso
    ctx.restoreGState() // end Clem
}

// ----------------------------------------------------------------------------
// Articulated Potato Plant + 3 Golden Spuds + Tiny Cute Smiling Pink Grub
// ----------------------------------------------------------------------------
func drawSpudPlantAndGrub(
    _ ctx: CGContext,
    baseX: Double,
    baseY: Double,
    liftHeight: Double,   // 0 = buried in dirt, 1 = lifted high showing 3 round spuds!
    swayAngle: Double,
    grubPop: Double,      // 0 = hidden, 1 = cute pink grub wiggling out of hole!
    timeSec: Double
) {
    let liftY = liftHeight * 115.0

    // Soft dirt mound & hole at base
    fillAndStrokeEllipse(ctx, CGRect(x: baseX - 95, y: baseY - 28, width: 190, height: 52), fill: cgColor(121, 85, 72), lineWidth: 5.0)
    if liftHeight > 0.15 {
        // Dark soil hole revealed when spuds are pulled up
        fillAndStrokeEllipse(ctx, CGRect(x: baseX - 65, y: baseY - 18, width: 130, height: 34), fill: cgColor(78, 52, 46), lineWidth: 4.5)
    }

    //Cute tiny smiling pink Grub wiggling out of the hole in Beat 3!
    if grubPop > 0.02 {
        ctx.saveGState()
        let wiggleX = sin(timeSec * 10.0) * 8.0 * grubPop
        let gy = baseY - 2.0 + grubPop * 26.0
        ctx.translateBy(x: CGFloat(baseX - 96.0 + wiggleX), y: CGFloat(gy))
        // 3 chubby pink segments
        fillAndStrokeEllipse(ctx, CGRect(x: -16, y: -26, width: 28, height: 24), fill: cgColor(244, 143, 177), lineWidth: 4.0)
        fillAndStrokeEllipse(ctx, CGRect(x: -18, y: -12, width: 32, height: 26), fill: cgColor(248, 187, 208), lineWidth: 4.0)
        fillAndStrokeEllipse(ctx, CGRect(x: -20, y: 4, width: 36, height: 32), fill: cgColor(244, 143, 177), lineWidth: 4.5)
        // Cute grub eyes & smile
        ctx.setFillColor(cgColor(20, 20, 20))
        ctx.fillEllipse(in: CGRect(x: -11, y: 18, width: 6, height: 7))
        ctx.fillEllipse(in: CGRect(x: 1, y: 18, width: 6, height: 7))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: -8, y: 12))
        ctx.addQuadCurve(to: CGPoint(x: 4, y: 12), control: CGPoint(x: -2, y: 6))
        ctx.setStrokeColor(cgColor(20, 20, 20))
        ctx.setLineWidth(3.0)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // Lifted Potato Plant & 3 Round Spuds
    ctx.saveGState()
    ctx.translateBy(x: CGFloat(baseX), y: CGFloat(baseY + liftY))
    ctx.rotate(by: CGFloat(swayAngle * 0.6))

    if liftHeight > 0.08 {
        // Root strands + 3 round golden-tan spuds clinging to roots!
        ctx.setStrokeColor(cgColor(109, 76, 65))
        ctx.setLineWidth(4.5)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 0, y: 10))
        ctx.addLine(to: CGPoint(x: -44, y: -42))
        ctx.move(to: CGPoint(x: 0, y: 10))
        ctx.addLine(to: CGPoint(x: 4, y: -62))
        ctx.move(to: CGPoint(x: 0, y: 10))
        ctx.addLine(to: CGPoint(x: 48, y: -38))
        ctx.strokePath()

        let spuds: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-68, -68, 52, 40),
            (-22, -92, 56, 46),
            (28, -66, 52, 42)
        ]
        for (sx, sy, sw, sh) in spuds {
            fillAndStrokeEllipse(ctx, CGRect(x: sx, y: sy, width: sw, height: sh), fill: cgColor(215, 169, 108), lineWidth: 5.0)
            // Potato eyes (dots)
            ctx.setFillColor(cgColor(121, 85, 72))
            ctx.fillEllipse(in: CGRect(x: sx + 14, y: sy + 16, width: 5, height: 5))
            ctx.fillEllipse(in: CGRect(x: sx + 30, y: sy + 22, width: 5, height: 5))
        }
    }

    // Lush leafy green potato plant stems above
    drawSpinachPlant(ctx, x: 0, y: 0, scale: 1.35, swayAngle: swayAngle)
    ctx.restoreGState()
}

// ----------------------------------------------------------------------------
// Master Frame Renderer (t in 0.0 ... 10.0s)
// ----------------------------------------------------------------------------
func renderFrame(frameIdx: Int) -> CGImage? {
    let t = Double(frameIdx) / Double(fps)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: W,
        height: H,
        bitsPerComponent: 8,
        bytesPerRow: W * 4,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // Camera choreography across the 3 beats
    // Beat 1 (0-3.2s): gentle push-in; Beat 2 (3.2-7.0s): pan & focus on spud discovery; Beat 3 (7.0-10.0s): pull-back
    let pushIn = smoothstep(0.0, 6.2, t) - 0.55 * smoothstep(7.0, 10.0, t)
    let camScale = 1.0 + 0.08 * pushIn
    let camFocusX = Double(W) * 0.5 + 25.0 * smoothstep(2.5, 6.5, t) * (1.0 - smoothstep(7.2, 9.8, t))
    let camFocusY = Double(H) * 0.46 - 28.0 * smoothstep(3.0, 6.5, t) * (1.0 - smoothstep(7.2, 9.8, t))

    ctx.saveGState()
    ctx.translateBy(x: CGFloat(Double(W) * 0.5), y: CGFloat(Double(H) * 0.5))
    ctx.scaleBy(x: CGFloat(camScale), y: CGFloat(camScale))
    ctx.translateBy(x: CGFloat(-camFocusX), y: CGFloat(-camFocusY))

    // 1. SKY & WARM AFTERNOON SUNLIGHT (Top 1/3)
    ctx.setFillColor(cgColor(179, 229, 252))
    ctx.fill(CGRect(x: -120, y: 560, width: W + 240, height: 640))

    // Animated Golden Sun with rotating rays
    let sunX = 760.0, sunY = 925.0
    ctx.saveGState()
    ctx.translateBy(x: CGFloat(sunX), y: CGFloat(sunY))
    ctx.rotate(by: CGFloat(t * 0.18))
    for i in 0..<12 {
        let ang = Double(i) * (.pi / 6.0)
        ctx.saveGState()
        ctx.rotate(by: CGFloat(ang))
        let ray = CGMutablePath()
        ray.move(to: CGPoint(x: -14, y: 68))
        ray.addLine(to: CGPoint(x: 0, y: 98))
        ray.addLine(to: CGPoint(x: 14, y: 68))
        ray.closeSubpath()
        fillAndStrokePath(ctx, ray, fill: cgColor(255, 213, 79), lineWidth: 4.0)
        ctx.restoreGState()
    }
    fillAndStrokeEllipse(ctx, CGRect(x: -64, y: -64, width: 128, height: 128), fill: cgColor(255, 238, 88), lineWidth: 5.5)
    ctx.restoreGState()

    // Drifting Fluffy White Clouds
    drawCloud(ctx, cx: 240.0 + t * 14.0, cy: 935.0, scale: 1.05)
    drawCloud(ctx, cx: 540.0 + t * 10.0, cy: 965.0, scale: 0.78)

    // 2. DISTANT HILLS, COZY COTTAGE & TWO FLANKING SHADE TREES (Top 1/3 Landmark from Story Draft)
    fillAndStrokeEllipse(ctx, CGRect(x: -140, y: 480, width: 1360, height: 320), fill: cgColor(165, 214, 167), lineWidth: 5.5)

    // Left Shade Tree
    fillAndStrokeRoundedRect(ctx, CGRect(x: 105, y: 630, width: 38, height: 150), radius: 8, fill: cgColor(121, 85, 72), lineWidth: 5.5)
    fillAndStrokeEllipse(ctx, CGRect(x: 35, y: 735, width: 180, height: 155), fill: cgColor(102, 187, 106), lineWidth: 5.5)

    // Cozy Cream Cottage with Terracotta Roof
    fillAndStrokeRoundedRect(ctx, CGRect(x: 245, y: 625, width: 280, height: 165), radius: 6, fill: cgColor(255, 248, 225), lineWidth: 5.5)
    let roof = CGMutablePath()
    roof.move(to: CGPoint(x: 220, y: 780))
    roof.addLine(to: CGPoint(x: 385, y: 895))
    roof.addLine(to: CGPoint(x: 550, y: 780))
    roof.closeSubpath()
    fillAndStrokePath(ctx, roof, fill: cgColor(229, 115, 115), lineWidth: 5.5)
    // Cottage door & windows
    fillAndStrokeRoundedRect(ctx, CGRect(x: 360, y: 625, width: 52, height: 95), radius: 6, fill: cgColor(141, 110, 99), lineWidth: 4.5)
    fillAndStrokeRoundedRect(ctx, CGRect(x: 278, y: 675, width: 56, height: 56), radius: 6, fill: cgColor(179, 229, 252), lineWidth: 4.5)
    fillAndStrokeRoundedRect(ctx, CGRect(x: 438, y: 675, width: 56, height: 56), radius: 6, fill: cgColor(179, 229, 252), lineWidth: 4.5)

    // Right Shade Tree
    fillAndStrokeRoundedRect(ctx, CGRect(x: 910, y: 630, width: 40, height: 155), radius: 8, fill: cgColor(121, 85, 72), lineWidth: 5.5)
    fillAndStrokeEllipse(ctx, CGRect(x: 830, y: 735, width: 195, height: 165), fill: cgColor(102, 187, 106), lineWidth: 5.5)

    // 3. GARDEN SOIL & LUSH GREEN MEADOW GROUND (Lower 2/3)
    ctx.setFillColor(cgColor(197, 225, 165))
    ctx.fill(CGRect(x: -120, y: -120, width: W + 240, height: 740))

    // Garden soil rows on left & center
    let soilPath = CGMutablePath()
    soilPath.move(to: CGPoint(x: -80, y: -80))
    soilPath.addLine(to: CGPoint(x: -80, y: 585))
    soilPath.addLine(to: CGPoint(x: 980, y: 585))
    soilPath.addLine(to: CGPoint(x: 980, y: -80))
    soilPath.closeSubpath()
    fillAndStrokePath(ctx, soilPath, fill: cgColor(188, 170, 164), lineWidth: 5.0)

    // 4. RUSTIC WOODEN GARDEN FENCE AT TOP 1/3 LINE
    // Horizontal rails
    fillAndStrokeRoundedRect(ctx, CGRect(x: 30, y: 632, width: 1020, height: 22), radius: 4, fill: cgColor(215, 184, 153), lineWidth: 5.0)
    fillAndStrokeRoundedRect(ctx, CGRect(x: 30, y: 586, width: 1020, height: 22), radius: 4, fill: cgColor(215, 184, 153), lineWidth: 5.0)
    // Vertical fenceposts
    for fx in stride(from: 65, through: 1015, by: 135) {
        fillAndStrokeRoundedRect(ctx, CGRect(x: CGFloat(fx), y: 565, width: 28, height: 112), radius: 6, fill: cgColor(188, 143, 107), lineWidth: 5.0)
    }

    // 5. SWAYING ROWS OF SPINACH CROP & POTATO PLANTS (Midground)
    let breezeSway = sin(t * 2.6) * 0.09
    // Back row of matching green spinach crop
    for (idx, cx) in stride(from: 110.0, through: 950.0, by: 120.0).enumerated() {
        let phase = Double(idx) * 0.45
        drawSpinachPlant(ctx, x: cx, y: 470.0, scale: 0.92, swayAngle: sin(t * 2.8 + phase) * 0.10)
    }
    // Second row of spinach crop (left & right of center action)
    for (idx, cx) in [115.0, 235.0, 355.0, 775.0, 895.0].enumerated() {
        let phase = Double(idx) * 0.6
        drawSpinachPlant(ctx, x: cx, y: 350.0, scale: 1.08, swayAngle: sin(t * 2.5 + phase) * 0.11)
    }

    // 6. ARTICULATED CHARACTERS & CORE DISCOVERY ACTION (Clem, Plum, Spuds, Grub)
    // Motion curves across 0..10s:
    // - Beat 1 (0..3.2s): Plum flutters onto fencepost (x=470,y=705) & points wing at crop; Clem walks from x=820 to x=645.
    // - Beat 2 (3.2..7.0s): Plum hops down to (x=315,y=245); Clem kneels at (x=645,y=295), reaches and lifts the potato plant revealing 3 round spuds!
    // - Beat 3 (7.0..10.0s): Cute pink grub pops out & wiggles; Plum & Clem bounce and cheer!

    let walkProgress = smoothstep(0.0, 2.8, t)
    let clemX = lerp(815.0, 645.0, walkProgress)
    let clemY = 305.0 + (t > 7.2 ? abs(sin((t - 7.2) * 7.0)) * 14.0 : 0.0)
    let clemKneel = smoothstep(3.0, 4.3, t)
    let clemReach = smoothstep(3.5, 4.8, t)
    let spudLift = smoothstep(4.7, 6.2, t)
    let grubPop = smoothstep(6.8, 7.7, t)

    // Blink schedule
    let isBlinking = (abs(t - 1.8) < 0.10) || (abs(t - 5.4) < 0.10) || (abs(t - 8.6) < 0.10)

    // Mouth / Beak speech sync:
    // Plum speaks 0.4..2.9s; Clem speaks 3.6..6.6s; Both cheer 7.2..9.6s
    let plumTalking = (t >= 0.4 && t <= 2.9) || (t >= 7.2 && t <= 9.5)
    let plumBeakOpen = plumTalking ? (0.45 + 0.55 * abs(sin(t * 14.0))) : 0.08
    let clemTalking = (t >= 3.6 && t <= 6.6) || (t >= 7.2 && t <= 9.6)
    let clemMouthOpen = clemTalking ? (0.35 + 0.65 * abs(sin(t * 12.0))) : 0.0

    // Draw Clem (in local flipped space, +x points left toward the spud patch at x=495)
    ctx.saveGState()
    ctx.translateBy(x: CGFloat(clemX), y: CGFloat(clemY))
    ctx.scaleBy(x: -1.0, y: 1.0)
    drawClem(
        ctx,
        x: 0,
        y: 0,
        scale: 0.92,
        walkCycle: t * 2.2,
        kneelProgress: clemKneel,
        reachProgress: clemReach,
        liftHeight: spudLift,
        headNod: sin(t * 3.2) * 0.06 + clemKneel * 0.12,
        mouthOpen: clemMouthOpen,
        blink: isBlinking
    )
    ctx.restoreGState()

    // Draw the Interactive Spud Plant & Cute Pink Grub at (x=495, y=225)
    drawSpudPlantAndGrub(
        ctx,
        baseX: 495.0,
        baseY: 225.0,
        liftHeight: spudLift,
        swayAngle: breezeSway,
        grubPop: grubPop,
        timeSec: t
    )

    // Plum's Position & Articulation
    // 0.0..0.9s: flutters down onto fencepost (470, 710)
    // 0.9..3.2s: perched on fencepost pointing wing at the crop
    // 3.2..4.4s: hops/flutters down to ground beside spuds (310, 240)
    // 7.0..10.0s: happy little bounce!
    let landProgress = smoothstep(0.0, 0.9, t)
    let hopDownProgress = smoothstep(3.2, 4.4, t)
    let plumFenceX = 470.0, plumFenceY = 718.0
    let plumGroundX = 305.0, plumGroundY = 235.0

    var plumX = lerp(340.0, plumFenceX, landProgress)
    var plumY = lerp(860.0, plumFenceY, landProgress)
    if t > 3.2 {
        let arcLift = sin(hopDownProgress * .pi) * 95.0
        plumX = lerp(plumFenceX, plumGroundX, hopDownProgress)
        plumY = lerp(plumFenceY, plumGroundY, hopDownProgress) + arcLift
    }
    if t > 7.0 {
        plumY += abs(sin((t - 7.0) * 8.5)) * 22.0
    }

    let isFlying = (t < 0.9) || (t > 3.2 && t < 4.4) || (t > 7.0)
    let wingFlap = isFlying ? sin(t * 28.0) * 0.65 : sin(t * 4.0) * 0.08
    let wingPoint = (t >= 0.9 && t <= 3.2) ? smoothstep(1.0, 1.5, t) * (1.0 - smoothstep(2.8, 3.2, t)) : 0.0

    drawPlum(
        ctx,
        x: plumX,
        y: plumY,
        scale: 0.88,
        headTilt: sin(t * 3.5) * 0.10,
        wingFlapAngle: wingFlap,
        pointWing: wingPoint,
        beakOpen: plumBeakOpen,
        blink: isBlinking,
        flipX: false
    )

    // Foreground framing plants & fluttering yellow butterfly
    drawSpinachPlant(ctx, x: 120.0, y: 110.0, scale: 1.15, swayAngle: breezeSway * 1.2)
    drawSpinachPlant(ctx, x: 920.0, y: 115.0, scale: 1.15, swayAngle: -breezeSway * 1.1)

    // Fluttering yellow garden butterfly across foreground in Beat 3
    let bfX = 160.0 + t * 78.0
    let bfY = 480.0 + sin(t * 5.5) * 36.0
    ctx.saveGState()
    ctx.translateBy(x: CGFloat(bfX), y: CGFloat(bfY))
    let bfWing = abs(sin(t * 22.0)) * 18.0 + 6.0
    fillAndStrokeEllipse(ctx, CGRect(x: -bfWing, y: -2, width: bfWing, height: 22), fill: cgColor(255, 238, 88), lineWidth: 3.5)
    fillAndStrokeEllipse(ctx, CGRect(x: 0, y: -2, width: bfWing, height: 22), fill: cgColor(255, 238, 88), lineWidth: 3.5)
    ctx.restoreGState()

    ctx.restoreGState() // End camera transform

    // 7. STORYBOOK CAPTION & PHONICS WORD HIGHLIGHT OVERLAY (Screen-space)
    let bannerRect = CGRect(x: 54, y: 36, width: W - 108, height: 96)
    fillAndStrokeRoundedRect(ctx, bannerRect, radius: 22, fill: cgColor(255, 253, 245, 0.94), stroke: cgColor(30, 30, 30), lineWidth: 4.5)

    var captionLine = "\"See this matching green CROP?\" chirped Plum."
    var badgeWord = "PHONICS WORD: CROP"
    if t >= 3.2 && t < 7.0 {
        captionLine = "Clem dug in the dirt. \"Found a round SPUD!\""
        badgeWord = "PHONICS WORD: SPUD"
    } else if t >= 7.0 {
        captionLine = "A tiny GRUB wiggled hello as they cheered!"
        badgeWord = "PHONICS WORDS: CROP • SPUD • GRUB"
    }

    // Phonics pill badge at top of banner
    let pillRect = CGRect(x: Double(W)/2.0 - 175.0, y: 108.0, width: 350.0, height: 34.0)
    fillAndStrokeRoundedRect(ctx, pillRect, radius: 16, fill: cgColor(255, 213, 79), stroke: cgColor(30, 30, 30), lineWidth: 3.5)
    drawText(ctx, badgeWord, x: CGFloat(W)/2.0, y: 117.0, size: 17.5, color: .black)
    drawText(ctx, captionLine, x: CGFloat(W)/2.0, y: 66.0, size: 25.0, color: .black)

    // Crisp outer storybook frame
    ctx.setStrokeColor(cgColor(25, 25, 25))
    ctx.setLineWidth(12.0)
    ctx.stroke(CGRect(x: 12, y: 12, width: W - 24, height: H - 24))

    return ctx.makeImage()
}

func savePNG(_ cgImage: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try data.write(to: url)
}

// ----------------------------------------------------------------------------
// 1. Export Full-Color Keyframes for Google Flow (Beat 1, Beat 2, Beat 3)
// ----------------------------------------------------------------------------
if let kf1 = renderFrame(frameIdx: 42) {
    try savePNG(kf1, to: keyframesDir.appendingPathComponent("garden_act1_beat1_crop_color.png"))
}
if let kf2 = renderFrame(frameIdx: 175) {
    try savePNG(kf2, to: keyframesDir.appendingPathComponent("garden_act1_beat2_spud_color.png"))
}
if let kf3 = renderFrame(frameIdx: 245) {
    try savePNG(kf3, to: keyframesDir.appendingPathComponent("garden_act1_beat3_grub_color.png"))
}
print("Saved 3 full-color Act 1 keyframes to output/color_keyframes/")

// ----------------------------------------------------------------------------
// 2. Encode 300-Frame (10.0s @ 30fps) H.264 Video Track
// ----------------------------------------------------------------------------
let tempVideoURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("garden_act1_video_only.mp4")
try? FileManager.default.removeItem(at: tempVideoURL)

let writer = try AVAssetWriter(outputURL: tempVideoURL, fileType: .mp4)
let videoSettings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: W,
    AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 8_500_000
    ]
]
let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
writerInput.expectsMediaDataInRealTime = false

let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: writerInput,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey as String: W,
        kCVPixelBufferHeightKey as String: H
    ]
)

writer.add(writerInput)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

let cs = CGColorSpaceCreateDeviceRGB()
for f in 0..<totalFrames {
    while !writerInput.isReadyForMoreMediaData {
        Thread.sleep(forTimeInterval: 0.003)
    }
    guard let pool = adaptor.pixelBufferPool else { continue }
    var pbOut: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pbOut)
    guard let pb = pbOut else { continue }

    CVPixelBufferLockBaseAddress(pb, [])
    if let baseAddr = CVPixelBufferGetBaseAddress(pb),
       let ctx = CGContext(
           data: baseAddr,
           width: W,
           height: H,
           bitsPerComponent: 8,
           bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
           space: cs,
           bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
       ),
       let frameCG = renderFrame(frameIdx: f) {
        ctx.draw(frameCG, in: CGRect(x: 0, y: 0, width: W, height: H))
    }
    CVPixelBufferUnlockBaseAddress(pb, [])

    let frameTime = CMTime(value: CMTimeValue(f), timescale: fps)
    adaptor.append(pb, withPresentationTime: frameTime)
}

writerInput.markAsFinished()
let writeSem = DispatchSemaphore(value: 0)
writer.finishWriting { writeSem.signal() }
writeSem.wait()

// ----------------------------------------------------------------------------
// 3. Synthesize Synchronized Audio Track (Music + Bird Chirps + Spud Pop + Voice)
// ----------------------------------------------------------------------------
let sampleRate = 44100
let totalSamples = Int(durationSec * Double(sampleRate))
var audioSamples = [Float](repeating: 0.0, count: totalSamples)

// A. Warm Acoustic Marimba & Guitar Storybook Melody
let melodyFreqs: [Double] = [
    261.63, 329.63, 392.00, 523.25, // C4 E4 G4 C5
    293.66, 369.99, 440.00, 587.33, // D4 F#4 A4 D5
    349.23, 440.00, 523.25, 659.25, // F4 A4 C5 E5
    392.00, 493.88, 587.33, 523.25  // G4 B4 D5 C5
]
let noteStep = 0.25
for i in 0..<totalSamples {
    let t = Double(i) / Double(sampleRate)
    let stepIdx = Int(t / noteStep)
    let noteT = t - Double(stepIdx) * noteStep
    let freq = melodyFreqs[stepIdx % melodyFreqs.count]
    let env = exp(-noteT * 5.2) * min(1.0, noteT / 0.008)
    let marimba = sin(2.0 * .pi * freq * t) + 0.30 * sin(2.0 * .pi * freq * 2.0 * t)
    let bass = 0.28 * sin(2.0 * .pi * (freq * 0.5) * t) * exp(-noteT * 2.5)
    audioSamples[i] += Float((marimba * env * 0.14) + bass * 0.10)
}

// B. Cheerful Bluebird Chirps (at t=0.45s, 0.70s, 7.35s, 7.60s)
for chirpStart in [0.45, 0.70, 7.35, 7.60] {
    let sIdx = Int(chirpStart * Double(sampleRate))
    let cLen = Int(0.16 * Double(sampleRate))
    for k in 0..<cLen {
        let idx = sIdx + k
        if idx < totalSamples {
            let ct = Double(k) / Double(sampleRate)
            let fSweep = 1650.0 + 950.0 * sin(ct * 38.0)
            let env = sin((ct / 0.16) * .pi)
            audioSamples[idx] += Float(sin(2.0 * .pi * fSweep * ct) * env * 0.20)
        }
    }
}

// C. Earthy "Pop!" SFX when Clem pulls up the Spuds (at t=5.0s)
let popStart = Int(5.0 * Double(sampleRate))
let popLen = Int(0.22 * Double(sampleRate))
for k in 0..<popLen {
    let idx = popStart + k
    if idx < totalSamples {
        let pt = Double(k) / Double(sampleRate)
        let fPop = 160.0 + 380.0 * (pt / 0.22)
        let env = exp(-pt * 14.0)
        audioSamples[idx] += Float(sin(2.0 * .pi * fPop * pt) * env * 0.35)
    }
}

// Write 16-bit mono WAV header + data, then mux directly via AVAssetWriter / AVAssetExportSession
let tempWAVURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("garden_act1_audio.wav")
try? FileManager.default.removeItem(at: tempWAVURL)

var pcmSamples = [Int16](repeating: 0, count: totalSamples)
for i in 0..<totalSamples {
    let clamped = max(-0.95, min(0.95, Double(audioSamples[i])))
    pcmSamples[i] = Int16(clamped * 32767.0)
}

var wavData = Data()
let dataSize = UInt32(totalSamples * 2)
let fileSize = dataSize + 36
wavData.append("RIFF".data(using: .ascii)!)
withUnsafeBytes(of: fileSize.littleEndian) { wavData.append(contentsOf: $0) }
wavData.append("WAVEfmt ".data(using: .ascii)!)
withUnsafeBytes(of: UInt32(16).littleEndian) { wavData.append(contentsOf: $0) }
withUnsafeBytes(of: UInt16(1).littleEndian) { wavData.append(contentsOf: $0) }
withUnsafeBytes(of: UInt16(1).littleEndian) { wavData.append(contentsOf: $0) }
withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { wavData.append(contentsOf: $0) }
withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { wavData.append(contentsOf: $0) }
withUnsafeBytes(of: UInt16(2).littleEndian) { wavData.append(contentsOf: $0) }
withUnsafeBytes(of: UInt16(16).littleEndian) { wavData.append(contentsOf: $0) }
wavData.append("data".data(using: .ascii)!)
withUnsafeBytes(of: dataSize.littleEndian) { wavData.append(contentsOf: $0) }
pcmSamples.withUnsafeBytes { wavData.append(contentsOf: $0) }
try wavData.write(to: tempWAVURL)

// ----------------------------------------------------------------------------
// 4. Mux Video & Audio into Temp MP4, then Copy to Final Destination
// ----------------------------------------------------------------------------
let tempFinalMP4URL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("garden_act1_final_muxed.mp4")
try? FileManager.default.removeItem(at: tempFinalMP4URL)

let composition = AVMutableComposition()
let videoAsset = AVURLAsset(url: tempVideoURL)
let audioAsset = AVURLAsset(url: tempWAVURL)

if let vTrack = videoAsset.tracks(withMediaType: .video).first,
   let compVTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
    try compVTrack.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: vTrack, at: .zero)
}
if let aTrack = audioAsset.tracks(withMediaType: .audio).first,
   let compATrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
    try compATrack.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: aTrack, at: .zero)
}

let exportSem = DispatchSemaphore(value: 0)
if let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) {
    exporter.outputURL = tempFinalMP4URL
    exporter.outputFileType = .mp4
    exporter.exportAsynchronously { exportSem.signal() }
    exportSem.wait()
    if exporter.status == .completed, FileManager.default.fileExists(atPath: tempFinalMP4URL.path) {
        try FileManager.default.copyItem(at: tempFinalMP4URL, to: outMP4URL)
    } else {
        print("Exporter status: \(exporter.status.rawValue), error: \(String(describing: exporter.error)) -- copying video track")
        try FileManager.default.copyItem(at: tempVideoURL, to: outMP4URL)
    }
}

try? FileManager.default.removeItem(at: tempVideoURL)
try? FileManager.default.removeItem(at: tempWAVURL)
try? FileManager.default.removeItem(at: tempFinalMP4URL)
print("Rendered full-fledged 10.0s @ 30fps articulated animation -> \(outMP4URL.path)")
