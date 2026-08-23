import XCTest
@testable import Starsong

@MainActor
final class StarNavigationTests: XCTestCase {
    let size = CGSize(width: 390, height: 844)

    func makeModel(seed: UInt64 = 12) -> SkyModel {
        let model = SkyModel()
        model.newSky(for: size, seed: seed)
        return model
    }

    /// Swiping up should walk up the sky and up the scale — the ordering is the
    /// whole reason this is usable rather than merely compliant.
    func testStarsAreOrderedLowNoteToHigh() {
        let model = makeModel()
        XCTAssertEqual(model.navigationOrder.count, model.stars.count)
        XCTAssertEqual(Set(model.navigationOrder), Set(model.stars.indices))

        var previous = 0.0
        for index in model.navigationOrder {
            let pitch = Music.pitch(forY: model.stars[index].y, in: model.tuning)
            XCTAssertGreaterThanOrEqual(pitch, previous)
            previous = pitch
        }
    }

    func testTheCursorStartsAtTheBottomAndStopsAtBothEnds() {
        let model = makeModel()
        XCTAssertNil(model.cursorStar)

        XCTAssertTrue(model.moveCursor(by: 1))
        XCTAssertEqual(model.cursorSlot, 0, "the first swipe up lands on the lowest note")

        XCTAssertFalse(model.moveCursor(by: -1), "already at the bottom; nothing to report")
        XCTAssertEqual(model.cursorSlot, 0)

        for _ in 0..<(model.stars.count * 2) { model.moveCursor(by: 1) }
        XCTAssertEqual(model.cursorSlot, model.stars.count - 1, "stops at the top rather than wrapping")
        XCTAssertFalse(model.moveCursor(by: 1))
    }

    func testMovingDownFromNowhereStartsAtTheTop() {
        let model = makeModel()
        XCTAssertTrue(model.moveCursor(by: -1))
        XCTAssertEqual(model.cursorSlot, model.stars.count - 1)
    }

    func testConnectingTheCursorAddsThatExactStar() {
        let model = makeModel()
        model.moveCursor(by: 1)
        model.moveCursor(by: 1)
        model.moveCursor(by: 1)
        let focused = try? XCTUnwrap(model.cursorStar)

        XCTAssertTrue(model.connectCursor())
        XCTAssertEqual(model.path, [focused])
        XCTAssertTrue(model.stars[focused!].isLit)

        // The same star twice in a row is still refused.
        XCTAssertFalse(model.connectCursor())
        XCTAssertEqual(model.path.count, 1)
    }

    func testConnectingWithNoCursorMovesToTheFirstStarInstead() {
        let model = makeModel()
        XCTAssertNil(model.cursorStar)
        XCTAssertTrue(model.connectCursor(), "a first activation should do something useful")
        XCTAssertNotNil(model.cursorStar)
        XCTAssertTrue(model.path.isEmpty, "it moved rather than guessing which star you meant")
    }

    func testANewSkyForgetsWhereYouWere() {
        let model = makeModel()
        model.moveCursor(by: 1)
        XCTAssertNotNil(model.cursorStar)
        model.newSky(for: size, seed: 3)
        XCTAssertNil(model.cursorStar)
        XCTAssertEqual(model.navigationOrder.count, model.stars.count)
    }

    func testPlacingAFigureRebuildsTheNavigationOrder() {
        let model = SkyModel()
        model.place(Atlas.lyra, for: size, seed: 8)
        XCTAssertEqual(model.navigationOrder.count, model.stars.count)
        XCTAssertEqual(Set(model.navigationOrder), Set(model.stars.indices))
    }

    // MARK: - What it says

    func testTheCursorAnnouncesNotePlaceAndProgress() {
        let model = makeModel()
        XCTAssertTrue(model.cursorDescription.contains("Swipe up"), "an unstarted sky should say how to start")

        model.moveCursor(by: 1)
        let spoken = model.cursorDescription
        XCTAssertTrue(spoken.contains("star 1 of \(model.stars.count)"), spoken)
        XCTAssertFalse(spoken.contains("already on the line"))

        model.connectCursor()
        XCTAssertTrue(model.cursorDescription.contains("already on the line"),
                      "you should not have to remember which stars you have used")
    }

    func testAnEmptySkySaysSo() {
        XCTAssertEqual(SkyModel().cursorDescription, "An empty sky")
    }

    func testPlaceNamesCoverTheWholeSky() {
        func place(_ x: CGFloat, _ y: CGFloat) -> String {
            SkyModel.place(of: Star(x: x, y: y, radius: 1, phase: 0, isBright: false))
        }
        XCTAssertEqual(place(0.1, 0.1), "upper left")
        XCTAssertEqual(place(0.9, 0.9), "lower right")
        XCTAssertEqual(place(0.5, 0.5), "centre")
        XCTAssertEqual(place(0.5, 0.1), "upper centre")
        XCTAssertEqual(place(0.1, 0.5), "middle left")
    }
}

final class NoteNameTests: XCTestCase {
    func testTheRootIsAThree() {
        // 220 Hz is A3, the bottom of the sky.
        XCTAssertEqual(Music.noteName(forY: 1.0), "A 3")
    }

    func testNamesMatchThePitchesTheyDescribe() {
        for tuning in Music.tunings {
            for step in stride(from: 0.0, through: 1.0, by: 0.05) {
                let y = CGFloat(step)
                let name = Music.noteName(forY: y, in: tuning)
                let pitch = Music.pitch(forY: y, in: tuning)
                // Recover the MIDI number from the frequency and check it agrees.
                let midi = Int((69 + 12 * log2(pitch / 440)).rounded())
                let expected = ["C", "C sharp", "D", "D sharp", "E", "F",
                                "F sharp", "G", "G sharp", "A", "A sharp", "B"][midi % 12]
                XCTAssertEqual(name, "\(expected) \(midi / 12 - 1)", "at y=\(y) in \(tuning.name)")
            }
        }
    }
}

import SwiftUI
import UIKit

@MainActor
final class CursorRenderingTests: XCTestCase {
    /// The cursor is drawn, not just modelled — someone with low vision, or
    /// using Switch Control, needs to see where the navigation is sitting.
    func testTheCursorIsVisiblyDrawn() throws {
        let model = SkyModel()
        model.newSky(for: CGSize(width: 390, height: 844), seed: 21)
        model.moveCursor(by: 1)
        model.moveCursor(by: 1)
        let focused = try XCTUnwrap(model.cursorStar)

        func render(cursor: Star?) throws -> Data {
            let canvas = SkyCanvas(stars: model.stars,
                                   constellations: [],
                                   pulses: [],
                                   shooters: [],
                                   birth: Date(),
                                   cursor: cursor,
                                   isStill: true)
                .frame(width: 390, height: 844)
            let renderer = ImageRenderer(content: canvas)
            renderer.scale = 2
            renderer.isOpaque = true
            return try XCTUnwrap(renderer.uiImage?.pngData())
        }

        let without = try render(cursor: nil)
        let with = try render(cursor: model.stars[focused])
        XCTAssertNotEqual(without, with, "the cursor left no mark on the sky")

        try with.write(to: URL.temporaryDirectory.appendingPathComponent("cursor.png"))
        print("CURSOR_SHOT_AT \(URL.temporaryDirectory.appendingPathComponent("cursor.png").path)")
    }

    /// Reduce Motion should hold the sky still rather than merely slowing it.
    func testReduceMotionFreezesTheTwinkle() throws {
        let model = SkyModel()
        model.newSky(for: CGSize(width: 390, height: 844), seed: 9)

        func render(still: Bool, birth: Date) throws -> Data {
            let canvas = SkyCanvas(stars: model.stars, constellations: [], pulses: [],
                                   shooters: [], birth: birth, cursor: nil, isStill: still)
                .frame(width: 200, height: 400)
            let renderer = ImageRenderer(content: canvas)
            renderer.isOpaque = true
            return try XCTUnwrap(renderer.uiImage?.pngData())
        }

        // Two different points in the twinkle cycle.
        let early = Date()
        let late = early.addingTimeInterval(-0.8)
        XCTAssertEqual(try render(still: true, birth: early), try render(still: true, birth: late),
                       "the sky moved with Reduce Motion on")
        XCTAssertNotEqual(try render(still: false, birth: early), try render(still: false, birth: late),
                          "the sky should twinkle when Reduce Motion is off")
    }

    @MainActor
    func testReduceMotionStopsShootingStars() {
        let model = SkyModel()
        for _ in 0..<40 { model.advance(to: Date(), spawnChance: 0) }
        XCTAssertTrue(model.shooters.isEmpty)
    }
}
