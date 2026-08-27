import Foundation

/// Which years have been opened. Small enough to live in `UserDefaults`, and
/// worth keeping at all because a keepsake is something you come back to — the
/// gold already in the sky is the record of the evenings you spent on it.
///
/// Keyed by name so two keepsakes built from the same checkout do not inherit
/// each other's progress.
struct KeepsakeProgress {
    private let defaults: UserDefaults
    private let key: String
    private(set) var read: Set<Int>

    init(name: String = Keepsake.name, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.key = "keepsake.read.\(name.lowercased())"
        let stored = defaults.array(forKey: key) as? [Int] ?? []
        self.read = Set(stored)
    }

    mutating func markRead(_ age: Int) {
        guard age >= 0, !read.contains(age) else { return }
        read.insert(age)
        save()
    }

    mutating func forgetEverything() {
        read = []
        save()
    }

    func isComplete(of count: Int) -> Bool {
        count > 0 && read.count >= count
    }

    private func save() {
        defaults.set(read.sorted(), forKey: key)
    }
}
