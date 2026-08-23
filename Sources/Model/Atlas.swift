import CoreGraphics
import Foundation

/// A real star, by catalogue position.
struct FigureStar: Hashable {
    let name: String
    /// Right ascension and declination in degrees (J2000).
    let rightAscension: Double
    let declination: Double
    /// Apparent magnitude, approximate — it only sets how big the star is drawn.
    let magnitude: Double
}

/// A real constellation, as a single stroke.
///
/// Starsong draws one continuous line, so each figure is stored as a *walk*:
/// the order to visit its stars, doubling back through a junction where the
/// traditional figure branches. A repeated star is a repeated note, which is a
/// perfectly good thing for a melody to do.
struct Figure: Identifiable, Hashable {
    let id: String
    let name: String
    /// One true sentence. No invented astronomy.
    let note: String
    let stars: [FigureStar]
    let walk: [Int]

    var isCoherent: Bool {
        stars.count >= 2 && walk.count >= 2 && walk.allSatisfy { stars.indices.contains($0) }
    }

    /// Where the figure sits in the sky, as 0–1 fractions.
    static let defaultBox = CGRect(x: 0.12, y: 0.20, width: 0.76, height: 0.52)

    /// Projects the real positions onto the sky.
    ///
    /// Gnomonic (tangent-plane) projection about the figure's own centre, which
    /// is how a star chart draws a small patch of sky: straight lines stay
    /// straight and the shape you know stays the shape you know. East is drawn
    /// to the left, as it is when you look up.
    func placedStars(in box: CGRect = Figure.defaultBox) -> [Star] {
        guard isCoherent else { return [] }
        let centre = Self.centre(of: stars)
        let flat = stars.map { Self.project($0, about: centre) }

        let xs = flat.map(\.x), ys = flat.map(\.y)
        let spanX = max(xs.max()! - xs.min()!, 1e-6)
        let spanY = max(ys.max()! - ys.min()!, 1e-6)
        let scale = min(box.width / spanX, box.height / spanY)
        let drawn = CGSize(width: spanX * scale, height: spanY * scale)
        let origin = CGPoint(x: box.midX - drawn.width / 2, y: box.midY - drawn.height / 2)

        return zip(stars, flat).map { star, point in
            Star(x: origin.x + (point.x - xs.min()!) * scale,
                 y: origin.y + (point.y - ys.min()!) * scale,
                 radius: max(0.9, 2.4 - 0.35 * star.magnitude),
                 phase: Double(star.rightAscension).truncatingRemainder(dividingBy: 6.28),
                 isBright: star.magnitude < 2.6,
                 isLit: true)
        }
    }

    /// Averaged as vectors on the sphere, so a figure that straddles 0h doesn't
    /// average its way to the far side of the sky.
    static func centre(of stars: [FigureStar]) -> (ra: Double, dec: Double) {
        var v = (x: 0.0, y: 0.0, z: 0.0)
        for star in stars {
            let ra = star.rightAscension * .pi / 180
            let dec = star.declination * .pi / 180
            v.x += cos(dec) * cos(ra)
            v.y += cos(dec) * sin(ra)
            v.z += sin(dec)
        }
        return (atan2(v.y, v.x), atan2(v.z, (v.x * v.x + v.y * v.y).squareRoot()))
    }

    /// Returns chart coordinates: x grows to the left (east), y grows downward.
    static func project(_ star: FigureStar, about centre: (ra: Double, dec: Double)) -> CGPoint {
        let ra = star.rightAscension * .pi / 180
        let dec = star.declination * .pi / 180
        let dRA = ra - centre.ra
        let cosC = sin(centre.dec) * sin(dec) + cos(centre.dec) * cos(dec) * cos(dRA)
        guard cosC > 1e-6 else { return .zero }   // more than 90° away; not a constellation
        let east = cos(dec) * sin(dRA) / cosC
        let north = (cos(centre.dec) * sin(dec) - sin(centre.dec) * cos(dec) * cos(dRA)) / cosC
        return CGPoint(x: -east, y: -north)
    }
}

/// The premade constellations. Positions are J2000 catalogue coordinates for
/// the named stars; magnitudes are approximate and only affect how large a star
/// is drawn.
enum Atlas {
    static func figure(id: String?) -> Figure? {
        guard let id else { return nil }
        return figures.first { $0.id == id }
    }

    static let figures: [Figure] = [orion, ursaMajor, cassiopeia, cygnus, lyra, leo, scorpius, coronaBorealis]

    static let orion = Figure(
        id: "orion",
        name: "Orion",
        note: "The hunter, and the most widely visible constellation on Earth — its three-star belt is the easiest thing to find in a winter sky. Betelgeuse, the star at his shoulder, is a red supergiant.",
        stars: [
            FigureStar(name: "Betelgeuse", rightAscension: 88.79, declination: 7.41, magnitude: 0.50),
            FigureStar(name: "Bellatrix", rightAscension: 81.28, declination: 6.35, magnitude: 1.64),
            FigureStar(name: "Mintaka", rightAscension: 83.00, declination: -0.30, magnitude: 2.23),
            FigureStar(name: "Alnilam", rightAscension: 84.05, declination: -1.20, magnitude: 1.69),
            FigureStar(name: "Alnitak", rightAscension: 85.19, declination: -1.94, magnitude: 1.77),
            FigureStar(name: "Saiph", rightAscension: 86.94, declination: -9.67, magnitude: 2.06),
            FigureStar(name: "Rigel", rightAscension: 78.63, declination: -8.20, magnitude: 0.13)
        ],
        // shoulders, down to the belt, out to each foot and back
        walk: [0, 1, 2, 6, 2, 3, 4, 5, 4, 0]
    )

    static let ursaMajor = Figure(
        id: "ursa-major",
        name: "The Plough",
        note: "The seven stars of the Plough, or Big Dipper, are an asterism inside the larger constellation Ursa Major. The two at the end of the bowl point to Polaris.",
        stars: [
            FigureStar(name: "Alkaid", rightAscension: 206.89, declination: 49.31, magnitude: 1.86),
            FigureStar(name: "Mizar", rightAscension: 200.98, declination: 54.93, magnitude: 2.23),
            FigureStar(name: "Alioth", rightAscension: 193.51, declination: 55.96, magnitude: 1.77),
            FigureStar(name: "Megrez", rightAscension: 183.86, declination: 57.03, magnitude: 3.31),
            FigureStar(name: "Phecda", rightAscension: 178.46, declination: 53.69, magnitude: 2.44),
            FigureStar(name: "Merak", rightAscension: 165.46, declination: 56.38, magnitude: 2.37),
            FigureStar(name: "Dubhe", rightAscension: 165.93, declination: 61.75, magnitude: 1.79)
        ],
        // handle, then round the bowl
        walk: [0, 1, 2, 3, 4, 5, 6, 3]
    )

    static let cassiopeia = Figure(
        id: "cassiopeia",
        name: "Cassiopeia",
        note: "A W of five bright stars, opposite the Plough across the pole — when one is low, the other is high. It never sets from most of the northern hemisphere.",
        stars: [
            FigureStar(name: "Caph", rightAscension: 2.29, declination: 59.15, magnitude: 2.27),
            FigureStar(name: "Schedar", rightAscension: 10.13, declination: 56.54, magnitude: 2.24),
            FigureStar(name: "Gamma Cassiopeiae", rightAscension: 14.18, declination: 60.72, magnitude: 2.15),
            FigureStar(name: "Ruchbah", rightAscension: 21.45, declination: 60.24, magnitude: 2.68),
            FigureStar(name: "Segin", rightAscension: 28.60, declination: 63.67, magnitude: 3.35)
        ],
        walk: [0, 1, 2, 3, 4]
    )

    static let cygnus = Figure(
        id: "cygnus",
        name: "Cygnus",
        note: "The swan, flying down the Milky Way, whose bright stars also form the Northern Cross. Deneb at its tail is one of the most luminous stars visible to the eye.",
        stars: [
            FigureStar(name: "Deneb", rightAscension: 310.36, declination: 45.28, magnitude: 1.25),
            FigureStar(name: "Sadr", rightAscension: 305.56, declination: 40.26, magnitude: 2.23),
            FigureStar(name: "Gienah", rightAscension: 311.55, declination: 33.97, magnitude: 2.48),
            FigureStar(name: "Delta Cygni", rightAscension: 296.24, declination: 45.13, magnitude: 2.87),
            FigureStar(name: "Albireo", rightAscension: 292.68, declination: 27.96, magnitude: 3.05)
        ],
        // down the spine, out along each wing, back through the crossing star
        walk: [0, 1, 2, 1, 3, 1, 4]
    )

    static let lyra = Figure(
        id: "lyra",
        name: "Lyra",
        note: "A small lyre hanging below Vega, the fifth-brightest star in the night sky. Its four fainter stars make a narrow parallelogram.",
        stars: [
            FigureStar(name: "Vega", rightAscension: 279.23, declination: 38.78, magnitude: 0.03),
            FigureStar(name: "Zeta Lyrae", rightAscension: 281.19, declination: 37.60, magnitude: 4.34),
            FigureStar(name: "Delta Lyrae", rightAscension: 283.62, declination: 36.90, magnitude: 4.30),
            FigureStar(name: "Sulafat", rightAscension: 284.74, declination: 32.69, magnitude: 3.25),
            FigureStar(name: "Sheliak", rightAscension: 282.52, declination: 33.36, magnitude: 3.52)
        ],
        walk: [0, 1, 2, 3, 4, 1]
    )

    static let leo = Figure(
        id: "leo",
        name: "Leo",
        note: "The lion, whose head and mane form a backwards question mark called the Sickle. Regulus, the dot at its foot, sits almost exactly on the path the Sun takes through the sky.",
        stars: [
            FigureStar(name: "Epsilon Leonis", rightAscension: 146.46, declination: 23.77, magnitude: 2.98),
            FigureStar(name: "Mu Leonis", rightAscension: 148.19, declination: 26.01, magnitude: 3.88),
            FigureStar(name: "Zeta Leonis", rightAscension: 154.17, declination: 23.42, magnitude: 3.44),
            FigureStar(name: "Algieba", rightAscension: 154.99, declination: 19.84, magnitude: 2.08),
            FigureStar(name: "Eta Leonis", rightAscension: 151.83, declination: 16.76, magnitude: 3.51),
            FigureStar(name: "Regulus", rightAscension: 152.09, declination: 11.97, magnitude: 1.35),
            FigureStar(name: "Chort", rightAscension: 168.56, declination: 15.43, magnitude: 3.32),
            FigureStar(name: "Denebola", rightAscension: 177.26, declination: 14.57, magnitude: 2.11),
            FigureStar(name: "Zosma", rightAscension: 168.53, declination: 20.52, magnitude: 2.56)
        ],
        // the Sickle, then the body and the tail
        walk: [0, 1, 2, 3, 4, 5, 6, 7, 8, 3]
    )

    static let scorpius = Figure(
        id: "scorpius",
        name: "Scorpius",
        note: "A scorpion curling low across the southern sky, with the red supergiant Antares at its heart — a name that means 'rival of Mars'.",
        stars: [
            FigureStar(name: "Graffias", rightAscension: 241.36, declination: -19.80, magnitude: 2.56),
            FigureStar(name: "Dschubba", rightAscension: 240.08, declination: -22.62, magnitude: 2.29),
            FigureStar(name: "Pi Scorpii", rightAscension: 239.71, declination: -26.11, magnitude: 2.89),
            FigureStar(name: "Antares", rightAscension: 247.35, declination: -26.43, magnitude: 1.06),
            FigureStar(name: "Tau Scorpii", rightAscension: 248.97, declination: -28.22, magnitude: 2.82),
            FigureStar(name: "Epsilon Scorpii", rightAscension: 252.54, declination: -34.29, magnitude: 2.29),
            FigureStar(name: "Mu Scorpii", rightAscension: 252.97, declination: -38.05, magnitude: 3.00),
            FigureStar(name: "Zeta Scorpii", rightAscension: 253.65, declination: -42.36, magnitude: 3.62),
            FigureStar(name: "Eta Scorpii", rightAscension: 258.04, declination: -43.24, magnitude: 3.32),
            FigureStar(name: "Shaula", rightAscension: 263.40, declination: -37.10, magnitude: 1.62)
        ],
        walk: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    )

    static let coronaBorealis = Figure(
        id: "corona-borealis",
        name: "Corona Borealis",
        note: "The northern crown: a small, neat arc of seven stars between Boötes and Hercules, with Alphecca the brightest of them.",
        stars: [
            FigureStar(name: "Theta Coronae Borealis", rightAscension: 233.24, declination: 31.36, magnitude: 4.14),
            FigureStar(name: "Nusakan", rightAscension: 231.96, declination: 29.11, magnitude: 3.66),
            FigureStar(name: "Alphecca", rightAscension: 233.67, declination: 26.71, magnitude: 2.22),
            FigureStar(name: "Gamma Coronae Borealis", rightAscension: 235.68, declination: 26.30, magnitude: 3.80),
            FigureStar(name: "Delta Coronae Borealis", rightAscension: 237.40, declination: 26.07, magnitude: 4.59),
            FigureStar(name: "Epsilon Coronae Borealis", rightAscension: 239.40, declination: 26.88, magnitude: 4.14),
            FigureStar(name: "Iota Coronae Borealis", rightAscension: 240.36, declination: 29.85, magnitude: 4.96)
        ],
        walk: [0, 1, 2, 3, 4, 5, 6]
    )
}
