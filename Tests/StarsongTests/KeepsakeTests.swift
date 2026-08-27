import XCTest
@testable import Starsong

/// The keepsake is a gift, which is exactly why it gets tested: there is no
/// second chance to notice on the night that two years landed on top of each
/// other or that the melody of her name came out as one repeated note.
final class KeepsakeTests: XCTestCase {
    private static let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    // MARK: - The years

    func testThereIsOneYearForEveryLineWritten() {
        XCTAssertEqual(Keepsake.life.count, Keepsake.years.count)
        XCTAssertEqual(FiftySky.stars().count, Keepsake.count)
    }

    func testYearsRunConsecutivelyFromTheYearSheWasBorn() {
        let life = Keepsake.life
        XCTAssertEqual(life.first?.year, Keepsake.birthYear)
        XCTAssertEqual(life.first?.age, 0)
        for (offset, year) in life.enumerated() {
            XCTAssertEqual(year.age, offset)
            XCTAssertEqual(year.year, Keepsake.birthYear + offset)
        }
    }

    /// The card carries the year as digits already; a second number beside it
    /// reads like a score rather than an age.
    func testAgesAreWrittenOut() {
        let expected: [Int: String] = [0: "nought", 1: "one", 7: "seven",
                                       13: "thirteen", 19: "nineteen", 20: "twenty",
                                       21: "twenty-one", 40: "forty", 49: "forty-nine",
                                       50: "fifty", 60: "sixty", 99: "ninety-nine"]
        // A keepsake for a hundredth birthday is somebody else's problem, but
        // it should say a number rather than walking off the end of an array.
        XCTAssertEqual(Keepsake.Year.spelled(100), "100")
        XCTAssertEqual(Keepsake.Year.spelled(-1), "-1")
        for (age, word) in expected {
            XCTAssertEqual(Keepsake.Year.spelled(age), word, "age \(age)")
        }
    }

    func testAnUnwrittenYearIsStillAYear() {
        let blank = Keepsake.Year(age: 12, year: 1988, line: "")
        XCTAssertFalse(blank.hasLine)
        XCTAssertEqual(blank.heading, "1988 · twelve")
    }

    func testDecadesAreTheLandmarks() {
        for age in 0..<50 {
            XCTAssertEqual(Keepsake.isMilestone(age: age), age % 10 == 0, "age \(age)")
        }
    }

    // MARK: - Her name, as a melody

    func testOnlyLettersSing() {
        let plain = NameSong.degrees(in: "MaryJo")
        XCTAssertEqual(NameSong.degrees(in: "Mary-Jo"), plain)
        XCTAssertEqual(NameSong.degrees(in: "Mary Jo"), plain)
        XCTAssertEqual(NameSong.degrees(in: "mary jo!"), plain)
    }

    func testAccentsKeepTheirLetter() {
        XCTAssertEqual(NameSong.degrees(in: "Zoë"), NameSong.degrees(in: "Zoe"))
        XCTAssertEqual(NameSong.degrees(in: "Renée"), NameSong.degrees(in: "Renee"))
    }

    /// The bottom of the sky is the root note, and a name that starts and ends
    /// there drones; the top is shrill. Every letter lands between.
    func testEveryLetterLandsInsideTheBand() {
        for degree in NameSong.degrees(in: Self.alphabet) {
            XCTAssertTrue((NameSong.lowest...NameSong.highest).contains(degree),
                          "degree \(degree) escaped the band")
        }
        XCTAssertGreaterThan(NameSong.lowest, 0)
        XCTAssertLessThan(NameSong.highest, Music.range)
    }

    /// The whole point of wrapping the alphabet inside the band rather than
    /// stretching it across the sky: letters that are neighbours sound like
    /// neighbours. Stretched, M and N came out an octave apart and every name
    /// with both in it sounded like a siren.
    func testNeighbouringLettersAreNeighbouringNotes() {
        let degrees = NameSong.degrees(in: Self.alphabet)
        for index in 0..<(degrees.count - 1) {
            // Every step is one note up, except where the band wraps.
            let step = degrees[index + 1] - degrees[index]
            XCTAssertTrue(step == 1 || step == -(NameSong.span - 1),
                          "step of \(step) between letter \(index) and \(index + 1)")
        }
        XCTAssertEqual(abs(NameSong.degrees(in: "MN")[0] - NameSong.degrees(in: "MN")[1]), 1)
    }

    /// Height *is* pitch everywhere else in the app, so a name turned into
    /// heights has to be the same melody read back.
    func testHeightsSingTheDegreesTheyCameFrom() {
        for name in ["Amanda", "Christopher", "Bo", "Zoe", "Xu"] {
            let degrees = NameSong.degrees(in: name)
            let heights = NameSong.heights(in: name)
            XCTAssertEqual(heights.count, degrees.count)
            for (height, degree) in zip(heights, degrees) {
                XCTAssertEqual(Music.degree(forY: height), degree, "\(name) at y=\(height)")
            }
        }
    }

    func testHerNameIsAPhraseAndNotOneRepeatedNote() {
        let degrees = NameSong.degrees(in: Keepsake.name)
        XCTAssertGreaterThan(degrees.count, 1)
        XCTAssertGreaterThan(Set(degrees).count, 1, "\(Keepsake.name) came out as a drone")
    }

    func testTheNameIsSaidEvenly() {
        let stars = NameSong.stars(in: "Amanda")
        XCTAssertEqual(stars.count, 6)
        let gaps = Music.gaps(between: stars).dropFirst()
        // Even spacing means `Music.gaps` reads the line as steady, which is
        // what a name is: a phrase, not a rhythm.
        XCTAssertEqual(Set(gaps).count, 1)
        for star in stars {
            XCTAssertTrue((0...1).contains(star.x))
            XCTAssertTrue((0...1).contains(star.y))
        }
    }

    /// `hashValue` is seeded per process, so a keepsake tuned with it would be
    /// in a different key every launch. Pinned rather than merely compared with
    /// itself, because comparing two calls in one process would not notice.
    func testHerNameAlwaysPicksTheSameKey() {
        XCTAssertEqual(NameSong.tuning(for: "Amanda").id, "balinese")
        XCTAssertEqual(NameSong.tuning(for: "amanda").id, "balinese")
        XCTAssertEqual(NameSong.tuning(for: "Am-anda").id, "balinese")
    }

    func testANameWithNoLettersInItStillWorks() {
        XCTAssertTrue(NameSong.degrees(in: "").isEmpty)
        XCTAssertTrue(NameSong.stars(in: "").isEmpty)
        XCTAssertTrue(Music.tunings.contains(NameSong.tuning(for: "1234")))
        XCTAssertEqual(FiftySky.waverProfile(for: ""), [0])
        XCTAssertEqual(FiftySky.stars(count: 50, name: "").count, 50)
    }

    // MARK: - The sky

    func testEveryYearIsWellInsideTheSky() {
        for star in FiftySky.stars() {
            XCTAssertTrue((0.05...0.95).contains(star.x), "x \(star.x)")
            XCTAssertTrue((0.10...0.90).contains(star.y), "y \(star.y)")
        }
    }

    /// The first attempt put year one at the exact centre and the opening
    /// decade came out five points apart on a phone — a smudge, not ten stars.
    func testNoTwoYearsLandOnTopOfEachOther() {
        let stars = FiftySky.stars()
        // The smallest sky the app runs on, near enough.
        let phone = CGSize(width: 375, height: 667)
        var closest = Double.greatestFiniteMagnitude
        for (i, a) in stars.enumerated() {
            for b in stars[(i + 1)...] {
                let one = a.point(in: phone), other = b.point(in: phone)
                closest = min(closest, Double(hypot(one.x - other.x, one.y - other.y)))
            }
        }
        XCTAssertGreaterThan(closest, 12, "two years are \(closest) points apart")
    }

    func testTheSpiralWindsOutwards() {
        let stars = FiftySky.stars()
        func radius(_ star: Star) -> Double {
            Double(hypot((star.x - FiftySky.centre.x) / FiftySky.reach.width,
                         (star.y - FiftySky.centre.y) / FiftySky.reach.height))
        }
        XCTAssertLessThan(radius(stars[0]), radius(stars[stars.count - 1]))
        // Her name wavers the radius, so year to year it is not monotonic — a
        // year the name pushes out can out-reach the one after it. The waver
        // repeats every letter, though, so years one name apart are pulled by
        // exactly the same amount and only the winding is left to compare.
        let period = FiftySky.waverProfile(for: Keepsake.name).count
        for age in 0..<(stars.count - period) {
            XCTAssertLessThan(radius(stars[age]), radius(stars[age + period]),
                              "year \(age) reaches no further than year \(age + period)")
        }
    }

    /// A spiral of fifty evenly-spaced stars would be a metronome. The reach
    /// between years grows as it winds out, and `Music.gaps` turns reach into
    /// note values — so the early years come quickly and the late ones are
    /// given room.
    func testTheYearsHaveARhythm() {
        let gaps = Array(Music.gaps(between: FiftySky.stars()).dropFirst())
        XCTAssertEqual(Set(gaps).count, Music.noteValues.count,
                       "the life does not use every note value")
        XCTAssertEqual(gaps.min(), Music.shortestGap)
        XCTAssertEqual(gaps.max(), Music.longestGap)

        // Which way round it goes is the point: the years near the middle come
        // quickly, and the ones out at the rim are given room.
        let opening = gaps.prefix(10).reduce(0, +)
        let closing = gaps.suffix(10).reduce(0, +)
        XCTAssertLessThan(opening, closing)
    }

    func testTheYearsClimbAndFallRatherThanSittingOnOneNote() {
        let degrees = FiftySky.stars().map { Music.degree(forY: $0.y) }
        XCTAssertGreaterThan(Set(degrees).count, 5)
        XCTAssertGreaterThan((degrees.max() ?? 0) - (degrees.min() ?? 0), 5)
    }

    func testDecadesAreDrawnAsTheBrightStars() {
        for (age, star) in FiftySky.stars().enumerated() {
            XCTAssertEqual(star.isBright, age % 10 == 0, "age \(age)")
        }
    }

    func testOpenedYearsTakeOnTheGold() {
        let stars = FiftySky.stars(lit: [0, 7, 49])
        for (age, star) in stars.enumerated() {
            XCTAssertEqual(star.isLit, [0, 7, 49].contains(age), "age \(age)")
        }
    }

    func testASkyOfOneOrNone() {
        XCTAssertTrue(FiftySky.stars(count: 0).isEmpty)
        let single = FiftySky.stars(count: 1)
        XCTAssertEqual(single.count, 1)
        XCTAssertTrue(single[0].x.isFinite && single[0].y.isFinite)
    }

    /// Measured against the name's own average, not the middle of the scale.
    /// Against the scale, AMANDA — which sings in the bottom third of the sky —
    /// produced nothing but negative numbers, and the waver became a uniform
    /// shrink that no longer had anything to do with her name.
    func testTheWaverPushesOutAsOftenAsItPullsIn() throws {
        let profile = FiftySky.waverProfile(for: "Amanda")
        XCTAssertEqual(try XCTUnwrap(profile.max()), 1, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(profile.min()), -1, accuracy: 0.0001)
        XCTAssertEqual(profile.reduce(0, +) / Double(profile.count), 0, accuracy: 0.0001)
    }

    /// A one-letter name has no deviation from its own mean, and dividing by
    /// that peak would be dividing by zero.
    func testANameOnOneNoteDoesNotDivideByZero() {
        let profile = FiftySky.waverProfile(for: "A")
        XCTAssertEqual(profile, [0])
        for star in FiftySky.stars(count: 50, name: "A") {
            XCTAssertTrue(star.x.isFinite && star.y.isFinite)
        }
    }

    // MARK: - Touching a year

    func testTheNearestYearWins() {
        let size = CGSize(width: 390, height: 844)
        let stars = FiftySky.stars()
        for age in [0, 1, 17, 33, 49] {
            XCTAssertEqual(FiftySky.year(nearest: stars[age].point(in: size),
                                         in: stars, size: size), age)
        }
    }

    func testATouchInEmptySkyOpensNothing() {
        let size = CGSize(width: 390, height: 844)
        let stars = FiftySky.stars()
        XCTAssertNil(FiftySky.year(nearest: CGPoint(x: 4, y: 830), in: stars, size: size))
        XCTAssertNil(FiftySky.year(nearest: .zero, in: stars, size: .zero))
    }

    // MARK: - What she has already read

    private func freshDefaults(_ test: String = #function) -> UserDefaults {
        let suite = "keepsake.tests." + test.filter { $0.isLetter || $0.isNumber }
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    func testProgressRemembersWhatWasRead() {
        let defaults = freshDefaults()
        var progress = KeepsakeProgress(name: "Amanda", defaults: defaults)
        XCTAssertTrue(progress.read.isEmpty)
        progress.markRead(3)
        progress.markRead(3)
        progress.markRead(41)

        let reopened = KeepsakeProgress(name: "Amanda", defaults: defaults)
        XCTAssertEqual(reopened.read, [3, 41])
    }

    func testTwoKeepsakesDoNotInheritEachOthersProgress() {
        let defaults = freshDefaults()
        var hers = KeepsakeProgress(name: "Amanda", defaults: defaults)
        hers.markRead(5)
        XCTAssertTrue(KeepsakeProgress(name: "Beatrice", defaults: defaults).read.isEmpty)
    }

    func testItIsOnlyCompleteOnceEveryYearHasBeenOpened() {
        let defaults = freshDefaults()
        var progress = KeepsakeProgress(name: "Amanda", defaults: defaults)
        for age in 0..<49 { progress.markRead(age) }
        XCTAssertFalse(progress.isComplete(of: 50))
        progress.markRead(49)
        XCTAssertTrue(progress.isComplete(of: 50))

        progress.forgetEverything()
        XCTAssertFalse(progress.isComplete(of: 50))
        XCTAssertTrue(KeepsakeProgress(name: "Amanda", defaults: defaults).read.isEmpty)
    }

    func testAnEmptyKeepsakeIsNeverComplete() {
        let progress = KeepsakeProgress(name: "Nobody", defaults: freshDefaults())
        XCTAssertFalse(progress.isComplete(of: 0))
    }

    /// What VoiceOver reads. The year is spoken whether or not anything was
    /// written for it, because silence would leave her swiping past a star that
    /// just sang without saying which one it was.
    func testEveryYearSaysSomething() {
        let written = Keepsake.Year(age: 20, year: 1996, line: "Prague, and no map.")
        XCTAssertEqual(written.spoken, "1996 · twenty. Prague, and no map.")

        let blank = Keepsake.Year(age: 21, year: 1997, line: "")
        XCTAssertTrue(blank.spoken.hasPrefix("1997 · twenty-one."))
        XCTAssertFalse(blank.spoken.hasSuffix("twenty-one."))
    }
}
