import AVFoundation
import Foundation
import Combine

@MainActor
final class AudioPitchManager: ObservableObject {
    @Published var isCapturing = false
    @Published var currentNoteText = "-"
    @Published var capturedNotes: [NoteEvent] = []
    @Published var captureError: String?

    private let audioEngine = AVAudioEngine()
    private var recentMidi: [Int] = []
    private let stableWindowSize = 2
    private var activeNoteIndex: Int?

    func toggleCapture() {
        isCapturing ? stopCapture() : startCapture()
    }

    func startCapture() {
        captureError = nil
        requestMicAccessIfNeeded { [weak self] granted in
            guard let self else { return }
            if granted {
                Task { @MainActor in
                    self.configureSessionAndStart()
                }
            } else {
                Task { @MainActor in
                    self.captureError = "Microphone access denied."
                }
            }
        }
    }

    func stopCapture() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isCapturing = false
        recentMidi.removeAll()
        activeNoteIndex = nil
    }

    func clearNotes() {
        capturedNotes.removeAll()
        currentNoteText = "-"
        activeNoteIndex = nil
    }

    private func configureSessionAndStart() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true)

            let input = audioEngine.inputNode
            let format = input.inputFormat(forBus: 0)
            let bufferSize: AVAudioFrameCount = 512

            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer, sampleRate: format.sampleRate)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isCapturing = true
        } catch {
            captureError = "Failed to start audio: \(error.localizedDescription)"
        }
    }

    private func requestMicAccessIfNeeded(_ completion: @escaping (Bool) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission(completion)
        @unknown default:
            completion(false)
        }
    }

    nonisolated private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channel = buffer.floatChannelData?.pointee else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }

        guard let frequency = PitchDetector.detectFrequency(samples: channel, count: count, sampleRate: sampleRate) else {
            return
        }

        let frameDuration = Double(count) / sampleRate
        let midi = PitchDetector.frequencyToMidi(frequency)
        Task { @MainActor in
            self.acceptMidi(midi, frameDuration: frameDuration)
        }
    }

    private func acceptMidi(_ midi: Int, frameDuration: TimeInterval) {
        recentMidi.append(midi)
        if recentMidi.count > stableWindowSize {
            recentMidi.removeFirst()
        }

        let stableMidi: Int
        if recentMidi.count < stableWindowSize {
            stableMidi = midi
        } else {
            stableMidi = mode(recentMidi)
        }

        let noteName = MusicTheory.midiToNoteName(stableMidi)
        currentNoteText = noteName

        if let index = activeNoteIndex {
            if capturedNotes[index].midi == stableMidi {
                capturedNotes[index].duration += frameDuration
            } else {
                capturedNotes.append(NoteEvent(midi: stableMidi, noteName: noteName))
                activeNoteIndex = capturedNotes.indices.last
            }
        } else {
            capturedNotes.append(NoteEvent(midi: stableMidi, noteName: noteName))
            activeNoteIndex = capturedNotes.indices.last
        }
    }

    private func mode(_ values: [Int]) -> Int {
        var counts: [Int: Int] = [:]
        for v in values {
            counts[v, default: 0] += 1
        }
        return counts.max(by: { a, b in
            if a.value == b.value { return a.key > b.key }
            return a.value < b.value
        })?.key ?? values.last ?? 60
    }
}
