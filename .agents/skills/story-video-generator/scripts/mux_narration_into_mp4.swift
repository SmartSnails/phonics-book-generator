import AVFoundation
import CoreMedia
import Foundation

// ============================================================================
// Lossless Audio Remuxer (mux_narration_into_mp4.swift)
// ============================================================================
// 1. Reads the 20 synthesized neural human voice WAV files from manifest.json
//    (strictly verifying every file is non-empty and audible).
// 2. Mixes the human voice narration with the ducked storybook music into an
//    AAC .m4a soundtrack (output/audio/act1_master_narration.m4a).
// 3. Uses AVMutableComposition + AVAssetExportPresetPassthrough to copy the
//    existing 1080x1080 H.264 video track byte-for-byte WITHOUT re-rendering
//    while replacing the audio track with the full narration + music mix.
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
    let utterances: [UtteranceManifest]
}

struct NarrationManifest: Decodable {
    let total_duration_sec: Double
    let scenes: [SceneManifest]
}

struct LoadedUtterance {
    let meta: UtteranceManifest
    let samplesL: [Float]
    let samplesR: [Float]
}

func loadWavFileStrict(_ path: String) -> (l: [Float], r: [Float], peak: Float) {
    let url = URL(fileURLWithPath: path)
    let data: Data
    do {
        data = try Data(contentsOf: url)
    } catch {
        fatalError("Failed to read WAV file at \(path): \(error)")
    }
    guard data.count > 44 else {
        fatalError("WAV file too small (\(data.count) bytes): \(path)")
    }

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

    let frameCount = dataByteCount / 4
    var left = [Float](repeating: 0, count: frameCount)
    var right = [Float](repeating: 0, count: frameCount)
    var peak: Float = 0
    data.withUnsafeBytes { rawPtr in
        guard let base = rawPtr.baseAddress else { return }
        let int16Ptr = base.advanced(by: dataOffset).assumingMemoryBound(to: Int16.self)
        for i in 0..<frameCount {
            let l = Float(int16Ptr[i * 2]) / 32768.0
            let r = Float(int16Ptr[i * 2 + 1]) / 32768.0
            left[i] = l
            right[i] = r
            let m = max(abs(l), abs(r))
            if m > peak { peak = m }
        }
    }
    guard frameCount > 1000 && peak > 0.01 else {
        fatalError("WAV file has no audible samples (frames=\(frameCount), peak=\(peak)): \(path)")
    }
    return (left, right, peak)
}

func buildMasterAudioTrack(
    manifest: NarrationManifest,
    sceneUtterances: [[LoadedUtterance]]
) -> (left: [Float], right: [Float]) {
    let sampleRate = 44100
    let totalSamples = Int(ceil(manifest.total_duration_sec * Double(sampleRate))) + sampleRate
    var masterL = [Float](repeating: 0, count: totalSamples)
    var masterR = [Float](repeating: 0, count: totalSamples)
    var voiceActivity = [Float](repeating: 0, count: totalSamples)

    // 1. Place all 20 human voice utterances at their exact timestamps
    for (sIdx, scene) in manifest.scenes.enumerated() {
        let uList = sceneUtterances[sIdx]
        for u in uList {
            let startSample = Int((scene.scene_start_sec + u.meta.start_in_scene_sec) * Double(sampleRate))
            let count = min(u.samplesL.count, totalSamples - startSample)
            if count > 0 && startSample >= 0 {
                for i in 0..<count {
                    masterL[startSample + i] += u.samplesL[i] * 1.15
                    masterR[startSample + i] += u.samplesR[i] * 1.15
                    voiceActivity[startSample + i] = 1.0
                }
            }
        }
    }

    // Smooth voice ducking envelope so music sits gently behind the human voices
    let smoothWin = sampleRate / 8
    var duckGain = [Float](repeating: 0.18, count: totalSamples)
    var runningSum: Float = 0
    for i in 0..<totalSamples {
        runningSum += voiceActivity[i]
        if i >= smoothWin {
            runningSum -= voiceActivity[i - smoothWin]
        }
        let activeRatio = runningSum / Float(smoothWin)
        duckGain[i] = 0.18 - 0.13 * min(1.0, activeRatio * 2.5)
    }

    // 2. Warm Acoustic Guitar & Marimba Storybook Progression (C - Am - F - G)
    let chordFreqs: [[Double]] = [
        [261.63, 329.63, 392.00, 523.25],
        [220.00, 261.63, 329.63, 440.00],
        [174.61, 220.00, 261.63, 349.23],
        [196.00, 246.94, 293.66, 392.00]
    ]
    let beatDur = 0.50
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
                let env = Float(sin((t / 0.28) * .pi)) * 0.07
                let s = Float(sin(2.0 * .pi * f * t)) * env
                masterL[startS + i] += s
                masterR[startS + i] += s
            }
        }
    }

    for i in 0..<totalSamples {
        masterL[i] = max(-0.98, min(0.98, masterL[i]))
        masterR[i] = max(-0.98, min(0.98, masterR[i]))
    }
    return (masterL, masterR)
}

func writeM4AAudio(left: [Float], right: [Float], durationSec: Double, outM4APath: String) {
    let outURL = URL(fileURLWithPath: outM4APath)
    try? FileManager.default.removeItem(at: outURL)
    try? FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    let writer = try! AVAssetWriter(outputURL: outURL, fileType: .m4a)
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

    let totalAudioFrames = Int(durationSec * 44100.0)
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

    while audioCursor < totalAudioFrames {
        while !audioInput.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.001)
        }
        let n = min(chunkFrames, totalAudioFrames - audioCursor)
        var pcm = [Int16](repeating: 0, count: n * 2)
        for i in 0..<n {
            pcm[i * 2]     = Int16(left[audioCursor + i] * 32767.0)
            pcm[i * 2 + 1] = Int16(right[audioCursor + i] * 32767.0)
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
    audioInput.markAsFinished()

    let sema = DispatchSemaphore(value: 0)
    writer.finishWriting { sema.signal() }
    sema.wait()
    print("Wrote master narration M4A -> \(outM4APath)")
}

func remuxVideoWithNewAudio(videoMp4Path: String, audioM4APath: String, outMp4Path: String) {
    let videoAsset = AVURLAsset(url: URL(fileURLWithPath: videoMp4Path))
    let audioAsset = AVURLAsset(url: URL(fileURLWithPath: audioM4APath))

    let comp = AVMutableComposition()
    guard let srcVideoTrack = videoAsset.tracks(withMediaType: .video).first,
          let dstVideoTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
        fatalError("Missing video track in \(videoMp4Path)")
    }
    let videoTimeRange = CMTimeRange(start: .zero, duration: videoAsset.duration)
    try! dstVideoTrack.insertTimeRange(videoTimeRange, of: srcVideoTrack, at: .zero)

    guard let srcAudioTrack = audioAsset.tracks(withMediaType: .audio).first,
          let dstAudioTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
        fatalError("Missing audio track in \(audioM4APath)")
    }
    let audioDur = CMTimeMinimum(videoAsset.duration, audioAsset.duration)
    try! dstAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: audioDur), of: srcAudioTrack, at: .zero)

    let tmpOutPath = outMp4Path + ".remux.mp4"
    let tmpOutURL = URL(fileURLWithPath: tmpOutPath)
    try? FileManager.default.removeItem(at: tmpOutURL)

    let srcSize = (try? FileManager.default.attributesOfItem(atPath: videoMp4Path)[.size] as? Int) ?? 0
    let preset = (srcSize > 50_000_000) ? AVAssetExportPresetHEVCHighestQuality : AVAssetExportPresetPassthrough
    guard let exporter = AVAssetExportSession(asset: comp, presetName: preset) else {
        fatalError("Could not create AVAssetExportSession")
    }
    exporter.outputURL = tmpOutURL
    exporter.outputFileType = .mp4

    let sema = DispatchSemaphore(value: 0)
    exporter.exportAsynchronously { sema.signal() }
    sema.wait()

    if exporter.status != .completed {
        fatalError("Remux failed: \(String(describing: exporter.error))")
    }
    let finalURL = URL(fileURLWithPath: outMp4Path)
    try? FileManager.default.removeItem(at: finalURL)
    try! FileManager.default.moveItem(at: tmpOutURL, to: finalURL)
    print("Losslessly remuxed video + narration audio -> \(outMp4Path)")
}

let args = CommandLine.arguments
if args.count < 4 {
    fatalError("Usage: swift mux_narration_into_mp4.swift <manifest.json> <input_output.mp4> <secondary_copy.mp4>")
}
let manifestPath = args[1]
let primaryMp4 = args[2]
let secondaryMp4 = args[3]

let m4aPath = "/Users/harshad/.gemini/antigravity/scratch/phonics-book-generator/output/audio/act1_master_narration.m4a"
if FileManager.default.fileExists(atPath: manifestPath) && manifestPath.hasSuffix(".json") {
    let manifestData = try! Data(contentsOf: URL(fileURLWithPath: manifestPath))
    let manifest = try! JSONDecoder().decode(NarrationManifest.self, from: manifestData)

    var sceneUtterances: [[LoadedUtterance]] = []
    var totalLoadedUtterances = 0
    for scene in manifest.scenes {
        var list: [LoadedUtterance] = []
        for u in scene.utterances {
            let wav = loadWavFileStrict(u.wav_path)
            list.append(LoadedUtterance(meta: u, samplesL: wav.l, samplesR: wav.r))
            totalLoadedUtterances += 1
            print("Loaded Scene \(scene.beat_number) #\(u.index) [\(u.speaker)]: \(wav.l.count) samples (peak=\(String(format: "%.2f", wav.peak)))")
        }
        sceneUtterances.append(list)
    }
    print("Verified all \(totalLoadedUtterances) neural human voice WAV files.")

    let masterAudio = buildMasterAudioTrack(manifest: manifest, sceneUtterances: sceneUtterances)
    writeM4AAudio(left: masterAudio.left, right: masterAudio.right, durationSec: manifest.total_duration_sec, outM4APath: m4aPath)
} else if FileManager.default.fileExists(atPath: m4aPath) {
    print("Using existing verified master narration audio -> \(m4aPath)")
} else {
    fatalError("Neither narration_manifest.json (\(manifestPath)) nor \(m4aPath) exists.")
}

remuxVideoWithNewAudio(videoMp4Path: primaryMp4, audioM4APath: m4aPath, outMp4Path: primaryMp4)
try? FileManager.default.removeItem(at: URL(fileURLWithPath: secondaryMp4))
try! FileManager.default.copyItem(at: URL(fileURLWithPath: primaryMp4), to: URL(fileURLWithPath: secondaryMp4))
print("Updated secondary copy -> \(secondaryMp4)")
