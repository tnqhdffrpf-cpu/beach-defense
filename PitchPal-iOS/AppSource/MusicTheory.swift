import Foundation

enum MusicTheory {
    static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    static func midiToNoteName(_ midi: Int) -> String {
        let pc = positiveMod(midi, 12)
        let octave = (midi / 12) - 1
        return "\(noteNames[pc])\(octave)"
    }

    static func pitchClassName(_ pitchClass: Int) -> String {
        noteNames[positiveMod(pitchClass, 12)]
    }

    static func positiveMod(_ value: Int, _ modulus: Int) -> Int {
        let m = value % modulus
        return m >= 0 ? m : m + modulus
    }
}
