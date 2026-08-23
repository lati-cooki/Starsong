import CoreGraphics
import Foundation

/// Five-note scales, so anything you draw sounds lovely whichever one a night
/// happens to be tuned to.
enum Music {
    struct Tuning: Identifiable, Hashable {
        let id: String
        let name: String
        /// Semitones above the root. Always five, so the octave maths holds.
        let degrees: [Int]
    }

    static let tunings: [Tuning] = [
        Tuning(id: "major",     name: "Major pentatonic", degrees: [0, 2, 4, 7, 9]),
        Tuning(id: "minor",     name: "Minor pentatonic", degrees: [0, 3, 5, 7, 10]),
        Tuning(id: "ritusen",   name: "Ritusen",          degrees: [0, 2, 5, 7, 9]),
        Tuning(id: "kumoi",     name: "Kumoi",            degrees: [0, 2, 3, 7, 9]),
        Tuning(id: "hirajoshi", name: "Hirajoshi",        degrees: [0, 2, 3, 7, 8]),
        Tuning(id: "egyptian",  name: "Egyptian",         degrees: [0, 2, 5, 7, 10])
    ]

    static let `default` = tunings[0]
    /// The original tuning, kept so anything that doesn't care can ignore all this.
    static var scale: [Int] { Music.default.degrees }

    static let range = 14
    static let rootFrequency = 220.0

    /// Each night is tuned by its own seed.
    static func tuning(for seed: UInt64) -> Tuning {
        tunings[Int(seed % UInt64(tunings.count))]
    }

    /// Sky position (0 = top) to a scale degree, clamped so an out-of-range
    /// tap can never index past the end of the scale.
    static func degree(forY y: CGFloat) -> Int {
        let raw = (1 - Double(y)) * Double(range) + 0.5
        guard raw.isFinite else { return 0 }
        return min(max(Int(raw), 0), range)
    }

    static func pitch(forY y: CGFloat, in tuning: Tuning = Music.default) -> Double {
        let degree = degree(forY: y)
        let octave = degree / tuning.degrees.count
        let semitone = tuning.degrees[degree % tuning.degrees.count]
        return rootFrequency * pow(2, Double(octave * 12 + semitone) / 12)
    }

    // MARK: - Saying it out loud

    private static let noteNames = ["C", "C sharp", "D", "D sharp", "E", "F",
                                    "F sharp", "G", "G sharp", "A", "A sharp", "B"]

    /// The note a star sings, spoken. 220 Hz is A3, which is MIDI 57.
    static func noteName(forY y: CGFloat, in tuning: Tuning = Music.default) -> String {
        let degree = degree(forY: y)
        let octave = degree / tuning.degrees.count
        let semitone = tuning.degrees[degree % tuning.degrees.count]
        let midi = 57 + octave * 12 + semitone
        return "\(noteNames[midi % 12]) \(midi / 12 - 1)"
    }

    // MARK: - Time

    /// A constellation's shape is also its rhythm: stars that sit close together
    /// tumble out quickly, a long reach across the sky holds.
    static let shortestGap = 0.14
    static let longestGap = 0.70
    static let gapPerSkyLength = 0.80

    /// The pause before each note. The first has none.
    static func gaps(between stars: [Star]) -> [Double] {
        guard !stars.isEmpty else { return [] }
        var gaps = [0.0]
        for (previous, next) in zip(stars, stars.dropFirst()) {
            let reach = Double(hypot(next.x - previous.x, next.y - previous.y))
            gaps.append(min(shortestGap + gapPerSkyLength * reach, longestGap))
        }
        return gaps
    }

    /// When each note starts, measured from the downbeat.
    static func schedule(for stars: [Star]) -> [Double] {
        var elapsed = 0.0
        return gaps(between: stars).map { gap in
            elapsed += gap
            return elapsed
        }
    }

    /// The breath at the end of a loop, before it comes round again.
    static let loopRest = 0.55

    /// One time round: the last note, its ring, and a breath.
    static func cycleLength(for stars: [Star]) -> Double {
        guard let last = schedule(for: stars).last else { return loopRest }
        return last + longestGap + loopRest
    }

    /// A note rings a little past the one that follows it.
    static func durations(for stars: [Star]) -> [Double] {
        let gaps = gaps(between: stars)
        return gaps.indices.map { i in
            let next = i + 1 < gaps.count ? gaps[i + 1] : longestGap
            return next + 0.9
        }
    }
}
