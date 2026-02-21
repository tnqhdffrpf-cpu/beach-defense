import SwiftUI

@main
struct LiveTranscriptWatchApp: App {
    @StateObject private var transcriptBridge = CompanionTranscriptBridge()

    var body: some Scene {
        WindowGroup {
            CompanionView()
                .environmentObject(transcriptBridge)
        }
    }
}
