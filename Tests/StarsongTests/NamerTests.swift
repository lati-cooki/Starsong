import XCTest
@testable import Starsong

final class NamerTests: XCTestCase {
    let stars = [
        Star(x: 0.1, y: 0.2, radius: 1, phase: 0, isBright: true),
        Star(x: 0.5, y: 0.7, radius: 1, phase: 0, isBright: false)
    ]

    func testPromptDescribesTheShapeAndTheMelody() {
        let prompt = Namer.prompt(for: [stars])
        XCTAssertTrue(prompt.contains("(10,20)"))
        XCTAssertTrue(prompt.contains("(50,70)"))
        XCTAssertTrue(prompt.contains("2 stars"))
        XCTAssertFalse(prompt.contains("Line 1"), "a single line needs no numbering")
        XCTAssertTrue(prompt.contains(String(Int(Music.pitch(forY: 0.2).rounded()))))
    }

    func testParsesStructuredOutput() throws {
        let payload = """
        {"stop_reason":"end_turn","content":[
          {"type":"thinking","thinking":""},
          {"type":"text","text":"{\\"name\\":\\"The Kite\\",\\"myth\\":\\"A story. Another.\\"}"}
        ]}
        """
        let myth = try Namer.parse(Data(payload.utf8))
        XCTAssertEqual(myth.name, "The Kite")
        XCTAssertEqual(myth.myth, "A story. Another.")
    }

    func testRefusalIsSurfacedRatherThanParsedAsAName() {
        let payload = #"{"stop_reason":"refusal","stop_details":{"type":"refusal","explanation":"no"},"content":[]}"#
        XCTAssertThrowsError(try Namer.parse(Data(payload.utf8))) { error in
            guard case Namer.Failure.refused = error else {
                return XCTFail("expected a refusal, got \(error)")
            }
        }
    }

    func testMalformedPayloadsThrow() {
        let noText = #"{"stop_reason":"end_turn","content":[{"type":"thinking","thinking":"hm"}]}"#
        XCTAssertThrowsError(try Namer.parse(Data(noText.utf8)))

        let notJSON = #"{"stop_reason":"end_turn","content":[{"type":"text","text":"The Kite"}]}"#
        XCTAssertThrowsError(try Namer.parse(Data(notJSON.utf8)))
    }

    func testAPromptForLayeredLinesDescribesEachAndSaysTheyOverlap() {
        let second = [Star(x: 0.2, y: 0.3, radius: 1, phase: 0, isBright: false),
                      Star(x: 0.8, y: 0.4, radius: 1, phase: 0, isBright: false)]
        let prompt = Namer.prompt(for: [stars, second])
        XCTAssertTrue(prompt.contains("Line 1"))
        XCTAssertTrue(prompt.contains("Line 2"))
        XCTAssertTrue(prompt.contains("at the same time"))
    }

    func testHalfDrawnLinesAreLeftOutOfThePrompt() {
        let lonely = [Star(x: 0.4, y: 0.4, radius: 1, phase: 0, isBright: false)]
        let prompt = Namer.prompt(for: [stars, lonely])
        XCTAssertFalse(prompt.contains("Line 2"), "a single star is not a line")
    }

    func testUnnamedFallbackIsUsable() {
        XCTAssertFalse(Namer.unnamed.name.isEmpty)
        XCTAssertFalse(Namer.unnamed.myth.isEmpty)
    }

    /// Skipped once you add a key — this covers the no-key path only, and must
    /// never reach the network from a test run.
    func testWithoutAKeyNamingFallsBackInsteadOfFailing() async throws {
        try XCTSkipIf(Namer.isConfigured, "a key is configured; skipping the offline path")
        let myth = await Namer.myth(for: [stars])
        XCTAssertEqual(myth, Namer.unnamed)
    }
}
