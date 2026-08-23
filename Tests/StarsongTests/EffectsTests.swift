import XCTest
@testable import Starsong

final class EffectsTests: XCTestCase {
    let now = Date(timeIntervalSinceReferenceDate: 1_000)

    func testShootersMoveAtTheSameSpeedRegardlessOfFrameRate() {
        // The original moved shooters by a fixed amount per frame, so they flew
        // twice as fast on a 120 Hz display. Position is now a function of time.
        let shooter = Shooter(origin: CGPoint(x: 0.1, y: 0.1),
                              velocity: CGVector(dx: 0.4, dy: 0.2),
                              start: now,
                              lifespan: 2)
        let halfway = shooter.position(at: now.addingTimeInterval(1))
        XCTAssertEqual(halfway.x, 0.5, accuracy: 1e-9)
        XCTAssertEqual(halfway.y, 0.3, accuracy: 1e-9)
        XCTAssertEqual(shooter.life(at: now.addingTimeInterval(1)), 0.5, accuracy: 1e-9)
        XCTAssertTrue(shooter.hasFaded(at: now.addingTimeInterval(2.1)))
    }

    func testPulsesScheduledInTheFutureAreNotYetVisible() {
        let pulse = Pulse(position: .zero, start: now.addingTimeInterval(0.5), line: 0)
        XCTAssertLessThan(pulse.progress(at: now), 0)
        XCTAssertFalse(pulse.hasFaded(at: now))
        XCTAssertEqual(pulse.progress(at: now.addingTimeInterval(0.95)), 0.5, accuracy: 1e-9)
        XCTAssertFalse(pulse.hasFaded(at: now.addingTimeInterval(1.2)))
        XCTAssertTrue(pulse.hasFaded(at: now.addingTimeInterval(1.5)))
    }

    @MainActor
    func testAdvanceReapsFadedEffects() {
        let model = SkyModel()
        model.newSky(for: CGSize(width: 390, height: 844), seed: 3)
        model.connect(at: model.stars[0].point(in: CGSize(width: 390, height: 844)),
                      in: CGSize(width: 390, height: 844))
        XCTAssertEqual(model.pulses.count, 1)
        model.advance(to: Date().addingTimeInterval(5), spawnChance: 0)
        XCTAssertTrue(model.pulses.isEmpty)
        XCTAssertTrue(model.shooters.isEmpty)
    }

    @MainActor
    func testAdvanceCanLaunchAShootingStarAndCapsThem() {
        let model = SkyModel()
        for _ in 0..<50 { model.advance(to: Date(), spawnChance: 1) }
        XCTAssertGreaterThan(model.shooters.count, 0)
        XCTAssertLessThanOrEqual(model.shooters.count, 3)
    }
}

final class StarAppearanceTests: XCTestCase {
    func testConnectedStarsAreAlwaysBigEnoughToSee() {
        let faint = Star(x: 0.5, y: 0.5, radius: 0.8, phase: 0, isBright: false)
        XCTAssertLessThan(faint.drawnRadius, 1.5)

        var lit = faint
        lit.isLit = true
        XCTAssertGreaterThanOrEqual(lit.drawnRadius, 3.2)
        XCTAssertTrue(lit.isProminent)
    }

    func testTwinkleStaysWithinBounds() {
        let star = Star(x: 0, y: 0, radius: 1, phase: 1.3, isBright: true)
        for tick in stride(from: 0.0, through: 20.0, by: 0.05) {
            let value = star.twinkle(at: tick)
            XCTAssertTrue((0.19...1.01).contains(value), "twinkle \(value) at t=\(tick)")
        }
    }
}
