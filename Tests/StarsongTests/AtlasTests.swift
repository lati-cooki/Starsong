import UIKit
import XCTest
@testable import Starsong

@MainActor
final class AtlasTests: XCTestCase {
    func testEveryFigureIsWellFormed() {
        XCTAssertFalse(Atlas.figures.isEmpty)
        var ids = Set<String>()
        for figure in Atlas.figures {
            XCTAssertTrue(figure.isCoherent, "\(figure.name) has a broken walk")
            XCTAssertTrue(ids.insert(figure.id).inserted, "duplicate id \(figure.id)")
            XCTAssertFalse(figure.note.isEmpty)
            XCTAssertEqual(Atlas.figure(id: figure.id)?.id, figure.id)

            for star in figure.stars {
                XCTAssertTrue((0...360).contains(star.rightAscension), "\(star.name) RA")
                XCTAssertTrue((-90...90).contains(star.declination), "\(star.name) dec")
                XCTAssertTrue((-2.0...7.0).contains(star.magnitude), "\(star.name) magnitude")
            }
            // Every star should be reachable, or it is drawn but never sung.
            XCTAssertEqual(Set(figure.walk), Set(figure.stars.indices),
                           "\(figure.name) leaves a star off the line")
        }
        XCTAssertNil(Atlas.figure(id: "not-a-constellation"))
    }

    func testPlacedStarsLandInsideTheSky() {
        for figure in Atlas.figures {
            let placed = figure.placedStars()
            XCTAssertEqual(placed.count, figure.stars.count)
            for star in placed {
                XCTAssertTrue((0...1).contains(star.x), "\(figure.name) x=\(star.x)")
                XCTAssertTrue((0...1).contains(star.y), "\(figure.name) y=\(star.y)")
                XCTAssertTrue(star.isLit)
            }
        }
    }

    /// The projection has to preserve the shape, not just the bounding box.
    /// Orion's belt is three stars in a near-straight line; if the maths were
    /// wrong they would not stay collinear.
    func testOrionsBeltStaysStraight() {
        let placed = Atlas.orion.placedStars()
        let belt = [placed[2], placed[3], placed[4]]   // Mintaka, Alnilam, Alnitak
        let a = CGPoint(x: belt[0].x, y: belt[0].y)
        let b = CGPoint(x: belt[2].x, y: belt[2].y)
        let m = CGPoint(x: belt[1].x, y: belt[1].y)
        // Distance of the middle star from the line through the outer two.
        let len = hypot(b.x - a.x, b.y - a.y)
        let offset = abs((b.x - a.x) * (a.y - m.y) - (a.x - m.x) * (b.y - a.y)) / len
        XCTAssertLessThan(offset, 0.012, "the belt bent")
        XCTAssertGreaterThan(len, 0.05, "the belt collapsed")
    }

    /// Bright stars should be drawn bigger than faint ones.
    func testMagnitudeSetsSize() {
        let placed = Atlas.lyra.placedStars()
        let vega = placed[0]                       // magnitude 0.03
        let zeta = placed[1]                       // magnitude 4.34
        XCTAssertGreaterThan(vega.radius, zeta.radius)
    }

    func testPlacingAFigureDrawsItReadyToPlay() {
        let model = SkyModel()
        model.place(Atlas.cassiopeia, for: CGSize(width: 390, height: 844), seed: 5)
        XCTAssertEqual(model.path.count, Atlas.cassiopeia.walk.count)
        XCTAssertEqual(model.figureID, "cassiopeia")
        XCTAssertEqual(model.myth?.name, "Cassiopeia")
        XCTAssertTrue(model.canPlay)
        XCTAssertTrue(model.path.allSatisfy { model.stars[$0].isLit })
        XCTAssertGreaterThan(model.stars.count, model.fieldStarCount)
    }

    func testAPlacedFigureCanBeKeptAndComesBack() throws {
        let size = CGSize(width: 390, height: 844)
        let model = SkyModel()
        model.place(Atlas.cygnus, for: size, seed: 77)
        let saved = try XCTUnwrap(model.snapshot())
        XCTAssertEqual(saved.figureID, "cygnus")

        let reopened = SkyModel()
        reopened.newSky(for: size, seed: 1)
        reopened.restore(saved)
        XCTAssertEqual(reopened.path, model.path)
        XCTAssertEqual(reopened.stars.count, model.stars.count)
        for (old, new) in zip(model.stars, reopened.stars) {
            XCTAssertEqual(old.x, new.x)
            XCTAssertEqual(old.y, new.y)
        }
    }

    func testAnEntryNamingAnUnknownFigureIsRejected() {
        let orphan = SavedSky(seed: 1, fieldStarCount: 40, figureID: "andromeda",
                              lines: [[0, 1]], name: "Gone", myth: "x")
        XCTAssertFalse(orphan.isCoherent, "the figure is not in the atlas any more")
    }

    /// Renders every figure to one sheet so the shapes can be checked by eye —
    /// a wrong coordinate is obvious in a picture and invisible in a number.
    func testRenderAContactSheet() throws {
        let sheet = VStack(spacing: 0) {
            ForEach(Atlas.figures.chunked(into: 3), id: \.first?.id) { row in
                HStack(spacing: 0) {
                    ForEach(row) { figure in
                        VStack(spacing: 4) {
                            ConstellationThumbnail(constellations: [figure.placedStars()],
                                                   lineWidth: 1.6, nodeRadius: 3.4)
                                .frame(width: 150, height: 150)
                            Text(figure.name)
                                .font(.system(size: 11, design: .serif))
                                .foregroundStyle(Palette.gold)
                        }
                        .frame(width: 160, height: 176)
                    }
                }
            }
        }
        .padding(12)
        .background(Palette.nightTop)

        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2
        let data = try XCTUnwrap(renderer.uiImage?.pngData())
        let out = URL.temporaryDirectory.appendingPathComponent("atlas-sheet.png")
        try data.write(to: out)
        print("ATLAS_SHEET_AT \(out.path)")
    }
}

import SwiftUI

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
