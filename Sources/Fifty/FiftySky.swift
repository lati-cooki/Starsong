import CoreGraphics
import Foundation

/// The shape of a life: fifty stars wound out from the middle of the sky, one
/// for each year, the first near the middle and the fiftieth at the rim.
///
/// A spiral rather than a row because a row of fifty stars on a phone is eight
/// points apart and reads as a dotted line, and because winding outwards says
/// the thing the list is for — it starts small and keeps reaching further.
///
/// Two musical consequences fall out of the geometry rather than being bolted
/// on. Height is pitch, so the melody rises and falls once per turn and widens
/// as it goes. And `Music.gaps` reads rhythm from how far apart stars sit, so
/// the early years — packed near the centre — come quickly, and the later ones,
/// with a longer reach between them, are given room.
enum FiftySky {
    /// Two and a half turns. Fewer and it reads as a circle; more and the
    /// years crowd into each other.
    static let turns = 2.5
    /// A little above the middle: the card of memories sits along the bottom.
    static let centre = CGPoint(x: 0.5, y: 0.45)
    /// Half-extents, in sky fractions.
    static let reach = CGSize(width: 0.40, height: 0.29)
    /// The first year is not at the centre. It was, at first, and the opening
    /// decade came out five points apart on a phone — a smudge rather than ten
    /// stars. Starting the spiral already a quarter of the way out costs
    /// nothing and puts sixteen points between the closest pair.
    static let innermost = 0.26
    /// Eases the radius so the early years are not squeezed while the late ones
    /// sprawl. Below 1 opens the middle out; 0.8 is where the closest pair and
    /// the widest gap stop fighting.
    static let easing = 0.80
    /// How much her name pulls the spiral out of true, as a fraction of the
    /// radius. Small on purpose: this is a waver in the outline, not a legible
    /// signature, and claiming otherwise would be claiming more than it does.
    static let waver = 0.10

    /// The sky. `lit` is the set of ages already opened — those stars take on
    /// the gold the rest of the app gives a star you drew.
    static func stars(count: Int = Keepsake.count,
                      name: String = Keepsake.name,
                      lit: Set<Int> = []) -> [Star] {
        guard count > 0 else { return [] }
        let wobbles = waverProfile(for: name)

        return (0..<count).map { age in
            let t = count > 1 ? Double(age) / Double(count - 1) : 0
            // Start at the top of the sky and wind clockwise.
            let angle = -Double.pi / 2 + t * turns * 2 * .pi
            let radius = innermost + (1 - innermost) * pow(t, easing)
            let pulled = radius * (1 + waver * wobbles[age % wobbles.count])
            let milestone = Keepsake.isMilestone(age: age)

            return Star(
                x: centre.x + CGFloat(pulled * cos(angle)) * reach.width,
                y: centre.y + CGFloat(pulled * sin(angle)) * reach.height,
                radius: milestone ? 2.2 : 1.5,
                // The golden angle, so no two stars twinkle together and the
                // sky does not breathe in unison.
                phase: Double(age) * 2.399_963,
                isBright: milestone,
                isLit: lit.contains(age)
            )
        }
    }

    /// Her name as a row of numbers in -1...1, used to pull the spiral about.
    ///
    /// Centred on the name's *own* average rather than on the middle of the
    /// scale, which matters more than it sounds: AMANDA sings in the bottom
    /// third of the sky, so measuring against the scale would have made every
    /// one of its numbers negative and turned a waver into a uniform shrink.
    /// Against its own mean, a name pushes out as often as it pulls in.
    static func waverProfile(for name: String) -> [Double] {
        let degrees = NameSong.degrees(in: name).map { Double($0) }
        guard !degrees.isEmpty else { return [0] }
        let mean = degrees.reduce(0, +) / Double(degrees.count)
        let deviations = degrees.map { $0 - mean }
        let peak = deviations.map { abs($0) }.max() ?? 0
        guard peak > 0 else { return [0] }
        return deviations.map { $0 / peak }
    }

    /// Fingers are wider than stars, so the nearest one within reach wins
    /// rather than only a direct hit. Returns the age, which is also the index.
    static let touchRadius = 42.0

    static func year(nearest point: CGPoint, in stars: [Star], size: CGSize) -> Int? {
        guard size.width > 0, size.height > 0 else { return nil }
        var best: (age: Int, distance: Double)?
        for (age, star) in stars.enumerated() {
            let at = star.point(in: size)
            let distance = Double(hypot(at.x - point.x, at.y - point.y))
            guard distance <= touchRadius else { continue }
            if best == nil || distance < best!.distance { best = (age, distance) }
        }
        return best?.age
    }
}
