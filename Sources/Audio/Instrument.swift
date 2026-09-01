import Foundation

/// The voices a line can be played in.
///
/// There are no samples in the bundle — nothing here is a recording, and none
/// of it is pretending very hard. Pluck and Bell are what synthesis is good at
/// and sound like the thing they are named after. Piano lands nearer an
/// electric piano, and Brass is a bloom in roughly the right shape. That is the
/// honest ceiling without a sound library.
enum Instrument: String, CaseIterable, Identifiable, Codable, Hashable {
    case chime, pluck, piano, brass, bell, marimba, pad, harp

    var id: String { rawValue }

    var name: String {
        switch self {
        case .chime:   "Chime"
        case .pluck:   "Pluck"
        case .piano:   "Piano"
        case .brass:   "Brass"
        case .bell:    "Bell"
        case .marimba: "Marimba"
        case .pad:     "Pad"
        case .harp:    "Harp"
        }
    }

    var blurb: String {
        switch self {
        case .chime:   "The sound the sky started with — a soft triangle with a shimmer above it."
        case .pluck:   "A plucked string, made the way a real one behaves: a burst of noise trapped in a loop the length of one wavelength, losing its edges each time round."
        case .piano:   "A struck string. Nearer an electric piano than a grand — synthesis only gets so close to a hammer."
        case .brass:   "Slow to speak, then blooms and holds, with a little vibrato. Trumpet-ish rather than a trumpet."
        case .bell:    "Partials that don't line up into a harmonic series, so it rings rather than sings."
        case .marimba: "A warm wooden bar with a crisp mallet attack and a hollow, resonant decay."
        case .pad:     "A soft, ethereal atmosphere — dual detuned waves with a slow attack and warm harmonic swell."
        case .harp:    "A rich, delicate string pluck with shimmering upper partials and a gentle resonant ring."
        }
    }

    /// One note, as mono samples. A pure function of its inputs — including the
    /// noise in `pluck`, which is seeded from the pitch so a given note always
    /// renders identically and can be cached and tested.
    func samples(frequency: Double, duration: Double, sampleRate: Double) -> [Float] {
        let count = max(Int(duration * sampleRate), 1)
        let raw: [Double]
        switch self {
        case .chime:   raw = Self.chimeSamples(frequency, duration, sampleRate, count)
        case .pluck:   raw = Self.pluckSamples(frequency, duration, sampleRate, count)
        case .piano:   raw = Self.pianoSamples(frequency, duration, sampleRate, count)
        case .brass:   raw = Self.brassSamples(frequency, duration, sampleRate, count)
        case .bell:    raw = Self.bellSamples(frequency, duration, sampleRate, count)
        case .marimba: raw = Self.marimbaSamples(frequency, duration, sampleRate, count)
        case .pad:     raw = Self.padSamples(frequency, duration, sampleRate, count)
        case .harp:    raw = Self.harpSamples(frequency, duration, sampleRate, count)
        }
        return Self.normalised(raw)
    }

    // MARK: - Shared shaping

    /// Scaled so the loudest moment of every voice is the same, and no voice can
    /// clip however many partials it stacks up.
    static func normalised(_ samples: [Double], peak: Double = 0.9) -> [Float] {
        let loudest = samples.reduce(0.0) { Swift.max($0, abs($1)) }
        guard loudest > 1e-9 else { return [Float](repeating: 0, count: samples.count) }
        let scale = peak / loudest
        return samples.map { Float($0 * scale) }
    }

    /// Fades in over `attack` and out over `release`, so no note begins or ends
    /// on a step — a step is a click.
    static func shape(_ t: Double, duration: Double, attack: Double, release: Double) -> Double {
        let rising = min(1, t / attack)
        let falling = min(1, Swift.max(0, duration - t) / release)
        return rising * falling
    }

    // MARK: - The voices

    private static func chimeSamples(_ frequency: Double, _ duration: Double,
                                     _ sampleRate: Double, _ count: Int) -> [Double] {
        (0..<count).map { i in
            let t = Double(i) / sampleRate
            let triangle = 2 / Double.pi * asin(sin(2 * .pi * frequency * t))
            let shimmer = sin(2 * .pi * frequency * 2.01 * t) * 0.35
            return (triangle + shimmer) * exp(-t * 5)
                * shape(t, duration: duration, attack: 0.02, release: 0.04)
        }
    }

    /// Karplus-Strong. A wavetable of noise one wavelength long, read round and
    /// round, low-passed a little each lap so the high frequencies die first —
    /// which is exactly what a real string does.
    ///
    /// The delay has to come out at `sampleRate / frequency` *including* the
    /// half sample the averaging filter adds, so the line is read with linear
    /// interpolation rather than rounded to whole samples. Rounding is audible:
    /// at the top of the sky it would land a third of a semitone flat.
    private static func pluckSamples(_ frequency: Double, _ duration: Double,
                                     _ sampleRate: Double, _ count: Int) -> [Double] {
        // The line holds `length` samples of history: line[index] is the oldest,
        // and every step forward from it is newer. So interpolating toward the
        // next slot *shortens* the delay — round the length up and interpolate
        // back down to the target rather than the other way about.
        let target = sampleRate / frequency - 0.5   // the filter adds half a sample
        guard target >= 2 else { return [Double](repeating: 0, count: count) }
        let length = Int(target.rounded(.up))
        let fraction = Double(length) - target

        var rng = SplitMix64(seed: UInt64(frequency * 1000))
        var line = (0..<length).map { _ in Double.random(in: -1...1, using: &rng) }

        // How much is kept each lap. Longer notes need a slower decay or the
        // string dies before the note is over.
        let damping = 0.994 + 0.005 * min(duration / 2.4, 1)

        var out = [Double](repeating: 0, count: count)
        var index = 0
        var previous = 0.0
        for i in 0..<count {
            let a = line[index]
            let b = line[(index + 1) % length]
            let read = a + fraction * (b - a)
            out[i] = read * shape(Double(i) / sampleRate, duration: duration,
                                  attack: 0.001, release: 0.02)
            line[index] = 0.5 * (read + previous) * damping
            previous = read
            index = (index + 1) % length
        }
        return out
    }

    /// A struck string: harmonics at 1/n, stretched slightly sharp the way real
    /// strings are stiff, and a decay in two stages — the knock dies fast, the
    /// tone hangs on.
    private static func pianoSamples(_ frequency: Double, _ duration: Double,
                                     _ sampleRate: Double, _ count: Int) -> [Double] {
        let inharmonicity = 0.0004
        let partials = (1...8).map { n -> (frequency: Double, amplitude: Double) in
            let stretch = (1 + inharmonicity * Double(n * n)).squareRoot()
            return (frequency * Double(n) * stretch, 1 / Double(n))
        }
        return (0..<count).map { i in
            let t = Double(i) / sampleRate
            let tone = partials.reduce(0.0) { sum, partial in
                sum + sin(2 * .pi * partial.frequency * t) * partial.amplitude
                    * exp(-t * (1.2 + Double(partials.count) * 0.35))
            }
            let knock = exp(-t * 90) * 0.4 * sin(2 * .pi * frequency * 0.5 * t)
            let body = 0.7 * exp(-t * 6) + 0.3 * exp(-t * 1.1)
            return (tone * body + knock)
                * shape(t, duration: duration, attack: 0.003, release: 0.05)
        }
    }

    /// Slow to speak, then holds. The overshoot just after the attack is what
    /// makes a brass note sound blown rather than faded up.
    private static func brassSamples(_ frequency: Double, _ duration: Double,
                                     _ sampleRate: Double, _ count: Int) -> [Double] {
        let attack = 0.06
        return (0..<count).map { i in
            let t = Double(i) / sampleRate
            // Vibrato arrives after the note has settled, as a player's does.
            let vibrato = 1 + 0.004 * sin(2 * .pi * 5.2 * t) * min(1, Swift.max(0, t - 0.25) / 0.3)
            let tone = (1...10).reduce(0.0) { sum, n in
                sum + sin(2 * .pi * frequency * vibrato * Double(n) * t) / Double(n)
            }
            let overshoot = 1 + 0.35 * exp(-Swift.max(0, t - attack) * 14) * min(1, t / attack)
            return tone * overshoot * shape(t, duration: duration, attack: attack, release: 0.09)
        }
    }

    /// Partials that are not whole multiples of anything, which is why a bell
    /// has no clear note until you listen for it. Ratios after a tubular bell.
    private static func bellSamples(_ frequency: Double, _ duration: Double,
                                    _ sampleRate: Double, _ count: Int) -> [Double] {
        let partials: [(ratio: Double, amplitude: Double, decay: Double)] = [
            (1.00, 1.00, 1.1), (2.00, 0.55, 1.6), (2.76, 0.42, 2.1),
            (5.40, 0.24, 3.0), (8.93, 0.16, 4.2)
        ]
        return (0..<count).map { i in
            let t = Double(i) / sampleRate
            let tone = partials.reduce(0.0) { sum, partial in
                sum + sin(2 * .pi * frequency * partial.ratio * t)
                    * partial.amplitude * exp(-t * partial.decay)
            }
            return tone * shape(t, duration: duration, attack: 0.004, release: 0.06)
        }
    }

    /// A wooden bar: strong fundamental, wood-bar overtone (~4x frequency) dying fast, and a crisp wooden knock.
    private static func marimbaSamples(_ frequency: Double, _ duration: Double,
                                       _ sampleRate: Double, _ count: Int) -> [Double] {
        let overtoneRatio = 3.98
        return (0..<count).map { i in
            let t = Double(i) / sampleRate
            let fundamental = sin(2 * .pi * frequency * t) * exp(-t * 6.5)
            let overtone = sin(2 * .pi * frequency * overtoneRatio * t) * 0.4 * exp(-t * 22.0)
            let knock = sin(2 * .pi * frequency * 0.5 * t) * 0.3 * exp(-t * 120.0)
            return (fundamental + overtone + knock)
                * shape(t, duration: duration, attack: 0.002, release: 0.03)
        }
    }

    /// Two detuned sines that sustain, an octave, and a bloom two octaves up
    /// that swells in and settles — the "harmonic swell" of the blurb.
    ///
    /// Two things here are the way they are because the tests measured them:
    ///
    /// - There is no fifth. The first version had a partial at 1.498x, and a
    ///   fifth inside a single voice makes the waveform repeat every *two*
    ///   cycles of the fundamental, so the pad read an octave low by
    ///   autocorrelation — which is also how an ear finds a pitch. Every partial
    ///   is a whole-number multiple of the fundamental now. Fifths are the bed's
    ///   job (`Harmony`), not a timbre's.
    /// - The bloom is what stops the pad being a bell. Without it, a mid-speed
    ///   `exp(-1.4t)` fade on a plain tone landed within a few percent of Bell
    ///   on both brightness and decay. A pad's identity is that it *sustains*,
    ///   so the core decays slowly, and the bloom gives it a brightness Brass —
    ///   the other sustaining voice — does not have.
    private static func padSamples(_ frequency: Double, _ duration: Double,
                                   _ sampleRate: Double, _ count: Int) -> [Double] {
        let detune1 = 1.0025
        let detune2 = 0.9975
        let attack = 0.08
        return (0..<count).map { i in
            let t = Double(i) / sampleRate
            let wave1 = sin(2 * .pi * frequency * detune1 * t)
            let wave2 = sin(2 * .pi * frequency * detune2 * t)
            let octave = sin(2 * .pi * frequency * 2.0 * t) * 0.25
            let core = (wave1 + wave2 + octave) * exp(-t * 0.5)
            let bloom = sin(2 * .pi * frequency * 4.0 * t) * 0.6
                * (1 - exp(-t * 12.0)) * exp(-t * 1.5)
            return (core + bloom) * shape(t, duration: duration, attack: attack, release: 0.12)
        }
    }

    /// Warm plucked string: rich harmonic series, soft pluck transient, and lingering ring.
    private static func harpSamples(_ frequency: Double, _ duration: Double,
                                    _ sampleRate: Double, _ count: Int) -> [Double] {
        let partials: [(ratio: Double, amp: Double)] = [
            (1.0, 1.0),
            (2.0, 0.45),
            (3.0, 0.25),
            (4.0, 0.12),
            (5.0, 0.06)
        ]
        return (0..<count).map { i in
            let t = Double(i) / sampleRate
            let tone = partials.reduce(0.0) { sum, p in
                sum + sin(2 * .pi * frequency * p.ratio * t) * p.amp * exp(-t * (1.8 + p.ratio * 0.4))
            }
            let pluckTap = sin(2 * .pi * frequency * 2.5 * t) * 0.3 * exp(-t * 70.0)
            return (tone + pluckTap) * shape(t, duration: duration, attack: 0.003, release: 0.05)
        }
    }
}
