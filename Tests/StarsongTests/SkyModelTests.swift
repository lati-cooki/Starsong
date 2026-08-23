import XCTest
@testable import Starsong

@MainActor
final class SkyModelTests: XCTestCase {
    let size = CGSize(width: 390, height: 844)

    func makeModel() -> SkyModel {
        let model = SkyModel()
        model.newSky(for: size, seed: 42)
        return model
    }

    func testSameSeedMakesTheSameSky() {
        let a = SkyModel(); a.newSky(for: size, seed: 7)
        let b = SkyModel(); b.newSky(for: size, seed: 7)
        XCTAssertEqual(a.stars.count, b.stars.count)
        for (left, right) in zip(a.stars, b.stars) {
            XCTAssertEqual(left.x, right.x)
            XCTAssertEqual(left.y, right.y)
            XCTAssertEqual(left.isBright, right.isBright)
        }
    }

    func testStarsStayInsideTheSky() {
        let model = makeModel()
        XCTAssertFalse(model.stars.isEmpty)
        for star in model.stars {
            XCTAssertTrue((0...1).contains(star.x))
            XCTAssertTrue((0...1).contains(star.y))
        }
    }

    func testStarCountScalesWithAreaAndStaysBounded() {
        XCTAssertGreaterThanOrEqual(SkyModel.starCount(for: .zero), 60)
        XCTAssertLessThanOrEqual(SkyModel.starCount(for: CGSize(width: 5_000, height: 5_000)), 260)
        XCTAssertGreaterThan(SkyModel.starCount(for: CGSize(width: 1_024, height: 1_366)),
                             SkyModel.starCount(for: CGSize(width: 390, height: 844)))
    }

    func testTappingNearAStarConnectsIt() {
        let model = makeModel()
        let target = model.stars[3]
        XCTAssertTrue(model.connect(at: target.point(in: size), in: size))
        XCTAssertEqual(model.path, [3])
        XCTAssertTrue(model.stars[3].isLit)
    }

    func testTappingEmptySkyConnectsNothing() {
        let model = SkyModel()
        model.newSky(for: size, seed: 1)
        // Push every star far away, then aim at the origin.
        let far = CGPoint(x: -500, y: -500)
        XCTAssertFalse(model.connect(at: far, in: size))
        XCTAssertTrue(model.path.isEmpty)
    }

    func testDraggingAcrossTheSameStarDoesNotRepeatIt() {
        let model = makeModel()
        let point = model.stars[5].point(in: size)
        XCTAssertTrue(model.connect(at: point, in: size))
        XCTAssertFalse(model.connect(at: point, in: size))
        XCTAssertEqual(model.path, [5])
    }

    func testUndoDimsAStarOnlyWhenTheLineNoLongerTouchesIt() {
        let model = makeModel()
        model.connect(at: model.stars[0].point(in: size), in: size)
        model.connect(at: model.stars[1].point(in: size), in: size)
        model.connect(at: model.stars[0].point(in: size), in: size)  // back to the start
        XCTAssertEqual(model.path, [0, 1, 0])

        model.undo()
        XCTAssertEqual(model.path, [0, 1])
        XCTAssertTrue(model.stars[0].isLit, "star 0 is still on the line")

        model.undo()
        XCTAssertFalse(model.stars[1].isLit, "star 1 left the line and should dim")
    }

    func testNewSkyClearsTheConstellation() {
        let model = makeModel()
        model.connect(at: model.stars[2].point(in: size), in: size)
        model.newSky(for: size, seed: 99)
        XCTAssertTrue(model.path.isEmpty)
        XCTAssertTrue(model.pulses.isEmpty)
        XCTAssertNil(model.myth)
        XCTAssertFalse(model.stars.contains { $0.isLit })
    }

    /// Positions are fractions of the sky, so rotating the device or resizing
    /// the window moves a constellation without deforming it.
    func testConstellationSurvivesAResize() {
        let model = makeModel()
        model.connect(at: model.stars[0].point(in: size), in: size)
        model.connect(at: model.stars[1].point(in: size), in: size)
        let drawn = model.pathStars

        let landscape = CGSize(width: size.height, height: size.width)
        let before = drawn.map { $0.point(in: size) }
        let after = drawn.map { $0.point(in: landscape) }

        XCTAssertEqual(model.path.count, 2)
        for (i, star) in drawn.enumerated() {
            XCTAssertEqual(after[i].x / landscape.width, before[i].x / size.width, accuracy: 1e-12)
            XCTAssertEqual(after[i].y / landscape.height, before[i].y / size.height, accuracy: 1e-12)
            XCTAssertEqual(Music.pitch(forY: star.y), Music.pitch(forY: star.y), accuracy: 0,
                           "pitch depends only on the fraction, not the pixel size")
        }
    }

    func testPlayNeedsAtLeastTwoStars() {
        let model = makeModel()
        model.connect(at: model.stars[0].point(in: size), in: size)
        XCTAssertFalse(model.canPlay)
        model.connect(at: model.stars[1].point(in: size), in: size)
        XCTAssertTrue(model.canPlay)
    }
}
