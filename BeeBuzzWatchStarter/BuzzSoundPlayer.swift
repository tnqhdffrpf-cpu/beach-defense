import AVFoundation
import WatchKit

final class BuzzSoundPlayer {
    static let shared = BuzzSoundPlayer()

    private var player: AVAudioPlayer?
    private var hapticTimer: Timer?

    private init() {}

    func startBuzz() {
        stopBuzz()

        if let url = Bundle.main.url(forResource: "buzz", withExtension: "wav") {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback)
                try session.setActive(true)

                let p = try AVAudioPlayer(contentsOf: url)
                p.numberOfLoops = -1
                p.volume = 1.0
                p.prepareToPlay()
                p.play()
                player = p
                return
            } catch {
                // Falls back to haptics below if audio setup fails.
            }
        }

        // Fallback for when no buzz.wav is bundled.
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { _ in
            WKInterfaceDevice.current().play(.directionUp)
        }
    }

    func stopBuzz() {
        player?.stop()
        player = nil

        hapticTimer?.invalidate()
        hapticTimer = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            // No-op.
        }
    }
}
