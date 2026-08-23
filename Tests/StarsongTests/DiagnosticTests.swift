import XCTest
@testable import Starsong

/// Not assertions — measurements. How different do two nights actually sound?
final class SoundDiagnostics: XCTestCase {
    func midi(_ f: Double) -> Int { Int((69 + 12 * log2(f / 440)).rounded()) }

    func testHowDifferentAreTheTunings() {
        // A constellation climbing the sky, so it touches every scale degree.
        let stars = (0...14).map { d -> Star in
            Star(x: CGFloat(d) / 14, y: 1 - CGFloat(d) / 14,
                 radius: 1, phase: 0, isBright: false)
        }
        let reference = stars.map { midi(Music.pitch(forY: $0.y, in: Music.tunings[0])) }
        print("TUNING-ANALYSIS")
        for tuning in Music.tunings {
            let notes = stars.map { midi(Music.pitch(forY: $0.y, in: tuning)) }
            let differing = zip(notes, reference).filter { $0 != $1 }.count
            print(String(format: "  %-18@ %@  differs from major in %d of %d notes",
                         tuning.name as NSString,
                         notes.map(String.init).joined(separator: ",") as NSString,
                         differing, notes.count))
        }
        // Pairwise: the closest two tunings in the set.
        var closest = (a: "", b: "", differing: Int.max)
        for i in Music.tunings.indices {
            for j in (i + 1)..<Music.tunings.count {
                let x = stars.map { midi(Music.pitch(forY: $0.y, in: Music.tunings[i])) }
                let y = stars.map { midi(Music.pitch(forY: $0.y, in: Music.tunings[j])) }
                let d = zip(x, y).filter { $0 != $1 }.count
                if d < closest.differing {
                    closest = (Music.tunings[i].name, Music.tunings[j].name, d)
                }
            }
        }
        print("  CLOSEST PAIR: \(closest.a) vs \(closest.b) — \(closest.differing) of 15 notes differ")
    }

    func testHowMuchDoesRhythmActuallyVary() {
        func line(_ points: [(CGFloat, CGFloat)]) -> [Star] {
            points.map { Star(x: $0.0, y: $0.1, radius: 1, phase: 0, isBright: false) }
        }
        let shapes: [(String, [Star])] = [
            ("tight cluster", line([(0.50, 0.50), (0.54, 0.52), (0.58, 0.49), (0.61, 0.53)])),
            ("evenly spread", line([(0.15, 0.30), (0.38, 0.45), (0.61, 0.30), (0.84, 0.45)])),
            ("huge leaps", line([(0.05, 0.15), (0.95, 0.80), (0.05, 0.80), (0.95, 0.15)])),
            ("typical drag", line([(0.20, 0.35), (0.33, 0.42), (0.47, 0.38), (0.60, 0.47), (0.74, 0.41)])),
            ("Orion", Atlas.orion.walk.map { Atlas.orion.placedStars()[$0] })
        ]
        print("RHYTHM-ANALYSIS")
        for (name, stars) in shapes {
            let gaps = Music.gaps(between: stars).dropFirst()
            let lo = gaps.min() ?? 0, hi = gaps.max() ?? 0
            print(String(format: "  %-14@ gaps %@  range %.2f–%.2f  spread x%.2f  cycle %.1fs",
                         name as NSString,
                         gaps.map { String(format: "%.2f", $0) }.joined(separator: " ") as NSString,
                         lo, hi, lo > 0 ? hi / lo : 0, Music.cycleLength(for: stars)))
        }
        print("  clamp floor \(Music.shortestGap)  ceiling \(Music.longestGap)")
    }

    /// The question the synthetic shapes cannot answer: when someone drags a
    /// finger across a real sky, are the stars it picks up evenly spaced?
    @MainActor
    func testDoRealDrawnLinesVaryEnoughToHaveARhythm() {
        let size = CGSize(width: 402, height: 874)
        var steady = 0, swinging = 0
        print("DRAG-ANALYSIS")
        for seed in UInt64(1)...20 {
            let model = SkyModel()
            model.newSky(for: size, seed: seed)
            // A sweep across the sky, like a finger.
            for step in 0...30 {
                let t = CGFloat(step) / 30
                model.connect(at: CGPoint(x: 20 + t * (size.width - 40),
                                          y: 300 + sin(Double(t) * 3) * 120), in: size)
            }
            let notes = model.pathStars
            guard notes.count > 2 else { continue }
            let gaps = Music.gaps(between: notes).dropFirst()
            let unique = Set(gaps.map { Int(($0 * 100).rounded()) })
            if unique.count > 1 { swinging += 1 } else { steady += 1 }
            if seed <= 5 {
                print("  seed \(seed): \(notes.count) stars, gaps " +
                      gaps.map { String(format: "%.2f", $0) }.joined(separator: " "))
            }
        }
        print("  of 20 drawn lines: \(swinging) have a rhythm, \(steady) come out steady")
    }

    func testHowManyVoicesALayeredCycleNeeds() {
        print("VOICE-ANALYSIS")
        // Every note of a cycle is scheduled at once, so a cycle claims one
        // voice per note the instant it starts.
        for lines in 1...SkyModel.maxLines {
            for notesEach in [4, 7, 10] {
                print("  \(lines) line(s) x \(notesEach) notes = \(lines * notesEach) voices claimed at once")
            }
        }
        print("  pool size: see Synth.voiceCount")
    }
}
