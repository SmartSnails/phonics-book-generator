import AppKit
import Foundation

struct RGB {
    var r: UInt8
    var g: UInt8
    var b: UInt8
}

struct RegionInfo {
    var id: Int
    var area: Int = 0
    var sumX: Int = 0
    var sumY: Int = 0
    var minX: Int = 10000
    var maxX: Int = 0
    var minY: Int = 10000
    var maxY: Int = 0
    var touchesBorder: Bool = false
    var cx: Int { area > 0 ? sumX / area : 0 }
    var cy: Int { area > 0 ? sumY / area : 0 }
    var w: Int { maxX - minX + 1 }
    var h: Int { maxY - minY + 1 }
}

// Locked Google Flow Character DNA Palette (@Clem & @Plum) + Sunny Cottage Garden Palette
let cWhite      = RGB(r: 255, g: 255, b: 255)
let cSky        = RGB(r: 210, g: 238, b: 255)
let cCloud      = RGB(r: 252, g: 254, b: 255)
let cSun        = RGB(r: 255, g: 222, b: 68)
let cSoilPath   = RGB(r: 232, g: 202, b: 162)
let cSoilMid    = RGB(r: 198, g: 156, b: 110)
let cSoilDark   = RGB(r: 168, g: 124, b: 82)
let cHoleSoil   = RGB(r: 146, g: 102, b: 64)
let cTreeTrunk  = RGB(r: 156, g: 108, b: 68)
let cTreeCanopy = RGB(r: 118, g: 204, b: 96)
let cBushGreen  = RGB(r: 96,  g: 186, b: 82)
let cLeafBright = RGB(r: 106, g: 204, b: 88)
let cLeafDeep   = RGB(r: 76,  g: 174, b: 70)
let cRosePetal  = RGB(r: 244, g: 108, b: 126)
let cFlowerYel  = RGB(r: 255, g: 226, b: 92)
let cWoodPost   = RGB(r: 220, g: 174, b: 122)
let cWoodRail   = RGB(r: 202, g: 154, b: 102)
let cRoofRed    = RGB(r: 218, g: 96,  b: 84)
let cHouseWall  = RGB(r: 252, g: 244, b: 222)
let cHouseDoor  = RGB(r: 186, g: 128, b: 84)
let cWindowBlue = RGB(r: 188, g: 228, b: 250)
let cChimney    = RGB(r: 196, g: 108, b: 92)

// @Plum (Round sky-blue bird with speckled crown/breast)
let cPlumBody   = RGB(r: 106, g: 192, b: 248)
let cPlumBreast = RGB(r: 164, g: 218, b: 252)
let cPlumWing   = RGB(r: 72,  g: 160, b: 226)
let cPlumSpeck  = RGB(r: 218, g: 240, b: 255)
let cPlumBeak   = RGB(r: 255, g: 168, b: 48)

// @Clem (5-yr-old boy: neat black/dark-espresso hair, warm skin, white collared shirt, blue denim overalls, brown boots)
let cClemHair   = RGB(r: 54,  g: 38,  b: 28)
let cClemSkin   = RGB(r: 255, g: 216, b: 186)
let cClemMouth  = RGB(r: 228, g: 98,  b: 98)
let cClemShirt  = RGB(r: 248, g: 250, b: 254)
let cClemDenim  = RGB(r: 72,  g: 132, b: 210)
let cClemPocket = RGB(r: 56,  g: 112, b: 188)
let cClemCuff   = RGB(r: 112, g: 164, b: 228)
let cBrassBtn   = RGB(r: 242, g: 196, b: 78)
let cClemBoot   = RGB(r: 146, g: 90,  b: 48)
let cBootSole   = RGB(r: 194, g: 148, b: 102)

// Props
let cSpudGold   = RGB(r: 234, g: 192, b: 116)
let cGrubPink   = RGB(r: 255, g: 190, b: 204)
let cPebble     = RGB(r: 204, g: 194, b: 182)

// ----------------------------------------------------------------------------
// Scene 1: page-038.png (CROP — Clem walking along fence & spinach/rose rows, Plum on post)
// ----------------------------------------------------------------------------
func colorScene1(_ r: RegionInfo) -> RGB {
    if r.touchesBorder { return cWhite }
    let cx = r.cx, cy = r.cy, a = r.area

    // Main Garden Path first so no character bounding box steals it
    if r.id == 11 || r.id == 727 || r.id == 729 || r.id == 811 { return cSoilPath }

    // Top sky & sun
    if r.id == 3 { return cSky }
    if r.id == 5 || (cx > 665 && cx < 770 && cy > 70 && cy < 165) { return cSun }

    // Top tree canopies & trunks
    if r.id == 2 || r.id == 4 { return cTreeCanopy }
    if r.id == 7 || r.id == 8 { return cTreeTrunk }

    // Plum on fencepost (x: 765..945, y: 300..465) — check BEFORE background bushes
    if r.id == 18 || r.id == 39 || r.id == 70 || (cx > 765 && cx < 945 && cy > 300 && cy < 465 && a < 10000) {
        if a < 65 {
            if cy > 335 && cy < 375 && (cx < 800 || (cx > 830 && cx < 865)) { return cWhite }
            return cPlumSpeck
        }
        if cx > 790 && cx < 825 && cy > 350 && cy < 380 && a < 500 { return cPlumBeak }
        if r.id == 70 || cx > 845 { return cPlumWing }
        if r.id == 18 { return cPlumBody }
        if r.id == 39 { return cPlumBreast }
        return cPlumBody
    }

    // Background bushes
    if r.id == 13 || r.id == 15 || r.id == 43 || (cy > 165 && cy < 510 && (cx < 400 || cx > 750) && a > 1500 && r.id != 7 && r.id != 8) {
        return cBushGreen
    }

    // Clem Hair & Head
    if r.id == 12 { return cClemHair }
    if r.id == 16 || (cx > 410 && cx < 648 && cy > 270 && cy < 458 && a > 250) {
        if a < 450 && cy > 340 && cy < 400 { return cWhite }
        if cy > 410 && cy < 438 && cx > 515 && cx < 570 && a < 800 { return cClemMouth }
        return cClemSkin
    }

    // Clem Hands (left hand around x:390..440, y:670..735; right hand around x:670..720, y:645..708)
    if (cx > 388 && cx < 442 && cy > 668 && cy < 735 && a < 2000) ||
       (cx > 665 && cx < 720 && cy > 645 && cy < 710 && a < 1600) {
        return cClemSkin
    }

    // Clem Shirt & Sleeves & Collar
    if r.id == 221 || r.id == 226 || r.id == 153 || r.id == 159 || r.id == 191 || r.id == 228 || r.id == 334 || r.id == 304 {
        return cClemShirt
    }
    if (cx > 475 && cx < 590 && cy > 450 && cy < 545 && a < 2000) {
        return cClemShirt
    }

    // Clem Overalls, Straps, Pocket, Belt, Pants, Cuffs
    if r.id == 266 || r.id == 354 || r.id == 584 || r.id == 351 || r.id == 213 || r.id == 168 {
        return cClemDenim
    }
    if r.id == 283 { return cClemPocket }
    if r.id == 311 || r.id == 322 || r.id == 350 || r.id == 635 || r.id == 497 {
        return cClemCuff
    }
    if cx > 465 && cx < 625 && cy > 455 && cy < 840 && a < 14000 {
        if a < 180 { return cBrassBtn }
        return cClemDenim
    }

    // Clem Boots (x: 440..690, y: 790..965)
    if cx > 440 && cx < 690 && cy > 790 && cy < 965 && a < 6000 {
        if r.id == 517 || r.id == 547 || r.id == 570 || cy > 885 { return cBootSole }
        return cClemBoot
    }

    // Wooden Fence (posts & rails on right side and receding middle-left)
    if r.id == 127 || r.id == 131 || r.id == 265 || r.id == 196 || r.id == 645 {
        return cWoodPost
    }
    if r.id == 154 || r.id == 230 || r.id == 223 || r.id == 330 || r.id == 277 || r.id == 314 || r.id == 421 || r.id == 273 || r.id == 413 {
        return cWoodRail
    }
    if (cx > 260 && cx < 465 && cy > 345 && cy < 540 && (r.h > r.w * 2 || (r.w > 18 && r.h < 45))) {
        return (r.h > r.w) ? cWoodPost : cWoodRail
    }
    if cx > 670 && cy > 420 && cy < 980 {
        if r.h > r.w * 2 && r.w < 45 { return cWoodPost }
        if cx > 705 && cx < 815 && (cy < 580 || (cy > 640 && cy < 760)) { return cWoodRail }
        if cx > 860 && cx < 1018 && ((cy > 540 && cy < 670) || (cy > 740 && cy < 905)) { return cWoodRail }
        if cx > 1010 && cy > 510 { return cWoodPost }
    }

    // Left garden bed: Roses (lower-left x < 260, y > 620) & Spinach Crop rows (x < 485, y > 440)
    if cx < 255 && cy > 620 && a < 4000 {
        if (cx > 80 && cx < 185 && cy > 675 && cy < 775) ||
           (cx > 30 && cx < 125 && cy > 780 && cy < 875) ||
           (cx > 110 && cx < 215 && cy > 840 && cy < 945) ||
           (cx > 25 && cx < 75 && cy > 625 && cy < 695) {
            return cRosePetal
        }
        return cLeafDeep
    }
    if cx < 510 && cy > 440 && a < 18000 {
        return (cx < 240) ? cLeafDeep : cLeafBright
    }
    // Plants behind fence on right
    if cx > 720 && cy > 340 && cy < 880 && a < 5000 {
        return cLeafBright
    }

    return cSoilPath
}

// ----------------------------------------------------------------------------
// Scene 2: page-043.png (SPUD — Cottage, trees, fence, potato plants, Clem pulling spuds, Plum on left)
// ----------------------------------------------------------------------------
func colorScene2(_ r: RegionInfo) -> RGB {
    if r.touchesBorder { return cWhite }
    let cx = r.cx, cy = r.cy, a = r.area

    // Garden Soil first so no bounding box steals it
    if r.id == 72 || r.id == 76 { return cSoilPath }

    // Sky, Clouds, Sun
    if r.id == 2 { return cSky }
    if r.id == 3 || r.id == 4 || r.id == 14 || r.id == 17 || (cy < 200 && cx < 640 && a > 3000) {
        if r.id == 14 { return cTreeCanopy }
        return cCloud
    }
    if r.id == 5 || (cx > 650 && cx < 840 && cy > 60 && cy < 250) { return cSun }

    // Trees & Bushes in background
    if r.id == 6 || r.id == 7 || r.id == 14 { return cTreeCanopy }
    if r.id == 20 || r.id == 25 || (cy > 290 && cy < 465 && (cx < 130 || cx > 930) && a > 1500) {
        return cTreeTrunk
    }
    if r.id == 34 || r.id == 57 || r.id == 62 || r.id == 66 || r.id == 70 || r.id == 71 {
        return cBushGreen
    }

    // Cottage House (x: 145..560, y: 185..460)
    if r.id == 10 || r.id == 11 { return cChimney }
    if r.id == 12 || r.id == 13 || r.id == 15 { return cRoofRed }
    if r.id == 16 || r.id == 31 { return cHouseWall }
    if r.id == 53 { return cHouseDoor }
    if (cx > 220 && cx < 300 && cy > 270 && cy < 425) || (cx > 470 && cx < 525 && cy > 360 && cy < 418) {
        return cWindowBlue
    }

    // Wooden Fence (y: 435..565)
    if cy > 438 && cy < 562 {
        if r.h > 75 && r.w < 30 { return cWoodPost }
        if r.w > 45 && r.h < 35 && cy < 520 { return cWoodRail }
    }

    // Clem Hair & Head (x: 600..915, y: 360..665)
    if r.id == 46 { return cClemHair }
    if r.id == 80 || (cx > 630 && cx < 885 && cy > 455 && cy < 665 && a > 300) {
        if a < 450 && cy > 530 && cy < 590 { return cWhite }
        return cClemSkin
    }

    // Clem Hands & Forearms
    if r.id == 380 || r.id == 548 || r.id == 549 || r.id == 639 ||
       (cx > 500 && cx < 655 && cy > 660 && cy < 785 && a > 1100 && a < 3500 && r.id != 411 && r.id != 477) {
        return cClemSkin
    }

    // Clem Shirt & Sleeves
    if r.id == 411 || r.id == 477 || r.id == 656 || r.id == 420 || r.id == 455 || r.id == 483 || r.id == 621 ||
       (cx > 595 && cx < 820 && cy > 610 && cy < 775 && a > 1200 && a < 12000) {
        return cClemShirt
    }

    // Clem Overalls & Kneeling Pants
    if r.id == 727 || r.id == 729 || r.id == 442 || r.id == 461 || r.id == 586 {
        return cClemDenim
    }
    if cx > 650 && cx < 865 && cy > 655 && cy < 1005 {
        if cx > 830 && cy > 830 { return cClemBoot }
        if a > 3000 { return cClemDenim }
    }
    // Clem Boot on right (x: 830..945, y: 830..990)
    if r.id == 698 || r.id == 774 || r.id == 767 || r.id == 799 || (cx > 830 && cx < 948 && cy > 830 && cy < 990) {
        return cClemBoot
    }

    // Plum on left dirt mound (x: 195..402, y: 745..970)
    if cx > 195 && cx < 402 && cy > 745 && cy < 970 {
        if a < 75 {
            if cy > 760 && cy < 805 && cx > 290 && cx < 330 { return cWhite }
            return cPlumSpeck
        }
        if cx > 335 && cx < 385 && cy > 765 && cy < 815 && a < 600 { return cPlumBeak }
        if r.id == 645 { return cPlumBreast }
        if cx < 305 && cy > 800 && a < 3500 { return cPlumWing }
        return cPlumBody
    }

    // Pulled Potato Plant & 4 Dangling Spuds (x: 430..645, y: 740..960)
    if r.id == 671 || r.id == 700 || r.id == 701 || r.id == 751 ||
       (cx > 435 && cx < 645 && cy > 800 && cy < 955 && a > 800 && a < 4500) {
        return cSpudGold
    }

    // Potato Plants (Flowers & Leaves)
    if cy > 475 && cy < 835 && a < 4500 {
        if a < 90 && cy < 585 { return cFlowerYel }
        return (cy < 640) ? cLeafBright : cLeafDeep
    }

    // Foreground bushes at bottom corners
    if r.id == 811 || r.id == 824 || (cy > 945 && (cx < 205 || cx > 870)) {
        return cBushGreen
    }

    return cSoilPath
}

// ----------------------------------------------------------------------------
// Scene 3: act1_scene3_grub_flow_bw.png (GRUB — Clem on hands & knees, Plum peeking at grub in hole)
// ----------------------------------------------------------------------------
func colorScene3(_ r: RegionInfo) -> RGB {
    if r.touchesBorder { return cWhite }
    let cx = r.cx, cy = r.cy, a = r.area

    // Soil Ground first
    if r.id == 22 { return cSoilPath }

    // Sky & Clouds
    if r.id == 2 { return cSky }
    if r.id == 3 || r.id == 4 { return cCloud }

    // Clem Hair & Head
    if r.id == 5 { return cClemHair }
    if r.id == 7 { return cClemSkin }
    if (cx > 440 && cx < 670 && cy > 720 && cy < 855 && a > 1800 && a < 5000) { return cClemSkin }

    // Clem Shirt & Sleeves
    if r.id == 10 || r.id == 35 || (cx > 345 && cx < 615 && cy > 435 && cy < 755 && a > 6000) {
        return cClemShirt
    }
    // Clem Overalls & Boots
    if r.id == 12 || r.id == 19 || r.id == 8 || r.id == 9 || r.id == 21 || r.id == 34 || r.id == 48 || r.id == 54 || r.id == 61 {
        return cClemDenim
    }
    if r.id == 56 || r.id == 53 || (cx > 115 && cx < 270 && cy > 615 && cy < 775) {
        return cClemBoot
    }

    // Plum on right (x: 735..930, y: 625..805)
    if cx > 735 && cx < 930 && cy > 625 && cy < 805 {
        if a < 90 { return cPlumSpeck }
        if cx < 755 && cy > 680 && cy < 720 && a < 400 { return cPlumBeak }
        if r.id == 65 { return cPlumBody }
        if cx > 795 && cy > 665 && cy < 755 && a < 3500 { return cPlumWing }
        return cPlumBody
    }

    // Cute Segmented Baby Grub in Hole (x: 650..740, y: 830..940)
    if cx > 650 && cx < 740 && cy > 830 && cy < 940 && a < 1500 {
        return cGrubPink
    }
    // Scooped Dirt Hole
    if cx > 610 && cx < 770 && cy > 855 && cy < 955 && a > 1500 && a < 9000 {
        return cHoleSoil
    }

    // Garden Sprouts & Leaves
    if (cx < 450 && cy > 490 && a < 25000) || (cx > 670 && cy > 490 && a < 9500) {
        if cx > 940 && cy > 710 && cy < 820 { return cPebble }
        return (cy > 850) ? cBushGreen : cLeafBright
    }

    return cSoilPath
}

// ----------------------------------------------------------------------------
// Scene 4: act1_scene4_snag_flow_bw.png (SNAG — Clem's sleeve caught on rose bush, Plum on fencepost)
// ----------------------------------------------------------------------------
func colorScene4(_ r: RegionInfo) -> RGB {
    if r.touchesBorder { return cWhite }
    let cx = r.cx, cy = r.cy, a = r.area

    // Main soil ground first
    if r.id == 291 || (cy > 600 && a > 50000) { return cSoilPath }

    // Sky, Sun
    if r.id == 2 || r.id == 4 { return cSky }
    if r.id == 3 { return cSun }

    // Clem Hair & Head
    if r.id == 5 { return cClemHair }
    if r.id == 7 { return cClemSkin }
    if (cx > 500 && cx < 605 && cy > 600 && cy < 750 && a > 2500 && a < 7000) ||
       (cx > 760 && cx < 860 && cy > 590 && cy < 795 && a > 2500 && a < 8000) {
        return cClemSkin
    }

    // Clem Shirt & Sleeves (including stretched left sleeve caught on thorn!)
    if (cx > 505 && cx < 795 && cy > 480 && cy < 625 && a > 1200 && a < 10000 && !(cx > 580 && cx < 750 && cy > 530)) {
        return cClemShirt
    }

    // Clem Overalls & Pocket & Straps & Pants
    if r.id == 222 || r.id == 204 || r.id == 116 || r.id == 173 || r.id == 310 || r.id == 311 ||
       (cx > 610 && cx < 775 && cy > 535 && cy < 955 && a > 4000) {
        if cy > 915 && a < 3500 { return cClemCuff }
        return cClemDenim
    }
    if cx > 650 && cx < 735 && cy > 645 && cy < 720 && a > 1500 && a < 4000 {
        return cClemPocket
    }

    // Clem Boots
    if cx > 585 && cx < 815 && cy > 955 && cy < 1040 {
        return (cy > 995) ? cBootSole : cClemBoot
    }

    // Plum on fencepost (x: 780..1025, y: 365..520)
    if cx > 780 && cx < 1025 && cy > 365 && cy < 520 {
        if a < 90 { return cPlumSpeck }
        if cx < 845 && cy > 410 && cy < 445 && a < 450 { return cPlumBeak }
        if cx > 890 { return cPlumWing }
        return cPlumBody
    }

    // Wooden Fence (posts at x~547, x~837, x~985)
    if cx > 515 && cy > 515 && cy < 890 && ((r.h > r.w * 2 && r.w < 55) || (r.w > 60 && r.h < 45)) {
        return (r.h > r.w) ? cWoodPost : cWoodRail
    }

    // Rose Bush on Left (x < 515, y > 340)
    if cx < 515 && cy > 340 {
        if a > 3500 { return cBushGreen }
        if (cx > 95 && cx < 205 && cy > 350 && cy < 430) ||
           (cx > 50 && cx < 130 && cy > 425 && cy < 505) ||
           (cx > 210 && cx < 320 && cy > 425 && cy < 520) ||
           (cx > 430 && cx < 505 && cy > 415 && cy < 495) ||
           (cx > 85 && cx < 200 && cy > 515 && cy < 630) ||
           (cx > 290 && cx < 395 && cy > 525 && cy < 630) ||
           (cx > 175 && cx < 285 && cy > 665 && cy < 790) ||
           (cx > 35 && cx < 120 && cy > 725 && cy < 820) ||
           (cx > 380 && cx < 465 && cy > 795 && cy < 885) {
            return cRosePetal
        }
        return cLeafDeep
    }

    // Foreground plants on right
    if cx > 815 && cy > 750 {
        return cLeafBright
    }

    return cSoilPath
}

func renderColoredScene(inPath: String, outPath: String, classifier: (RegionInfo) -> RGB) {
    guard let nsImg = NSImage(contentsOfFile: inPath),
          let cg = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    let w = cg.width, h = cg.height
    let data = UnsafeMutablePointer<UInt8>.allocate(capacity: w * h * 4)
    defer { data.deallocate() }
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

    var visited = [Int32](repeating: 0, count: w * h)
    var q = [Int](repeating: 0, count: w * h)
    var regions: [RegionInfo] = [RegionInfo(id: 0)]
    var regionId: Int32 = 0

    for y in 0..<h {
        for x in 0..<w {
            let idx = y * w + x
            if visited[idx] != 0 { continue }
            let p = idx * 4
            let lum = (Int(data[p]) + Int(data[p+1]) + Int(data[p+2])) / 3
            if lum < 175 {
                visited[idx] = -1
                continue
            }
            regionId += 1
            var info = RegionInfo(id: Int(regionId))
            var head = 0, tail = 0
            q[tail] = idx; tail += 1
            visited[idx] = regionId
            while head < tail {
                let cur = q[head]; head += 1
                let cy = cur / w, cx = cur % w
                info.area += 1
                info.sumX += cx
                info.sumY += cy
                if cx < info.minX { info.minX = cx }
                if cx > info.maxX { info.maxX = cx }
                if cy < info.minY { info.minY = cy }
                if cy > info.maxY { info.maxY = cy }
                if cx == 0 || cx == w - 1 || cy == 0 || cy == h - 1 { info.touchesBorder = true }

                for (dx, dy) in [(-1,0),(1,0),(0,-1),(0,1)] {
                    let nx = cx + dx, ny = cy + dy
                    if nx >= 0 && nx < w && ny >= 0 && ny < h {
                        let n = ny * w + nx
                        if visited[n] == 0 {
                            let np = n * 4
                            if (Int(data[np]) + Int(data[np+1]) + Int(data[np+2])) / 3 >= 175 {
                                visited[n] = regionId; q[tail] = n; tail += 1
                            } else { visited[n] = -1 }
                        }
                    }
                }
            }
            regions.append(info)
        }
    }

    var regionColors = [RGB](repeating: cWhite, count: regions.count)
    for i in 1..<regions.count {
        regionColors[i] = classifier(regions[i])
    }

    // Propagate into anti-aliased border pixels and blend with ink luminance
    for _ in 0..<2 {
        var nextVisited = visited
        for y in 1..<(h-1) {
            for x in 1..<(w-1) {
                let idx = y * w + x
                if visited[idx] <= 0 {
                    let n1 = visited[idx - 1], n2 = visited[idx + 1], n3 = visited[idx - w], n4 = visited[idx + w]
                    if n1 > 0 { nextVisited[idx] = n1 }
                    else if n2 > 0 { nextVisited[idx] = n2 }
                    else if n3 > 0 { nextVisited[idx] = n3 }
                    else if n4 > 0 { nextVisited[idx] = n4 }
                }
            }
        }
        visited = nextVisited
    }

    for i in 0..<(w * h) {
        let rid = Int(visited[i])
        if rid > 0 {
            let col = regionColors[rid]
            let p = i * 4
            let lum = Float(Int(data[p]) + Int(data[p+1]) + Int(data[p+2])) / (3.0 * 255.0)
            let inkFactor = max(0.0, min(1.0, (lum - 0.12) / 0.80))
            data[p]   = UInt8(Float(col.r) * inkFactor)
            data[p+1] = UInt8(Float(col.g) * inkFactor)
            data[p+2] = UInt8(Float(col.b) * inkFactor)
            data[p+3] = 255
        }
    }

    if let outCG = ctx.makeImage() {
        let rep = NSBitmapImageRep(cgImage: outCG)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: outPath))
        }
    }
}

let dir = "/Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/Blends/illustrations"
renderColoredScene(inPath: "\(dir)/act1_scene1_crop_flow_bw.png", outPath: "\(dir)/act1_scene1_crop_flow_color.png", classifier: colorScene1)
renderColoredScene(inPath: "\(dir)/act1_scene2_spud_flow_bw.png", outPath: "\(dir)/act1_scene2_spud_flow_color.png", classifier: colorScene2)
renderColoredScene(inPath: "\(dir)/act1_scene3_grub_flow_bw.png", outPath: "\(dir)/act1_scene3_grub_flow_color.png", classifier: colorScene3)
renderColoredScene(inPath: "\(dir)/act1_scene4_snag_flow_bw.png", outPath: "\(dir)/act1_scene4_snag_flow_color.png", classifier: colorScene4)
print("Colorized all 4 Act 1 Google Flow scenes.")
