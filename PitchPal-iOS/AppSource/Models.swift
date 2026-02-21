import Foundation

struct NoteEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let midi: Int
    let noteName: String
    let startedAt: Date
    var duration: TimeInterval

    init(midi: Int, noteName: String, startedAt: Date = Date(), duration: TimeInterval = 0) {
        self.id = UUID()
        self.midi = midi
        self.noteName = noteName
        self.startedAt = startedAt
        self.duration = duration
    }
}

struct Melody: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let notes: [NoteEvent]

    init(notes: [NoteEvent]) {
        self.id = UUID()
        self.createdAt = Date()
        self.notes = notes
    }
}

struct ChordSuggestion: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let chords: [String]
    let confidence: Double
    let similarSongs: [String]
}
