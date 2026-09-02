import XCTest
@testable import Starsong

final class HarmonyTests: XCTestCase {
    func star(_ x: CGFloat, _ y: CGFloat) -> Star {
        Star(x: x, y: y, radius: 1, phase: 0, isBright: false)
    }

    /// A line of `count` stars spaced unevenly enough that `Music.gaps` gives it
    /// a rhythm rather than a metronome.
    func line(_ count: Int) -> [Star] {
        (0..<count).map { i in
            star(0.1 + CGFloat(i) * 0.8 / CGFloat(max(count - 1, 1)),
                 0.2 + CGFloat(i % 3) * 0.25)
        }
    }

    /// A star sitting exactly on scale degree `degree`, `0...14`.
    func star(atDegree degree: Int, x: CGFloat = 0.5) -> Star {
        star(x, 1 - CGFloat(degree) / CGFloat(Music.range))
    }

    /// A line that walks the given degrees left to right, evenly spaced.
    func line(degrees: [Int]) -> [Star] {
        degrees.enumerated().map { i, d in
            star(atDegree: d, x: 0.1 + CGFloat(i) * 0.8 / CGFloat(max(degrees.count - 1, 1)))
        }
    }

    // MARK: - The safety argument

    /// The whole reason the bed cannot sour a melody: every note it plays is a
    /// degree of the same tuning the melody is drawing from, so it can only
    /// sound notes the line could already have sung. Checked against the two
    /// octaves the dyads are allowed to reach across.
    func testEveryChordToneIsAMemberOfItsTuning() {
        for tuning in Music.tunings {
            let members = Set(tuning.degrees + tuning.degrees.map { $0 + 12 })
            for bars in 1...12 {
                for chord in Harmony.chords(bars: bars, in: tuning) {
                    for tone in chord.tones {
                        XCTAssertTrue(members.contains(tone),
                                      "\(tuning.name): \(tone) is not in \(tuning.degrees)")
                    }
                }
            }
        }
    }

    /// Root and fifth, never a third — the five tunings disagree about whether
    /// they are major or minor and a third would pick a side.
    func testEveryChordIsARootAndAFifth() {
        for tuning in Music.tunings {
            for chord in Harmony.fifthDyads(in: tuning) {
                XCTAssertEqual(chord.tones.count, 2, tuning.name)
                XCTAssertEqual(chord.tones[0], chord.root, tuning.name)
                XCTAssertEqual(chord.tones[1] - chord.tones[0], 7, tuning.name)
            }
        }
    }

    /// Harmonic motion has to be available in every tuning, or the bed is a
    /// drone in some of them and the cadence has nothing to return *from*.
    func testEveryTuningHasSomewhereToGo() {
        for tuning in Music.tunings {
            XCTAssertGreaterThanOrEqual(Harmony.fifthDyads(in: tuning).count, 2, tuning.name)
            XCTAssertNotEqual(Harmony.away(in: tuning).root, 0, tuning.name)
        }
    }

    // MARK: - Home

    /// The tonic is wherever the tune rests, not degree 0 of the tuning. The
    /// keepsake's spiral closes on degree 4 in every key, and a bed that called
    /// degree 0 home was in a different key from the tune it sat under.
    func testTheTonicIsTheLastNotesPitchClass() {
        for tuning in Music.tunings {
            for degree in 0...Music.range {
                let stars = line(degrees: [0, 3, degree])
                let expected = Music.semitone(forY: stars.last!.y, in: tuning) % 12
                XCTAssertEqual(Harmony.tonic(of: stars, in: tuning), expected,
                               "\(tuning.name) degree \(degree)")
            }
        }
        XCTAssertEqual(Harmony.tonic(of: [], in: Music.default), 0)
    }

    /// Home is the tonic and its fifth when the tuning has that fifth, and the
    /// tonic alone when it does not — bare, but unambiguous. Never an octave:
    /// `voiced` folds every tone into one octave, so `[t, t + 12]` would come
    /// out as the same note rolled twice.
    func testHomeIsRootedOnTheTonic() {
        for tuning in Music.tunings {
            let members = Set(tuning.degrees)
            for degree in 0...Music.range {
                let stars = line(degrees: [2, degree])
                let home = Harmony.home(for: stars, in: tuning)
                let tonic = Harmony.tonic(of: stars, in: tuning)
                XCTAssertEqual(home.root, tonic, tuning.name)
                XCTAssertEqual(home.tones.first, tonic, tuning.name)
                if members.contains((tonic + 7) % 12) {
                    XCTAssertEqual(home.tones, [tonic, tonic + 7], "\(tuning.name) has the fifth")
                } else {
                    XCTAssertEqual(home.tones, [tonic], "\(tuning.name) lacks the fifth")
                }
                XCTAssertEqual(Set(Harmony.voiced(home)).count, home.tones.count,
                               "\(tuning.name): a tone is doubled")
            }
        }
    }

    /// The keepsake rests on degree 4. Three tunings have its fifth; In and
    /// Balinese do not, and take the bare tonic.
    func testWhichTuningsGiveTheKeepsakeAFifth() {
        let expected = ["major": 2, "minor": 2, "hirajoshi": 2, "in": 1, "balinese": 1]
        for tuning in Music.tunings {
            let home = Harmony.home(for: FiftySky.stars(), in: tuning)
            XCTAssertEqual(home.tones.count, expected[tuning.id], tuning.name)
        }
    }

    /// Home first, then every fifth dyad, with nothing listed twice: when home
    /// *is* one of the fifth dyads it must not appear again as a competitor.
    func testCandidatesAreHomeAndEveryFifthDyadOnce() {
        for tuning in Music.tunings {
            for degree in 0...Music.range {
                let stars = line(degrees: [1, degree])
                let candidates = Harmony.candidates(for: stars, in: tuning)
                let home = Harmony.home(for: stars, in: tuning)
                XCTAssertEqual(candidates.first, home, tuning.name)
                let sets = candidates.map { Set(Harmony.voiced($0)) }
                XCTAssertEqual(Set(sets).count, sets.count, "\(tuning.name): a chord is listed twice")
                for dyad in Harmony.fifthDyads(in: tuning) {
                    XCTAssertTrue(sets.contains(Set(Harmony.voiced(dyad))),
                                  "\(tuning.name): dyad on \(dyad.root) is missing")
                }
            }
        }
    }

    // MARK: - Spans

    /// A chord may change only where a note starts. A grid of bars drifted a
    /// sixteenth off the melody after the first bar, because the line moves in
    /// half-pulses and bars in whole ones.
    func testEverySpanOpensOnAMelodyOnset() {
        for count in 2...16 {
            let stars = line(count)
            let onsets = Music.schedule(for: stars)
            for span in Harmony.spans(under: stars) {
                XCTAssertTrue(onsets.contains { abs($0 - span.lowerBound) < 1e-9 },
                              "\(count) notes: a span opens at \(span.lowerBound), between notes")
            }
        }
    }

    /// Spans tile the cycle: the first opens on the downbeat, each one starts
    /// where the last ended, and the last runs to the end of the cycle, so the
    /// arrival is still sounding through the rest at the loop seam.
    func testSpansTileTheCycle() {
        for count in 2...16 {
            let stars = line(count)
            let spans = Harmony.spans(under: stars)
            XCTAssertEqual(spans.first?.lowerBound, 0, "\(count) notes")
            XCTAssertEqual(spans.last?.upperBound ?? -1, Music.cycleLength(for: stars),
                           accuracy: 1e-9, "\(count) notes")
            for (a, b) in zip(spans, spans.dropFirst()) {
                XCTAssertEqual(a.upperBound, b.lowerBound, accuracy: 1e-9, "\(count) notes: a gap between spans")
                XCTAssertLessThan(a.lowerBound, a.upperBound, "\(count) notes: an empty span")
            }
        }
    }

    /// A span runs about a bar: never shorter than half of one, and — except
    /// the last, which is the cadence and may run long — never longer than a
    /// bar plus the two-pulse gap an onset can sit past the bar it was
    /// waiting for. The one exception is a line whose whole cycle is shorter
    /// than half a bar: two notes make a 0.9 s cycle and get one short span.
    func testSpansRunAboutABar() {
        for count in 2...16 {
            let stars = line(count)
            let spans = Harmony.spans(under: stars)
            let wholeCycleIsShort = spans.count == 1
                && Music.cycleLength(for: stars) < Harmony.barLength / 2
            for (i, span) in spans.enumerated() {
                let length = span.upperBound - span.lowerBound
                if !wholeCycleIsShort {
                    XCTAssertGreaterThanOrEqual(length + 1e-9, Harmony.barLength / 2,
                                                "\(count) notes: span \(i) is too short")
                }
                if i < spans.count - 1 {
                    XCTAssertLessThanOrEqual(length - 1e-9, Harmony.barLength + Music.longestGap,
                                             "\(count) notes: span \(i) is too long")
                }
            }
        }
    }

    /// A steady line has no breaths in it, so its spans are whole bars snapped
    /// to the pulse: eight notes at one pulse each is exactly a bar.
    func testASteadyLineGetsWholeBars() {
        let stars = line(degrees: Array(repeating: [3, 5], count: 12).flatMap { $0 })   // 24 notes, even spacing
        XCTAssertEqual(Music.gaps(between: stars).dropFirst().min(), Music.pulse, "not a steady line")
        let spans = Harmony.spans(under: stars)
        for span in spans.dropLast() {
            XCTAssertEqual(span.upperBound - span.lowerBound, Harmony.barLength, accuracy: 1e-9)
        }
    }

    /// A breath — a two-pulse gap — lets a chord change early, but only once
    /// the span has run half a bar; a breath after a quarter of a bar is just
    /// a long note.
    func testABreathOpensASpanAfterHalfABar() {
        // Reaches: three short, one long (a breath), then short. Positions
        // chosen so the gaps come out as pulse/2, pulse/2, pulse/2, 2*pulse.
        let stars = [star(0.10, 0.5), star(0.15, 0.5), star(0.20, 0.5), star(0.25, 0.5),
                     star(0.65, 0.5), star(0.70, 0.5), star(0.75, 0.5), star(0.80, 0.5),
                     star(0.85, 0.5), star(0.90, 0.5), star(0.95, 0.5)]
        let gaps = Music.gaps(between: stars)
        XCTAssertEqual(gaps[4], Music.longestGap, accuracy: 1e-9, "the fourth reach should be a breath")
        let onsets = Music.schedule(for: stars)
        let spans = Harmony.spans(under: stars)
        // The breath lands at onsets[4] = 0.15 * 3 + 0.6 = 1.05 s, which is
        // less than half a bar (1.2 s) into the first span, so it must NOT open
        // a span there.
        XCTAssertFalse(spans.contains { abs($0.lowerBound - onsets[4]) < 1e-9 },
                       "a breath before half a bar opened a span")

        // Nine tight notes then the breath: it lands at 8 * 0.15 + 0.6 =
        // 1.8 s, past half a bar and short of a whole one, so it must open a
        // span there and nowhere earlier. Six notes follow it so that more
        // than half a bar of cycle remains after the breath.
        let later = (0..<9).map { star(0.10 + CGFloat($0) * 0.03, 0.5) }
            + (0..<6).map { star(0.70 + CGFloat($0) * 0.03, 0.5) }
        let laterOnsets = Music.schedule(for: later)
        XCTAssertEqual(Music.gaps(between: later)[9], Music.longestGap, accuracy: 1e-9)
        XCTAssertEqual(Harmony.spans(under: later).map(\.lowerBound), [0, laterOnsets[9]])
    }

    /// A chord does not change on the very last note to ring for a single
    /// gap: an onset opens a span only if half a bar of the cycle remains
    /// after it. Nine steady notes at one pulse each reach a bar on the
    /// ninth, but only 0.6 s of cycle is left there, so it stays one span.
    func testNoSpanOpensWithLessThanHalfABarLeft() {
        let stars = line(degrees: Array(repeating: 0, count: 9))
        XCTAssertEqual(Music.gaps(between: stars)[8], Music.pulse, accuracy: 1e-9, "not a steady line")
        XCTAssertEqual(Music.schedule(for: stars)[8], Harmony.barLength, accuracy: 1e-9, "ninth note should land on the bar")
        XCTAssertEqual(Harmony.spans(under: stars).count, 1)
        // Two more notes and there is room: the span opens on the ninth.
        let longer = line(degrees: Array(repeating: 0, count: 13))
        XCTAssertEqual(Harmony.spans(under: longer).map(\.lowerBound), [0, Harmony.barLength])
    }

    // MARK: - Cadence

    /// The point of the exercise. Whatever length the melody is, the bed's last
    /// bar is home, so a loop seam sounds like a return rather than a join.
    func testEveryProgressionEndsAtHome() {
        for tuning in Music.tunings {
            for bars in 1...16 {
                let chords = Harmony.chords(bars: bars, in: tuning)
                XCTAssertEqual(chords.count, bars, tuning.name)
                XCTAssertEqual(chords.last, Harmony.tonic(in: tuning),
                               "\(tuning.name) at \(bars) bars did not come home")
            }
        }
    }

    func testProgressionsStartAtHomeToo() {
        for tuning in Music.tunings {
            for bars in 1...16 {
                XCTAssertEqual(Harmony.chords(bars: bars, in: tuning).first,
                               Harmony.tonic(in: tuning), tuning.name)
            }
        }
    }

    /// Three bars is the first length with room to leave and come back. Two or
    /// fewer hold home deliberately — a drone is the honest thing to do with a
    /// melody too short to have a journey in it.
    func testShortMelodiesDroneAndLongerOnesMove() {
        for tuning in Music.tunings {
            for bars in 1...2 {
                let chords = Harmony.chords(bars: bars, in: tuning)
                XCTAssertTrue(chords.allSatisfy { $0 == Harmony.tonic(in: tuning) },
                              "\(tuning.name) at \(bars) bars should drone")
            }
            for bars in 3...16 {
                let chords = Harmony.chords(bars: bars, in: tuning)
                XCTAssertTrue(chords.contains(Harmony.away(in: tuning)),
                              "\(tuning.name) at \(bars) bars never leaves home")
            }
        }
    }

    // MARK: - Fitting the melody

    /// The bed has to cover the melody including the rest at the loop seam,
    /// because that rest is where the arrival still needs to be sounding.
    func testTheBedCoversTheWholeCycle() {
        for tuning in Music.tunings {
            for count in 2...12 {
                let notes = line(count)
                let bed = Harmony.bed(under: notes, in: tuning)
                XCTAssertFalse(bed.isEmpty, "\(count) notes got no bed")
                let covered = (bed.last!.delay + Harmony.barLength)
                XCTAssertGreaterThanOrEqual(covered + 1e-9,
                                            Music.cycleLength(for: notes),
                                            "\(tuning.name), \(count) notes: bed ends early")
            }
        }
    }

    /// One chord per bar, in order, no gaps between them.
    func testChordsLandOneToABarInOrder() {
        let bed = Harmony.bed(under: line(9), in: Music.default)
        for (bar, voicing) in bed.enumerated() {
            XCTAssertEqual(voicing.delay, Double(bar) * Harmony.barLength, accuracy: 1e-9)
        }
    }

    /// Each chord has to be gone before the next one arrives. Overlapping them
    /// is what turned the first attempt into a drone — see `Harmony.noteLength`
    /// — and on a voice that decays there is nothing to gain by it.
    func testChordsDieInsideTheirOwnBar() {
        let bed = Harmony.bed(under: line(9), in: Music.default)
        XCTAssertGreaterThan(bed.count, 1, "need at least two bars to compare")
        for voicing in bed {
            XCTAssertLessThan(voicing.duration + Harmony.roll, Harmony.barLength,
                              "a chord is still sounding when the next one lands")
        }
    }

    /// The bed speaks in the same voice as the rest of the app: something that
    /// blooms and dies. Every voice but `brass` has a decay term in it, and
    /// `brass` holding at full amplitude is exactly what made a sustained bed
    /// sound like a horror film.
    func testTheBedIsVoicedOnSomethingThatDecays() {
        XCTAssertNotEqual(Harmony.voice, .brass,
                          "brass does not decay — see Harmony.noteLength")
        let held = Harmony.voice.samples(frequency: 110, duration: 1.3,
                                         sampleRate: 44_100)
        let opening = held.prefix(held.count / 4).map { abs($0) }.max() ?? 0
        let ending = held.suffix(held.count / 4).map { abs($0) }.max() ?? 0
        XCTAssertLessThan(ending, opening * 0.5,
                          "the bed's voice is still going at full tilt when it should have died")
    }

    /// Quiet enough to sit under the melody. The quietest a melody note gets is
    /// 0.17, on a layered line.
    func testTheBedIsQuieterThanTheMelody() {
        XCTAssertLessThan(Harmony.volume, 0.17)
    }

    /// A single star is a tap, not a melody, and gets nothing.
    func testTooShortToHarmonise() {
        XCTAssertTrue(Harmony.bed(under: [], in: Music.default).isEmpty)
        XCTAssertTrue(Harmony.bed(under: [star(0.5, 0.5)], in: Music.default).isEmpty)
    }

    // MARK: - Pitch

    /// The bed sits below the melody rather than inside it. The lowest note a
    /// line can sing is the root at 220 Hz, so every tone actually sounded has
    /// to come out under that — which is what `voiced` is for, and it is not
    /// true of the unfolded dyads.
    func testTheBedSitsBelowTheMelody() {
        for tuning in Music.tunings {
            for bars in 1...12 {
                for chord in Harmony.chords(bars: bars, in: tuning) {
                    for tone in Harmony.voiced(chord) {
                        XCTAssertLessThan(Harmony.frequency(semitonesAboveRoot: tone),
                                          Music.rootFrequency,
                                          "\(tuning.name): tone \(tone) is up in the melody")
                    }
                }
            }
        }
    }

    /// Folding must not smuggle in a note the tuning does not have — the whole
    /// safety argument survives only because dropping an octave keeps a tone a
    /// member of the scale.
    func testFoldingKeepsEveryToneInTheTuning() {
        for tuning in Music.tunings {
            let members = Set(tuning.degrees)
            for chord in Harmony.fifthDyads(in: tuning) {
                for tone in Harmony.voiced(chord) {
                    XCTAssertTrue(members.contains(tone),
                                  "\(tuning.name): folded \(tone) left \(tuning.degrees)")
                    XCTAssertTrue((0..<12).contains(tone), "\(tone) is not folded")
                }
            }
        }
    }

    /// Folding a fifth that runs high turns it into the fourth below — the same
    /// pair of notes. Hirajoshi's away chord is the case that needs it.
    func testAFifthThatRunsHighBecomesTheFourthBelow() {
        let hirajoshi = Music.tunings.first { $0.id == "hirajoshi" }!
        let away = Harmony.away(in: hirajoshi)
        XCTAssertEqual(away.tones, [7, 14])
        XCTAssertEqual(Harmony.voiced(away), [7, 2])
    }

    func testIntervalClassMeasuresBothDirections() {
        XCTAssertEqual(Harmony.intervalClass(0), 0)
        XCTAssertEqual(Harmony.intervalClass(7), 5)    // a fifth up is a fourth down
        XCTAssertEqual(Harmony.intervalClass(5), 5)
        XCTAssertEqual(Harmony.intervalClass(6), 6)    // the tritone is its own inverse
        XCTAssertEqual(Harmony.intervalClass(-1), 1)
        XCTAssertEqual(Harmony.intervalClass(13), 1)
    }

    /// Not a chosen list — this is what "travel furthest from home" returns, and
    /// it comes out as V, iv, v, iv and III. Pinned so a change to the rule or
    /// to the tunings has to be looked at rather than just noticed later.
    func testTheAwayChordIsTheOneThatTravelsFurthest() {
        let expected = ["major": 7, "minor": 5, "hirajoshi": 7, "in": 5, "balinese": 3]
        for tuning in Music.tunings {
            XCTAssertEqual(Harmony.away(in: tuning).root, expected[tuning.id],
                           tuning.name)
        }
    }

    // MARK: - Fit

    /// Fit is the time a chord's tones are sounding inside a span. A span
    /// entirely on the root, under major's (0, 7), is worth the whole span;
    /// under (2, 9) it is worth nothing.
    func testFitCountsChordToneTime() {
        let major = Music.tunings[0]
        let stars = line(degrees: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])   // steady, all on the root
        let span = Harmony.spans(under: stars)[0]
        let onRoot = Harmony.Chord(root: 0, tones: [0, 7])
        let offRoot = Harmony.Chord(root: 2, tones: [2, 9])
        let length = span.upperBound - span.lowerBound
        XCTAssertEqual(Harmony.fit(of: onRoot, in: span, under: stars, in: major),
                       length, accuracy: 1e-9)
        XCTAssertEqual(Harmony.fit(of: offRoot, in: span, under: stars, in: major), 0, accuracy: 1e-9)
    }

    /// A line that sits on degrees 1 and 3 — pitch classes 2 and 7 in major —
    /// is covered entirely by the dyad (7, 2) and only half by (0, 7) or
    /// (2, 9). Fit has to pick the one that covers it.
    func testFitPicksTheChordThatCoversTheMelody() {
        let major = Music.tunings[0]
        let stars = line(degrees: Array(repeating: [1, 3], count: 12).flatMap { $0 })
        let chords = Harmony.chords(under: stars, in: major)
        XCTAssertGreaterThanOrEqual(chords.count, 3, "need a free span before the cadence")
        XCTAssertEqual(chords[0].root, 7, "first span should be the dyad covering both notes")
    }

    /// The note under a chord change is the one the ear checks first, so a
    /// chord that holds it outranks any that does not. By duration alone the
    /// keepsake put a chord tone under five of nine changes; downbeat first
    /// puts one under every change the tuning allows. So: wherever *some*
    /// candidate contains the note at a span's start, the chosen chord must.
    func testAChordChangeLandsOnAChordToneWheneverItCan() {
        for tuning in Music.tunings {
            for stars in [FiftySky.stars(), line(9), line(16), line(degrees: [4, 8, 1, 6, 12, 3, 9, 2, 7, 0, 5, 11])] {
                let onsets = Music.schedule(for: stars)
                let spans = Harmony.spans(under: stars)
                let chords = Harmony.chords(under: stars, in: tuning)
                let candidates = Harmony.candidates(for: stars, in: tuning)
                XCTAssertEqual(chords.count, spans.count, tuning.name)
                for (i, (span, chord)) in zip(spans, chords).enumerated() where i < spans.count - 1 {
                    let note = onsets.firstIndex { abs($0 - span.lowerBound) < 1e-9 }!
                    let pc = Music.semitone(forY: stars[note].y, in: tuning) % 12
                    let pool = i == spans.count - 2
                        ? candidates.filter { $0 != Harmony.home(for: stars, in: tuning) }
                        : candidates
                    let possible = pool.contains { Harmony.voiced($0).contains(pc) }
                    if possible {
                        XCTAssertTrue(Harmony.voiced(chord).contains(pc),
                                      "\(tuning.name): span \(i) opens on \(pc) under \(chord.tones)")
                    }
                }
            }
        }
    }

    // MARK: - Cadence

    /// The point of the exercise. Whatever the melody, the last chord is home
    /// and it contains the note the tune rests on, so a loop seam sounds like
    /// a return rather than a join.
    func testEveryProgressionEndsAtHomeUnderTheLastNote() {
        for tuning in Music.tunings {
            for stars in (2...16).map(line) + [FiftySky.stars()] {
                let chords = Harmony.chords(under: stars, in: tuning)
                XCTAssertEqual(chords.last, Harmony.home(for: stars, in: tuning),
                               "\(tuning.name), \(stars.count) notes did not come home")
                XCTAssertTrue(Harmony.voiced(chords.last!).contains(Harmony.tonic(of: stars, in: tuning)),
                              "\(tuning.name): the last chord does not hold the last note")
            }
        }
    }

    /// With three or more spans, the chord before the last is not home, so the
    /// ending is a real leaving and returning rather than a coin toss. Two
    /// spans or one are too short to have a journey in them.
    func testTheChordBeforeTheLastIsAway() {
        for tuning in Music.tunings {
            for stars in (2...16).map(line) + [FiftySky.stars()] {
                let chords = Harmony.chords(under: stars, in: tuning)
                guard chords.count >= 3 else { continue }
                XCTAssertNotEqual(chords[chords.count - 2], Harmony.home(for: stars, in: tuning),
                                  "\(tuning.name), \(stars.count) notes: no cadence")
            }
        }
    }

    /// Ties fall to the chord already sounding, so a span that is indifferent
    /// does not change chord for the sake of it.
    func testTiesStayOnThePreviousChord() {
        let major = Music.tunings[0]
        // Degree 2 is pitch class 4, which only the dyad (9, 4) holds; degree
        // 3 is 7, held by (0, 7) and (7, 2). A span entirely on degree 3 after
        // one on degree 2: (0,7) and (7,2) tie, neither is the previous chord
        // (9,4), and home is (root of the last note) — make the last note
        // degree 1 (pc 2) so home is (2, 9) and is not in the tie either.
        // Then the lower root, 0, wins. (The second span is the penultimate
        // one, so home is excluded from its pool anyway.)
        let stars = line(degrees: Array(repeating: 2, count: 8) + Array(repeating: 3, count: 8)
                                  + Array(repeating: 2, count: 8) + [1])
        let chords = Harmony.chords(under: stars, in: major)
        XCTAssertEqual(chords.count, 3)
        XCTAssertEqual(chords[0].root, 9)
        XCTAssertEqual(chords[1].root, 0, "tie between (0,7) and (7,2) should go to the lower root")
    }
}
