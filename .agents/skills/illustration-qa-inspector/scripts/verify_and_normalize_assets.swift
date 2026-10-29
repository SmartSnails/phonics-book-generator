#!/usr/bin/env swift
// verify_and_normalize_assets.swift
// Deterministic QA checker and pure B&W line-art normalizer using macOS CoreGraphics/AppKit.
// Usage:
//   swift -module-cache-path /tmp/swift-cache verify_and_normalize_assets.swift --mode bw|color --input <in.jpg> --output <out.png>

import Foundation
import AppKit
import CoreGraphics

enum Mode: String {
    case bw = "bw"
    case color = "color"
}

var mode: Mode = .bw
var inputPath = ""
var outputPath = ""

var i = 1
let args = CommandLine.arguments
while i < args.count {
    switch args[i] {
    case "--mode":
        i += 1
        if i < args.count, let m = Mode(rawValue: args[i]) { mode = m }
    case "--input":
        i += 1
        if i < args.count { inputPath = args[i] }
    case "--output":
        i += 1
        if i < args.count { outputPath = args[i] }
    default:
        break
    }
    i += 1
}

guard !inputPath.isEmpty, !outputPath.isEmpty else {
    fputs("Usage: verify_and_normalize_assets.swift --mode bw|color --input <in> --output <out>\n", stderr)
    exit(1)
}

let inURL = URL(fileURLWithPath: inputPath)
guard let nsImage = NSImage(contentsOf: inURL),
      let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("ERROR: Cannot load image at \(inputPath)\n", stderr)
    exit(2)
}

let width = cgImage.width
let height = cgImage.height
let bytesPerPixel = 4
let bytesPerRow = width * bytesPerPixel
var rawData = [UInt8](repeating: 255, count: width * height * bytesPerPixel)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: &rawData,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("ERROR: Failed to create CGContext\n", stderr)
    exit(3)
}

context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

var darkPixels = 0
var grayMidPixels = 0
var colorfulPixels = 0
let totalPixels = width * height

for p in 0..<totalPixels {
    let idx = p * 4
    let r = Int(rawData[idx])
    let g = Int(rawData[idx + 1])
    let b = Int(rawData[idx + 2])
    let lum = (299 * r + 587 * g + 114 * b) / 1000
    let maxC = max(r, max(g, b))
    let minC = min(r, min(g, b))
    let satDiff = maxC - minC

    if satDiff > 35 {
        colorfulPixels += 1
    }

    if mode == .bw {
        // Clean paper grain and soft anti-aliased edges into crisp B&W coloring book lines
        if lum < 120 {
            rawData[idx] = 0
            rawData[idx + 1] = 0
            rawData[idx + 2] = 0
            rawData[idx + 3] = 255
            darkPixels += 1
        } else if lum > 205 {
            rawData[idx] = 255
            rawData[idx + 1] = 255
            rawData[idx + 2] = 255
            rawData[idx + 3] = 255
        } else {
            // Smooth curve for anti-aliased stroke edge
            let scaled = UInt8(min(255, max(0, (lum - 120) * 255 / 85)))
            rawData[idx] = scaled
            rawData[idx + 1] = scaled
            rawData[idx + 2] = scaled
            rawData[idx + 3] = 255
            grayMidPixels += 1
        }
    } else {
        if lum < 90 { darkPixels += 1 }
    }
}

guard let outCGImage = context.makeImage() else {
    fputs("ERROR: Failed to construct output CGImage\n", stderr)
    exit(4)
}

let bitmapRep = NSBitmapImageRep(cgImage: outCGImage)
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    fputs("ERROR: Failed to encode PNG\n", stderr)
    exit(5)
}

let outURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try pngData.write(to: outURL)

let inkPct = Double(darkPixels) * 100.0 / Double(totalPixels)
let colorPct = Double(colorfulPixels) * 100.0 / Double(totalPixels)
print(String(format: "{\"width\":%d,\"height\":%d,\"mode\":\"%@\",\"black_ink_pct\":%.2f,\"colorful_pct\":%.2f,\"output\":\"%@\"}", width, height, mode.rawValue, inkPct, colorPct, outputPath))
