import Foundation

/// The chords under a melody.
///
/// Every one of `Music.tunings` is pentatonic, which is why anything you draw
/// sounds lovely: there is no wrong note to land on. It is also why nothing you
/// draw sounds *finished*. A single line has nothing to be consonant or
/// dissonant against, so no note in it is ever an arrival — the melody is pretty
/// and it wanders. This puts something underneath it rather than changing the
/// line above, so `Music` still decides every pitch a star sings.
///
/// **Every chord tone is a member of the line's own tuning.** That is the whole
/// safety argument, and it is a stronger one than checking intervals: a bed
/// built only from scale members cannot introduce a note the melody could not
/// already have played, in any tuning, ever.
///
/// Checking intervals is what the first attempt did — reject a chord tone
/// sitting a semitone from any scale degree — and it rejected the plain
/// tonic-and-fifth drone in three tunings of five. The reason is worth keeping,
/// because it is not what it looks like: those three are exactly the tunings
/// that contain a semitone pair *of their own* (hirajoshi has 2-3 and 7-8, `in`
/// has 0-1 and 7-8, balinese has 0-1). What the rule flagged was each scale's
/// own character, which the melody is already free to play, not anything the
/// bed was doing to it.
enum Harmony {

    // MARK: - Time

    /// A bar, in pulses.
    ///
    /// `Music.pulse` is the shortest thing a melody subdivides to, so it reads
    /// as an eighth rather than a beat — at 0.3s that is about 100bpm, and eight
    /// of them is one bar of four. A chord every 2.4s is slow enough to be heard
    /// as harmony; changing every bar of *two* was tried on paper and is fast
    /// enough that the bed starts sounding like a second melody competing with
    /// the line.
    static let barPulses = 8
    static var barLength: Double { Music.pulse * Double(barPulses) }

    /// How long a chord sounds for. Comfortably inside a bar, so one chord has
    /// died away before the next arrives.
    ///
    /// This was the opposite at first — `barLength + 0.6`, so that chords
    /// overlapped and the harmony was continuous underneath the line. On a
    /// phone that is a horror-film drone, and the reason is worth writing down
    /// because none of it is obvious from the numbers:
    ///
    /// - It was voiced on `Instrument.brass`, which is the one voice with no
    ///   `exp(-t)` term in it. It holds at full amplitude for its whole
    ///   duration instead of dying away like everything else in the app, so
    ///   overlapping bars made an unbroken wall rather than a wash.
    /// - Brass is ten harmonics at 1/n. A phone speaker rolls off below roughly
    ///   300 Hz, so a bed built at 110–207 Hz was not heard as bass at all —
    ///   what came out was harmonics three through ten, 330–1100 Hz, as a
    ///   mid-range buzz. Putting the bed low did not put it out of the way.
    /// - Then `largeHall` smeared the whole thing together.
    ///
    /// So the shape of the mistake was not a volume that wanted turning down.
    /// Starsong is decaying pings in a reverb, all the way through; a sustained
    /// pad is a foreign object in it however carefully it is tuned. Harmony has
    /// to be said in the same voice as everything else.
    static let noteLength = 1.3

    // MARK: - Chords

    /// Two notes a perfect fifth apart.
    ///
    /// No third. The third is what decides whether a chord is major or minor,
    /// and these five tunings disagree about which they are — major pentatonic
    /// wants 4, minor wants 3, and `in` has neither. A root and a fifth agree
    /// with all of them.
    struct Chord: Equatable {
        /// Semitones above the tuning's root.
        let root: Int
        /// Semitones above the tuning's root, lowest first.
        let tones: [Int]
    }

    /// 0...6. The distance the ear hears between two pitch classes: a semitone
    /// up and a semitone down are the same distance apart.
    static func intervalClass(_ semitones: Int) -> Int {
        let wrapped = ((semitones % 12) + 12) % 12
        return min(wrapped, 12 - wrapped)
    }

    /// The pairs of scale members, within two octaves, that sit a perfect fifth
    /// apart — every one of them safe by the rule above, because both notes are
    /// degrees of the tuning.
    ///
    /// Every tuning has at least two. `(0, 7)` is always one of them, because
    /// `RhythmTests.testEveryTuningSharesItsRootAndFifth` holds every tuning to
    /// containing its root and its fifth.
    static func fifthDyads(in tuning: Music.Tuning) -> [Chord] {
        let reach = Set(tuning.degrees + tuning.degrees.map { $0 + 12 })
        return tuning.degrees.sorted()
            .filter { reach.contains($0 + 7) }
            .map { Chord(root: $0, tones: [$0, $0 + 7]) }
    }

    /// Home.
    static func tonic(in tuning: Music.Tuning) -> Chord {
        Chord(root: 0, tones: [0, 7])
    }

    /// The chord that travels furthest from home, measured by interval class so
    /// that a fifth up and a fourth down count as the same journey. Ties go to
    /// the lower root, which is what `max(by:)` does with a strict comparison.
    ///
    /// Across the five tunings this picks, in order: the fifth, the fourth, the
    /// fifth, the fourth, and the third — V, iv, v, iv, III. Those were not
    /// chosen; they are what the rule returns, which is a good sign the rule is
    /// the right one.
    static func away(in tuning: Music.Tuning) -> Chord {
        let candidates = fifthDyads(in: tuning).filter { $0.root != 0 }
        guard !candidates.isEmpty else { return tonic(in: tuning) }
        return candidates.max { intervalClass($0.root) < intervalClass($1.root) }!
    }

    /// One chord per bar: home at both ends, alternating in between.
    ///
    /// Ending home is the cadence, and it is the point of the whole exercise —
    /// it is what makes a loop seam sound like a return rather than a join.
    ///
    /// Two bars or fewer have no room to leave and come back, so they hold home
    /// and act as a drone. At four bars the rule yields two bars of home at the
    /// end; that is a cadence lengthening rather than a mistake, and it sounds
    /// like an ending, so it is left alone.
    static func chords(bars: Int, in tuning: Music.Tuning) -> [Chord] {
        guard bars > 0 else { return [] }
        let home = tonic(in: tuning)
        guard bars > 2 else { return Array(repeating: home, count: bars) }
        let elsewhere = away(in: tuning)
        return (0..<bars).map { bar in
            guard bar != 0, bar != bars - 1 else { return home }
            return bar.isMultiple(of: 2) ? home : elsewhere
        }
    }

    // MARK: - Pitch

    /// The bed sits an octave below the melody's root, so it is underneath the
    /// line rather than inside it. `Music.rootFrequency` is A3; this is A2.
    static var bassFrequency: Double { Music.rootFrequency / 2 }

    static func frequency(semitonesAboveRoot semitones: Int) -> Double {
        bassFrequency * pow(2, Double(semitones) / 12)
    }

    /// The chord as it is actually sounded: every tone folded into the one
    /// octave above `bassFrequency`.
    ///
    /// Needed because the fifth can run high. `away` in hirajoshi is rooted on
    /// 7, so its fifth is 14, and 14 semitones above a bass of 110 Hz is 247 Hz
    /// — above the 220 Hz root, which is the lowest note a star can sing. Left
    /// unfolded the bed pokes up into the melody instead of sitting under it.
    ///
    /// Folding is safe under the rule this whole type rests on: dropping a tone
    /// by an octave keeps it a member of the tuning, because the membership set
    /// is the degrees together with the degrees an octave up. What it can do is
    /// turn a fifth above into a fourth below — the same two notes, voiced the
    /// way a bass player voices them when the fifth runs out of room.
    static func voiced(_ chord: Chord) -> [Int] {
        chord.tones.map { ((($0 % 12) + 12) % 12) }
    }

    // MARK: - The bed under one line

    struct Voicing: Equatable {
        let chord: Chord
        let delay: Double
        let duration: Double
    }

    /// Enough bars to cover one time round the line, with the chords above.
    ///
    /// Sized from `Music.cycleLength` rather than from the note count, so the
    /// bed covers the same span the melody does — including the rest at the loop
    /// seam, which is where the arrival needs to still be sounding.
    static func bed(under stars: [Star], in tuning: Music.Tuning) -> [Voicing] {
        guard stars.count >= 2 else { return [] }
        let cycle = Music.cycleLength(for: stars)
        let bars = max(Int((cycle / barLength).rounded(.up)), 1)
        return chords(bars: bars, in: tuning).enumerated().map { bar, chord in
            Voicing(chord: chord,
                    delay: Double(bar) * barLength,
                    duration: noteLength)
        }
    }

    /// A plucked string, low and quiet.
    ///
    /// `Instrument.pluck` for the reason in `noteLength`: it decays, so a chord
    /// blooms and dies the way every other sound in the app does, and at these
    /// frequencies Karplus-Strong is a bass string rather than anything
    /// pretending to be a pad.
    static let voice = Instrument.pluck
    /// Under the melody's quietest note by a good margin. Harmony you notice
    /// only when it changes is doing its job.
    static let volume: Float = 0.05

    /// The gap between the two notes of a chord.
    ///
    /// Sounding both at once is a block; rolling the fifth in just behind the
    /// root reads as something played. Short enough not to be heard as two
    /// separate events.
    static let roll = 0.07

    /// Schedules the bed onto the audio clock, alongside the melody and on the
    /// same clock, so the two keep together however busy the main thread is.
    ///
    /// Goes to `Synth.Channel.bed`, which has voices of its own: a fifty-note
    /// keepsake line already claims fifty of the melody pool's sixty-four, and a
    /// bed sharing that pool would wrap the round-robin and cut the opening
    /// notes off — the exact fault that sizing the pool for fifty notes fixed.
    static func sound(under stars: [Star], in tuning: Music.Tuning,
                      offset: Double = 0) {
        for voicing in bed(under: stars, in: tuning) {
            for (note, tone) in voiced(voicing.chord).enumerated() {
                Synth.shared.ping(frequency(semitonesAboveRoot: tone),
                                  instrument: voice,
                                  delay: offset + voicing.delay + Double(note) * roll,
                                  duration: voicing.duration,
                                  volume: volume,
                                  channel: .bed)
            }
        }
    }
}
