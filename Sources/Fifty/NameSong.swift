import CoreGraphics
import Foundation

/// A name, turned into a melody.
///
/// The rule is the one the rest of the app already uses: **height is pitch**.
/// So a name becomes a row of heights in the sky and the sky sings it — nothing
/// here invents a second musical system alongside Starsong's.
///
/// Letters map onto the scale in alphabetical order — A is the lowest note, B
/// the one above it, and so on. The sky holds fifteen notes and the alphabet
/// holds twenty-six, so it wraps; the useful consequence is that letters near
/// each other in the alphabet sing near each other, which is why AMANDA comes
/// out as a phrase that steps rather than one that leaps. Mapping the alphabet
/// across the *whole* range instead — A at the bottom, Z at the top — was tried
/// first and put M and N an octave apart, which turns most names into a siren.
enum NameSong {
    /// The band of the sky the letters live in. Kept off both edges: the very
    /// bottom of the sky is the root note and a name that starts and ends there
    /// sounds like a drone, and the very top is shrill.
    static let lowest = 2
    static let highest = 12
    static var span: Int { highest - lowest + 1 }

    /// The scale degrees a name sings. Letters only — spaces, hyphens and
    /// apostrophes are silent, so "Mary-Jo" and "Mary Jo" sing the same.
    static func degrees(in name: String) -> [Int] {
        letters(in: name).map { lowest + Int($0) % span }
    }

    /// A...Z as 0...25. Accents are folded, so "Zoë" keeps its E.
    static func letters(in name: String) -> [UInt8] {
        name.folding(options: [.diacriticInsensitive], locale: .current)
            .uppercased()
            .unicodeScalars
            .compactMap { scalar in
                guard scalar.value >= 65, scalar.value <= 90 else { return nil }
                return UInt8(scalar.value - 65)
            }
    }

    /// Where in the sky each letter sits. Inverting the degree here is what
    /// makes the melody visible: a name written out as stars slopes the way it
    /// sounds.
    static func heights(in name: String) -> [CGFloat] {
        degrees(in: name).map { 1 - CGFloat($0) / CGFloat(Music.range) }
    }

    /// The name as a row of stars, evenly spaced.
    ///
    /// Even in *x*, that is. The heights are the letters, so the only thing
    /// varying the reach from one letter to the next is how far the melody
    /// leaps — and `Music.gaps` reads rhythm from exactly that. So a name
    /// arrives with the lilt its own leaps give it rather than on a metronome,
    /// and the app's rule that shape is rhythm needs no exception here.
    ///
    /// AMANDA runs quickly through its first three letters and ends on a note
    /// four times as long, because the widest leap in it is the fall from its
    /// top note home to the last A.
    static func stars(in name: String) -> [Star] {
        let heights = heights(in: name)
        guard heights.count > 1 else {
            return heights.map { Star(x: 0.5, y: $0, radius: 2.4, phase: 0, isBright: true) }
        }
        return heights.enumerated().map { index, y in
            let t = CGFloat(index) / CGFloat(heights.count - 1)
            return Star(x: 0.15 + t * 0.70, y: y, radius: 2.4, phase: Double(index),
                        isBright: true)
        }
    }

    /// The key her name is in. A stable hash — `hashValue` is seeded per
    /// process, so using it would tune the keepsake differently every launch.
    static func tuning(for name: String) -> Music.Tuning {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for letter in letters(in: name) {
            hash ^= UInt64(letter)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return Music.tuning(for: hash)
    }
}
