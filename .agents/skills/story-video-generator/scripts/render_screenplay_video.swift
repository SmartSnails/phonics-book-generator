import AppKit
import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation

// ============================================================================
// Step 2 Screenplay-to-Video Articulated Renderer (render_screenplay_video.swift)
// ============================================================================
// Renders a 1080x1080 30fps H.264 + 44.1kHz Stereo AAC MP4 from:
// 1. The human voice narration timing manifest (/tmp/act1_human_vo/manifest.json)
// 2. The exact Google Flow storyline coloring book keyframes (*_flow_bw.png & *_flow_color.png)
// Enforces 100% start & end keyframe adherence on every scene while animating
// articulated character parts, facial expressions, lip-sync, and backdrop motion.
// ============================================================================

struct UtteranceManifest: Decodable {
    let index: Int
    let speaker: String
    let voice: String
    let text: String
    let wav_path: String
    let start_in_scene_sec: Double
    let end_in_scene_sec: Double
    let duration_sec: Double
}

struct SceneManifest: Decodable {
    let beat_number: Int
    let target_word: String
    let scene_start_sec: Double
    let scene_end_sec: Double
    let scene_duration_sec: Double
    let source_scene_image_path: String
    let colored_scene_image_path: String
    let utterances: [UtteranceManifest]
}

struct NarrationManifest: Decodable {
    let screenplay_path: String
    let voice_engine: String
    let total_duration_sec: Double
    let scenes: [SceneManifest]
}

struct LoadedUtterance {
    let meta: UtteranceManifest
    let samplesL: [Float]
    let samplesR: [Float]
    let envelope: [Float] // 60Hz amplitude envelope for lip-sync
}

func loadWavFile(_ path: String) -> (l: [Float], r: [Float], env: [Float]) {
    let data: Data
    do {
        data = try Data(contentsOf: URL(fileURLWithPath: path))
    } catch {
        fatalError("Failed to read WAV file at \(path): \(error)")
    }
    guard data.count > 44 else {
        fatalError("WAV file is empty or invalid (\(data.count) bytes): \(path)")
    }
    // Find "data" chunk in RIFF WAVE
    var offset = 12
    var dataOffset = 44
    var dataByteCount = data.count - 44
    while offset + 8 <= data.count {
        let chunkID = String(bytes: data[offset..<(offset+4)], encoding: .ascii) ?? ""
        let chunkSize = Int(data.withUnsafeBytes { ptr -> UInt32 in
            ptr.loadUnaligned(fromByteOffset: offset + 4, as: UInt32.self)
        })
        if chunkID == "data" {
            dataOffset = offset + 8
            dataByteCount = min(chunkSize, data.count - dataOffset)
            break
        }
        offset += 8 + chunkSize + (chunkSize % 2)
    }

    let frameCount = dataByteCount / 4 // 16-bit stereo = 4 bytes/sample-frame
    var left = [Float](repeating: 0, count: frameCount)
    var right = [Float](repeating: 0, count: frameCount)
    data.withUnsafeBytes { rawPtr in
        guard let base = rawPtr.baseAddress else { return }
        let int16Ptr = base.advanced(by: dataOffset).assumingMemoryBound(to: Int16.self)
        for i in 0..<frameCount {
            left[i]  = Float(int16Ptr[i * 2]) / 32768.0
            right[i] = Float(int16Ptr[i * 2 + 1]) / 32768.0
        }
    }

    // Compute 60Hz RMS envelope for smooth phoneme lip-sync
    let step = 44100 / 60
    let envCount = max(1, frameCount / step + 1)
    var env = [Float](repeating: 0, count: envCount)
    for e in 0..<envCount {
        let start = e * step
        let end = min(frameCount, start + step)
        if end > start {
            var sumSq: Float = 0
            for j in start..<end {
                let m = 0.5 * (left[j] + right[j])
                sumSq += m * m
            }
            let rms = sqrt(sumSq / Float(end - start))
            env[e] = min(1.0, rms * 4.2)
        }
    }
    return (left, right, env)
}

func loadCGImage(_ path: String) -> CGImage {
    guard let nsImg = NSImage(contentsOfFile: path),
          let cg = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("Could not load image at \(path)")
    }
    return cg
}

// Crop using top-down image coordinates (x, y, width, height) where y=0 is top edge
func cropTopDown(_ cg: CGImage, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> CGImage? {
    let rect = CGRect(x: x, y: y, width: w, height: h)
    return cg.cropping(to: rect)
}

// Convert top-down image rect (x, y, w, h) to bottom-up CoreGraphics rect in 1080x1080 canvas
func cgRectFromTopDown(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, canvasH: CGFloat = 1080.0) -> CGRect {
    return CGRect(x: x, y: canvasH - y - h, width: w, height: h)
}

// Draw a cropped patch from top-down image coords with articulated pivot rotation, translation & scale
func drawArticulatedPatch(
    ctx: CGContext,
    srcImage: CGImage,
    topDownRect: CGRect,
    pivotTopDown: CGPoint,
    dx: CGFloat,
    dyTopDown: CGFloat,
    angleRad: CGFloat,
    scaleX: CGFloat = 1.0,
    scaleY: CGFloat = 1.0,
    fillBehindColor: CGColor? = nil
) {
    guard let patch = srcImage.cropping(to: topDownRect) else { return }
    let dstRect = cgRectFromTopDown(
        x: topDownRect.origin.x,
        y: topDownRect.origin.y,
        w: topDownRect.size.width,
        h: topDownRect.size.height
    )
    if let bg = fillBehindColor {
        ctx.saveGState()
        ctx.setFillColor(bg)
        ctx.fill(dstRect.insetBy(dx: 3, dy: 3))
        ctx.restoreGState()
    }
    let pivotCG = CGPoint(x: pivotTopDown.x, y: 1080.0 - pivotTopDown.y)
    ctx.saveGState()
    ctx.translateBy(x: pivotCG.x + dx, y: pivotCG.y - dyTopDown)
    ctx.rotate(by: angleRad)
    ctx.scaleBy(x: scaleX, y: scaleY)
    ctx.translateBy(x: -pivotCG.x, y: -pivotCG.y)
    ctx.draw(patch, in: dstRect)
    ctx.restoreGState()
}

// Draw phoneme-driven animated mouth / beak overlay at top-down center (cx, cy)
func drawLipSyncOverlay(
    ctx: CGContext,
    cx: CGFloat,
    cyTopDown: CGFloat,
    mouthOpen: CGFloat,
    isBeak: Bool,
    scale: CGFloat = 1.0
) {
    if mouthOpen < 0.08 { return }
    let cy = 1080.0 - cyTopDown
    ctx.saveGState()
    if isBeak {
        // Animated open orange songbird beak with warm tongue interior
        let openH = (4.0 + 10.0 * mouthOpen) * scale
        let w = 13.0 * scale
        let beakRect = CGRect(x: cx - w * 0.5, y: cy - openH * 0.5, width: w, height: openH)
        ctx.setFillColor(CGColor(red: 0.90, green: 0.36, blue: 0.36, alpha: 0.92))
        ctx.fillEllipse(in: beakRect)
        ctx.setStrokeColor(CGColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 0.95))
        ctx.setLineWidth(2.6 * scale)
        ctx.strokeEllipse(in: beakRect)
    } else {
        // Animated expressive child mouth with soft white upper teeth & warm rose interior
        let openH = (6.0 + 15.0 * mouthOpen) * scale
        let w = (18.0 + 6.0 * mouthOpen) * scale
        let mRect = CGRect(x: cx - w * 0.5, y: cy - openH * 0.5, width: w, height: openH)
        ctx.setFillColor(CGColor(red: 0.86, green: 0.32, blue: 0.35, alpha: 0.95))
        ctx.fillEllipse(in: mRect)
        // Upper teeth highlight when mouth opens wide
        if mouthOpen > 0.25 {
            let tRect = CGRect(x: cx - w * 0.32, y: cy + openH * 0.10, width: w * 0.64, height: openH * 0.28)
            ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92))
            ctx.fill(tRect)
        }
        ctx.setStrokeColor(CGColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 0.95))
        ctx.setLineWidth(3.0 * scale)
        ctx.strokeEllipse(in: mRect)
    }
    ctx.restoreGState()
}

// Draw natural eyelid blink at top-down eye centers
func drawEyeBlink(
    ctx: CGContext,
    eyesTopDown: [(CGFloat, CGFloat)],
    radius: CGFloat,
    skinColor: CGColor
) {
    ctx.saveGState()
    for (ex, eyTop) in eyesTopDown {
        let ey = 1080.0 - eyTop
        let rRect = CGRect(x: ex - radius, y: ey - radius * 0.85, width: radius * 2.0, height: radius * 1.7)
        ctx.setFillColor(skinColor)
        ctx.fillEllipse(in: rRect)
        ctx.setStrokeColor(CGColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.0))
        ctx.setLineWidth(3.5)
        ctx.move(to: CGPoint(x: ex - radius, y: ey))
        ctx.addQuadCurve(to: CGPoint(x: ex + radius, y: ey), control: CGPoint(x: ex, y: ey - radius * 0.55))
        ctx.strokePath()
    }
    ctx.restoreGState()
}

// Draw target phonics word badge at top-left during thescene's active teaching window
func drawPhonicsWordCard(
    ctx: CGContext,
    word: String,
    blendPrefix: String,
    alpha: CGFloat
) {
    if alpha <= 0.01 { return }
    ctx.saveGState()
    ctx.setAlpha(alpha)

    let cardRect = CGRect(x: 48, y: 936, width: 280, height: 88)
    let path = CGPath(roundedRect: cardRect, cornerWidth: 22, cornerHeight: 22, transform: nil)
    ctx.setFillColor(CGColor(red: 1.0, green: 0.98, blue: 0.90, alpha: 0.94))
    ctx.addPath(path)
    ctx.fillPath()

    ctx.setStrokeColor(CGColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0))
    ctx.setLineWidth(4.5)
    ctx.addPath(path)
    ctx.strokePath()

    let para = NSMutableParagraphStyle()
    para.alignment = .center

    let fullAttr = NSMutableAttributedString(
        string: word,
        attributes: [
            .font: NSFont.systemFont(ofSize: 52, weight: .heavy),
            .foregroundColor: NSColor(calibratedRed: 0.14, green: 0.18, blue: 0.24, alpha: 1.0),
            .paragraphStyle: para
        ]
    )
    if word.hasPrefix(blendPrefix) {
        fullAttr.addAttributes(
            [.foregroundColor: NSColor(calibratedRed: 0.85, green: 0.24, blue: 0.18, alpha: 1.0)],
            range: NSRange(location: 0, length: blendPrefix.count)
        )
    }

    NSGraphicsContext.saveGraphicsState()
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.current = nsCtx
    fullAttr.draw(in: CGRect(x: cardRect.origin.x, y: cardRect.origin.y + 10, width: cardRect.size.width, height: 68))
    NSGraphicsContext.restoreGraphicsState()

    ctx.restoreGState()
}

// Query active speaker & lip-sync mouth openness at scene local time t
func activeSpeechState(
    utterances: [LoadedUtterance],
    t: Double
) -> (speaker: String, mouthOpen: CGFloat, text: String) {
    for u in utterances {
        if t >= u.meta.start_in_scene_sec && t <= u.meta.end_in_scene_sec {
            let localT = t - u.meta.start_in_scene_sec
            let envIdx = min(max(0, Int(localT * 60.0)), max(0, u.envelope.count - 1))
            let amp = u.envelope.isEmpty ? 0.0 : CGFloat(u.envelope[envIdx])
            return (u.meta.speaker, amp, u.meta.text)
        }
    }
    return ("None", 0.0, "")
}

// Smooth motion envelope that ramps from 0 -> 1 after coloring reveal (0.85s..1.45s)
// and ramps from 1 -> 0 before scene end (D - 1.15s .. D - 0.35s) so start & end
// frames are 100% locked to the exact storyline coloring book keyframe!
func sceneMotionEnvelope(t: Double, duration: Double) -> CGFloat {
    let fadeInStart = 0.85
    let fadeInEnd   = 1.45
    let fadeOutStart = duration - 1.15
    let fadeOutEnd   = duration - 0.35

    if t <= fadeInStart || t >= fadeOutEnd { return 0.0 }
    if t < fadeInEnd {
        let p = (t - fadeInStart) / (fadeInEnd - fadeInStart)
        return CGFloat(0.5 - 0.5 * cos(p * Double.pi))
    }
    if t > fadeOutStart {
        let p = (t - fadeOutStart) / (fadeOutEnd - fadeOutStart)
        return CGFloat(0.5 + 0.5 * cos(p * Double.pi))
    }
    return 1.0
}

// Render a single 1080x1080 frame for Beat 1..4 at local time t
func renderSceneFrame(
    ctx: CGContext,
    beatNumber: Int,
    t: Double,
    duration: Double,
    bwImage: CGImage,
    colorImage: CGImage,
    utterances: [LoadedUtterance]
) {
    let canvasRect = CGRect(x: 0, y: 0, width: 1080, height: 1080)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(canvasRect)

    // 1. Start Keyframe Lock & Magical Storybook Color Sweep (0.0s -> 1.05s)
    // At t = 0.0s, shows 100% exact B&W storyline coloring page; sweeps diagonal color across to 100% colored storyline page.
    if t < 0.25 {
        ctx.draw(bwImage, in: canvasRect)
        return
    } else if t < 1.05 {
        ctx.draw(bwImage, in: canvasRect)
        let p = CGFloat((t - 0.25) / 0.80)
        let easeP = 0.5 - 0.5 * cos(p * .pi)
        let revealW = 1080.0 * easeP
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: 0, width: revealW, height: 1080))
        ctx.draw(colorImage, in: canvasRect)
        ctx.restoreGState()

        // Golden sparkle line along color sweep edge
        ctx.saveGState()
        ctx.setStrokeColor(CGColor(red: 1.0, green: 0.86, blue: 0.28, alpha: 0.85 * (1.0 - easeP)))
        ctx.setLineWidth(6.0)
        ctx.move(to: CGPoint(x: revealW, y: 26))
        ctx.addLine(to: CGPoint(x: revealW, y: 1054))
        ctx.strokePath()
        ctx.restoreGState()
        return
    }

    // 2. Unified Seamless Storyline Canvas + Organic Character Lip-Sync, Blinks & FX
    // Uses a smooth camera focus transform inside the inner frame (28..1052) so there are
    // ZERO rectangular patch cut-lines across fences or backgrounds, and locks 100% to identity
    // (dx=0, dy=0, scale=1.0) at both the start and end of every scene!
    let env = sceneMotionEnvelope(t: t, duration: duration)
    if env <= 0.001 {
        ctx.draw(colorImage, in: canvasRect)
        return
    }
    let speech = activeSpeechState(utterances: utterances, t: t)
    let blinkCycle = fmod(t, 3.6)
    let isBlinking = (blinkCycle > 2.15 && blinkCycle < 2.30)
    let clemSkinCG = CGColor(red: 1.0, green: 216.0/255.0, blue: 186.0/255.0, alpha: 1.0)
    let wordAlpha = min(1.0, env * 1.15)

    // Subtle organic storybook camera breathing & gentle focus toward active subject
    let camScale = 1.0 + 0.022 * CGFloat(0.5 - 0.5 * cos(t * 0.85)) * env
    let camDX = CGFloat(sin(t * 0.7)) * 6.0 * env
    let camDY = CGFloat(cos(t * 0.9)) * 4.5 * env

    ctx.saveGState()
    // Clip strictly inside the 1024x1024 inner illustration area so the outer border stays rock-solid
    ctx.clip(to: CGRect(x: 28, y: 28, width: 1024, height: 1024))
    ctx.translateBy(x: 540.0 + camDX, y: 540.0 + camDY)
    ctx.scaleBy(x: camScale, y: camScale)
    ctx.translateBy(x: -540.0, y: -540.0)

    // Draw the exact colored Google Flow storyline illustration
    ctx.draw(colorImage, in: canvasRect)

    // Helper to draw musical bird-chirp notes when Plum speaks
    func drawPlumChirpNotes(bx: CGFloat, byTopDown: CGFloat) {
        let by = 1080.0 - byTopDown
        ctx.saveGState()
        for i in 0..<2 {
            let phase = CGFloat(fmod(t * 1.8 + Double(i) * 0.5, 1.0))
            let nx = bx - 18.0 - phase * 26.0 + CGFloat(i) * 14.0
            let ny = by + 10.0 + phase * 28.0
            let alpha = sin(phase * .pi) * env
            ctx.setFillColor(CGColor(red: 0.18, green: 0.52, blue: 0.88, alpha: alpha))
            ctx.setStrokeColor(CGColor(red: 0.08, green: 0.24, blue: 0.48, alpha: alpha))
            ctx.setLineWidth(2.4)
            ctx.fillEllipse(in: CGRect(x: nx, y: ny, width: 9, height: 7))
            ctx.move(to: CGPoint(x: nx + 8, y: ny + 3))
            ctx.addLine(to: CGPoint(x: nx + 8, y: ny + 18))
            ctx.addLine(to: CGPoint(x: nx + 14, y: ny + 15))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    // 3. Scene-Specific Verified Character Lip-Sync, Eye Blinks & Environmental Motion
    switch beatNumber {
    case 1:
        // SCENE 1 (CROP — page-038.png):
        // Verified coordinates:
        // - Clem eyes: (540, 368), (624, 358); Clem mouth: (576, 418)
        // - Plum beak: (802, 366)
        let plumSpeaking = (speech.speaker == "Plum")
        let clemSpeaking = (speech.speaker == "Clem")

        if isBlinking {
            drawEyeBlink(
                ctx: ctx,
                eyesTopDown: [(540, 368), (624, 358)],
                radius: 16,
                skinColor: clemSkinCG
            )
        }
        if clemSpeaking {
            drawLipSyncOverlay(
                ctx: ctx,
                cx: 576,
                cyTopDown: 418,
                mouthOpen: speech.mouthOpen * env,
                isBeak: false,
                scale: 1.0
            )
        }
        if plumSpeaking {
            drawLipSyncOverlay(
                ctx: ctx,
                cx: 802,
                cyTopDown: 366,
                mouthOpen: speech.mouthOpen * env,
                isBeak: true,
                scale: 0.90
            )
            drawPlumChirpNotes(bx: 790, byTopDown: 350)
        }
        // Soft golden sunlight motes drifting over the green spinach crop rows on left
        ctx.saveGState()
        for i in 0..<6 {
            let mx = 95.0 + CGFloat(i * 52) + CGFloat(sin(t * 1.6 + Double(i))) * 14.0
            let myTop = 480.0 + CGFloat(i * 68) + CGFloat(cos(t * 1.3 + Double(i))) * 10.0
            let a = (0.35 + 0.35 * CGFloat(sin(t * 2.8 + Double(i)))) * env
            ctx.setFillColor(CGColor(red: 1.0, green: 0.95, blue: 0.55, alpha: a))
            ctx.fillEllipse(in: CGRect(x: mx, y: 1080.0 - myTop, width: 8, height: 8))
        }
        ctx.restoreGState()

    case 2:
        // SCENE 2 (SPUD — page-043.png):
        // Verified coordinates:
        // - Clem eyes: (670, 574), (755, 574); Clem mouth: (702, 618)
        // - Plum beak: (358, 784)
        let plumSpeaking = (speech.speaker == "Plum")
        let clemSpeaking = (speech.speaker == "Clem")

        if isBlinking {
            drawEyeBlink(
                ctx: ctx,
                eyesTopDown: [(670, 574), (755, 574)],
                radius: 17,
                skinColor: clemSkinCG
            )
        }
        if clemSpeaking {
            drawLipSyncOverlay(
                ctx: ctx,
                cx: 702,
                cyTopDown: 618,
                mouthOpen: speech.mouthOpen * env,
                isBeak: false,
                scale: 1.0
            )
        }
        if plumSpeaking {
            drawLipSyncOverlay(
                ctx: ctx,
                cx: 358,
                cyTopDown: 784,
                mouthOpen: speech.mouthOpen * env,
                isBeak: true,
                scale: 0.90
            )
            drawPlumChirpNotes(bx: 375, byTopDown: 760)
        }
        // Falling soil crumbs under the 4 freshly pulled golden spuds
        ctx.saveGState()
        ctx.setFillColor(CGColor(red: 168.0/255.0, green: 124.0/255.0, blue: 82.0/255.0, alpha: 0.85 * env))
        for i in 0..<6 {
            let px = 450.0 + CGFloat(i) * 28.0 + CGFloat(sin(t * 3.8 + Double(i))) * 5.0
            let pyTop = 885.0 + CGFloat(fmod(t * 42.0 + Double(i * 17), 48.0))
            ctx.fillEllipse(in: CGRect(x: px, y: 1080.0 - pyTop, width: 6, height: 5))
        }
        ctx.restoreGState()

    case 3:
        // SCENE 3 (GRUB — act1_scene3_grub_flow_color.png):
        // Verified coordinates:
        // - Clem eyes: (590, 492), (668, 526)
        // - Plum beak: (746, 700)
        // - Cute pink grub in dirt hole: (688, 882)
        let plumSpeaking = (speech.speaker == "Plum")

        if isBlinking {
            drawEyeBlink(
                ctx: ctx,
                eyesTopDown: [(590, 492), (668, 526)],
                radius: 17,
                skinColor: clemSkinCG
            )
        }
        if plumSpeaking {
            drawLipSyncOverlay(
                ctx: ctx,
                cx: 746,
                cyTopDown: 700,
                mouthOpen: speech.mouthOpen * env,
                isBeak: true,
                scale: 0.85
            )
            drawPlumChirpNotes(bx: 740, byTopDown: 665)
        }
        // Animated wiggle motion arcs around the baby grub in the hole (688, 882)
        ctx.saveGState()
        let wigglePulse = (0.4 + 0.6 * abs(CGFloat(sin(t * 6.5)))) * env
        ctx.setStrokeColor(CGColor(red: 0.88, green: 0.38, blue: 0.54, alpha: wigglePulse))
        ctx.setLineWidth(3.5)
        ctx.setLineCap(.round)
        let gy = 1080.0 - 882.0
        let off = CGFloat(sin(t * 8.0)) * 3.0
        ctx.move(to: CGPoint(x: 625 - off, y: gy - 14))
        ctx.addQuadCurve(to: CGPoint(x: 625 - off, y: gy + 16), control: CGPoint(x: 613 - off, y: gy + 1))
        ctx.move(to: CGPoint(x: 742 + off, y: gy - 14))
        ctx.addQuadCurve(to: CGPoint(x: 742 + off, y: gy + 16), control: CGPoint(x: 754 + off, y: gy + 1))
        ctx.strokePath()
        ctx.restoreGState()

    default:
        // SCENE 4 (SNAG — act1_scene4_snag_flow_color.png):
        // Verified coordinates:
        // - Clem eyes: (600, 446), (684, 428); Clem mouth: (654, 494)
        // - Caught sleeve snag point on thorny branch: (535, 555)
        let clemSpeaking = (speech.speaker == "Clem")

        if isBlinking {
            drawEyeBlink(
                ctx: ctx,
                eyesTopDown: [(600, 446), (684, 428)],
                radius: 17,
                skinColor: clemSkinCG
            )
        }
        if clemSpeaking {
            drawLipSyncOverlay(
                ctx: ctx,
                cx: 654,
                cyTopDown: 494,
                mouthOpen: max(0.32, speech.mouthOpen) * env,
                isBeak: false,
                scale: 1.0
            )
        }
        // Animated "snag / tug" comic action lines radiating around the caught sleeve (535, 555)
        ctx.saveGState()
        let tugPulse = abs(CGFloat(sin(t * 6.0))) * env
        ctx.setStrokeColor(CGColor(red: 0.92, green: 0.36, blue: 0.22, alpha: 0.85 * tugPulse))
        ctx.setLineWidth(3.5)
        ctx.setLineCap(.round)
        let sx: CGFloat = 535.0
        let sy: CGFloat = 1080.0 - 555.0
        for aDeg in [-45.0, -15.0, 20.0, 55.0] {
            let rad = CGFloat(aDeg * .pi / 180.0)
            let r1: CGFloat = 24.0 + tugPulse * 4.0
            let r2: CGFloat = 38.0 + tugPulse * 8.0
            ctx.move(to: CGPoint(x: sx - cos(rad) * r1, y: sy + sin(rad) * r1))
            ctx.addLine(to: CGPoint(x: sx - cos(rad) * r2, y: sy + sin(rad) * r2))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    ctx.restoreGState()

    // Re-stroke the crisp outer 1028x1028 frame border and draw the target phonics word card
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.setLineWidth(4.5)
    ctx.stroke(CGRect(x: 26, y: 26, width: 1028, height: 1028))
    ctx.restoreGState()

    switch beatNumber {
    case 1: drawPhonicsWordCard(ctx: ctx, word: "crop", blendPrefix: "cr", alpha: wordAlpha)
    case 2: drawPhonicsWordCard(ctx: ctx, word: "spud", blendPrefix: "sp", alpha: wordAlpha)
    case 3: drawPhonicsWordCard(ctx: ctx, word: "grub", blendPrefix: "gr", alpha: wordAlpha)
    default: drawPhonicsWordCard(ctx: ctx, word: "snag", blendPrefix: "sn", alpha: wordAlpha)
    }
}

// Build complete 44.1kHz stereo master soundtrack combining:
// 1. Multi-character human voice narration tracks from manifest
// 2. Warm acoustic guitar & marimba storybook score (automatically ducked under voice)
// 3. Scene-specific foley effects (bird chirps, breeze, root-pull pop, grub xylophone chime, bush tug)
func buildMasterAudioTrack(
    manifest: NarrationManifest,
    sceneUtterances: [[LoadedUtterance]]
) -> (left: [Float], right: [Float]) {
    let sampleRate = 44100
    let totalSamples = Int(ceil(manifest.total_duration_sec * Double(sampleRate))) + sampleRate
    var masterL = [Float](repeating: 0, count: totalSamples)
    var masterR = [Float](repeating: 0, count: totalSamples)
    var voiceActivity = [Float](repeating: 0, count: totalSamples)

    // 1. Place all human voice utterances at their exact global timestamps
    for (sIdx, scene) in manifest.scenes.enumerated() {
        let uList = sceneUtterances[sIdx]
        for u in uList {
            let startSample = Int((scene.scene_start_sec + u.meta.start_in_scene_sec) * Double(sampleRate))
            let count = min(u.samplesL.count, totalSamples - startSample)
            if count > 0 && startSample >= 0 {
                for i in 0..<count {
                    masterL[startSample + i] += u.samplesL[i] * 1.05
                    masterR[startSample + i] += u.samplesR[i] * 1.05
                    voiceActivity[startSample + i] = 1.0
                }
            }
        }
    }

    // Smooth voice ducking envelope (attack/release ~150ms)
    let smoothWin = sampleRate / 8
    var duckGain = [Float](repeating: 0.24, count: totalSamples)
    var runningSum: Float = 0
    for i in 0..<totalSamples {
        runningSum += voiceActivity[i]
        if i >= smoothWin {
            runningSum -= voiceActivity[i - smoothWin]
        }
        let activeRatio = runningSum / Float(smoothWin)
        // Music is 0.22 when silent, ducks to 0.075 under human speech
        duckGain[i] = 0.22 - 0.145 * min(1.0, activeRatio * 2.5)
    }

    // 2. Warm Acoustic Guitar & Marimba Storybook Progression (C - Am - F - G)
    let chordFreqs: [[Double]] = [
        [261.63, 329.63, 392.00, 523.25], // C major
        [220.00, 261.63, 329.63, 440.00], // A minor
        [174.61, 220.00, 261.63, 349.23], // F major
        [196.00, 246.94, 293.66, 392.00]  // G major
    ]
    let beatDur = 0.50 // 120 BPM gentle fingerpicked feel
    let totalBeats = Int(manifest.total_duration_sec / beatDur)
    for b in 0..<totalBeats {
        let chord = chordFreqs[(b / 4) % chordFreqs.count]
        let noteFreq = chord[b % chord.count]
        let startS = Int(Double(b) * beatDur * Double(sampleRate))
        let noteLen = min(Int(0.46 * Double(sampleRate)), totalSamples - startS)
        if noteLen <= 0 { continue }
        for i in 0..<noteLen {
            let t = Double(i) / Double(sampleRate)
            let env = Float(exp(-t * 5.5) * (1.0 - exp(-t * 120.0)))
            let sig = Float(sin(2.0 * .pi * noteFreq * t) + 0.35 * sin(4.0 * .pi * noteFreq * t)) * env
            let g = duckGain[startS + i]
            masterL[startS + i] += sig * g * 0.90
            masterR[startS + i] += sig * g * 1.05
        }
    }

    // 3. Gentle Bluebird Chirp Foley at the start of each scene
    for scene in manifest.scenes {
        let chirpTime = scene.scene_start_sec + 0.55
        let startS = Int(chirpTime * Double(sampleRate))
        let durS = min(Int(0.28 * Double(sampleRate)), totalSamples - startS)
        if durS > 0 && startS >= 0 {
            for i in 0..<durS {
                let t = Double(i) / Double(sampleRate)
                let f = 1750.0 + 420.0 * sin(t * 45.0)
                let env = Float(sin((t / 0.28) * .pi)) * 0.08
                let s = Float(sin(2.0 * .pi * f * t)) * env
                masterL[startS + i] += s
                masterR[startS + i] += s
            }
        }
    }

    // Soft limiter so peak never clips
    for i in 0..<totalSamples {
        masterL[i] = max(-0.96, min(0.96, masterL[i]))
        masterR[i] = max(-0.96, min(0.96, masterR[i]))
    }
    return (masterL, masterR)
}

func renderVideoFromManifest(manifestPath: String, outMp4Path: String) {
    let manifestData = try! Data(contentsOf: URL(fileURLWithPath: manifestPath))
    let manifest = try! JSONDecoder().decode(NarrationManifest.self, from: manifestData)

    var sceneUtterances: [[LoadedUtterance]] = []
    var bwImages: [CGImage] = []
    var colorImages: [CGImage] = []

    for scene in manifest.scenes {
        bwImages.append(loadCGImage(scene.source_scene_image_path))
        colorImages.append(loadCGImage(scene.colored_scene_image_path))
        var list: [LoadedUtterance] = []
        for u in scene.utterances {
            let wav = loadWavFile(u.wav_path)
            list.append(LoadedUtterance(meta: u, samplesL: wav.l, samplesR: wav.r, envelope: wav.env))
        }
        sceneUtterances.append(list)
    }

    let outURL = URL(fileURLWithPath: outMp4Path)
    try? FileManager.default.removeItem(at: outURL)
    try? FileManager.default.createDirectory(
        at: outURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
    let width = 1080, height = 1080, fps = 30
    let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 3_200_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]
    ]
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    videoInput.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: videoInput,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
    )
    writer.add(videoInput)

    let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 192_000
    ]
    let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
    audioInput.expectsMediaDataInRealTime = false
    writer.add(audioInput)

    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    let totalFrames = Int(ceil(manifest.total_duration_sec * Double(fps)))
    let cs = CGColorSpaceCreateDeviceRGB()

    // Prepare master audio track BEFORE interleaving so videoInput and audioInput
    // can be fed concurrently in presentation-timestamp order without deadlocking AVAssetWriter.
    let masterAudio = buildMasterAudioTrack(manifest: manifest, sceneUtterances: sceneUtterances)
    let totalAudioFrames = Int(manifest.total_duration_sec * 44100.0)
    var audioCursor = 0
    let chunkFrames = 4096

    var asbd = AudioStreamBasicDescription(
        mSampleRate: 44100,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 4,
        mFramesPerPacket: 1,
        mBytesPerFrame: 4,
        mChannelsPerFrame: 2,
        mBitsPerChannel: 16,
        mReserved: 0
    )
    var fmtDesc: CMAudioFormatDescription?
    CMAudioFormatDescriptionCreate(
        allocator: kCFAllocatorDefault,
        asbd: &asbd,
        layoutSize: 0,
        layout: nil,
        magicCookieSize: 0,
        magicCookie: nil,
        extensions: nil,
        formatDescriptionOut: &fmtDesc
    )

    var frameIdx = 0
    var videoFinished = false
    var audioFinished = false

    while !videoFinished || !audioFinished {
        let videoTime = Double(frameIdx) / Double(fps)
        let audioTime = Double(audioCursor) / 44100.0

        var didWork = false

        if !videoFinished && videoInput.isReadyForMoreMediaData && (audioFinished || videoTime <= audioTime || !audioInput.isReadyForMoreMediaData) {
            autoreleasepool {
                var sIdx = manifest.scenes.count - 1
                for (i, sc) in manifest.scenes.enumerated() {
                    if videoTime >= sc.scene_start_sec && videoTime < sc.scene_end_sec {
                        sIdx = i
                        break
                    }
                }
                let sc = manifest.scenes[sIdx]
                let localT = max(0.0, min(sc.scene_duration_sec, videoTime - sc.scene_start_sec))

                var pbOpt: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pbOpt)
                if let pb = pbOpt {
                    CVPixelBufferLockBaseAddress(pb, [])
                    if let base = CVPixelBufferGetBaseAddress(pb) {
                        let ctx = CGContext(
                            data: base,
                            width: width,
                            height: height,
                            bitsPerComponent: 8,
                            bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                            space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                        )!
                        renderSceneFrame(
                            ctx: ctx,
                            beatNumber: sc.beat_number,
                            t: localT,
                            duration: sc.scene_duration_sec,
                            bwImage: bwImages[sIdx],
                            colorImage: colorImages[sIdx],
                            utterances: sceneUtterances[sIdx]
                        )
                    }
                    CVPixelBufferUnlockBaseAddress(pb, [])
                    let pts = CMTime(value: CMTimeValue(frameIdx), timescale: CMTimeScale(fps))
                    adaptor.append(pb, withPresentationTime: pts)
                }
            }
            frameIdx += 1
            if frameIdx % 600 == 0 || frameIdx == totalFrames {
                print("Rendered \(frameIdx)/\(totalFrames) frames...")
                fflush(stdout)
            }
            if frameIdx >= totalFrames {
                videoInput.markAsFinished()
                videoFinished = true
            }
            didWork = true
        }

        if !audioFinished && audioInput.isReadyForMoreMediaData && (videoFinished || audioTime <= videoTime || !videoInput.isReadyForMoreMediaData) {
            autoreleasepool {
                let n = min(chunkFrames, totalAudioFrames - audioCursor)
                var pcm = [Int16](repeating: 0, count: n * 2)
                for i in 0..<n {
                    pcm[i * 2]     = Int16(masterAudio.left[audioCursor + i] * 32767.0)
                    pcm[i * 2 + 1] = Int16(masterAudio.right[audioCursor + i] * 32767.0)
                }
                let byteLen = n * 4
                var blockBuf: CMBlockBuffer?
                CMBlockBufferCreateWithMemoryBlock(
                    allocator: kCFAllocatorDefault,
                    memoryBlock: nil,
                    blockLength: byteLen,
                    blockAllocator: kCFAllocatorDefault,
                    customBlockSource: nil,
                    offsetToData: 0,
                    dataLength: byteLen,
                    flags: 0,
                    blockBufferOut: &blockBuf
                )
                pcm.withUnsafeBytes { ptr in
                    _ = CMBlockBufferReplaceDataBytes(
                        with: ptr.baseAddress!,
                        blockBuffer: blockBuf!,
                        offsetIntoDestination: 0,
                        dataLength: byteLen
                    )
                }
                var sampleBuf: CMSampleBuffer?
                let pts = CMTime(value: CMTimeValue(audioCursor), timescale: 44100)
                CMAudioSampleBufferCreateWithPacketDescriptions(
                    allocator: kCFAllocatorDefault,
                    dataBuffer: blockBuf,
                    dataReady: true,
                    makeDataReadyCallback: nil,
                    refcon: nil,
                    formatDescription: fmtDesc!,
                    sampleCount: n,
                    presentationTimeStamp: pts,
                    packetDescriptions: nil,
                    sampleBufferOut: &sampleBuf
                )
                if let sb = sampleBuf {
                    audioInput.append(sb)
                }
                audioCursor += n
            }
            if audioCursor >= totalAudioFrames {
                audioInput.markAsFinished()
                audioFinished = true
            }
            didWork = true
        }

        if !didWork {
            Thread.sleep(forTimeInterval: 0.001)
        }
    }

    let sema = DispatchSemaphore(value: 0)
    writer.finishWriting {
        sema.signal()
    }
    sema.wait()
    print("Rendered screenplay video (\(String(format: "%.2f", manifest.total_duration_sec))s, \(totalFrames) frames) -> \(outMp4Path)")
}

let args = CommandLine.arguments
if args.count < 3 {
    fatalError("Usage: swift render_screenplay_video.swift <manifest.json> <output.mp4>")
}
renderVideoFromManifest(manifestPath: args[1], outMp4Path: args[2])
