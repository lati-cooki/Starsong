import XCTest
@testable import Starsong

final class RhythmTests: XCTestCase {
    func star(_ x: CGFloat, _ y: CGFloat) -> Star {
        Star(x: x, y: y, radius: 1, phase: 0, isBright: false)
    }

    func testStarsFurtherApartLeaveALongerPause() {
        let close = [star(0.5, 0.5), star(0.52, 0.5)]
        let far = [star(0.1, 0.1), star(0.9, 0.8)]
        XCTAssertLessThan(Music.gaps(between: close)[1], Music.gaps(between: far)[1])
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

    func testNoTwoTuningsAreTheSameScale() {
        let heights = stride(from: 0.0, through: 1.0, by: 0.02).map { CGFloat($0) }
        var melodies = Set<[Int]>()
        for tuning in Music.tunings {
            let sweep = heights.map { Int(Music.pitch(forY: $0, in: tuning).rounded()) }
            melodies.insert(sweep)
        }
        XCTAssertEqual(melodies.count, Music.tunings.count, "two tunings are the same scale")
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
