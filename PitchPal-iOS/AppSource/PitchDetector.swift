import Foundation

enum PitchDetector {
    nonisolated static func detectFrequency(
        samples: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double,
        minFrequency: Double = 80.0,
        maxFrequency: Double = 900.0
    ) -> Double? {
        guard count > 256 else { return nil }

        var rms: Float = 0
        for i in 0..<count {
            let s = samples[i]
            rms += s * s
        }
        rms = sqrtf(rms / Float(count))
        if rms < 0.01 { return nil }

        let minLag = max(1, Int(sampleRate / maxFrequency))
        let maxLag = min(count - 2, Int(sampleRate / minFrequency))
        guard minLag < maxLag else { return nil }

        var bestLag = minLag
        var bestCorrelation: Float = 0

        for lag in minLag...maxLag {
            var correlation: Float = 0
            var energyA: Float = 0
            var energyB: Float = 0

            let limit = count - lag
            for i in 0..<limit {
                let a = samples[i]
                let b = samples[i + lag]
                correlation += a * b
                energyA += a * a
                energyB += b * b
            }

            let denom = sqrtf(energyA * energyB)
            if denom > 0 {
                correlation /= denom
            } else {
                correlation = 0
            }

            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }

        guard bestCorrelation > 0.20 else { return nil }
        return sampleRate / Double(bestLag)
    }

    nonisolated static func frequencyToMidi(_ frequency: Double) -> Int {
        Int(round(69.0 + 12.0 * log2(frequency / 440.0)))
    }
}
