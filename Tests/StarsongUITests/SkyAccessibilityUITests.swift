import XCTest

/// Model tests prove the navigation logic works. These prove the accessibility
/// tree actually carries it — that the canvas really is one labelled element
/// with a spoken value, and not a silent rectangle with good intentions.
final class SkyAccessibilityUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    func testTheSkyIsOneLabelledElementThatSaysWhereYouAre() {
        let app = launch()
        let sky = app.descendants(matching: .any)["Night sky"]
        XCTAssertTrue(sky.waitForExistence(timeout: 20), "the sky is not in the accessibility tree")

        let spoken = try? XCTUnwrap(sky.value as? String)
        XCTAssertTrue(spoken?.contains("Swipe up") ?? false,
                      "an untouched sky should say how to start; got \(spoken ?? "nothing")")
    }

    func testEveryControlIsReachableAndNamed() {
        let app = launch()
        for name in ["Undo", "New sky", "Play", "Name it", "Real constellations"] {
            XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 10),
                          "\(name) is missing from the accessibility tree")
        }
    }

    /// The atlas is the one part of the app that is fully usable without sight
    /// today: a named list, each row with a button that plays it.
    func testTheAtlasIsNavigableAndEveryRowCanBeHeard() {
        let app = launch()
        app.buttons["Real constellations"].tap()

        XCTAssertTrue(app.navigationBars["Real constellations"].waitForExistence(timeout: 10))
        for name in ["Orion", "Cassiopeia", "Cygnus"] {
            XCTAssertTrue(app.descendants(matching: .any)[name].firstMatch.exists,
                          "\(name) is not reachable")
        }
        XCTAssertGreaterThan(app.buttons["Hear it"].firstMatch.exists ? 1 : 0, 0,
                             "a row cannot be played")

        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["New sky"].waitForExistence(timeout: 10))
    }

    /// Placing a figure should leave the sky drawn and playable.
    func testPlacingAConstellationFromTheAtlasDrawsIt() {
        let app = launch()
        app.buttons["Real constellations"].tap()
        app.descendants(matching: .any)["Orion"].firstMatch.tap()

        // The name is an editable field now, not a heading, so it is reachable
        // as a text field whose *value* is the name — the label belongs to the
        // control ("Constellation name") rather than to this constellation.
        let name = app.textFields["Constellation name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10),
                      "the placed figure should offer its name for editing")
        XCTAssertEqual(name.value as? String, "Orion",
                       "the placed figure should name itself")
        XCTAssertTrue(app.buttons["Play"].isEnabled, "a placed figure should be playable")
    }
}

extension SkyAccessibilityUITests {
    /// What XCUITest can and cannot reach, written down so the next person does
    /// not repeat the experiment: it reads the accessibility *tree* (labels,
    /// values, hints) but cannot invoke accessibility *actions*. `tap()` sends a
    /// real touch, and only VoiceOver turns a double tap into an activation;
    /// `adjust` drives real sliders only, and the sky reports as a Button
    /// because the activate action wins the element-type mapping.
    ///
    /// So the adjustable gesture and the named actions are NOT verified here.
    /// `StarNavigationTests` covers every bit of logic behind them; this covers
    /// that the sky is present, labelled, and says how to begin.
    func testTheSkySaysHowToPlayItWithoutSight() {
        let app = launch()
        let sky = app.descendants(matching: .any)["Night sky"]
        XCTAssertTrue(sky.waitForExistence(timeout: 20))

        let resting = sky.value as? String
        XCTAssertTrue(resting?.contains("Swipe up") ?? false,
                      "the resting value should say how to begin; got \(resting ?? "nothing")")
        XCTAssertTrue(resting?.contains("stars") ?? false,
                      "it should say how much sky there is; got \(resting ?? "nothing")")
    }

    /// The sighted path, end to end through the real UI: sweeping across the
    /// sky draws a constellation and wakes the controls up.
    func testSweepingAcrossTheSkyDrawsAConstellation() {
        let app = launch()
        let sky = app.descendants(matching: .any)["Night sky"]
        XCTAssertTrue(sky.waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["Play"].isEnabled, "nothing is drawn yet")

        // A few sweeps at different heights, so this does not depend on where
        // one particular random sky happened to put its stars.
        for height in [0.35, 0.5, 0.65] {
            sky.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: height))
                .press(forDuration: 0.05,
                       thenDragTo: sky.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: height + 0.05)))
            if app.buttons["Play"].isEnabled { break }
        }

        XCTAssertTrue(app.buttons["Play"].isEnabled, "sweeping the sky drew nothing")
        XCTAssertTrue(app.buttons["Keep this one"].exists, "a drawn constellation should be keepable")
    }
}

extension SkyAccessibilityUITests {
    /// Three sheets hang off one view. Stacking `.sheet` modifiers is a known
    /// way to have one of them silently never present, so each is opened here
    /// by name rather than trusted.
    func testEverySheetActuallyOpens() {
        let app = launch()
        let cases = [("Voices", "Voices"), ("Real constellations", "Real constellations")]
        for (button, title) in cases {
            XCTAssertTrue(app.buttons[button].waitForExistence(timeout: 15), "\(button) is missing")
            app.buttons[button].tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10),
                          "tapping \(button) did not present its sheet")
            app.buttons["Done"].tap()
            XCTAssertTrue(app.buttons["New sky"].waitForExistence(timeout: 10),
                          "\(title) did not dismiss")
        }
    }

    func testChoosingAVoiceChangesWhatTheSkySays() {
        let app = launch()
        app.buttons["Voices"].tap()
        XCTAssertTrue(app.navigationBars["Voices"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Pluck"].waitForExistence(timeout: 10), "no row for Pluck")
        app.buttons["Pluck"].tap()

        // The caption under the wordmark carries the current voice, and says so
        // out loud as well as showing it.
        let caption = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Pluck, tuned to'"))
            .firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 10),
                      "the caption did not follow the chosen voice")
    }
}

extension SkyAccessibilityUITests {
    /// Drives the voice picker end to end and leaves screenshots behind, since
    /// synthesised instruments are the kind of thing you want to look at and
    /// listen to rather than take on trust from an assertion.
    func testVoicePickerVisualCheck() throws {
        let app = launch()

        app.buttons["Voices"].tap()
        XCTAssertTrue(app.navigationBars["Voices"].waitForExistence(timeout: 15))
        for voice in ["Chime", "Pluck", "Piano", "Brass", "Bell"] {
            XCTAssertTrue(app.buttons[voice].exists, "\(voice) is missing from the picker")
        }
        try save(XCUIScreen.main.screenshot(), as: "voices-sheet")

        app.buttons["Pluck"].tap()

        // Draw something in the new voice.
        let sky = app.descendants(matching: .any)["Night sky"]
        XCTAssertTrue(sky.waitForExistence(timeout: 10))
        for height in [0.4, 0.55] {
            sky.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: height))
                .press(forDuration: 0.05,
                       thenDragTo: sky.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: height + 0.06)))
            if app.buttons["Play"].isEnabled { break }
        }
        XCTAssertTrue(app.buttons["Play"].isEnabled, "nothing was drawn")
        try save(XCUIScreen.main.screenshot(), as: "pluck-line")
    }

    private func save(_ shot: XCUIScreenshot, as name: String) throws {
        try shot.pngRepresentation.write(
            to: URL.temporaryDirectory.appendingPathComponent("\(name).png"))
        print("SHOT \(name) \(URL.temporaryDirectory.appendingPathComponent("\(name).png").path)")
    }
}

extension SkyAccessibilityUITests {
    /// The keepsake is a full-screen cover rather than a sheet — a different
    /// presentation path from the three this file already distrusts, and worth
    /// opening for real rather than assuming.
    ///
    /// Matched on the shape of the label rather than on "Amanda", because the
    /// name is content: `Keepsake.swift` is meant to be edited, and a test that
    /// breaks when it is would be a test punishing the one thing the file is for.
    func testHerKeepsakeOpensAndCloses() {
        let app = launch()
        let way = app.buttons
            .matching(NSPredicate(format: "label ENDSWITH %@", "'s fifty")).firstMatch
        XCTAssertTrue(way.waitForExistence(timeout: 15), "the keepsake has no way in")
        way.tap()

        let sky = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", "'s sky")).firstMatch
        XCTAssertTrue(sky.waitForExistence(timeout: 10), "the keepsake never presented")

        let spoken = sky.value as? String
        XCTAssertTrue(spoken?.contains("years") ?? false,
                      "her sky should say how many years it holds; got \(spoken ?? "nothing")")

        for name in ["Her name", "Play her life", "Close"] {
            XCTAssertTrue(app.buttons[name].exists, "\(name) is missing from the keepsake")
        }

        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["New sky"].waitForExistence(timeout: 10),
                      "the keepsake did not close")
    }
}
