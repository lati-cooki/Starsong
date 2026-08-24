import XCTest
@testable import Starsong

/// Naming a constellation yourself. The point of these is the bookkeeping around
/// the name, not the name itself: which changes count as deliberate, what a
/// rename does to the story, and what it does to an entry already in the log.
@MainActor
final class RenameTests: XCTestCase {
    let size = CGSize(width: 390, height: 844)

    /// A model with two stars connected, which is the least that can be named.
    private func drawnSky() -> SkyModel {
        let model = SkyModel()
        model.newSky(for: size, seed: 7)
        model.connect(starAt: 0)
        model.connect(starAt: 1)
        return model
    }

    func testTypingANameSetsItAndMarksItYours() {
        let model = drawnSky()
        XCTAssertNil(model.myth)
        XCTAssertFalse(model.nameIsMine)

        model.rename("The Quiet Ladder")
        XCTAssertEqual(model.myth?.name, "The Quiet Ladder")
        XCTAssertTrue(model.nameIsMine)
    }

    func testSurroundingWhitespaceIsTrimmed() {
        let model = drawnSky()
        model.rename("  The Long Way Home \n")
        XCTAssertEqual(model.myth?.name, "The Long Way Home")
    }

    /// Renaming a myth Claude told should not throw the myth away — the story is
    /// the expensive half to regenerate.
    func testRenamingKeepsTheStory() {
        let model = drawnSky()
        model.rename("First")
        XCTAssertEqual(model.myth?.myth, "", "no story yet, and that is allowed")

        // Stand in for a story having arrived from the API.
        model.restore(SavedSky(seed: 7, fieldStarCount: model.fieldStarCount,
                               lines: [[0, 1]], name: "Told", myth: "A story about it."))
        model.rename("Renamed")
        XCTAssertEqual(model.myth?.name, "Renamed")
        XCTAssertEqual(model.myth?.myth, "A story about it.", "the story should survive")
    }

    /// A name with no story is still worth keeping — `isCoherent` asks for a
    /// name, not a story. Without this, naming by hand with no key would produce
    /// something the log silently refuses.
    func testAHandNamedSkyWithNoStoryCanBeKept() throws {
        let model = drawnSky()
        model.rename("The Two")
        let sky = try XCTUnwrap(model.snapshot())
        XCTAssertEqual(sky.name, "The Two")
        XCTAssertTrue(sky.myth.isEmpty)
        XCTAssertTrue(sky.isCoherent)
    }

    /// Without a name of your own, keeping still falls back rather than failing.
    func testAnUnnamedSkyStillKeepsAsTheUnnamed() throws {
        let model = drawnSky()
        let sky = try XCTUnwrap(model.snapshot())
        XCTAssertEqual(sky.name, Namer.unnamed.name)
    }

    func testClearingTheNameHandsItBack() {
        let model = drawnSky()
        model.rename("Mine")
        XCTAssertTrue(model.nameIsMine)

        model.rename("   ")
        XCTAssertNil(model.myth)
        XCTAssertFalse(model.nameIsMine, "an empty name is not a decision to protect")
    }

    func testRenamingToTheSameNameChangesNothing() {
        let model = drawnSky()
        model.rename("Same")
        let before = model.myth
        model.rename("Same")
        XCTAssertEqual(model.myth, before)
    }

    // MARK: - What counts as deliberate

    /// The flag exists to decide whether "Name it" should ask first, so what
    /// sets and clears it is the actual behaviour under test.
    func testDrawingMoreClearsTheNameAndItsProtection() {
        let model = drawnSky()
        model.rename("Interrupted")
        XCTAssertTrue(model.nameIsMine)

        model.connect(starAt: 2)
        XCTAssertNil(model.myth, "the shape changed, so the name no longer describes it")
        XCTAssertFalse(model.nameIsMine)
    }

    func testUndoClearsItToo() {
        let model = drawnSky()
        model.rename("Undone")
        model.undo()
        XCTAssertNil(model.myth)
        XCTAssertFalse(model.nameIsMine)
    }

    func testANewSkyStartsUnprotected() {
        let model = drawnSky()
        model.rename("Old Sky")
        model.newSky(for: size, seed: 9)
        XCTAssertNil(model.myth)
        XCTAssertFalse(model.nameIsMine)
    }

    /// A restored sky's name was settled by whoever kept it. Authorship isn't
    /// recorded in the file, so asking before replacing is the cheap mistake.
    func testARestoredNameIsProtected() {
        let model = drawnSky()
        model.restore(SavedSky(seed: 7, fieldStarCount: model.fieldStarCount,
                               lines: [[0, 1]], name: "Kept Name", myth: "Its story."))
        XCTAssertEqual(model.myth?.name, "Kept Name")
        XCTAssertTrue(model.nameIsMine)
    }

    /// Orion has been called Orion for millennia; that outranks a suggestion.
    func testAnAtlasFigureKeepsItsRealName() {
        let model = SkyModel()
        model.place(Atlas.orion, for: size, seed: 3)
        XCTAssertEqual(model.myth?.name, Atlas.orion.name)
        XCTAssertTrue(model.nameIsMine)
    }

    // MARK: - The log

    /// Renaming something already kept should update that entry rather than
    /// orphaning it, which is why `rename` leaves `keptID` alone.
    func testRenamingSomethingKeptStillPointsAtTheSameEntry() throws {
        let model = drawnSky()
        model.rename("Before")
        let kept = try XCTUnwrap(model.snapshot())
        model.markKept(kept)
        XCTAssertEqual(model.keptID, kept.id)

        model.rename("After")
        XCTAssertEqual(model.keptID, kept.id, "still the same entry, now under a new name")

        let updated = try XCTUnwrap(model.snapshot(id: kept.id))
        XCTAssertEqual(updated.id, kept.id)
        XCTAssertEqual(updated.name, "After")
    }
}
