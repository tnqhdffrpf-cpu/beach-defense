import Combine
import CoreMotion
import Foundation
import WatchKit

@MainActor
final class MagneticFieldMonitor: ObservableObject {
    enum SensorMode: String {
        case magnetometer = "MAG"
        case deviceMotion = "DM"
        case unavailable = "NA"
    }

    @Published var isAvailable = true
    @Published var isRunning = false
    @Published var fieldStrengthMicrotesla: Double = 0
    @Published var smoothedFieldMicrotesla: Double = 0
    @Published var isMagnetDetected = false
    @Published var sensorMode: SensorMode = .unavailable

    // Spike-based detector tuning.
    // Trigger: only when raw field spikes clearly above local baseline.
    let detectAbsoluteMicrotesla: Double = 100
    let detectDeltaMicrotesla: Double = 45
    // Release: shut off fast once field drops back down.
    let releaseAbsoluteMicrotesla: Double = 78
    let releaseDeltaMicrotesla: Double = 20

    private let motionManager = CMMotionManager()
    private var hapticTimer: Timer?
    private var hasFilterSeed = false
    private var baselineMicrotesla: Double = 50
    private var hasBaselineSeed = false

    // Higher alpha = less lag.
    private let filterAlpha = 0.55
    private let baselineAlpha = 0.08

    func start() {
        guard !isRunning else { return }
        isRunning = true
        hasFilterSeed = false
        hasBaselineSeed = false

        if motionManager.isMagnetometerAvailable {
            isAvailable = true
            sensorMode = .magnetometer
            motionManager.magnetometerUpdateInterval = 0.02
            motionManager.startMagnetometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, self.isRunning else { return }
                guard let data else { return }
                self.consumeFieldVector(
                    x: data.magneticField.x,
                    y: data.magneticField.y,
                    z: data.magneticField.z
                )
            }
            return
        }

        // Fallback path for devices where direct magnetometer updates are unavailable.
        if motionManager.isDeviceMotionAvailable {
            isAvailable = true
            sensorMode = .deviceMotion
            motionManager.deviceMotionUpdateInterval = 0.02
            motionManager.startDeviceMotionUpdates(
                using: .xArbitraryCorrectedZVertical,
                to: .main
            ) { [weak self] motion, _ in
                guard let self, self.isRunning else { return }
                guard let motion else { return }
                let field = motion.magneticField.field
                self.consumeFieldVector(x: field.x, y: field.y, z: field.z)
            }
            return
        }

        isAvailable = false
        sensorMode = .unavailable
        stop()
    }

    private func consumeFieldVector(x: Double, y: Double, z: Double) {
        let rawMagnitude = sqrt((x * x) + (y * y) + (z * z))

        fieldStrengthMicrotesla = rawMagnitude
        let filtered = lowPass(rawMagnitude)
        smoothedFieldMicrotesla = filtered
        updateBaseline(with: rawMagnitude)
        evaluateDetection(rawMagnitude: rawMagnitude)
    }

    func stop() {
        motionManager.stopMagnetometerUpdates()
        motionManager.stopDeviceMotionUpdates()
        isRunning = false
        fieldStrengthMicrotesla = 0
        smoothedFieldMicrotesla = 0
        hasFilterSeed = false
        hasBaselineSeed = false
        baselineMicrotesla = 50
        setMagnetDetected(false)
    }

    private func lowPass(_ newValue: Double) -> Double {
        if !hasFilterSeed {
            hasFilterSeed = true
            smoothedFieldMicrotesla = newValue
            return newValue
        }

        let filtered = (filterAlpha * newValue) + ((1 - filterAlpha) * smoothedFieldMicrotesla)
        return filtered
    }

    private func updateBaseline(with rawMagnitude: Double) {
        // Keep baseline adaptive only while not actively detected.
        guard !isMagnetDetected else { return }

        if !hasBaselineSeed {
            hasBaselineSeed = true
            baselineMicrotesla = rawMagnitude
            return
        }

        baselineMicrotesla =
            (baselineAlpha * rawMagnitude) + ((1 - baselineAlpha) * baselineMicrotesla)
    }

    private func evaluateDetection(rawMagnitude: Double) {
        let deltaFromBaseline = rawMagnitude - baselineMicrotesla

        if isMagnetDetected {
            if rawMagnitude <= releaseAbsoluteMicrotesla || deltaFromBaseline <= releaseDeltaMicrotesla {
                setMagnetDetected(false)
            }
            return
        }

        if rawMagnitude >= detectAbsoluteMicrotesla && deltaFromBaseline >= detectDeltaMicrotesla {
            setMagnetDetected(true)
        }
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
        // Slightly slower cadence reduces audible ticking while staying tactile.
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.16, repeats: true) { _ in
            WKInterfaceDevice.current().play(.click)
        }
    }

    private func stopHaptics() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }

    deinit {
        motionManager.stopMagnetometerUpdates()
        motionManager.stopDeviceMotionUpdates()
        hapticTimer?.invalidate()
    }
}
