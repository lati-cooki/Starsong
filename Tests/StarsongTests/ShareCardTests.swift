import UIKit
import XCTest
@testable import Starsong

@MainActor
final class ShareCardTests: XCTestCase {
    func testTheShareCardRendersToAPNG() throws {
        let sky = SavedSky(seed: 20_260_822,
                           fieldStarCount: 70,
                           lines: [[3, 11, 24, 38, 52]],
                           name: "The Lantern Bearer",
                           myth: "She carried a light up the hill every evening so the smaller stars could find their way home. On clear nights you can still see her stopping halfway, waiting for the slow ones.")

        let data = try XCTUnwrap(ShareCardRenderer.png(for: sky), "the card should render")
        XCTAssertGreaterThan(data.count, 10_000, "a blank card would be tiny")

        let image = try XCTUnwrap(UIImage(data: data))
        let width = try XCTUnwrap(image.cgImage?.width)
        XCTAssertGreaterThan(width, 1_000, "rendered at 3x from a 380pt card")

        // Leave the artifact somewhere it can be looked at.
        let out = URL.temporaryDirectory.appendingPathComponent("share-card.png")
        try data.write(to: out)
        print("SHARE_CARD_AT \(out.path)")
    }

    func testAnIncoherentSkyStillRendersRatherThanCrashing() {
        let broken = SavedSky(seed: 1, fieldStarCount: 4, lines: [[0, 99]], name: "Bad", myth: "x")
        XCTAssertFalse(broken.isCoherent)
        XCTAssertTrue(broken.constellation.count < broken.noteCount, "out-of-range indices dropped")
        XCTAssertNotNil(ShareCardRenderer.png(for: broken))
    }
}
