import Foundation

/// The chords under a melody, derived from the melody.
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
///
/// **The bed follows the tune.** The second attempt built the bed from the bar
/// count — home on degree 0, home and away alternating by bar parity, a chord
/// every 2.4s regardless — and it was in a different key from the melody it
/// sat under: the keepsake rests on degree 4 in every tuning, and the bass
/// insisted on 0. Four rules replace that. Home is where the tune rests
/// (`tonic`, `home`). Chords change only on melody onsets, at about a bar
/// (`spans`). Each is chosen by how much of the melody it covers, with the note
/// under the change held first (`fit`, `chords`). And the cadence is forced:
/// the last chord is home and the one before it is not (`chords`).
enum Harmony {

    // MARK: - Time

    /// The target length of a span, in pulses.
    ///
    /// `Music.pulse` is the shortest thing a melody subdivides to, so it reads
    /// as an eighth rather than a beat — at 0.3s that is about 100bpm, and eight
    /// of them is one bar of four. A chord every 2.4s is slow enough to be heard
    /// as harmony; changing every bar of *two* was tried on paper and is fast
    /// enough that the bed starts sounding like a second melody competing with
    /// the line. Not a grid: chords change on melody onsets, and `spans` uses
    /// this as the length to wait for.
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

    // MARK: - Home

    /// The pitch class the tune rests on: its last note.
    ///
    /// Not degree 0 of the tuning. The keepsake's spiral opens near the top of
    /// the sky and closes at the bottom of its own rim, and both of those land
    /// on degree 4 in every key — so a bed that called degree 0 home was in a
    /// different key from the melody it sat under. Where a tune ends is what
    /// the ear takes for its key, and the bass has to agree.
    static func tonic(of stars: [Star], in tuning: Music.Tuning) -> Int {
        guard let last = stars.last else { return 0 }
        return Music.semitone(forY: last.y, in: tuning) % 12
    }

    /// The tonic and its fifth, when the tuning has that fifth; otherwise the
    /// tonic alone. Bare, but it cannot be mistaken for anything else, and it
    /// keeps the safety rule: no note from outside the tuning.
    ///
    /// Not an octave. `voiced` folds every tone into one octave, so `[t, t+12]`
    /// would come out as the same note rolled twice — a flam, not a chord.
    static func home(for stars: [Star], in tuning: Music.Tuning) -> Chord {
        let tonic = tonic(of: stars, in: tuning)
        guard Set(tuning.degrees).contains((tonic + 7) % 12) else {
            return Chord(root: tonic, tones: [tonic])
        }
        return Chord(root: tonic, tones: [tonic, tonic + 7])
    }

    /// Everything the bed may play under this line: home, then every fifth
    /// dyad in the tuning. Home comes first so that a tie on fit falls to it.
    /// Deduplicated by folded pitch-class set, because home is usually one of
    /// the dyads already and must not compete with itself.
    static func candidates(for stars: [Star], in tuning: Music.Tuning) -> [Chord] {
        let home = home(for: stars, in: tuning)
        var seen: Set<Set<Int>> = [Set(voiced(home))]
        var chords = [home]
        for dyad in fifthDyads(in: tuning) where seen.insert(Set(voiced(dyad))).inserted {
            chords.append(dyad)
        }
        return chords
    }

    // MARK: - Spans

    /// Slop for comparing accumulated onsets against exact multiples of the
    /// pulse. Load-bearing: eight gaps of 0.3 land at 2.3999999999999995, not
    /// 2.4, and without this the keepsake gets seven spans instead of nine.
    private static let tolerance = 1e-9

    /// Where the chords change. Each span is a stretch of the cycle, in
    /// seconds from the downbeat, that one chord covers.
    ///
    /// A chord may change only on a melody onset — a grid of bars drifted a
    /// sixteenth off the line after the first bar, because the melody moves
    /// in half-pulses and bars in whole ones. Walking the onsets, one opens a
    /// new span once the current span has run a bar, or half a bar if the
    /// onset sits after a two-pulse gap, which is where the line breathes. So
    /// the bar is the *target* length of a span, not a grid, and the harmonic
    /// rhythm follows the phrase shape: the keepsake's packed early years get
    /// bar-length spans and its spaced-out late years get shorter ones.
    ///
    /// An onset opens a span only if half a bar of the cycle remains after
    /// it; otherwise the rest of the line stays in the current span. Without
    /// that, a chord could change on the very last note and ring for a single
    /// gap, when the final chord should already be sounding under the ending.
    ///
    /// The last span runs to the end of the cycle, through the rest at the
    /// loop seam, so the arrival is still sounding when the line comes round.
    static func spans(under stars: [Star]) -> [Range<Double>] {
        guard stars.count >= 2 else { return [] }
        let onsets = Music.schedule(for: stars)
        let gaps = Music.gaps(between: stars)
        let cycle = Music.cycleLength(for: stars)
        var openings = [0.0]
        for i in 1..<onsets.count {
            guard cycle - onsets[i] >= barLength / 2 - tolerance else { break }
            let running = onsets[i] - openings.last!
            let breath = gaps[i] >= Music.longestGap - tolerance
            if running >= barLength - tolerance || (breath && running >= barLength / 2 - tolerance) {
                openings.append(onsets[i])
            }
        }
        let ends = openings.dropFirst() + [cycle]
        return zip(openings, ends).map { $0..<$1 }
    }

    // MARK: - Fit

    /// How well a chord suits a span: the time, in seconds, that notes of the
    /// chord's pitch classes are sounding inside it. Each melody note owns the
    /// time from its onset to the next (the last, to the end of the cycle).
    static func fit(of chord: Chord, in span: Range<Double>,
                    under stars: [Star], in tuning: Music.Tuning) -> Double {
        let tones = Set(voiced(chord))
        let onsets = Music.schedule(for: stars)
        let cycle = Music.cycleLength(for: stars)
        var covered = 0.0
        for (i, star) in stars.enumerated() {
            let from = onsets[i]
            let to = i + 1 < onsets.count ? onsets[i + 1] : cycle
            let overlap = min(to, span.upperBound) - max(from, span.lowerBound)
            guard overlap > 0, tones.contains(Music.semitone(forY: star.y, in: tuning) % 12) else { continue }
            covered += overlap
        }
        return covered
    }

    /// The pitch class of the note sounding at `time`: the last one to have
    /// started. Used for the note under a chord change.
    static func pitchClass(at time: Double, under stars: [Star], in tuning: Music.Tuning) -> Int {
        guard !stars.isEmpty else { return 0 }
        let onsets = Music.schedule(for: stars)
        let sounding = onsets.lastIndex { $0 <= time + 1e-9 } ?? 0
        return Music.semitone(forY: stars[sounding].y, in: tuning) % 12
    }

    /// One chord per span, chosen by fit, with the cadence forced.
    ///
    /// The last span is home, always. With three or more spans the one before
    /// it is the best-fitting chord that is *not* home, so the ending is a real
    /// leaving and returning. Two spans or one are too short for a journey and
    /// take fit alone, with the last still forced home.
    ///
    /// A chord that holds the note under the change outranks any that does
    /// not, whatever their fit: that note is the one the ear checks first, and
    /// by duration alone the keepsake put a chord tone under five of nine
    /// changes where downbeat-first puts one under every change the tuning
    /// allows. Weighting the downbeat by a bar instead was tried and is not
    /// safe — a span can run three seconds, so a chord missing the downbeat
    /// could still win on coverage.
    ///
    /// Then fit. Ties go to the chord already sounding, then to home, then to
    /// the lower root — in that order, as the tuple compares.
    static func chords(under stars: [Star], in tuning: Music.Tuning) -> [Chord] {
        let spans = spans(under: stars)
        let home = home(for: stars, in: tuning)
        let candidates = candidates(for: stars, in: tuning)
        var chosen: [Chord] = []
        for (index, span) in spans.enumerated() {
            if index == spans.count - 1 { chosen.append(home); continue }
            let cadence = spans.count >= 3 && index == spans.count - 2
            let pool = cadence ? candidates.filter { $0 != home } : candidates
            let underneath = pitchClass(at: span.lowerBound, under: stars, in: tuning)
            func rank(_ chord: Chord) -> (Int, Double, Int, Int, Int) {
                (voiced(chord).contains(underneath) ? 1 : 0,
                 fit(of: chord, in: span, under: stars, in: tuning),
                 chord == chosen.last ? 1 : 0,
                 chord == home ? 1 : 0,
                 -chord.root)
            }
            chosen.append(pool.max { rank($0) < rank($1) } ?? home)
        }
        return chosen
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
    /// Needed because the fifth can run high. Hirajoshi's dyad on 7, so its
    /// fifth is 14, and 14 semitones above a bass of 110 Hz is 247 Hz
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

    /// One voicing per span, with the chord fit chose for it.
    static func bed(under stars: [Star], in tuning: Music.Tuning) -> [Voicing] {
        zip(spans(under: stars), chords(under: stars, in: tuning)).map { span, chord in
            Voicing(chord: chord, delay: span.lowerBound, duration: noteLength)
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
