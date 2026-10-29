#!/usr/bin/env swift
// render_story_video.swift
// Compiles a 3-scene full-color story into an animated MP4 video (1080x1440 H.264 + AAC pleasant musical score)
// using macOS native AVFoundation and CoreGraphics.
// Usage:
//   swift -module-cache-path /tmp/swift-cache render_story_video.swift <video_manifest.json>

import Foundation
import AppKit
import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo

struct SceneClipSpec: Codable {
    let scene_number: Int
    let title: String
    let caption: String
    let image_path: String
    let camera_move: String   // "zoom_in", "pan_right", "zoom_out"
    let duration_sec: Double
}

struct VideoManifest: Codable {
    let theme_title: String
    let story_title: String
    let mood: String          // "farm" or "jungle"
    let output_mp4_path: String
    let scenes: [SceneClipSpec]
}

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: render_story_video.swift <video_manifest.json>\n", stderr)
    exit(1)
}

let manifestURL = URL(fileURLWithPath: CommandLine.arguments[1])
let manifestData = try Data(contentsOf: manifestURL)
let manifest = try JSONDecoder().decode(VideoManifest.self, from: manifestData)

let vidW = 1080
let vidH = 1440
let fps: Int32 = 30

let outURL = URL(fileURLWithPath: manifest.output_mp4_path)
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
if FileManager.default.fileExists(atPath: outURL.path) {
    try FileManager.default.removeItem(at: outURL)
}

let tempVideoURL = outURL.deletingLastPathComponent().appendingPathComponent("temp_video_\(UUID().uuidString).mp4")
let tempAudioURL = outURL.deletingLastPathComponent().appendingPathComponent("temp_audio_\(UUID().uuidString).wav")

// 1. Load CGImages for all scenes
var sceneImages: [CGImage] = []
for sc in manifest.scenes {
    let u = URL(fileURLWithPath: sc.image_path)
    guard let nsImg = NSImage(contentsOf: u),
          let cgImg = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fputs("ERROR: Cannot load scene image \(sc.image_path)\n", stderr)
        exit(2)
    }
    sceneImages.append(cgImg)
}

// 2. Render Video Track via AVAssetWriter
let writer = try AVAssetWriter(outputURL: tempVideoURL, fileType: .mp4)
let videoSettings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: vidW,
    AVVideoHeightKey: vidH
]
let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
writerInput.expectsMediaDataInRealTime = false

let sourceBufferAttrs: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
    kCVPixelBufferWidthKey as String: vidW,
    kCVPixelBufferHeightKey as String: vidH
]
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: sourceBufferAttrs)

writer.add(writerInput)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

func drawCaptionBanner(_ ctx: CGContext, storyTitle: String, sceneTitle: String, caption: String) {
    ctx.saveGState()
    // Top badge
    let topRect = CGRect(x: 40, y: CGFloat(vidH) - 105, width: CGFloat(vidW) - 80, height: 68)
    ctx.setFillColor(NSColor(calibratedWhite: 1.0, alpha: 0.88).cgColor)
    let topPath = CGPath(roundedRect: topRect, cornerWidth: 18, cornerHeight: 18, transform: nil)
    ctx.addPath(topPath)
    ctx.fillPath()
    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setLineWidth(3.0)
    ctx.addPath(topPath)
    ctx.strokePath()

    // Bottom story subtitle card
    let botRect = CGRect(x: 40, y: 36, width: CGFloat(vidW) - 80, height: 145)
    ctx.setFillColor(NSColor(calibratedWhite: 1.0, alpha: 0.90).cgColor)
    let botPath = CGPath(roundedRect: botRect, cornerWidth: 20, cornerHeight: 20, transform: nil)
    ctx.addPath(botPath)
    ctx.fillPath()
    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setLineWidth(3.5)
    ctx.addPath(botPath)
    ctx.strokePath()

    let graphicsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsCtx

    let pStyle = NSMutableParagraphStyle()
    pStyle.alignment = .center

    let topAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "ArialRoundedMTBold", size: 28) ?? NSFont.boldSystemFont(ofSize: 28),
        .foregroundColor: NSColor.black,
        .paragraphStyle: pStyle
    ]
    NSString(string: "\(storyTitle) — \(sceneTitle)").draw(in: CGRect(x: 56, y: CGFloat(vidH) - 96, width: CGFloat(vidW) - 112, height: 48), withAttributes: topAttrs)

    let capAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "ArialRoundedMTBold", size: 24) ?? NSFont.systemFont(ofSize: 24),
        .foregroundColor: NSColor.black,
        .paragraphStyle: pStyle
    ]
    NSString(string: caption).draw(in: CGRect(x: 64, y: 50, width: CGFloat(vidW) - 128, height: 112), withAttributes: capAttrs)

    NSGraphicsContext.restoreGraphicsState()
    ctx.restoreGState()
}

var currentFrame: Int64 = 0
let colorSpace = CGColorSpaceCreateDeviceRGB()

for (sIdx, sc) in manifest.scenes.enumerated() {
    let cgImg = sceneImages[sIdx]
    let totalFramesForScene = Int(sc.duration_sec * Double(fps))

    for f in 0..<totalFramesForScene {
        while !writerInput.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.005)
        }
        let progress = Double(f) / Double(max(1, totalFramesForScene - 1))
        var pixelBufferOut: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixelBufferOut)
        guard let pixelBuffer = pixelBufferOut else { continue }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: vidW,
            height: vidH,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) {
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: vidW, height: vidH))

            // Smooth Ken Burns camera motion
            var scale = 1.05
            var offsetX = 0.0
            var offsetY = 0.0
            if sc.camera_move == "zoom_in" {
                scale = 1.0 + 0.14 * progress
            } else if sc.camera_move == "zoom_out" {
                scale = 1.14 - 0.14 * progress
            } else if sc.camera_move == "pan_right" {
                scale = 1.12
                offsetX = -45.0 + 90.0 * progress
            } else {
                scale = 1.04 + 0.08 * sin(progress * .pi)
            }

            let imgW = Double(cgImg.width)
            let imgH = Double(cgImg.height)
            let baseScale = max(Double(vidW) / imgW, Double(vidH) / imgH) * scale
            let drawW = imgW * baseScale
            let drawH = imgH * baseScale
            let drawX = (Double(vidW) - drawW) / 2.0 + offsetX
            let drawY = (Double(vidH) - drawH) / 2.0 + offsetY

            ctx.interpolationQuality = .high
            ctx.draw(cgImg, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))

            // Subtle fade-in at start of scene and fade-out at end
            if f < 10 {
                let alpha = CGFloat(10 - f) / 10.0 * 0.6
                ctx.setFillColor(NSColor(calibratedWhite: 1.0, alpha: alpha).cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: vidW, height: vidH))
            } else if f > totalFramesForScene - 10 {
                let alpha = CGFloat(f - (totalFramesForScene - 10)) / 10.0 * 0.6
                ctx.setFillColor(NSColor(calibratedWhite: 1.0, alpha: alpha).cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: vidW, height: vidH))
            }

            drawCaptionBanner(ctx, storyTitle: manifest.story_title, sceneTitle: sc.title, caption: sc.caption)
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        let presentationTime = CMTimeMake(value: currentFrame, timescale: fps)
        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        currentFrame += 1
    }
}

writerInput.markAsFinished()
let waitSem = DispatchSemaphore(value: 0)
writer.finishWriting {
    waitSem.signal()
}
waitSem.wait()

// 3. Synthesize a cheerful music-box/marimba WAV audio score matching total duration
let totalDurationSec = manifest.scenes.reduce(0.0) { $0 + $1.duration_sec }
let sampleRate = 44100
let numSamples = Int(totalDurationSec * Double(sampleRate))

// Pentatonic melody frequencies (C major / G major playful intervals)
let farmNotes: [Double] = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 392.00, 329.63]
let jungleNotes: [Double] = [293.66, 329.63, 392.00, 440.00, 493.88, 587.33, 440.00, 392.00]
let melody = (manifest.mood == "jungle") ? jungleNotes : farmNotes
let noteDuration = 0.45

var pcmSamples = [Int16](repeating: 0, count: numSamples)
for s in 0..<numSamples {
    let t = Double(s) / Double(sampleRate)
    let noteIdx = Int(t / noteDuration) % melody.count
    let noteTime = t.truncatingRemainder(dividingBy: noteDuration)
    let freq = melody[noteIdx]
    // Gentle music-box pluck envelope + warm fifth harmony
    let env = exp(-4.5 * noteTime) * min(1.0, noteTime / 0.015)
    let wave = sin(2.0 * .pi * freq * t) + 0.35 * sin(2.0 * .pi * (freq * 1.5) * t) + 0.2 * sin(2.0 * .pi * (freq * 2.0) * t)
    let sampleVal = max(-0.85, min(0.85, wave * env * 0.28))
    pcmSamples[s] = Int16(sampleVal * 32767.0)
}

// Write 16-bit mono WAV header + data
var wavData = Data()
let dataSize = UInt32(numSamples * 2)
let fileSize = dataSize + 36
wavData.append("RIFF".data(using: .ascii)!)
withUnsafeBytes(of: fileSize.littleEndian) { wavData.append(contentsOf: $0) }
wavData.append("WAVEfmt ".data(using: .ascii)!)
withUnsafeBytes(of: UInt32(16).littleEndian) { wavData.append(contentsOf: $0) }
withUnsafeBytes(of: UInt16(1).littleEndian) { wavData.append(contentsOf: $0) }  // PCM
withUnsafeBytes(of: UInt16(1).littleEndian) { wavData.append(contentsOf: $0) }  // 1 channel
withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { wavData.append(contentsOf: $0) }
withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { wavData.append(contentsOf: $0) }
withUnsafeBytes(of: UInt16(2).littleEndian) { wavData.append(contentsOf: $0) }
withUnsafeBytes(of: UInt16(16).littleEndian) { wavData.append(contentsOf: $0) }
wavData.append("data".data(using: .ascii)!)
withUnsafeBytes(of: dataSize.littleEndian) { wavData.append(contentsOf: $0) }
pcmSamples.withUnsafeBytes { wavData.append(contentsOf: $0) }
try wavData.write(to: tempAudioURL)

// 4. Mux Video + Audio into final MP4 using AVMutableComposition + AVAssetExportSession
let composition = AVMutableComposition()
let videoAsset = AVURLAsset(url: tempVideoURL)
let audioAsset = AVURLAsset(url: tempAudioURL)

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
    exporter.outputURL = outURL
    exporter.outputFileType = .mp4
    exporter.exportAsynchronously {
        exportSem.signal()
    }
    exportSem.wait()
}

try? FileManager.default.removeItem(at: tempVideoURL)
try? FileManager.default.removeItem(at: tempAudioURL)

print("Rendered story short video (\(totalDurationSec)s, \(vidW)x\(vidH) MP4 with music score) -> \(outURL.path)")
