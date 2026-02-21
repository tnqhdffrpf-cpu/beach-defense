import CoreLocation
import Combine
import SwiftUI

struct PaceCoachView: View {
    @StateObject private var monitor = PaceMonitor()
    @State private var coach = FeedbackCoach()

    @State private var lockedPaceSecPerMile: Double?
    @State private var toleranceSeconds = 30

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    Text(zoneLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(zoneColor)

                    Text(currentPaceText)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.45)

                    Text(lockedPaceLabel)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    if let delta = deltaSeconds {
                        Text(deltaText(delta))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(deltaColor(delta))
                    }

                    VStack(spacing: 6) {
                        HStack {
                            Text("Range")
                            Spacer()
                            Text("\(toleranceSeconds)s")
                                .monospacedDigit()
                        }

                        HStack(spacing: 8) {
                            Button("-15s") { toleranceSeconds = max(15, toleranceSeconds - 15) }
                            Button("+15s") { toleranceSeconds = min(180, toleranceSeconds + 15) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                    Button(action: toggleRun) {
                        Text(monitor.isRunning ? "Stop" : "Start")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(monitor.isRunning ? .red : .green)

                    if monitor.isRunning {
                        HStack(spacing: 8) {
                            Button("Lock Pace") {
                                if let current = monitor.currentPaceSecPerMile {
                                    lockedPaceSecPerMile = current
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .disabled(monitor.currentPaceSecPerMile == nil)

                            Button("Unlock") {
                                lockedPaceSecPerMile = nil
                            }
                            .buttonStyle(.bordered)
                            .disabled(lockedPaceSecPerMile == nil)
                        }
                    }

                    if monitor.authorizationStatus == .denied || monitor.authorizationStatus == .restricted {
                        Text("Allow Location on Watch for pace tracking")
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
        }
        .onChange(of: zone) { _, newZone in
            let canCoach = monitor.isRunning && lockedPaceSecPerMile != nil
            coach.apply(zone: canCoach ? newZone : .unknown)
        }
        .onChange(of: monitor.isRunning) { _, running in
            if !running {
                coach.stop()
                lockedPaceSecPerMile = nil
            }
        }
        .onDisappear {
            coach.stop()
            monitor.stop()
        }
    }

    private var deltaSeconds: Double? {
        guard let locked = lockedPaceSecPerMile else { return nil }
        guard let current = monitor.currentPaceSecPerMile else { return nil }
        return current - locked
    }

    private var zone: PaceZone {
        guard let delta = deltaSeconds else { return .unknown }
        if delta >= Double(toleranceSeconds) { return .slow }
        if delta <= -Double(toleranceSeconds) { return .fast }
        return .inRange
    }

    private var zoneLabel: String {
        switch zone {
        case .unknown:
            return monitor.isRunning ? "LOCKING PACE" : "READY"
        case .inRange:
            return "ON TARGET"
        case .slow:
            return "TOO SLOW"
        case .fast:
            return "FAST ZONE"
        }
    }

    private var zoneColor: Color {
        switch zone {
        case .unknown:
            return .gray
        case .inRange:
            return .green
        case .slow:
            return .red
        case .fast:
            return .cyan
        }
    }

    private var currentPaceText: String {
        guard let current = monitor.currentPaceSecPerMile else {
            return monitor.isRunning ? "--:-- /mi" : "Tap Start"
        }
        return "\(formatPace(current)) /mi"
    }

    private var lockedPaceLabel: String {
        if let locked = lockedPaceSecPerMile {
            return "Locked \(formatPace(locked)) /mi"
        }
        return "No locked pace"
    }

    private func toggleRun() {
        if monitor.isRunning {
            monitor.stop()
            coach.stop()
        } else {
            monitor.start()
        }
    }

    private func formatPace(_ secondsPerMile: Double) -> String {
        let total = Int(secondsPerMile.rounded())
        let minutes = max(0, total / 60)
        let seconds = max(0, total % 60)
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func deltaText(_ delta: Double) -> String {
        if delta > 0 {
            return String(format: "+%.0fs slower", delta)
        } else if delta < 0 {
            return String(format: "%.0fs faster", abs(delta))
        }
        return "On target"
    }

    private func deltaColor(_ delta: Double) -> Color {
        if delta >= Double(toleranceSeconds) { return .red }
        if delta <= -Double(toleranceSeconds) { return .cyan }
        return .green
    }
}

#Preview {
    PaceCoachView()
}
