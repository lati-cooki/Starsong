import XCTest
@testable import Starsong

@MainActor
final class KeepsakeModelTests: XCTestCase {
    private let size = CGSize(width: 390, height: 844)

    private func makeModel(years: [String] = Array(repeating: "", count: 12),
                           _ test: String = #function) -> KeepsakeModel {
        let suite = "keepsake.model.tests." + test.filter { $0.isLetter || $0.isNumber }
        UserDefaults().removePersistentDomain(forName: suite)
        let life = years.indices.map {
            Keepsake.Year(age: $0, year: 1976 + $0, line: years[$0])
        }
        return KeepsakeModel(name: "Amanda", life: life, defaults: UserDefaults(suiteName: suite)!)
    }

    func testItOpensWithNothingShowingAndEveryYearWaiting() {
        let model = makeModel()
        XCTAssertNil(model.showing)
        XCTAssertNil(model.year)
        XCTAssertNil(model.cursor)
        XCTAssertTrue(model.read.isEmpty)
        XCTAssertFalse(model.isComplete)
        XCTAssertEqual(model.stars.count, model.life.count)
        XCTAssertFalse(model.stars.contains { $0.isLit })
    }

    func testTouchingAStarOpensItsYearAndKeepsIt() {
        let model = makeModel()
        model.touch(at: model.stars[4].point(in: size), in: size)

        XCTAssertEqual(model.showing, 4)
        XCTAssertEqual(model.year?.year, 1980)
        XCTAssertEqual(model.read, [4])
        XCTAssertTrue(model.stars[4].isLit)
        XCTAssertEqual(model.cursor?.x, model.stars[4].x)
        // The ring it left behind.
        XCTAssertEqual(model.pulses.count, 1)
    }

    func testTouchingEmptySkyOpensNothing() {
        let model = makeModel()
        model.touch(at: CGPoint(x: 3, y: 838), in: size)
        XCTAssertNil(model.showing)
        XCTAssertTrue(model.read.isEmpty)
    }

    /// A drag crosses the same star for many frames; only the first one is a
    /// new year, and the rest must not stack up rings or re-sound the note.
    func testHoldingOnOneStarOnlyOpensItOnce() {
        let model = makeModel()
        let star = model.stars[2].point(in: size)
        for _ in 0..<5 { model.touch(at: star, in: size) }
        XCTAssertEqual(model.pulses.count, 1)
        XCTAssertEqual(model.read, [2])
    }

    func testSteppingWalksTheYearsAndStopsAtBothEnds() {
        let model = makeModel()
        model.step(by: 1)
        XCTAssertEqual(model.showing, 0)
        model.step(by: 1)
        XCTAssertEqual(model.showing, 1)
        model.step(by: -1)
        XCTAssertEqual(model.showing, 0)

        model.step(by: -1)
        XCTAssertEqual(model.showing, 0, "stepped below the year she was born")
        for _ in 0..<40 { model.step(by: 1) }
        XCTAssertEqual(model.showing, model.life.count - 1)
    }

    func testTheCaptionIsTheDedicationUntilThereIsProgressToReport() {
        let model = makeModel()
        XCTAssertEqual(model.caption, Keepsake.dedication.uppercased())
        model.show(3)
        XCTAssertEqual(model.caption, "1 OF \(model.life.count) OPENED")
    }

    func testItIsCompleteOnlyOnceEveryYearHasBeenOpened() {
        let model = makeModel()
        for age in 0..<(model.life.count - 1) { model.show(age) }
        XCTAssertFalse(model.isComplete)
        model.show(model.life.count - 1)
        XCTAssertTrue(model.isComplete)
    }

    func testItComesBackWhereSheLeftIt() {
        let suite = "keepsake.model.tests.resume"
        UserDefaults().removePersistentDomain(forName: suite)
        let defaults = UserDefaults(suiteName: suite)!
        let life = (0..<10).map { Keepsake.Year(age: $0, year: 1976 + $0, line: "") }

        let first = KeepsakeModel(name: "Amanda", life: life, defaults: defaults)
        first.show(6)

        let reopened = KeepsakeModel(name: "Amanda", life: life, defaults: defaults)
        XCTAssertEqual(reopened.read, [6])
        XCTAssertTrue(reopened.stars[6].isLit)
        // Where she got to is remembered; which card was up is not. A keepsake
        // should open on the dedication, not mid-sentence.
        XCTAssertNil(reopened.showing)
    }

    func testTheSkySaysWhereToBeginBeforeAnythingIsOpen() {
        let model = makeModel()
        XCTAssertTrue(model.spoken.contains("\(model.life.count) years"))
        XCTAssertTrue(model.spoken.contains("\(Keepsake.birthYear)"))
        model.show(1)
        XCTAssertEqual(model.spoken, model.life[1].spoken)
    }

    func testPlayingSchedulesTheWholeLifeAndStopsCleanly() {
        let model = makeModel()
        model.play()
        XCTAssertTrue(model.isPlaying)
        // Every year is scheduled up front, on the audio clock.
        XCTAssertEqual(model.pulses.count, model.life.count)

        model.stop()
        XCTAssertFalse(model.isPlaying)
    }

    /// A whole life goes onto the audio clock in one go, so stopping has to
    /// reach what was already queued rather than only the task that queued it.
    /// The rings are the visible half of that: any still in the future are
    /// dropped, or the sky keeps pulsing through a life that is not playing.
    func testStoppingDropsTheRingsThatHadNotHappenedYet() {
        let model = makeModel()
        model.play()
        XCTAssertEqual(model.pulses.count, model.life.count)

        model.stop()
        let now = Date()
        XCTAssertTrue(model.pulses.allSatisfy { $0.start <= now },
                      "a ring was left queued for a life that has stopped")
        XCTAssertLessThan(model.pulses.count, model.life.count)
    }

    /// Opening one year after another should let the first ring out rather than
    /// being cut off, so silencing is reserved for stopping playback.
    func testTouchingTwoYearsInARowLetsBothRing() {
        let model = makeModel()
        model.show(2)
        model.show(5)
        XCTAssertEqual(model.pulses.count, 2)
    }

    func testTouchingAYearStopsPlayback() {
        let model = makeModel()
        model.play()
        model.touch(at: model.stars[3].point(in: size), in: size)
        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(model.showing, 3)
    }

    func testFadedRingsAreReaped() {
        let model = makeModel()
        model.show(0)
        XCTAssertEqual(model.pulses.count, 1)
        model.advance(to: Date().addingTimeInterval(30))
        XCTAssertTrue(model.pulses.isEmpty)
    }

    func testAKeepsakeWithNoYearsInItDoesNotFallOver() {
        let model = KeepsakeModel(name: "Amanda", life: [],
                                  defaults: UserDefaults(suiteName: "keepsake.model.tests.empty")!)
        XCTAssertTrue(model.stars.isEmpty)
        model.step(by: 1)
        model.play()
        model.touch(at: CGPoint(x: 100, y: 100), in: size)
        XCTAssertNil(model.showing)
        XCTAssertFalse(model.isComplete)
    }
}
