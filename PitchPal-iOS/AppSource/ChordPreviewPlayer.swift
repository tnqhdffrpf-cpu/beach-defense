import AVFoundation
import Foundation
import Combine

@MainActor
final class ChordPreviewPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var activeProgressionSignature: String?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let renderFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: renderFormat)
        player.volume = 1.0
    }

    func togglePlay(progression: [String]) {
        let signature = progression.joined(separator: "|")
        if isPlaying && activeProgressionSignature == signature {
            stop()
            return
        }
        play(progression: progression, signature: signature)
    }

    func progressionIsPlaying(_ progression: [String]) -> Bool {
        let signature = progression.joined(separator: "|")
        return isPlaying && activeProgressionSignature == signature
    }

    func stop() {
        player.stop()
        isPlaying = false
        activeProgressionSignature = nil
    }

    private func play(progression: [String], signature: String) {
        guard !progression.isEmpty else { return }

        do {
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            print("Failed to start chord preview engine: \(error)")
            return
        }

        guard let buffer = buildBuffer(for: progression) else { return }

        player.stop()
        isPlaying = true
        activeProgressionSignature = signature

        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = false
                self.activeProgressionSignature = nil
            }
        }
        player.play()
    }

    private func buildBuffer(for progression: [String]) -> AVAudioPCMBuffer? {
        let sampleRate = renderFormat.sampleRate
        let chordDuration = 0.72
        let gapDuration = 0.08

        let framesPerChord = Int(chordDuration * sampleRate)
        let gapFrames = Int(gapDuration * sampleRate)
        let totalFrames = progression.count * (framesPerChord + gapFrames)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: renderFormat, frameCapacity: AVAudioFrameCount(totalFrames)),
              let channel = buffer.floatChannelData?.pointee else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(totalFrames)

        var writeIndex = 0
        for chordName in progression {
            let frequencies = chordFrequencies(for: chordName)
            synthesizeChord(
                frequencies: frequencies,
                into: channel,
                startFrame: writeIndex,
                frameCount: framesPerChord,
                sampleRate: sampleRate
            )
            writeIndex += framesPerChord
            writeIndex += gapFrames
        }

        return buffer
    }

    private func synthesizeChord(
        frequencies: [Double],
        into buffer: UnsafeMutablePointer<Float>,
        startFrame: Int,
        frameCount: Int,
        sampleRate: Double
    ) {
        guard !frequencies.isEmpty else { return }

        let attackFrames = Int(sampleRate * 0.02)
        let releaseFrames = Int(sampleRate * 0.10)
        let toneGain = 0.30 / Double(frequencies.count)

        for frame in 0..<frameCount {
            let t = Double(frame) / sampleRate
            var sample = 0.0
            for freq in frequencies {
                let phase = 2.0 * Double.pi * freq * t
                let sine = sin(phase)
                let triangle = (2.0 / Double.pi) * asin(sin(phase))
                sample += (0.72 * sine) + (0.28 * triangle)
            }

            let envelope: Double
            if frame < attackFrames {
                envelope = Double(frame) / Double(max(1, attackFrames))
            } else if frame > frameCount - releaseFrames {
                envelope = Double(max(0, frameCount - frame)) / Double(max(1, releaseFrames))
            } else {
                envelope = 1.0
            }

            let mixed = sample * envelope * toneGain
            let clamped = max(-0.95, min(0.95, mixed))
            buffer[startFrame + frame] = Float(clamped)
        }
    }

    private func chordFrequencies(for chordName: String) -> [Double] {
        let isMinor = chordName.hasSuffix("m")
        let rootText = isMinor ? String(chordName.dropLast()) : chordName
        guard let pitchClass = MusicTheory.noteNames.firstIndex(of: rootText) else { return [] }

        // Mid-range guitar-like voicing.
        let baseMidi = 48 + pitchClass
        let triadIntervals = isMinor ? [0, 3, 7] : [0, 4, 7]
        let midiNotes = triadIntervals.map { baseMidi + $0 } + [baseMidi + 12]

        return midiNotes.map { midi in
            440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
        }
    }
}
