import AppKit
import CoreGraphics
import Foundation

// ============================================================================
// Act 2 ("Into the Woods") Storyline Keyframe Normalizer & Flood-Fill Colorizer
// (colorize_flow_act2_scenes.swift)
// ============================================================================
// Normalizes all 5 Act 2 storyline coloring book illustrations (stag, trot,
// twig, skin, flap) into 1080x1080 pure B&W coloring pages (*_flow_bw.png) and
// deterministically flood-fills each enclosed region with Clem & Plum's exact
// Google Flow Character Sheet palette (*_flow_color.png), preserving 100% of
// the black ink outlines pixel-for-pixel.
// ============================================================================

struct RGB {
    var r: UInt8
    var g: UInt8
    var b: UInt8
}

// Locked Google Flow Character Sheet & Woodland Palette
let skyBlue       = RGB(r: 208, g: 240, b: 255)
let sunbeamGold   = RGB(r: 255, g: 246, b: 204)
let canopyLight   = RGB(r: 126, g: 208, b: 102)
let canopyMid     = RGB(r: 88,  g: 178, b: 78)
let bushGreen     = RGB(r: 104, g: 192, b: 88)
let fernGreen     = RGB(r: 72,  g: 164, b: 68)
let trunkBrown    = RGB(r: 164, g: 114, b: 74)
let stumpTan      = RGB(r: 212, g: 174, b: 126)
let pathGold      = RGB(r: 234, g: 206, b: 158)
let forestFloor   = RGB(r: 168, g: 214, b: 124)
let rockWarmGray  = RGB(r: 216, g: 212, b: 204)
let rockMossGray  = RGB(r: 194, g: 202, b: 186)

// Clem (Google Flow Character DNA)
let clemHair      = RGB(r: 44,  g: 36,  b: 34)
let clemSkin      = RGB(r: 255, g: 216, b: 186)
let clemShirt     = RGB(r: 246, g: 250, b: 255)
let clemOveralls  = RGB(r: 68,  g: 134, b: 218)
let clemPocket    = RGB(r: 92,  g: 156, b: 236)
let clemBoots     = RGB(r: 138, g: 86,  b: 48)

// Plum (Google Flow Character DNA)
let plumBody      = RGB(r: 104, g: 188, b: 248)
let plumBelly     = RGB(r: 226, g: 244, b: 255)
let plumBeak      = RGB(r: 255, g: 180, b: 52)

// Woodland Creatures & Target Props
let stagCoat      = RGB(r: 204, g: 146, b: 92)
let stagChest     = RGB(r: 242, g: 216, b: 178)
let stagAntlers   = RGB(r: 232, g: 198, b: 138)
let twigWood      = RGB(r: 156, g: 104, b: 62)
let lizardGreen   = RGB(r: 112, g: 212, b: 96)
let shedSkinPale  = RGB(r: 238, g: 244, b: 226)
let flapBirdCoral = RGB(r: 244, g: 132, b: 76)
let flapBirdGold  = RGB(r: 255, g: 212, b: 118)

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

func processScene(
    sceneNumber: Int,
    inputPath: String,
    outBWPath: String,
    outColorPath: String
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

    // Dilate ink barrier by 1px to prevent color bleed through thin line joints
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

    func classifyComponent(st: CompStats) -> RGB {
        let cx = Double(st.sumX) / Double(max(1, st.count))
        let cy = Double(st.sumY) / Double(max(1, st.count))
        let w = st.maxX - st.minX
        let h = st.maxY - st.minY

        switch sceneNumber {
        case 1:
            // SCENE 1: STAG
            // Left branch behind Clem (x 80..210, y 495..615)
            if cx >= 80 && cx <= 210 && cy >= 495 && cy <= 615 && w < 140 { return trunkBrown }
            // Clem (left: x 145..385, y 350..965)
            if cx >= 145 && cx <= 385 && cy >= 350 && cy <= 965 && !st.touchesBorder {
                if cy < 465 { return clemHair }
                if cy < 580 { return clemSkin }
                if cy >= 855 { return clemBoots }
                if cy >= 730 && (cx < 200 || cx > 342) { return clemSkin } // hands
                if cx >= 198 && cx <= 342 && cy >= 585 && cy <= 855 {
                    if w < 85 && h < 85 && cy < 720 { return clemPocket }
                    return clemOveralls
                }
                return clemShirt
            }
            // Plum on branch (x 360..535, y 320..505)
            if cx >= 360 && cx <= 535 && cy >= 320 && cy <= 505 && !st.touchesBorder {
                if cx > 460 && cy > 375 && cy < 415 && w < 45 { return plumBeak }
                if cy > 400 && cx > 415 && cx < 495 { return plumBelly }
                return plumBody
            }
            // Stag (right: x 525..935, y 190..875)
            if cx >= 525 && cx <= 935 && cy >= 190 && cy <= 875 && !st.touchesBorder {
                if cy < 370 { return stagAntlers }
                if cx >= 615 && cx <= 715 && cy >= 460 && cy <= 685 && w < 120 { return stagChest }
                return stagCoat
            }
            // Tree canopies (top y < 235)
            if cy < 235 && (cx < 490 || cx > 570) { return canopyLight }
            // Tree trunks (tall vertical regions)
            if h > 340 && (cx < 200 || (cx > 315 && cx < 410) || cx > 775) { return trunkBrown }
            // Ground / clearing path
            if cy > 725 { return pathGold }
            if cy > 620 && w < 220 { return bushGreen }
            return (cy < 680) ? skyBlue : forestFloor

        case 2:
            // SCENE 2: TROT
            // Plum on stump (x 35..210, y 660..825)
            if cx >= 35 && cx <= 210 && cy >= 660 && cy <= 825 && !st.touchesBorder {
                if cx > 140 && cy < 735 && w < 40 { return plumBeak }
                if cx > 105 && cy > 720 { return plumBelly }
                return plumBody
            }
            // Stump (x 25..245, y 810..990)
            if cx <= 245 && cy >= 810 && cy <= 990 && w < 240 {
                return (cy < 855) ? stumpTan : trunkBrown
            }
            // Clem (x 175..445, y 435..965)
            if cx >= 175 && cx <= 445 && cy >= 435 && cy <= 965 && !st.touchesBorder {
                if cy < 535 { return clemHair }
                if cy < 635 || cx > 385 || (cx < 240 && cy > 745 && cy < 825) { return clemSkin } // face + hands
                if cy >= 865 { return clemBoots }
                if cx >= 235 && cx <= 378 && cy >= 645 && cy <= 865 {
                    if w < 80 && h < 80 && cy < 765 { return clemPocket }
                    return clemOveralls
                }
                return clemShirt
            }
            // Trotting Stag (x 430..865, y 65..845)
            if cx >= 430 && cx <= 865 && cy >= 65 && cy <= 845 && !st.touchesBorder {
                if cy < 275 && cx > 550 { return stagAntlers }
                if cx > 690 && cy > 360 && cy < 560 && w < 130 { return stagChest }
                return stagCoat
            }
            // Ferns (excluding Clem's boots area x 220..410)
            if w < 180 && h < 240 && (cx < 180 || cx > 815 || (cy > 880 && cx > 440)) { return fernGreen }
            // Tree trunks
            if h > 320 && (cx < 340 || (cx > 460 && cx < 610) || cx > 860) { return trunkBrown }
            if cy > 550 { return pathGold }
            return (cy < 340) ? sunbeamGold : forestFloor

        case 3:
            // SCENE 3: TWIG
            // Plum on left branch (x 45..315, y 415..665)
            if cx >= 45 && cx <= 315 && cy >= 415 && cy <= 665 && !st.touchesBorder {
                if cx > 235 && cy > 485 && cy < 535 && w < 45 { return plumBeak }
                if cx > 185 && cy > 515 { return plumBelly }
                return plumBody
            }
            // Clem in center (x 355..755, y 125..895)
            if cx >= 355 && cx <= 755 && cy >= 125 && cy <= 895 && !st.touchesBorder {
                if cy < 305 { return clemHair }
                if cy < 435 { return clemSkin }
                if (cx < 525 && cy >= 720) || (cx >= 525 && cy >= 765) { return clemBoots }
                if cy >= 585 && (cx < 430 || cx > 670) { return clemSkin } // hands
                if cx >= 430 && cx <= 665 && cy >= 435 && cy <= 765 {
                    if w < 110 && h < 100 && cy < 595 { return clemPocket }
                    return clemOveralls
                }
                return clemShirt
            }
            // Snapped Twig on path (x 240..600, y 780..960)
            if cx >= 240 && cx <= 600 && cy >= 780 && cy <= 960 && !st.touchesBorder && w < 220 {
                if w < 55 && h < 55 { return canopyLight } // twig leaves
                return twigWood
            }
            // Background Stag on right (x 715..940, y 190..585)
            if cx >= 715 && cx <= 940 && cy >= 190 && cy <= 585 && !st.touchesBorder {
                if cy < 300 { return stagAntlers }
                return stagCoat
            }
            if cy < 190 && (cx < 450 || cx > 600) { return canopyLight }
            if cy >= 330 && cy <= 520 && cx < 450 && w < 340 { return bushGreen }
            if h > 320 && (cx < 350 || cx > 720) { return trunkBrown }
            if cy > 680 && st.touchesBorder && (cx < 260 || cx > 750) { return bushGreen }
            if cy > 520 { return pathGold }
            return skyBlue

        case 4:
            // SCENE 4: SKIN
            // Clem crouching left (x 70..585, y 75..855)
            if cx >= 70 && cx <= 585 && cy >= 75 && cy <= 855 && !st.touchesBorder {
                if cy < 255 { return clemHair }
                if cy < 405 { return clemSkin }
                if cx > 445 && cy >= 505 && cy <= 595 { return clemSkin } // pointing hand
                if cx >= 185 && cx <= 305 && cy >= 605 && cy <= 725 { return clemSkin } // right hand on knee
                if cy >= 685 && (cx < 205 || cx > 340) { return clemBoots }
                if cx >= 150 && cx <= 465 && cy >= 400 && cy <= 845 {
                    if w < 110 && h < 110 && cy < 595 && cx > 250 && cx < 365 { return clemPocket }
                    return clemOveralls
                }
                return clemShirt
            }
            // Plum on mossy rock (x 615..850, y 235..450)
            if cx >= 615 && cx <= 850 && cy >= 235 && cy <= 450 && !st.touchesBorder {
                if cx < 685 && cy > 300 && cy < 345 && w < 45 { return plumBeak }
                if cy > 330 && cx < 765 { return plumBelly }
                return plumBody
            }
            // Living lizard vs shed skin on rock (x 560..920, y 615..925)
            if cx >= 560 && cx <= 920 && cy >= 615 && cy <= 925 && !st.touchesBorder && w < 340 && h < 310 {
                if cx > 745 && cy > 760 { return shedSkinPale } // shed skin outline on right
                return lizardGreen
            }
            // Rocks & boulders
            if cy > 330 && cx > 550 && st.count > 12000 {
                return (cy < 620) ? rockMossGray : rockWarmGray
            }
            if h > 300 && cy < 420 { return trunkBrown }
            if cy > 600 { return pathGold }
            return (cy < 320) ? sunbeamGold : forestFloor

        default:
            // SCENE 5: FLAP
            // Clem standing left (x 35..455, y 225..965)
            if cx >= 35 && cx <= 455 && cy >= 225 && cy <= 965 && !st.touchesBorder {
                if cy < 375 { return clemHair }
                if cy < 495 { return clemSkin }
                if cy < 560 && (cx < 125 || cx > 365) { return clemSkin } // raised hands
                if cy >= 850 { return clemBoots }
                if cx >= 150 && cx <= 345 && cy >= 495 && cy <= 855 {
                    if w < 100 && h < 100 && cy < 660 { return clemPocket }
                    return clemOveralls
                }
                return clemShirt
            }
            // Plum fluttering (x 470..955, y 155..420)
            if cx >= 470 && cx <= 955 && cy >= 155 && cy <= 420 && !st.touchesBorder {
                if w < 40 && h < 40 && (cx > 625 && cx < 785) { return plumBeak }
                return plumBody
            }
            // Big Flapping Woodland Bird (x 470..940, y 400..835)
            if cx >= 470 && cx <= 940 && cy >= 400 && cy <= 835 && !st.touchesBorder && w < 480 {
                if cx >= 615 && cx <= 735 && cy >= 580 && cy <= 745 { return flapBirdGold }
                return flapBirdCoral
            }
            if cy < 260 && h > 220 { return trunkBrown }
            if cy > 780 { return forestFloor }
            return bushGreen
        }
    }

    var compColors = [RGB](repeating: sunbeamGold, count: Int(currentID))
    for cid in 0..<Int(currentID) {
        compColors[cid] = classifyComponent(st: stats[cid])
    }

    var colorBytes = [UInt8](repeating: 255, count: W * H * 4)
    for p in 0..<(W * H) {
        let idx = p * 4
        if isInk[p] {
            let lum = (Int(raw[idx]) * 299 + Int(raw[idx + 1]) * 587 + Int(raw[idx + 2]) * 114) / 1000
            let v = UInt8(max(0, min(55, lum / 3)))
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

let brainDir = "/Users/harshad/.gemini/antigravity/brain/27c7aa59-f079-4a46-b804-76663438d7c7"
let illusDir = "/Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/Blends/illustrations"

let scenes: [(Int, String, String)] = [
    (1, "\(brainDir)/act2_scene1_stag_raw_1793602745693.jpg", "act2_scene1_stag_flow"),
    (2, "\(brainDir)/act2_scene2_trot_raw_1793602758615.jpg", "act2_scene2_trot_flow"),
    (3, "\(brainDir)/act2_scene3_twig_raw_1793602770713.jpg", "act2_scene3_twig_flow"),
    (4, "\(brainDir)/act2_scene4_skin_raw_1793602746019.jpg", "act2_scene4_skin_flow"),
    (5, "\(brainDir)/act2_scene5_flap_raw_1793602762420.jpg", "act2_scene5_flap_flow")
]

for (num, src, prefix) in scenes {
    processScene(
        sceneNumber: num,
        inputPath: src,
        outBWPath: "\(illusDir)/\(prefix)_bw.png",
        outColorPath: "\(illusDir)/\(prefix)_color.png"
    )
}
print("Successfully generated all 5 Act 2 B&W and Colored Storyline Keyframes.")
