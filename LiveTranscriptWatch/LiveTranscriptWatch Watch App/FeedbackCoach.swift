import Foundation
import WatchKit

enum PaceZone {
    case unknown
    case inRange
    case slow
    case fast
}

@MainActor
final class FeedbackCoach {
    private var timer: Timer?
    private var currentZone: PaceZone = .unknown
    private var slowPulseToggle = false

    func apply(zone: PaceZone) {
        guard zone != currentZone else { return }
        currentZone = zone
        timer?.invalidate()
        timer = nil

        switch zone {
        case .slow:
            playSlowPulse()
            timer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.playSlowPulse()
                }
            }
        case .fast:
            WKInterfaceDevice.current().play(.success)
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                WKInterfaceDevice.current().play(.success)
            }
        case .inRange, .unknown:
            break
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        currentZone = .unknown
    }

    private func playSlowPulse() {
        slowPulseToggle.toggle()
        WKInterfaceDevice.current().play(slowPulseToggle ? .failure : .retry)
    }
}
