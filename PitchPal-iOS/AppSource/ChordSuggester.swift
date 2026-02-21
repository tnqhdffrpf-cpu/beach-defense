import Foundation

enum ChordSuggester {
    private struct KeyCandidate {
        let tonic: Int
        let isMinor: Bool
        let score: Int
    }

    static func suggestProgressions(for notes: [NoteEvent], count: Int = 3) -> [ChordSuggestion] {
        guard !notes.isEmpty else { return [] }

        let pitchClassWeights = buildPitchClassWeights(from: notes)
        let key = inferBestKey(weights: pitchClassWeights)
        let progressionTemplates = key.isMinor
            ? [[1, 6, 3, 7], [1, 4, 7, 3], [1, 7, 6, 7]]
            : [[1, 5, 6, 4], [1, 4, 5, 1], [6, 4, 1, 5]]

        return progressionTemplates.prefix(count).map { degrees in
            let chords = degrees.map { degreeToChordName(degree: $0, tonic: key.tonic, isMinorKey: key.isMinor) }
            let confidence = progressionConfidence(chords: chords, weights: pitchClassWeights)
            let label = "\(MusicTheory.pitchClassName(key.tonic))\(key.isMinor ? " minor" : " major")"
            return ChordSuggestion(
                name: label,
                chords: chords,
                confidence: confidence,
                similarSongs: similarSongs(for: degrees, inMinorKey: key.isMinor)
            )
        }
        .sorted(by: { $0.confidence > $1.confidence })
    }

    private static func buildPitchClassWeights(from notes: [NoteEvent]) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for note in notes {
            let pc = MusicTheory.positiveMod(note.midi, 12)
            let weight = max(1, Int((note.duration * 10).rounded()))
            counts[pc, default: 0] += weight
        }
        return counts
    }

    private static func inferBestKey(weights: [Int: Int]) -> KeyCandidate {
        let majorScale = [0, 2, 4, 5, 7, 9, 11]
        let minorScale = [0, 2, 3, 5, 7, 8, 10]

        var best = KeyCandidate(tonic: 0, isMinor: false, score: Int.min)
        for tonic in 0..<12 {
            let majorScore = majorScale.reduce(0) { partial, degree in
                partial + weights[MusicTheory.positiveMod(tonic + degree, 12), default: 0]
            }
            if majorScore > best.score {
                best = KeyCandidate(tonic: tonic, isMinor: false, score: majorScore)
            }

            let minorScore = minorScale.reduce(0) { partial, degree in
                partial + weights[MusicTheory.positiveMod(tonic + degree, 12), default: 0]
            }
            if minorScore > best.score {
                best = KeyCandidate(tonic: tonic, isMinor: true, score: minorScore)
            }
        }
        return best
    }

    private static func degreeToChordName(degree: Int, tonic: Int, isMinorKey: Bool) -> String {
        if isMinorKey {
            let table: [(offset: Int, minor: Bool)] = [
                (0, true), (2, false), (3, false), (5, true), (7, true), (8, false), (10, false)
            ]
            let idx = max(1, min(7, degree)) - 1
            let spec = table[idx]
            let root = MusicTheory.pitchClassName(tonic + spec.offset)
            return spec.minor ? "\(root)m" : root
        } else {
            let table: [(offset: Int, minor: Bool)] = [
                (0, false), (2, true), (4, true), (5, false), (7, false), (9, true), (11, false)
            ]
            let idx = max(1, min(7, degree)) - 1
            let spec = table[idx]
            let root = MusicTheory.pitchClassName(tonic + spec.offset)
            return spec.minor ? "\(root)m" : root
        }
    }

    private static func progressionConfidence(chords: [String], weights: [Int: Int]) -> Double {
        guard !chords.isEmpty else { return 0 }
        let chordToneMap = chords.map { chord -> [Int] in
            let isMinor = chord.hasSuffix("m")
            let rootName = isMinor ? String(chord.dropLast()) : chord
            guard let root = MusicTheory.noteNames.firstIndex(of: rootName) else { return [] }
            return isMinor ? [root, (root + 3) % 12, (root + 7) % 12] : [root, (root + 4) % 12, (root + 7) % 12]
        }

        let totalWeight = max(1, weights.values.reduce(0, +))
        let matched = chordToneMap.flatMap { $0 }.reduce(0) { partial, pc in
            partial + weights[pc, default: 0]
        }
        return min(1.0, Double(matched) / Double(totalWeight * 2))
    }

    private static func similarSongs(for degrees: [Int], inMinorKey: Bool) -> [String] {
        let key = degrees.map(String.init).joined(separator: "-")

        if inMinorKey {
            switch key {
            case "1-6-3-7":
                return ["Rolling in the Deep", "Zombie"]
            case "1-4-7-3":
                return ["Sultans of Swing"]
            case "1-7-6-7":
                return ["All Along the Watchtower"]
            default:
                return []
            }
        }

        switch key {
        case "1-5-6-4":
            return ["Let It Be", "With or Without You", "No Woman, No Cry"]
        case "1-4-5-1":
            return ["La Bamba", "Twist and Shout"]
        case "6-4-1-5":
            return ["Someone Like You", "Apologize"]
        default:
            return []
        }
    }
}
