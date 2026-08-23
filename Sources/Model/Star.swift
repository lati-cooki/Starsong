import CoreGraphics
import Foundation

/// A star in the sky. Positions are stored as 0...1 fractions of the sky so
/// rotating the device or resizing the window keeps a constellation intact.
struct Star: Identifiable, Hashable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    /// Base radius in points, before the "bright" multiplier.
    var radius: CGFloat
    /// Twinkle offset so the sky doesn't pulse in unison.
    var phase: Double
    /// Born bright — part of the sky's original character.
    var isBright: Bool
    /// Lit by the player by being drawn into the current constellation.
    var isLit: Bool

    init(id: UUID = UUID(),
         x: CGFloat,
         y: CGFloat,
         radius: CGFloat,
         phase: Double,
         isBright: Bool,
         isLit: Bool = false) {
        self.id = id
        self.x = x
        self.y = y
        self.radius = radius
        self.phase = phase
        self.isBright = isBright
        self.isLit = isLit
    }

    var isProminent: Bool { isBright || isLit }

    /// A star you connected becomes a node on the line, so it gets a floor —
    /// otherwise a faint star stays nearly invisible at a vertex.
    var drawnRadius: CGFloat {
        if isLit { return max(radius * 2, 3.2) }
        return radius * (isBright ? 1.8 : 1)
    }

    func point(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }

    /// 0.2...1.0 brightness, cycling roughly every three seconds.
    func twinkle(at time: Double) -> Double {
        0.6 + 0.4 * sin(time * 2 + phase)
    }
}

/// An expanding ring left behind when a star sings.
/// Time-parametric: everything is derived from `start`, so rendering never
/// needs per-frame state mutation, and pulses can be scheduled into the future.
struct Pulse: Identifiable {
    let id = UUID()
    let position: CGPoint
    let start: Date
    let duration: Double
    /// Which line sounded it, so the ring matches the colour of its melody.
    /// `nil` is the quiet ring under a finger, before any note belongs anywhere.
    let line: Int?

    init(position: CGPoint, start: Date, duration: Double = 0.9, line: Int?) {
        self.position = position
        self.start = start
        self.duration = duration
        self.line = line
    }

    /// < 0 before it begins, >= 1 once it has faded out.
    func progress(at now: Date) -> Double {
        now.timeIntervalSince(start) / duration
    }

    func hasFaded(at now: Date) -> Bool { progress(at: now) >= 1 }
}

/// A shooting star. Also time-parametric, so its speed is independent of frame rate.
struct Shooter: Identifiable {
    let id = UUID()
    let origin: CGPoint
    /// Sky fractions per second.
    let velocity: CGVector
    let start: Date
    let lifespan: Double

    func position(at now: Date) -> CGPoint {
        let t = now.timeIntervalSince(start)
        return CGPoint(x: origin.x + velocity.dx * t, y: origin.y + velocity.dy * t)
    }

    /// 1 at birth, 0 at death.
    func life(at now: Date) -> Double {
        1 - min(max(now.timeIntervalSince(start) / lifespan, 0), 1)
    }

    func hasFaded(at now: Date) -> Bool { now.timeIntervalSince(start) >= lifespan }
}
