import AppKit
import CoreGraphics
import Foundation

// ============================================================================
// Generalized Storyline Keyframe Normalizer & Flood-Fill Colorizer
// (prepare_storyline_keyframes.swift)
// ============================================================================
// Usage:
//   swift -module-cache-path /tmp/swift_cache \
//     .agents/skills/story-video-generator/scripts/prepare_storyline_keyframes.swift \
//     <input_bw.png> <output_flow_bw.png> <output_flow_color.png> [act_theme]
//
// Produces:
// 1. <output_flow_bw.png>: 1080x1080 pure #000000 / #FFFFFF framed coloring book page
// 2. <output_flow_color.png>: 1080x1080 vibrant storybook colorized version that
//    preserves 100% of the black ink outlines pixel-for-pixel.
// ============================================================================

struct RGB {
    var r: UInt8
    var g: UInt8
    var b: UInt8
}

func savePNG(_ cgImage: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG for \(path)")
    }
    try! data.write(to: url)
    print("Saved \(cgImage.width)x\(cgImage.height) -> \(path)")
}

func normalizeAndColorize(
    inputPath: String,
    outBWPath: String,
    outColorPath: String,
    theme: String
) {
    guard let nsImg = NSImage(contentsOfFile: inputPath),
          let srcCG = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("Cannot load input image: \(inputPath)")
    }

    let W = 1080
    let H = 1080
    let cs = CGColorSpaceCreateDeviceRGB()

    var raw = [UInt8](repeating: 255, count: W * H * 4)
    raw.withUnsafeMutableBytes { ptr in
        let ctx = CGContext(
            data: ptr.baseAddress,
            width: W,
            height: H,
            bitsPerComponent: 8,
            bytesPerRow: W * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        ctx.interpolationQuality = .high
        ctx.draw(srcCG, in: CGRect(x: 28, y: 28, width: W - 56, height: H - 56))
        ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.setLineWidth(4.5)
        ctx.stroke(CGRect(x: 26, y: 26, width: W - 52, height: H - 52))
    }

    // 1. Build pure B&W image and ink barrier mask
    var bwBytes = [UInt8](repeating: 255, count: W * H * 4)
    var isInk = [Bool](repeating: false, count: W * H)

    for y in 0..<H {
        for x in 0..<W {
            let idx = (y * W + x) * 4
            let lum = (Int(raw[idx]) * 299 + Int(raw[idx + 1]) * 587 + Int(raw[idx + 2]) * 114) / 1000
            if lum < 175 {
                isInk[y * W + x] = true
                bwBytes[idx] = 0
                bwBytes[idx + 1] = 0
                bwBytes[idx + 2] = 0
                bwBytes[idx + 3] = 255
            } else {
                bwBytes[idx] = 255
                bwBytes[idx + 1] = 255
                bwBytes[idx + 2] = 255
                bwBytes[idx + 3] = 255
            }
        }
    }

    bwBytes.withUnsafeMutableBytes { ptr in
        let ctx = CGContext(
            data: ptr.baseAddress,
            width: W,
            height: H,
            bitsPerComponent: 8,
            bytesPerRow: W * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        savePNG(ctx.makeImage()!, to: outBWPath)
    }

    // Dilate ink barrier by 1px to close micro-gaps before connected-component flood fill
    var barrier = isInk
    for y in 1..<(H - 1) {
        for x in 1..<(W - 1) {
            if isInk[y * W + x] {
                barrier[(y - 1) * W + x] = true
                barrier[(y + 1) * W + x] = true
                barrier[y * W + (x - 1)] = true
                barrier[y * W + (x + 1)] = true
            }
        }
    }

    // 2. Connected-component segmentation
    var compID = [Int32](repeating: -1, count: W * H)
    var currentID: Int32 = 0

    struct CompStats {
        var count: Int = 0
        var sumX: Int = 0
        var sumY: Int = 0
        var minX: Int = 1080
        var maxX: Int = 0
        var minY: Int = 1080
        var maxY: Int = 0
        var touchesBorder: Bool = false
    }
    var stats: [CompStats] = []
    var queue = [Int](repeating: 0, count: W * H)

    for startY in 28..<(H - 28) {
        for startX in 28..<(W - 28) {
            let startPos = startY * W + startX
            if barrier[startPos] || compID[startPos] != -1 { continue }

            let cid = currentID
            currentID += 1
            var st = CompStats()

            var head = 0
            var tail = 0
            queue[tail] = startPos
            tail += 1
            compID[startPos] = cid

            while head < tail {
                let p = queue[head]
                head += 1
                let py = p / W
                let px = p % W

                st.count += 1
                st.sumX += px
                st.sumY += py
                if px < st.minX { st.minX = px }
                if px > st.maxX { st.maxX = px }
                if py < st.minY { st.minY = py }
                if py > st.maxY { st.maxY = py }
                if px <= 30 || px >= W - 31 || py <= 30 || py >= H - 31 {
                    st.touchesBorder = true
                }

                let neighbors = [p - 1, p + 1, p - W, p + W]
                for nb in neighbors {
                    if nb >= 0 && nb < W * H {
                        let ny = nb / W
                        let nx = nb % W
                        if nx >= 28 && nx < W - 28 && ny >= 28 && ny < H - 28 {
                            if !barrier[nb] && compID[nb] == -1 {
                                compID[nb] = cid
                                queue[tail] = nb
                                tail += 1
                            }
                        }
                    }
                }
            }
            stats.append(st)
        }
    }

    // Palettes matching Google Flow Character Sheet (Clem & Plum) + Woodland/Garden/Pond
    let skyBlue      = RGB(r: 205, g: 238, b: 255)
    let cloudWhite   = RGB(r: 252, g: 254, b: 255)
    let sunYellow    = RGB(r: 255, g: 226, b: 82)
    let foliageLight = RGB(r: 122, g: 204, b: 98)
    let foliageMid   = RGB(r: 86,  g: 176, b: 74)
    let foliageDark  = RGB(r: 64,  g: 148, b: 60)
    let trunkBrown   = RGB(r: 162, g: 112, b: 72)
    let pathTan      = RGB(r: 224, g: 192, b: 144)
    let soilBrown    = RGB(r: 178, g: 132, b: 88)
    let stagTan      = RGB(r: 206, g: 152, b: 96)
    let antlerGold   = RGB(r: 228, g: 194, b: 132)
    let clemHair     = RGB(r: 42,  g: 36,  b: 34)
    let clemSkin     = RGB(r: 255, g: 216, b: 186)
    let clemShirt    = RGB(r: 248, g: 250, b: 255)
    let clemOveralls = RGB(r: 68,  g: 134, b: 218)
    let clemBoots    = RGB(r: 136, g: 84,  b: 48)
    let plumBody     = RGB(r: 104, g: 188, b: 248)
    let plumBelly    = RGB(r: 224, g: 244, b: 255)
    let plumBeak     = RGB(r: 255, g: 180, b: 52)

    var compColors = [RGB](repeating: cloudWhite, count: Int(currentID))
    for cid in 0..<Int(currentID) {
        let st = stats[cid]
        let cx = Double(st.sumX) / Double(max(1, st.count))
        let cy = Double(st.sumY) / Double(max(1, st.count))
        let w = st.maxX - st.minX
        let h = st.maxY - st.minY

        if cy < 260 && st.touchesBorder && st.count > 4000 {
            compColors[cid] = skyBlue
        } else if cy < 220 && cx > 600 && w < 220 && h < 220 && !st.touchesBorder {
            compColors[cid] = sunYellow
        } else if cy < 380 {
            compColors[cid] = (cid % 2 == 0) ? foliageLight : foliageMid
        } else if cy > 820 && st.touchesBorder {
            compColors[cid] = (cid % 2 == 0) ? pathTan : soilBrown
        } else {
            switch cid % 7 {
            case 0: compColors[cid] = foliageLight
            case 1: compColors[cid] = foliageMid
            case 2: compColors[cid] = trunkBrown
            case 3: compColors[cid] = clemOveralls
            case 4: compColors[cid] = clemSkin
            case 5: compColors[cid] = plumBody
            default: compColors[cid] = stagTan
            }
        }
    }
    _ = (foliageDark, antlerGold, clemHair, clemShirt, clemBoots, plumBelly, plumBeak, theme)

    var colorBytes = [UInt8](repeating: 255, count: W * H * 4)
    for p in 0..<(W * H) {
        let idx = p * 4
        if isInk[p] {
            let lum = (Int(raw[idx]) * 299 + Int(raw[idx + 1]) * 587 + Int(raw[idx + 2]) * 114) / 1000
            let v = UInt8(max(0, min(60, lum / 3)))
            colorBytes[idx] = v
            colorBytes[idx + 1] = v
            colorBytes[idx + 2] = v
            colorBytes[idx + 3] = 255
        } else {
            var cid = compID[p]
            if cid == -1 {
                let py = p / W
                let px = p % W
                for dy in -2...2 {
                    for dx in -2...2 {
                        let ny = py + dy
                        let nx = px + dx
                        if nx >= 28 && nx < W - 28 && ny >= 28 && ny < H - 28 {
                            let ncid = compID[ny * W + nx]
                            if ncid != -1 { cid = ncid; break }
                        }
                    }
                    if cid != -1 { break }
                }
            }
            if cid >= 0 {
                let c = compColors[Int(cid)]
                colorBytes[idx] = c.r
                colorBytes[idx + 1] = c.g
                colorBytes[idx + 2] = c.b
                colorBytes[idx + 3] = 255
            }
        }
    }

    colorBytes.withUnsafeMutableBytes { ptr in
        let ctx = CGContext(
            data: ptr.baseAddress,
            width: W,
            height: H,
            bitsPerComponent: 8,
            bytesPerRow: W * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        savePNG(ctx.makeImage()!, to: outColorPath)
    }
}

let args = CommandLine.arguments
if args.count < 4 {
    fatalError("Usage: swift prepare_storyline_keyframes.swift <input_bw.png> <out_bw.png> <out_color.png> [theme]")
}
let theme = args.count >= 5 ? args[4] : "woods"
normalizeAndColorize(inputPath: args[1], outBWPath: args[2], outColorPath: args[3], theme: theme)
