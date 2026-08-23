import XCTest
@testable import Starsong

final class RhythmTests: XCTestCase {
    func star(_ x: CGFloat, _ y: CGFloat) -> Star {
        Star(x: x, y: y, radius: 1, phase: 0, isBright: false)
    }

    /// Rhythm is relative to the line it is in: the longest reach in *this*
    /// constellation gets the long note, whatever that reach measures. So the
    /// comparison has to be within one line, not between two.
    func testTheLongestReachInALineGetsTheLongestNote() {
        let line = [star(0.10, 0.50), star(0.14, 0.50),   // a short hop
                    star(0.90, 0.50),                      // a long one
                    star(0.95, 0.50)]                      // short again
        let gaps = Music.gaps(between: line)
        XCTAssertEqual(gaps[1], Music.shortestGap, accuracy: 1e-9)
        XCTAssertEqual(gaps[2], Music.longestGap, accuracy: 1e-9)
        XCTAssertEqual(gaps[3], Music.shortestGap, accuracy: 1e-9)
    }

    /// A line drawn with even spacing is a steady line and should sound steady.
    /// Stretching a few percent of wobble into a rhythm would invent one.
    func testAnEvenlyDrawnLineKeepsASteadyPulse() {
        let even = (0..<5).map { star(0.15 + CGFloat($0) * 0.17, 0.4) }
        let gaps = Music.gaps(between: even).dropFirst()
        XCTAssertTrue(gaps.allSatisfy { abs($0 - Music.pulse) < 1e-9 },
                      "an even line should tick, not swing: \(Array(gaps))")
    }

    /// And the values it does use are proper note lengths, not a continuum —
    /// which is what makes the difference audible at all.
    func testGapsAreWholeNoteValues() {
        let ragged = [star(0.1, 0.2), star(0.15, 0.25), star(0.8, 0.7),
                      star(0.85, 0.72), star(0.3, 0.3), star(0.75, 0.6)]
        let allowed = Music.noteValues.map { Music.pulse * $0 }
        for gap in Music.gaps(between: ragged).dropFirst() {
            XCTAssertTrue(allowed.contains { abs($0 - gap) < 1e-9 }, "\(gap) is not a note value")
        }
    }

    func testGapsAreBoundedAndTheFirstNoteIsImmediate() {
        let stars = [star(0, 0), star(1, 1), star(0.5, 0.5), star(0.5, 0.5)]
        let gaps = Music.gaps(between: stars)
        XCTAssertEqual(gaps.count, stars.count)
        XCTAssertEqual(gaps[0], 0, "the first note starts on the downbeat")
        for gap in gaps.dropFirst() {
            XCTAssertTrue((Music.shortestGap...Music.longestGap).contains(gap), "gap \(gap)")
        }
        // A repeated star is a distance of zero, not a divide by zero.
        XCTAssertEqual(gaps[3], Music.shortestGap, accuracy: 1e-9)
    }

    func testTheScheduleAlwaysMovesForward() {
        let stars = (0..<12).map { star(CGFloat($0) / 12, CGFloat($0 % 3) / 3) }
        let starts = Music.schedule(for: stars)
        XCTAssertEqual(starts.count, stars.count)
        for (a, b) in zip(starts, starts.dropFirst()) {
            XCTAssertGreaterThan(b, a)
        }
        XCTAssertEqual(Music.durations(for: stars).count, stars.count)
        XCTAssertTrue(Music.durations(for: stars).allSatisfy { $0 > 0 })
    }

    func testEmptyAndSingleNoteMelodies() {
        XCTAssertTrue(Music.gaps(between: []).isEmpty)
        XCTAssertTrue(Music.schedule(for: []).isEmpty)
        XCTAssertEqual(Music.gaps(between: [star(0.5, 0.5)]), [0])
    }

    /// The point of the whole thing: Orion's belt is three stars almost on top
    /// of one another, so it should tumble out much faster than the long reach
    /// from a shoulder down to the belt.
    func testOrionsBeltIsQuickerThanItsShoulders() {
        let placed = Atlas.orion.placedStars()
        let melody = Atlas.orion.walk.map { placed[$0] }
        let gaps = Music.gaps(between: melody)

        // walk: Betelgeuse, Bellatrix, Mintaka, Rigel, Mintaka, Alnilam, Alnitak, ...
        let shoulderToBelt = gaps[2]        // Bellatrix -> Mintaka
        let alongTheBelt = gaps[5]          // Mintaka -> Alnilam
        XCTAssertLessThan(alongTheBelt, shoulderToBelt * 0.75,
                          "the belt should be noticeably faster than the reach into it")
    }
}

final class TuningTests: XCTestCase {
    func testEveryTuningIsFiveNotesInsideAnOctave() {
        for tuning in Music.tunings {
            XCTAssertEqual(tuning.degrees.count, 5, tuning.name)
            XCTAssertEqual(tuning.degrees, tuning.degrees.sorted(), "\(tuning.name) is out of order")
            XCTAssertEqual(tuning.degrees.first, 0, "\(tuning.name) should start on the root")
            XCTAssertTrue(tuning.degrees.allSatisfy { (0..<12).contains($0) }, tuning.name)
            XCTAssertEqual(Set(tuning.degrees).count, 5, "\(tuning.name) repeats a note")
        }
        XCTAssertEqual(Set(Music.tunings.map(\.id)).count, Music.tunings.count)
    }

    func testASeedAlwaysPicksTheSameTuning() {
        for seed in [UInt64(0), 1, 42, .max] {
            XCTAssertEqual(Music.tuning(for: seed), Music.tuning(for: seed))
        }
        XCTAssertTrue(Music.tunings.contains(Music.tuning(for: .random(in: .min ... .max))))
    }

    /// Every tuning is built on the same root and fifth — that is deliberate,
    /// and it is what keeps two different nights sounding like one instrument.
    /// So any single height can land on a note they all agree about; it's the
    /// whole sweep that has to differ.
    func testEveryTuningSharesItsRootAndFifth() {
        for tuning in Music.tunings {
            XCTAssertTrue(tuning.degrees.contains(0), tuning.name)
            XCTAssertTrue(tuning.degrees.contains(7), tuning.name)
        }
    }

    /// Not just "different" — *audibly* different. Two scales that diverge on
    /// two notes out of fifteen sound like one scale, which is exactly the trap
    /// this set fell into twice before it was chosen by search.
    func testEveryPairOfTuningsIsAudiblyDifferent() {
        // One star per scale degree, so the comparison covers the whole sky.
        let sky = (0...Music.range).map { degree -> CGFloat in
            1 - CGFloat(degree) / CGFloat(Music.range)
        }
        func notes(_ tuning: Music.Tuning) -> [Int] {
            sky.map { Int((69 + 12 * log2(Music.pitch(forY: $0, in: tuning) / 440)).rounded()) }
        }

        var worst = (pair: "", differing: Int.max)
        for i in Music.tunings.indices {
            for j in (i + 1)..<Music.tunings.count {
                let a = Music.tunings[i], b = Music.tunings[j]
                let differing = zip(notes(a), notes(b)).filter { $0 != $1 }.count
                if differing < worst.differing {
                    worst = ("\(a.name) vs \(b.name)", differing)
                }
            }
        }
        XCTAssertGreaterThanOrEqual(worst.differing, 5,
                                    "\(worst.pair) differ in only \(worst.differing) of \(sky.count) notes")
    }

    func testPitchStaysMonotonicInEveryTuning() {
        for tuning in Music.tunings {
            var previous = 0.0
            for step in stride(from: 1.0, through: 0.0, by: -0.01) {
                let pitch = Music.pitch(forY: CGFloat(step), in: tuning)
                XCTAssertGreaterThanOrEqual(pitch, previous, "\(tuning.name) dipped at y=\(step)")
                previous = pitch
            }
        }
    }

    @MainActor
    func testASkyIsTunedByItsSeedAndAKeptSkyRemembersIt() {
        let model = SkyModel()
        model.newSky(for: CGSize(width: 390, height: 844), seed: 4)
        XCTAssertEqual(model.tuning, Music.tuning(for: 4))

        let saved = SavedSky(seed: 4, fieldStarCount: 40, lines: [[0, 1]], name: "x", myth: "y")
        XCTAssertEqual(saved.tuning, model.tuning)
    }
}
