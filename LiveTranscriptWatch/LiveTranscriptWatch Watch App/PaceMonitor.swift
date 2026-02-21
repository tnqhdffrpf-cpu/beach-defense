import CoreLocation
import Combine
import Foundation

@MainActor
final class PaceMonitor: NSObject, Combine.ObservableObject {
    @Combine.Published private(set) var currentPaceSecPerMile: Double?
    @Combine.Published private(set) var isRunning = false
    @Combine.Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()
    private var samples: [CLLocation] = []

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
    }

    func start() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }

        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            return
        }

        samples.removeAll()
        currentPaceSecPerMile = nil
        isRunning = true
        locationManager.startUpdatingLocation()
    }

    func stop() {
        isRunning = false
        locationManager.stopUpdatingLocation()
        samples.removeAll()
        currentPaceSecPerMile = nil
    }

    private func updatePace() {
        guard let first = samples.first, let last = samples.last else {
            currentPaceSecPerMile = nil
            return
        }

        let elapsed = last.timestamp.timeIntervalSince(first.timestamp)
        guard elapsed >= 8 else {
            currentPaceSecPerMile = nil
            return
        }

        var distance: CLLocationDistance = 0
        for i in 1..<samples.count {
            distance += samples[i].distance(from: samples[i - 1])
        }

        guard distance >= 10 else {
            currentPaceSecPerMile = nil
            return
        }

        let miles = distance / 1609.344
        guard miles > 0 else {
            currentPaceSecPerMile = nil
            return
        }

        currentPaceSecPerMile = elapsed / miles
    }
}

extension PaceMonitor: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if self.isRunning,
               manager.authorizationStatus != .authorizedAlways,
               manager.authorizationStatus != .authorizedWhenInUse {
                self.stop()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard self.isRunning else { return }

            let valid = locations.filter { location in
                location.horizontalAccuracy > 0 && location.horizontalAccuracy <= 40
            }

            guard !valid.isEmpty else { return }

            self.samples.append(contentsOf: valid)

            let cutoff = Date().addingTimeInterval(-30)
            self.samples.removeAll { $0.timestamp < cutoff }

            self.updatePace()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.stop()
        }
    }
}
