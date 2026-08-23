import Foundation
import Observation

/// The kept constellations, written to disk as JSON. Small enough that the
/// whole log is loaded at launch and rewritten on every change.
@MainActor
@Observable
final class SkyLog {
    private(set) var entries: [SavedSky] = []
    private let url: URL

    /// `nonisolated` so it can be used as a default argument of `init`, which is
    /// evaluated at the call site outside of the main actor. `URL` is `Sendable`
    /// and the value is immutable, so this is safe from any isolation domain.
    nonisolated static let defaultURL: URL = {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? URL.temporaryDirectory
        return base.appendingPathComponent("skylog.json")
    }()

    init(url: URL = SkyLog.defaultURL) {
        self.url = url
        load()
    }

    var isEmpty: Bool { entries.isEmpty }
    var count: Int { entries.count }

    func keep(_ sky: SavedSky) {
        guard sky.isCoherent else { return }
        entries.removeAll { $0.id == sky.id }
        entries.insert(sky, at: 0)   // newest first
        persist()
    }

    func remove(_ sky: SavedSky) {
        entries.removeAll { $0.id == sky.id }
        persist()
    }

    func remove(atOffsets offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        persist()
    }

    // MARK: - Disk

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = (try? decoder.decode([SavedSky].self, from: data)) ?? []
        entries = decoded.filter(\.isCoherent)
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
