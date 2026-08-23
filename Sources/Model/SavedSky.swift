import CoreGraphics
import Foundation

/// A kept constellation. Because the sky is generated from a seed, a whole
/// night only costs a few dozen bytes: the seed and how many stars it made,
/// plus which of them you connected.
struct SavedSky: Codable, Identifiable, Hashable {
    let id: UUID
    let seed: UInt64
    /// Random background stars. A placed figure's stars sit after these.
    let fieldStarCount: Int
    /// Set when this was a real constellation from the atlas.
    let figureID: String?
    /// One entry per line. Skies kept before layering existed hold a single one.
    let lines: [[Int]]
    /// The voice each line is played in, one per entry in `lines`. Skies kept
    /// before there was more than one voice come back as Chime, which is what
    /// they sounded like.
    let voices: [Instrument]
    let name: String
    let myth: String
    let keptAt: Date

    /// `starCount` is the name the first version wrote; keeping the key means
    /// skies kept before figures existed still load.
    private enum CodingKeys: String, CodingKey {
        case id, seed, lines, voices, name, myth, keptAt, figureID
        case path                                   // what the first version wrote
        case fieldStarCount = "starCount"
    }

    /// Writes only the current shape. `path` is read, never written again.
    func encode(to encoder: Encoder) throws {
        var box = encoder.container(keyedBy: CodingKeys.self)
        try box.encode(id, forKey: .id)
        try box.encode(seed, forKey: .seed)
        try box.encode(fieldStarCount, forKey: .fieldStarCount)
        try box.encodeIfPresent(figureID, forKey: .figureID)
        try box.encode(lines, forKey: .lines)
        try box.encode(voices, forKey: .voices)
        try box.encode(name, forKey: .name)
        try box.encode(myth, forKey: .myth)
        try box.encode(keptAt, forKey: .keptAt)
    }

    /// Reads both shapes: `lines` if it is there, otherwise the single `path` a
    /// sky kept before layering would have written.
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(UUID.self, forKey: .id)
        seed = try box.decode(UInt64.self, forKey: .seed)
        fieldStarCount = try box.decode(Int.self, forKey: .fieldStarCount)
        figureID = try box.decodeIfPresent(String.self, forKey: .figureID)
        name = try box.decode(String.self, forKey: .name)
        myth = try box.decode(String.self, forKey: .myth)
        keptAt = try box.decode(Date.self, forKey: .keptAt)
        if let lines = try box.decodeIfPresent([[Int]].self, forKey: .lines) {
            self.lines = lines
        } else {
            self.lines = [try box.decode([Int].self, forKey: .path)]
        }

        // Anything kept before voices existed was played on the chime, and an
        // entry whose voices have got out of step with its lines is repaired
        // rather than dropped — a wrong instrument is a much smaller loss than
        // a lost constellation.
        let stored = (try box.decodeIfPresent([Instrument].self, forKey: .voices)) ?? []
        self.voices = (0..<self.lines.count).map { stored.indices.contains($0) ? stored[$0] : .chime }
    }

    init(id: UUID = UUID(),
         seed: UInt64,
         fieldStarCount: Int,
         figureID: String? = nil,
         lines: [[Int]],
         voices: [Instrument] = [],
         name: String,
         myth: String,
         keptAt: Date = Date()) {
        self.id = id
        self.seed = seed
        self.fieldStarCount = fieldStarCount
        self.figureID = figureID
        self.lines = lines
        let provided = voices
        self.voices = (0..<lines.count).map { provided.indices.contains($0) ? provided[$0] : .chime }
        self.name = name
        self.myth = myth
        self.keptAt = keptAt
    }

    var figure: Figure? { Atlas.figure(id: figureID) }
    var totalStarCount: Int { fieldStarCount + (figure?.stars.count ?? 0) }

    /// Rebuilds the exact stars this constellation was drawn on.
    var stars: [Star] {
        var rng = SplitMix64(seed: seed)
        var stars = SkyModel.makeStars(count: fieldStarCount, using: &rng)
        if let figure { stars.append(contentsOf: figure.placedStars()) }
        for index in lines.joined() where stars.indices.contains(index) {
            stars[index].isLit = true
        }
        return stars
    }

    /// The tuning this night was under, so a kept melody sounds as it did.
    var tuning: Music.Tuning { Music.tuning(for: seed) }

    /// Every line, as stars.
    var constellations: [[Star]] {
        let stars = stars
        return lines.map { line in line.compactMap { stars.indices.contains($0) ? stars[$0] : nil } }
    }

    /// Rebuilt as the model holds them.
    var savedLines: [Line] {
        lines.indices.map { Line(stars: lines[$0], instrument: voices[$0]) }
    }

    /// The first line, for anything that only needs one shape.
    var constellation: [Star] { constellations.first ?? [] }

    /// How many stars are on the page, counting a star once per time it is sung.
    var noteCount: Int { lines.reduce(0) { $0 + $1.count } }

    /// A file on disk is untrusted input: an index pointing past the end of the
    /// sky would crash the renderer, so a malformed entry is dropped.
    var isCoherent: Bool {
        fieldStarCount > 0
            && !lines.isEmpty
            && lines.allSatisfy { $0.count >= 2 }
            && (figureID == nil || figure != nil)
            && lines.joined().allSatisfy { (0..<totalStarCount).contains($0) }
            && !name.isEmpty
    }
}
