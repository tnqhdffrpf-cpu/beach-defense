import AVFoundation
import WatchKit

final class BuzzSoundPlayer {
    static let shared = BuzzSoundPlayer()

    private var player: AVAudioPlayer?
    private var hapticTimer: Timer?

    private init() {}

    func startBuzz() {
        startHaptics()
        stopAudio()

        guard let url = Bundle.main.url(forResource: "buzz", withExtension: "wav") else {
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)

            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.numberOfLoops = -1
            audioPlayer.volume = 1.0
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            player = audioPlayer
        } catch {
            player = nil
        }
    }

    func stopBuzz() {
        stopAudio()
        stopHaptics()

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            // No-op.
        }
    }

    func startHaptics() {
        guard hapticTimer == nil else { return }
        WKInterfaceDevice.current().play(.click)
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            self.playPulse()
        }
    }

    func stopHaptics() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }

    private func stopAudio() {
        player?.stop()
        player = nil
    }

    private func playPulse() {
        DispatchQueue.main.async {
            WKInterfaceDevice.current().play(.click)
        }
    }
}
