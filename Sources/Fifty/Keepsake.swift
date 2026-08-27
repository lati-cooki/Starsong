import Foundation

// ─────────────────────────────────────────────────────────────────────────────
//  EVERYTHING PERSONAL LIVES IN THIS FILE.
//
//  Nothing below is code you have to understand. Change the name, the year she
//  was born, the two messages, and the fifty lines — one per year of her life —
//  and the keepsake rebuilds itself around them. Nothing else in the app needs
//  to be touched.
//
//  A year you leave empty is still a star and still sings; it just shows the
//  year rather than a memory. So you can fill in the ones you know tonight and
//  come back to the rest.
// ─────────────────────────────────────────────────────────────────────────────

enum Keepsake {

    /// Her name. It is the title, and it is also the melody the keepsake opens
    /// with — see `NameSong`, which turns letters into notes.
    static let name = "Amanda"

    /// The year she was born. Star one is this year; star fifty is this year
    /// plus forty-nine.
    static let birthYear = 1976

    /// Under her name, small.
    static let dedication = "Fifty years of you"

    /// Shown once every year has been opened.
    static let closing = """
        Fifty stars, and not one of them was there before you. \
        Happy birthday, my love.
        """

    /// The key it is played in. Her name picks it — see `NameSong.tuning` — so
    /// the keepsake is tuned to a scale nothing else in the app would have
    /// landed on. Swap in any of `Music.tunings` to choose it yourself.
    static var tuning: Music.Tuning { NameSong.tuning(for: name) }

    /// The voice the whole keepsake is played in. `.chime`, `.pluck`, `.piano`,
    /// `.brass`, `.bell` — Starsong's five. Piano suits a long line of years.
    static let voice: Instrument = .piano

    /// Make this `true` and the app opens straight into the keepsake instead of
    /// into Starsong — one line, and it becomes her app rather than a room
    /// inside yours. Left `false` so the repository's own tests still find
    /// Starsong where they expect it.
    static let opensOnLaunch = false

    /// One line per year, oldest first: `years[0]` is the year she was born,
    /// `years[49]` is the fiftieth. Keep them short — a phrase, not a
    /// paragraph. Two or three lines of text is about what the card holds
    /// comfortably.
    ///
    /// Leave a line as `""` and that year shows only its number.
    static let years: [String] = [
        // ── The first ten ──────────────────────────────────────────────────
        "Born. The sky got one star brighter and nobody noticed but it.",
        "", "", "", "", "", "", "", "", "",
        // ── Ten to nineteen ────────────────────────────────────────────────
        "", "", "", "", "", "", "", "", "", "",
        // ── Twenty to twenty-nine ──────────────────────────────────────────
        "", "", "", "", "", "", "", "", "", "",
        // ── Thirty to thirty-nine ──────────────────────────────────────────
        "", "", "", "", "", "", "", "", "", "",
        // ── Forty to forty-nine ────────────────────────────────────────────
        "", "", "", "", "", "", "", "", "",
        "Fifty. Which is not an ending, it is just a very good place to stand."
    ]

    // ── Below here is machinery, not content. ────────────────────────────────

    /// How many stars are in her sky. Fifty, unless you change `years`.
    static var count: Int { years.count }

    /// One year of her life.
    struct Year: Identifiable, Hashable {
        /// 0 for the year she was born, 49 for the fiftieth.
        let age: Int
        let year: Int
        let line: String

        var id: Int { age }
        var hasLine: Bool { !line.isEmpty }

        /// "1996 · twenty" — the heading on the card.
        var heading: String { "\(year) · \(Self.spelled(age))" }

        /// What VoiceOver reads. A year with nothing written for it still says
        /// so: silence would leave her swiping past a star that just sang
        /// without ever hearing which one it was.
        var spoken: String {
            hasLine ? "\(heading). \(line)" : "\(heading). Nothing written for this year yet."
        }

        private static let ones = ["nought", "one", "two", "three", "four", "five",
                                   "six", "seven", "eight", "nine", "ten", "eleven",
                                   "twelve", "thirteen", "fourteen", "fifteen",
                                   "sixteen", "seventeen", "eighteen", "nineteen"]
        private static let tens = ["", "", "twenty", "thirty", "forty", "fifty",
                                   "sixty", "seventy", "eighty", "ninety"]

        /// Ages are written out rather than printed as digits: the card already
        /// carries one number, and "1996 · 20" reads like a score.
        static func spelled(_ age: Int) -> String {
            guard age >= 0, age < 100 else { return "\(age)" }
            if age < 20 { return ones[age] }
            let ten = tens[age / 10]
            let unit = age % 10
            return unit == 0 ? ten : "\(ten)-\(ones[unit])"
        }
    }

    /// Her fifty years, in order.
    static var life: [Year] {
        years.indices.map { age in
            Year(age: age, year: birthYear + age, line: years[age])
        }
    }

    /// A decade begins here — drawn as one of the bright stars, so the sky has
    /// landmarks in it rather than fifty identical dots.
    static func isMilestone(age: Int) -> Bool { age % 10 == 0 }
}
