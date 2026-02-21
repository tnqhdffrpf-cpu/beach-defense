import AVFoundation
import Combine
import Speech
import WatchConnectivity

@MainActor
final class CompanionTranscriptBridge: NSObject, ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isListening = false
    @Published private(set) var permissionError: String?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    override init() {
        super.init()
        configureWatchSession()
    }

    func startListening() {
        Task {
            let authorized = await requestPermissionsIfNeeded()
            guard authorized else { return }
            startRecognitionPipeline()
        }
    }

    func stopListening() {
        stopRecognitionPipeline()
        isListening = false
        pushTranscriptToWatch()
    }

    private func startRecognitionPipeline() {
        guard !audioEngine.isRunning else {
            isListening = true
            pushTranscriptToWatch()
            return
        }

        permissionError = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            pushTranscriptToWatch()
        } catch {
            permissionError = "Microphone could not start."
            stopRecognitionPipeline()
            return
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            Task { @MainActor in
                if let result {
                    let newText = result.bestTranscription.formattedString
                    if self.transcript != newText {
                        self.transcript = newText
                        self.pushTranscriptToWatch()
                    }
                }

                if error != nil {
                    self.permissionError = "Speech recognition stopped unexpectedly."
                    self.stopListening()
                }
            }
        }
    }

    private func stopRecognitionPipeline() {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestPermissionsIfNeeded() async -> Bool {
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        let micAuthorized = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        if speechAuthorized && micAuthorized {
            permissionError = nil
            return true
        }

        permissionError = "Enable Speech Recognition and Microphone in Settings."
        return false
    }

    private func configureWatchSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func pushTranscriptToWatch() {
        guard WCSession.isSupported() else { return }

        let payload: [String: Any] = [
            "text": transcript,
            "isListening": isListening,
            "timestamp": Date().timeIntervalSince1970
        ]

        let session = WCSession.default
        if session.activationState == .activated {
            try? session.updateApplicationContext(payload)

            if session.isReachable {
                session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
            }
        }
    }
}

extension CompanionTranscriptBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let request = message["request"] as? String, request == "latest" else { return }

        Task { @MainActor in
            self.pushTranscriptToWatch()
        }
    }
}
