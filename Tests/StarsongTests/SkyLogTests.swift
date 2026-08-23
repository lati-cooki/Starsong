import XCTest
@testable import Starsong

@MainActor
final class SkyLogTests: XCTestCase {
    let size = CGSize(width: 390, height: 844)
    var url: URL!

    override func setUp() {
        super.setUp()
        url = URL.temporaryDirectory.appendingPathComponent("skylog-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
        super.tearDown()
    }

    func drawSomething(seed: UInt64 = 11) -> SkyModel {
        let model = SkyModel()
        model.newSky(for: size, seed: seed)
        model.connect(at: model.stars[0].point(in: size), in: size)
        model.connect(at: model.stars[1].point(in: size), in: size)
        model.connect(at: model.stars[2].point(in: size), in: size)
        return model
    }

    // MARK: - Snapshots

    func testASnapshotNeedsALine() {
        let model = SkyModel()
        model.newSky(for: size, seed: 1)
        XCTAssertNil(model.snapshot(), "nothing drawn")
        model.connect(at: model.stars[0].point(in: size), in: size)
        XCTAssertNil(model.snapshot(), "a single star is not a constellation")
        model.connect(at: model.stars[1].point(in: size), in: size)
        XCTAssertNotNil(model.snapshot())
    }

    /// The whole point of the seed: a saved sky is a few dozen bytes, and the
    /// stars come back exactly where they were.
    func testRestoringRebuildsTheSameStars() throws {
        let model = drawSomething()
        let before = model.stars
        let saved = try XCTUnwrap(model.snapshot())

        let reopened = SkyModel()
        reopened.newSky(for: size, seed: 999)      // some other night
        reopened.restore(saved)

        XCTAssertEqual(reopened.stars.count, before.count)
        for (old, new) in zip(before, reopened.stars) {
            XCTAssertEqual(old.x, new.x)
            XCTAssertEqual(old.y, new.y)
        }
        XCTAssertEqual(reopened.path, model.path)
        XCTAssertTrue(reopened.path.allSatisfy { reopened.stars[$0].isLit })
    }

    func testRestoringUsesTheSavedStarCountNotTheCurrentScreen() throws {
        let phone = drawSomething()
        let saved = try XCTUnwrap(phone.snapshot())

        let tablet = SkyModel()
        tablet.newSky(for: CGSize(width: 1_024, height: 1_366))
        XCTAssertNotEqual(tablet.fieldStarCount, saved.fieldStarCount)

        tablet.restore(saved)
        XCTAssertEqual(tablet.stars.count, saved.fieldStarCount)
        XCTAssertEqual(tablet.fieldStarCount, saved.fieldStarCount)
    }

    func testEditingTheLineMeansItIsNoLongerTheKeptOne() throws {
        let model = drawSomething()
        let saved = try XCTUnwrap(model.snapshot())
        model.markKept(saved)
        XCTAssertNotNil(model.keptID)

        model.undo()
        XCTAssertNil(model.keptID)
    }

    // MARK: - The log on disk

    func testKeepingSurvivesARelaunch() throws {
        let model = drawSomething()
        let saved = try XCTUnwrap(model.snapshot())

        let log = SkyLog(url: url)
        log.keep(saved)
        XCTAssertEqual(log.count, 1)

        let reopened = SkyLog(url: url)
        XCTAssertEqual(reopened.entries.first?.id, saved.id)
        XCTAssertEqual(reopened.entries.first?.lines, saved.lines)
        XCTAssertEqual(reopened.entries.first?.seed, saved.seed)
    }

    func testKeepingTheSameConstellationTwiceUpdatesItInPlace() throws {
        let model = drawSomething()
        let first = try XCTUnwrap(model.snapshot())
        let log = SkyLog(url: url)
        log.keep(first)

        // Same id, a story added after naming.
        let named = SavedSky(id: first.id, seed: first.seed, fieldStarCount: first.fieldStarCount,
                             lines: first.lines, name: "The Kite", myth: "A story.")
        log.keep(named)

        XCTAssertEqual(log.count, 1)
        XCTAssertEqual(log.entries.first?.name, "The Kite")
    }

    func testNewestFirstAndRemoval() throws {
        let log = SkyLog(url: url)
        let a = try XCTUnwrap(drawSomething(seed: 1).snapshot())
        let b = try XCTUnwrap(drawSomething(seed: 2).snapshot())
        log.keep(a)
        log.keep(b)
        XCTAssertEqual(log.entries.map(\.id), [b.id, a.id])

        log.remove(b)
        XCTAssertEqual(log.entries.map(\.id), [a.id])
        XCTAssertEqual(SkyLog(url: url).count, 1)
    }

    /// A file on disk is untrusted input — an index past the end of the sky
    /// would crash the renderer, so those entries are dropped on load.
    func testCorruptEntriesAreRejected() throws {
        let bad = SavedSky(seed: 1, fieldStarCount: 5, lines: [[0, 99]], name: "Bad", myth: "x")
        let empty = SavedSky(seed: 1, fieldStarCount: 5, lines: [[1]], name: "Lonely", myth: "x")
        let good = SavedSky(seed: 1, fieldStarCount: 5, lines: [[0, 3]], name: "Good", myth: "x")
        XCTAssertFalse(bad.isCoherent)
        XCTAssertFalse(empty.isCoherent)
        XCTAssertTrue(good.isCoherent)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([bad, empty, good]).write(to: url)

        let log = SkyLog(url: url)
        XCTAssertEqual(log.entries.map(\.name), ["Good"])

        let model = SkyModel()
        model.restore(bad)          // must be a no-op, not a crash
        XCTAssertTrue(model.path.isEmpty)
    }

    func testMissingFileIsAnEmptyLog() {
        let log = SkyLog(url: URL.temporaryDirectory.appendingPathComponent("does-not-exist.json"))
        XCTAssertTrue(log.isEmpty)
    }
}

final class ThumbnailLayoutTests: XCTestCase {
    let box = CGSize(width: 100, height: 100)

    func testLayoutFitsInsideTheBoxAndKeepsShape() {
        let stars = [Star(x: 0.2, y: 0.3, radius: 1, phase: 0, isBright: false),
                     Star(x: 0.8, y: 0.3, radius: 1, phase: 0, isBright: false),
                     Star(x: 0.5, y: 0.9, radius: 1, phase: 0, isBright: false)]
        let points = ConstellationThumbnail.layout(stars, in: box, inset: 8)
        for point in points {
            XCTAssertTrue((0...100).contains(point.x))
            XCTAssertTrue((0...100).contains(point.y))
        }
        // The first two share a y, so they must still share one after layout.
        XCTAssertEqual(points[0].y, points[1].y, accuracy: 1e-9)
    }

    /// A constellation drawn straight down has a zero-width bounding box.
    func testStraightLinesDoNotDivideByZero() {
        let stars = [Star(x: 0.5, y: 0.2, radius: 1, phase: 0, isBright: false),
                     Star(x: 0.5, y: 0.8, radius: 1, phase: 0, isBright: false)]
        let points = ConstellationThumbnail.layout(stars, in: box, inset: 8)
        XCTAssertEqual(points.count, 2)
        for point in points {
            XCTAssertTrue(point.x.isFinite && point.y.isFinite)
            XCTAssertTrue((0...100).contains(point.x))
        }
    }

    func testEmptyInputIsHandled() {
        XCTAssertTrue(ConstellationThumbnail.layout([], in: box, inset: 8).isEmpty)
    }
}
