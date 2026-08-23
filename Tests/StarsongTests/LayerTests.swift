import XCTest
@testable import Starsong

@MainActor
final class LayerTests: XCTestCase {
    let size = CGSize(width: 390, height: 844)

    func drawing(_ count: Int = 3, seed: UInt64 = 31) -> SkyModel {
        let model = SkyModel()
        model.newSky(for: size, seed: seed)
        for i in 0..<count { model.connect(starAt: i) }
        return model
    }

    override func tearDown() {
        super.tearDown()
    }

    func testASkyStartsWithOneEmptyLine() {
        let model = SkyModel()
        model.newSky(for: size, seed: 1)
        XCTAssertEqual(model.lines.count, 1)
        XCTAssertEqual(model.activeLine, 0)
        XCTAssertTrue(model.path.isEmpty)
        XCTAssertFalse(model.hasSomethingToPlay)
    }

    func testDrawingGoesOntoTheActiveLine() {
        let model = drawing()
        XCTAssertEqual(model.lines, [[0, 1, 2]])
        XCTAssertEqual(model.path, [0, 1, 2])
        XCTAssertTrue(model.hasSomethingToPlay)
    }

    func testNewLinesAreCappedAndOnlyOpenOnceThereIsSomethingToLayerOver() {
        let model = drawing()
        XCTAssertTrue(model.startNewLine())
        XCTAssertEqual(model.activeLine, 1)
        XCTAssertTrue(model.path.isEmpty, "a fresh line starts empty")

        model.connect(starAt: 5)
        model.connect(starAt: 6)
        XCTAssertTrue(model.startNewLine())
        XCTAssertEqual(model.lines.count, SkyModel.maxLines)

        XCTAssertFalse(model.startNewLine(), "three lines is the ceiling")
        XCTAssertEqual(model.lines.count, SkyModel.maxLines)
    }

    /// The heart of layering: drawing while something is looping starts a new
    /// line, but only once — after that you are drawing on the new one.
    func testDrawingOverALoopOpensExactlyOneNewLine() {
        let model = drawing()
        model.play()
        XCTAssertTrue(model.isPlaying)

        model.connect(starAt: 10)
        XCTAssertEqual(model.lines.count, 2, "the first star of a take opens a line")
        XCTAssertEqual(model.activeLine, 1)
        XCTAssertEqual(model.lines[0], [0, 1, 2], "the looping line is untouched")

        model.connect(starAt: 11)
        model.connect(starAt: 12)
        XCTAssertEqual(model.lines.count, 2, "the rest of the take extends it")
        XCTAssertEqual(model.lines[1], [10, 11, 12])

        model.stop()
    }

    func testStoppingAndPlayingAgainAllowsAnotherLayer() {
        let model = drawing()
        model.play()
        model.connect(starAt: 10)
        model.connect(starAt: 11)
        model.stop()

        model.play()
        model.connect(starAt: 20)
        XCTAssertEqual(model.lines.count, 3, "a new take opens a new line")
        model.stop()
    }

    func testDrawingWhileStoppedNeverOpensALine() {
        let model = drawing()
        for i in 10..<15 { model.connect(starAt: i) }
        XCTAssertEqual(model.lines.count, 1)
    }

    // MARK: - Undo across layers

    func testUndoEmptiesTheActiveLineThenRemovesIt() {
        let model = drawing()
        model.startNewLine()
        model.connect(starAt: 8)
        XCTAssertEqual(model.lines.count, 2)

        model.undo()                       // removes star 8, line 1 now empty
        XCTAssertEqual(model.lines.count, 2)
        XCTAssertTrue(model.lines[1].isEmpty)

        model.undo()                       // the empty line goes
        XCTAssertEqual(model.lines.count, 1)
        XCTAssertEqual(model.activeLine, 0)
        XCTAssertEqual(model.path, [0, 1, 2], "the line below is untouched")
    }

    func testAStarStaysLitWhileAnyLineUsesIt() {
        let model = drawing()
        model.startNewLine()
        model.connect(starAt: 1)           // also on line 0
        model.connect(starAt: 9)
        model.undo()                       // drops 9
        model.undo()                       // drops the shared star from line 1
        XCTAssertTrue(model.stars[1].isLit, "line 0 still runs through it")
    }

    func testUndoOnAnUntouchedSkyDoesNothing() {
        let model = SkyModel()
        model.newSky(for: size, seed: 2)
        model.undo()
        XCTAssertEqual(model.lines, [[]])
        XCTAssertEqual(model.activeLine, 0)
    }

    // MARK: - Playing

    func testPlayAndStop() {
        let model = drawing()
        XCTAssertTrue(model.canPlay)
        model.play()
        XCTAssertTrue(model.isPlaying)
        model.play()                        // a second press does not stack loops
        XCTAssertTrue(model.isPlaying)
        model.stop()
        XCTAssertFalse(model.isPlaying)
    }

    func testAnEmptySkyWillNotPlay() {
        let model = SkyModel()
        model.newSky(for: size, seed: 4)
        model.play()
        XCTAssertFalse(model.isPlaying)
    }

    func testNewSkyAndRestoreStopThePlaying() {
        let model = drawing()
        model.play()
        model.newSky(for: size, seed: 6)
        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(model.lines, [[]])
    }

    /// Lines of different lengths must not share a cycle, or layering would
    /// just be unison.
    func testDifferentLinesHaveDifferentCycles() {
        let short = [Star(x: 0.5, y: 0.5, radius: 1, phase: 0, isBright: false),
                     Star(x: 0.52, y: 0.5, radius: 1, phase: 0, isBright: false)]
        let long = (0..<6).map { Star(x: CGFloat($0) / 6, y: 0.2, radius: 1, phase: 0, isBright: false) }
        XCTAssertLessThan(Music.cycleLength(for: short), Music.cycleLength(for: long))
        XCTAssertGreaterThan(Music.cycleLength(for: short), Music.loopRest)
        XCTAssertEqual(Music.cycleLength(for: []), Music.loopRest)
    }

    // MARK: - Keeping layered skies

    func testKeepingAndRestoringEveryLine() throws {
        let model = drawing()
        model.startNewLine()
        model.connect(starAt: 20)
        model.connect(starAt: 21)
        let saved = try XCTUnwrap(model.snapshot())
        XCTAssertEqual(saved.lines.count, 2)
        XCTAssertEqual(saved.noteCount, 5)

        let reopened = SkyModel()
        reopened.newSky(for: size, seed: 999)
        reopened.restore(saved)
        XCTAssertEqual(reopened.lines, model.lines)
        XCTAssertTrue(reopened.lines.joined().allSatisfy { reopened.stars[$0].isLit })
    }

    func testHalfDrawnLinesAreNotKept() throws {
        let model = drawing()
        model.startNewLine()
        model.connect(starAt: 30)          // one star: not a constellation
        let saved = try XCTUnwrap(model.snapshot())
        XCTAssertEqual(saved.lines, [[0, 1, 2]], "the unfinished line is left out")
    }

    /// A sky kept before layering existed wrote a single `path`. It still has to
    /// open.
    func testSkiesKeptBeforeLayeringStillLoad() throws {
        let old = """
        {"id":"7E1B1C64-3F14-4E2E-9E4A-0B5E5B0E9A11","seed":15855122925088383480,
         "starCount":70,"path":[30,16,7,20],"name":"The Unnamed","myth":"A story.",
         "keptAt":"2026-08-22T19:42:54Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sky = try decoder.decode(SavedSky.self, from: Data(old.utf8))

        XCTAssertEqual(sky.lines, [[30, 16, 7, 20]], "the old single path became one line")
        XCTAssertTrue(sky.isCoherent)
        XCTAssertEqual(sky.fieldStarCount, 70)

        // And it re-encodes in the new shape without losing anything.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let again = try decoder.decode(SavedSky.self, from: try encoder.encode(sky))
        XCTAssertEqual(again.lines, sky.lines)
        XCTAssertEqual(again.id, sky.id)
    }
}
