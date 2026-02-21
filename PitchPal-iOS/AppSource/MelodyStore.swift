import Foundation
import Combine

final class MelodyStore: ObservableObject {
    @Published var savedMelodies: [Melody] = []

    private let storageKey = "pitchpal.savedMelodies"

    init() {
        load()
    }

    func saveMelody(from notes: [NoteEvent]) {
        guard !notes.isEmpty else { return }
        let melody = Melody(notes: notes)
        savedMelodies.insert(melody, at: 0)
        persist()
    }

    func deleteMelodies(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            if savedMelodies.indices.contains(index) {
                savedMelodies.remove(at: index)
            }
        }
        persist()
    }

    func deleteMelody(_ melody: Melody) {
        savedMelodies.removeAll { $0.id == melody.id }
        persist()
    }

    func clearAll() {
        savedMelodies.removeAll()
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(savedMelodies)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to persist melodies: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            savedMelodies = try JSONDecoder().decode([Melody].self, from: data)
        } catch {
            print("Failed to load melodies: \(error)")
        }
    }
}
