import XCTest
@testable import Starsong

final class MusicTests: XCTestCase {
    func testHigherStarsSingHigher() {
        let low = Music.pitch(forY: 0.82)   // near the bottom of the sky
        let high = Music.pitch(forY: 0.12)  // near the top
        XCTAssertGreaterThan(high, low)
    }

    func testPitchIsMonotonicUpTheSky() {
        var previous = 0.0
        for step in stride(from: 1.0, through: 0.0, by: -0.01) {
            let pitch = Music.pitch(forY: CGFloat(step))
            XCTAssertGreaterThanOrEqual(pitch, previous, "pitch dipped at y=\(step)")
            previous = pitch
        }
    }

    /// The original port indexed the scale with a value derived from y without
    /// clamping, so a position outside the sky could walk off the array.
    func testDegreeIsClampedForOutOfRangePositions() {
        for y in [-5.0, -0.2, 0.0, 1.0, 1.4, 12.0] {
            let degree = Music.degree(forY: CGFloat(y))
            XCTAssertTrue((0...Music.range).contains(degree), "degree \(degree) out of range for y=\(y)")
            XCTAssertTrue(Music.pitch(forY: CGFloat(y)).isFinite)
        }
        XCTAssertEqual(Music.degree(forY: CGFloat.nan), 0)
    }

    func testEveryDegreeLandsOnThePentatonicScale() {
        for degree in 0...Music.range {
            let y = 1 - CGFloat(degree) / CGFloat(Music.range)
            let semitonesAboveRoot = 12 * log2(Music.pitch(forY: y) / Music.rootFrequency)
            let pitchClass = Int(semitonesAboveRoot.rounded()) % 12
            XCTAssertTrue(Music.scale.contains(pitchClass),
                          "degree \(degree) produced pitch class \(pitchClass)")
        }
    }

    /// The pitch a star sings, as a number the harmony can reason about. The
    /// bottom of the sky is the root; the top is two octaves and four degrees
    /// up, which is 24 semitones plus the tuning's highest degree.
    func testSemitoneCountsUpFromTheRoot() {
        for tuning in Music.tunings {
            XCTAssertEqual(Music.semitone(forY: 1, in: tuning), 0, tuning.name)
            XCTAssertEqual(Music.semitone(forY: 0, in: tuning),
                           24 + tuning.degrees[4], tuning.name)
            // Degree 5 is the root an octave up, in every tuning.
            XCTAssertEqual(Music.semitone(forY: 1 - 5.0 / 14, in: tuning), 12, tuning.name)
        }
    }
}
