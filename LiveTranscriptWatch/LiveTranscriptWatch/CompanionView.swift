import SwiftUI

struct CompanionView: View {
    @EnvironmentObject private var transcriptBridge: CompanionTranscriptBridge

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Pace Coach Companion")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))

                Text("Use Apple Watch for pace coaching. iPhone can stream transcript to watch if needed.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                ScrollView {
                    Text(displayText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .frame(maxHeight: .infinity)

                if let permissionError = transcriptBridge.permissionError {
                    Text(permissionError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: toggleListening) {
                    Text(transcriptBridge.isListening ? "Stop Mic Relay" : "Start Mic Relay")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(transcriptBridge.isListening ? .red : .green)
            }
            .padding()
        }
    }

    private var displayText: String {
        let trimmed = transcriptBridge.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No live transcript" : trimmed
    }

    private func toggleListening() {
        if transcriptBridge.isListening {
            transcriptBridge.stopListening()
        } else {
            transcriptBridge.startListening()
        }
    }
}

#Preview {
    CompanionView()
        .environmentObject(CompanionTranscriptBridge())
}
