import SwiftUI

struct ContentView: View {
    @StateObject private var audio = AudioPitchManager()
    @StateObject private var store = MelodyStore()
    @StateObject private var chordPlayer = ChordPreviewPlayer()
    @State private var suggestions: [ChordSuggestion] = []
    @State private var mascotMotion = false

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    GroupBox("Live Pitch") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current note")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(audio.currentNoteText)
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                            }
                            Spacer()
                            Button(audio.isCapturing ? "Stop" : "Start") {
                                audio.toggleCapture()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    if let error = audio.captureError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    GroupBox("Detected Melody Notes") {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(audio.capturedNotes, id: \.id) { note in
                                    Text(note.noteName)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.blue.opacity(0.15), in: Capsule())
                                }
                            }
                        }
                        .frame(height: 38)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack {
                        Button("Analyze Chords") {
                            suggestions = ChordSuggester.suggestProgressions(for: audio.capturedNotes)
                        }
                        .buttonStyle(.bordered)

                        Button("Save Melody") {
                            store.saveMelody(from: audio.capturedNotes)
                        }
                        .buttonStyle(.bordered)
                        .disabled(audio.capturedNotes.isEmpty)

                        Button("Clear") {
                            audio.clearNotes()
                            suggestions.removeAll()
                        }
                        .buttonStyle(.bordered)
                    }

                    GroupBox("Suggested 4-Chord Progressions") {
                        if suggestions.isEmpty {
                            Text("Tap Analyze Chords after humming a melody.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(suggestions) { suggestion in
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(suggestion.name) • confidence \(Int(suggestion.confidence * 100))%")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(suggestion.chords.joined(separator: " - "))
                                                .font(.headline)
                                            if !suggestion.similarSongs.isEmpty {
                                                Text("Similar songs: \(suggestion.similarSongs.joined(separator: ", "))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Button {
                                            chordPlayer.togglePlay(progression: suggestion.chords)
                                        } label: {
                                            Label(
                                                chordPlayer.progressionIsPlaying(suggestion.chords) ? "Stop" : "Play",
                                                systemImage: chordPlayer.progressionIsPlaying(suggestion.chords) ? "stop.fill" : "play.fill"
                                            )
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    GroupBox("Saved Melodies") {
                        if store.savedMelodies.isEmpty {
                            Text("No saved melodies yet.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            List {
                                ForEach(store.savedMelodies, id: \.id) { melody in
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(melody.createdAt, style: .date)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(melody.notes.map(\.noteName).joined(separator: " "))
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                        Button(role: .destructive) {
                                            store.deleteMelody(melody)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                    }
                                }
                            }
                            .frame(height: 160)

                            Button("Delete All Saved Melodies", role: .destructive) {
                                store.clearAll()
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 8)
                        }
                    }

                    Spacer()
                }
                .padding()
                .navigationTitle("PitchPal")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        mascotView
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.16).repeatForever(autoreverses: true)) {
                mascotMotion = true
            }
        }
        .onDisappear {
            chordPlayer.stop()
        }
    }

    private var backgroundView: some View {
        Color.black
    }

    private var isMascotListening: Bool {
        audio.isCapturing && audio.currentNoteText != "-"
    }

    private var mascotView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    isMascotListening
                        ? Color(red: 1.0, green: 0.34, blue: 0.78)
                        : Color(red: 0.86, green: 0.87, blue: 0.93)
                )
                .frame(width: 16, height: 20)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(red: 0.70, green: 0.72, blue: 0.80))
                .frame(width: 6, height: 8)
                .offset(y: 14)
            HStack(spacing: 4) {
                Circle().fill(.black).frame(width: 2.8, height: 2.8)
                Circle().fill(.black).frame(width: 2.8, height: 2.8)
            }
            .offset(y: -1.5)
        }
        .rotationEffect(.degrees(isMascotListening ? (mascotMotion ? 8 : -8) : 0))
        .scaleEffect(isMascotListening ? (mascotMotion ? 1.09 : 1.0) : 1.0)
        .shadow(
            color: Color(red: 1.0, green: 0.2, blue: 0.72).opacity(isMascotListening ? 0.85 : 0),
            radius: isMascotListening ? (mascotMotion ? 12 : 7) : 0
        )
        .animation(.easeInOut(duration: 0.12), value: isMascotListening)
    }
}

#Preview {
    ContentView()
}
