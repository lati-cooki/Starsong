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

    /// Chosen by search rather than by ear, because picking them by ear went
    /// wrong twice: the first six included pairs differing in 2 notes of 15
    /// across the whole sky, which is not a different mood, it is the same one
    /// with a wobble. These five are the set whose *most similar* pair still
    /// differs in 6 notes of 15. `TuningTests` holds the floor at 5 so this
    /// cannot regress by eyeball again.
    static let tunings: [Tuning] = [
        Tuning(id: "major",     name: "Major pentatonic", degrees: [0, 2, 4, 7, 9]),
        Tuning(id: "minor",     name: "Minor pentatonic", degrees: [0, 3, 5, 7, 10]),
        Tuning(id: "hirajoshi", name: "Hirajoshi",        degrees: [0, 2, 3, 7, 8]),
        Tuning(id: "in",        name: "In",               degrees: [0, 1, 5, 7, 8]),
        Tuning(id: "balinese",  name: "Balinese",         degrees: [0, 1, 3, 7, 10])
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

    /// A constellation's shape is also its rhythm — but only if the shape has
    /// any variety in it. Mapping distance straight onto time did not work:
    /// measured on hand-drawn lines, consecutive stars sit so evenly that every
    /// gap came out within a few percent of every other, which is a metronome,
    /// not a rhythm.
    ///
    /// So gaps are **note values** — half, one or two pulses — chosen by where
    /// each reach falls within *that line's own* range of reaches. Discrete
    /// values are what makes a rhythm audible; a continuum just jitters. And a
    /// shared pulse means layered lines lock to one tempo while running to
    /// different lengths, which is polymeter rather than drift.
    static let pulse = 0.30
    static let noteValues = [0.5, 1.0, 2.0]

    static var shortestGap: Double { pulse * noteValues.first! }
    static var longestGap: Double { pulse * noteValues.last! }

    /// A line whose hops are all much of a muchness is a steady line, and it
    /// should sound like one. Amplifying a five-percent wobble into a rhythm
    /// would be inventing one that was never drawn.
    static let evennessTolerance = 1.25

    /// The pause before each note. The first has none.
    static func gaps(between stars: [Star]) -> [Double] {
        guard !stars.isEmpty else { return [] }
        let reaches = zip(stars, stars.dropFirst())
            .map { Double(hypot($1.x - $0.x, $1.y - $0.y)) }
        guard let shortest = reaches.min(), let longest = reaches.max() else { return [0] }

        let isSteady = longest <= shortest * evennessTolerance
        var gaps = [0.0]
        for reach in reaches {
            guard !isSteady else { gaps.append(pulse); continue }
            let position = (reach - shortest) / (longest - shortest)
            let step = min(Int(position * Double(noteValues.count)), noteValues.count - 1)
            gaps.append(pulse * noteValues[step])
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
    static var loopRest: Double { pulse * 2 }

    /// One time round, in whole pulses, so layered lines stay on one grid.
    static func cycleLength(for stars: [Star]) -> Double {
        guard let last = schedule(for: stars).last else { return loopRest }
        return last + pulse * 2
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
