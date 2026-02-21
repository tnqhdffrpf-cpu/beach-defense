import SwiftUI
import WatchKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var beeX: CGFloat = 240
    @State private var beeY: CGFloat = 0
    @State private var beeScale: CGFloat = 1.0
    @State private var beeRotation: Double = 0
    @State private var watchFaceOpacity: Double = 1.0
    @State private var isBuzzing = false
    @State private var isReturningToFace = false
    @State private var sequenceToken = UUID()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let hour24 = Calendar.current.component(.hour, from: context.date)
                let hour = hour24 % 12 == 0 ? 12 : hour24 % 12
                let minute = Calendar.current.component(.minute, from: context.date)

                VStack(spacing: -52) {
                    Text("\(hour)")
                        .font(.system(size: 127, weight: .black, design: .rounded))
                        .fontWidth(.expanded)
                        .foregroundStyle(Color(red: 0.96, green: 0.55, blue: 0.34))
                        .monospacedDigit()

                    Text(String(format: "%02d", minute))
                        .font(.system(size: 127, weight: .black, design: .rounded))
                        .fontWidth(.expanded)
                        .foregroundStyle(Color(red: 0.48, green: 0.59, blue: 0.60))
                        .monospacedDigit()

                    Text(context.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.64, green: 0.7, blue: 0.78))
                        .textCase(.uppercase)
                        .padding(.top, 2)
                }
                .offset(y: -26)
                .opacity(watchFaceOpacity)
            }

            Image("Image")
                .resizable()
                .scaledToFit()
                .frame(width: 153, height: 153)
                // Slight zoom + clip trims edge artifacts from non-transparent source images.
                .scaleEffect(1.06)
                .clipped()
                .scaleEffect(beeScale)
                .rotationEffect(.degrees(beeRotation))
                .offset(x: beeX, y: beeY)
                .shadow(color: .yellow.opacity(0.2), radius: 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isBuzzing {
                stopAll(withReturnTransition: true)
            } else {
                guard !isReturningToFace else { return }
                startSequence()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                resetToIdle()
            } else {
                stopAll()
            }
        }
        .onDisappear {
            stopAll()
        }
    }

    private func startSequence() {
        guard !isBuzzing else { return }
        guard !isReturningToFace else { return }
        isBuzzing = true
        let currentToken = UUID()
        sequenceToken = currentToken

        beeX = 240
        beeY = 0
        beeScale = 1.0
        beeRotation = 0
        watchFaceOpacity = 1.0
        BuzzSoundPlayer.shared.startHaptics()

        Task { @MainActor in
            // Keep watch-face look for 3 seconds.
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard sequenceToken == currentToken, isBuzzing else { return }

            // Fade out watch-face over the next 2 seconds.
            withAnimation(.easeInOut(duration: 2.0)) {
                watchFaceOpacity = 0
            }

            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard sequenceToken == currentToken, isBuzzing else { return }

            BuzzSoundPlayer.shared.startBuzz()

            // Fly in quickly, then stay large at center.
            withAnimation(.easeOut(duration: 0.4)) {
                beeX = 0
                beeScale = 1.6
            }

            // Start continuous shake while buzzing.
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard sequenceToken == currentToken, isBuzzing else { return }

            withAnimation(.easeInOut(duration: 0.05).repeatForever(autoreverses: true)) {
                beeRotation = 8
            }
        }
    }

    private func stopAll() {
        stopAll(withReturnTransition: false)
    }

    private func stopAll(withReturnTransition: Bool) {
        let currentToken = UUID()
        sequenceToken = currentToken
        BuzzSoundPlayer.shared.stopBuzz()
        isBuzzing = false

        // Immediately hide all content for a full-black stop moment.
        beeX = 240
        beeY = 0
        beeScale = 1.0
        beeRotation = 0
        watchFaceOpacity = 0

        guard withReturnTransition else {
            isReturningToFace = false
            watchFaceOpacity = 1.0
            return
        }

        isReturningToFace = true
        Task { @MainActor in
            // Stay black for 3 seconds.
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard sequenceToken == currentToken, !isBuzzing else { return }

            // Fade watch-face back in over 2 seconds.
            withAnimation(.easeInOut(duration: 2.0)) {
                watchFaceOpacity = 1.0
            }

            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard sequenceToken == currentToken else { return }
            isReturningToFace = false
        }
    }

    private func resetToIdle() {
        beeX = 240
        beeY = 0
        beeScale = 1.0
        beeRotation = 0
        watchFaceOpacity = 1.0
    }
}

#Preview {
    ContentView()
}
