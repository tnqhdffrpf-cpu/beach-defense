import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var beeX: CGFloat = -130
    @State private var beeY: CGFloat = 0
    @State private var beeScale: CGFloat = 0.75
    @State private var beeRotation: Double = 0
    @State private var isRunning = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.13, green: 0.16, blue: 0.24)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 8) {
                Spacer()

                Text("Tap To Buzz")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.86))

                Text("Cover the watch face to stop")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))

                Spacer()
            }

            Text("🐝")
                .font(.system(size: 62))
                .scaleEffect(beeScale)
                .rotationEffect(.degrees(beeRotation))
                .offset(x: beeX, y: beeY)
                .shadow(color: .yellow.opacity(0.22), radius: 6)
                .animation(.easeInOut(duration: 0.08).repeatCount(isRunning ? 10 : 0, autoreverses: true), value: beeRotation)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            startSequence()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                stopAll()
            }
        }
        .onDisappear {
            stopAll()
        }
    }

    private func startSequence() {
        guard !isRunning else { return }
        isRunning = true

        BuzzSoundPlayer.shared.startBuzz()

        beeX = 0
        beeY = 0
        beeScale = 0.8
        beeRotation = 0

        // Quick fly-out.
        withAnimation(.easeIn(duration: 0.28)) {
            beeX = 150
            beeY = -60
            beeScale = 0.62
        }

        // Re-enter and settle large at center.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            beeX = -150
            beeY = 16
            withAnimation(.spring(response: 0.44, dampingFraction: 0.7)) {
                beeX = 0
                beeY = 0
                beeScale = 1.25
            }
        }

        // Shake around center.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            beeRotation = 8
        }

        // Stop shake but keep buzz and centered bee.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeOut(duration: 0.18)) {
                beeRotation = 0
            }
            isRunning = false
        }
    }

    private func stopAll() {
        BuzzSoundPlayer.shared.stopBuzz()
        isRunning = false
        beeRotation = 0
    }
}

#Preview {
    ContentView()
}
