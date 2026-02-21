import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var monitor = MagneticFieldMonitor()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let hour24 = Calendar.current.component(.hour, from: context.date)
                let hour = hour24 % 12 == 0 ? 12 : hour24 % 12
                let minute = Calendar.current.component(.minute, from: context.date)

                VStack(spacing: -36) {
                    Text("\(hour)")
                        .font(.system(size: 122, weight: .black, design: .rounded))
                        .fontWidth(.expanded)
                        .foregroundStyle(Color(red: 0.96, green: 0.55, blue: 0.34))
                        .monospacedDigit()

                    Text(String(format: "%02d", minute))
                        .font(.system(size: 122, weight: .black, design: .rounded))
                        .fontWidth(.expanded)
                        .foregroundStyle(Color(red: 0.48, green: 0.59, blue: 0.60))
                        .monospacedDigit()

                    Text(context.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.63, green: 0.68, blue: 0.72))
                        .textCase(.uppercase)
                        .padding(.top, 2)
                }
                .offset(y: -24)
            }

            // Tiny status dot only you should notice.
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(monitor.isMagnetDetected ? Color.green.opacity(0.95) : Color.clear)
                        .frame(width: 6, height: 6)
                        .padding(.trailing, 6)
                        .padding(.bottom, 4)
                }
            }
        }
        .onAppear {
            monitor.start()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                monitor.start()
            } else {
                monitor.stop()
            }
        }
    }
}

#Preview {
    ContentView()
}
