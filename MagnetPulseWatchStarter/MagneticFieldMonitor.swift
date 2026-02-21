import CoreMotion
import Foundation
import WatchKit

@MainActor
final class MagneticFieldMonitor: ObservableObject {
    @Published var isAvailable = true
    @Published var isRunning = false
    @Published var fieldStrengthMicrotesla: Double = 0
    @Published var isMagnetDetected = false

    // Earth's field is often ~25-65 uT. This trips on strong nearby magnets.
    let thresholdMicrotesla: Double = 130

    private let motionManager = CMMotionManager()
    private var hapticTimer: Timer?

    func start() {
        guard motionManager.isMagnetometerAvailable else {
            isAvailable = false
            stop()
            return
        }

        guard !isRunning else { return }
        isAvailable = true
        isRunning = true

        motionManager.magnetometerUpdateInterval = 0.05
        motionManager.startMagnetometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, self.isRunning else { return }
            guard let data else { return }

            let x = data.magneticField.x
            let y = data.magneticField.y
            let z = data.magneticField.z
            let magnitude = sqrt((x * x) + (y * y) + (z * z))

            self.fieldStrengthMicrotesla = magnitude
            self.setMagnetDetected(magnitude >= self.thresholdMicrotesla)
        }
    }

    func stop() {
        motionManager.stopMagnetometerUpdates()
        isRunning = false
        fieldStrengthMicrotesla = 0
        setMagnetDetected(false)
    }

    private func setMagnetDetected(_ detected: Bool) {
        guard isMagnetDetected != detected else { return }
        isMagnetDetected = detected

        if detected {
            startHaptics()
        } else {
            stopHaptics()
        }
    }

    private func startHaptics() {
        guard hapticTimer == nil else { return }

        WKInterfaceDevice.current().play(.click)
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            WKInterfaceDevice.current().play(.click)
        }
    }

    private func stopHaptics() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }

    deinit {
        motionManager.stopMagnetometerUpdates()
        hapticTimer?.invalidate()
    }
}
