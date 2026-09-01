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

    /// `(0, 7)` is always available, which is what lets `tonic(in:)` be the same
    /// chord in every tuning. Leans on the same guarantee
    /// `RhythmTests.testEveryTuningSharesItsRootAndFifth` holds.
    func testHomeIsTheTonicAndItsFifthInEveryTuning() {
        for tuning in Music.tunings {
            let home = Harmony.tonic(in: tuning)
            XCTAssertEqual(home.tones, [0, 7], tuning.name)
            XCTAssertTrue(Harmony.fifthDyads(in: tuning).contains(home), tuning.name)
        }
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
}
