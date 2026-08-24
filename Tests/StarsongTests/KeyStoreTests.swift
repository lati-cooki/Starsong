import XCTest
@testable import Starsong

/// The Keychain is real in these tests, not mocked, because the failure this
/// code is most likely to have is a malformed query that the Security framework
/// rejects — and a mock would happily accept one.
final class KeyStoreTests: XCTestCase {
    /// Whatever was installed before the test ran, put back afterwards. Running
    /// the suite should not log you out of your own app.
    private var saved: String?

    override func setUp() {
        super.setUp()
        saved = KeyStore.load()
        try? KeyStore.remove()
    }

    override func tearDown() {
        try? KeyStore.remove()
        if let saved { try? KeyStore.save(saved) }
        super.tearDown()
    }

    func testAKeySurvivesARoundTrip() throws {
        XCTAssertNil(KeyStore.load(), "setUp should have cleared it")
        XCTAssertFalse(KeyStore.hasKey)

        try KeyStore.save("sk-ant-test-abcdef123456")
        XCTAssertTrue(KeyStore.hasKey)
        XCTAssertEqual(KeyStore.load(), "sk-ant-test-abcdef123456")
    }

    /// Pasting a key picks up a newline more often than not, and a stray one in
    /// an HTTP header value comes back as an unexplained 401.
    func testSurroundingWhitespaceIsTrimmed() throws {
        try KeyStore.save("  sk-ant-test-padded\n")
        XCTAssertEqual(KeyStore.load(), "sk-ant-test-padded")
    }

    func testSavingTwiceReplacesRatherThanDuplicating() throws {
        try KeyStore.save("sk-ant-first-000000000")
        try KeyStore.save("sk-ant-second-11111111")
        XCTAssertEqual(KeyStore.load(), "sk-ant-second-11111111")
    }

    func testAnEmptyKeyIsRefused() {
        XCTAssertThrowsError(try KeyStore.save("   \n ")) { error in
            XCTAssertEqual(error as? KeyStore.Failure, .empty)
        }
        XCTAssertNil(KeyStore.load())
    }

    /// "Make sure there is no key" is the useful contract, so removing nothing
    /// is a success rather than an error to handle at every call site.
    func testRemovingWhenThereIsNothingSucceeds() {
        XCTAssertNoThrow(try KeyStore.remove())
        XCTAssertNoThrow(try KeyStore.remove())
    }

    func testFingerprintShowsEnoughToRecogniseAndNotEnoughToUse() {
        let key = "sk-ant-api03-SECRETMIDDLEPART-9xyz"
        let shown = KeyStore.fingerprint(key)
        XCTAssertTrue(shown.hasPrefix("sk-ant-a"), shown)
        XCTAssertTrue(shown.hasSuffix("9xyz"), shown)
        XCTAssertFalse(shown.contains("SECRETMIDDLEPART"), "the middle must not leak")
        XCTAssertLessThan(shown.count, key.count)

        // Nothing useful to show, so show nothing rather than most of a short key.
        XCTAssertEqual(KeyStore.fingerprint("short"), "••••")
    }
}

/// Which key wins, and how a failure reads. The network is not touched.
final class KeyResolutionTests: XCTestCase {
    private var saved: String?

    override func setUp() {
        super.setUp()
        saved = KeyStore.load()
        try? KeyStore.remove()
    }

    override func tearDown() {
        try? KeyStore.remove()
        if let saved { try? KeyStore.save(saved) }
        super.tearDown()
    }

    /// A key the person brought wins over one baked in at build time: they chose
    /// it more recently and it is the one they can change.
    func testASavedKeyBeatsTheOneBuiltIn() throws {
        try KeyStore.save("sk-ant-keychain-wins-01")
        XCTAssertEqual(Namer.apiKey, "sk-ant-keychain-wins-01")
        XCTAssertEqual(Namer.source, .keychain)
        XCTAssertTrue(Namer.isConfigured)
    }

    /// With nothing saved, whichever way this checkout is configured has to be
    /// self-consistent — a source of `.none` and a usable key cannot coexist.
    func testWithNothingSavedTheBundleDecides() {
        XCTAssertFalse(KeyStore.hasKey)
        switch Namer.source {
        case .keychain:
            XCTFail("nothing is saved, so the source cannot be the Keychain")
        case .bundle:
            XCTAssertNotNil(Namer.apiKey)
            XCTAssertTrue(Namer.isConfigured)
        case .none:
            XCTAssertNil(Namer.apiKey)
            XCTAssertFalse(Namer.isConfigured)
        }
    }

    func testRemovingASavedKeyFallsBackRatherThanBreaking() throws {
        try KeyStore.save("sk-ant-temporary-0000001")
        XCTAssertEqual(Namer.source, .keychain)

        try KeyStore.remove()
        XCTAssertNotEqual(Namer.source, .keychain)
        XCTAssertEqual(Namer.isConfigured, Namer.apiKey != nil)
    }

    /// Every failure used to arrive as the same wordless fallback, which is what
    /// made a missing key and a rejected key indistinguishable.
    func testFailuresReadDifferentlyFromOneAnother() {
        let missing = Namer.describe(Namer.Failure.missingKey)
        let rejected = Namer.describe(Namer.Failure.http(status: 401))
        let limited = Namer.describe(Namer.Failure.http(status: 429))
        let broken = Namer.describe(Namer.Failure.http(status: 503))
        let unreadable = Namer.describe(Namer.Failure.malformedResponse)
        let refused = Namer.describe(Namer.Failure.refused("The sky declined."))

        let all = [missing, rejected, limited, broken, unreadable, refused]
        XCTAssertEqual(Set(all).count, all.count, "these must not read alike: \(all)")
        XCTAssertTrue(all.allSatisfy { !$0.isEmpty })

        // The two a person can actually act on should say where to go.
        XCTAssertTrue(missing.contains("Profile"), missing)
        XCTAssertTrue(rejected.contains("Profile"), rejected)
        // A refusal is already a sentence; don't bury it.
        XCTAssertEqual(refused, "The sky declined.")
    }
}
