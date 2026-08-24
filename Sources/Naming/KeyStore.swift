import Foundation
import Security

/// Where a bring-your-own API key lives. The Keychain rather than
/// `UserDefaults`, because a key is a credential: defaults are a plist in the
/// container, readable by anything that can see the filesystem and swept up by
/// unencrypted backups.
///
/// Stored `.whenUnlockedThisDeviceOnly` — naming a constellation only happens
/// with the app in front of you, so there is no reason to keep the key readable
/// in the background, and no reason to let it migrate to another device.
enum KeyStore {
    /// Namespaced by bundle id so a debug and a release install don't share one.
    private static var service: String {
        (Bundle.main.bundleIdentifier ?? "com.starsong.app") + ".anthropic"
    }
    private static let account = "anthropic-api-key"

    enum Failure: Error, Equatable {
        case empty
        case keychain(OSStatus)
    }

    // MARK: - Reading

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static var hasKey: Bool { load() != nil }

    // MARK: - Writing

    /// Overwrites any existing key. Trims first: keys get pasted with a stray
    /// newline more often than not, and a trailing newline in an HTTP header
    /// value is worth catching here rather than as a puzzling 401.
    static func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.empty }

        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)

        var insert = base
        insert[kSecValueData as String] = Data(trimmed.utf8)
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(insert as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure.keychain(status) }
    }

    /// Succeeds when there was nothing to remove — "make sure there is no key"
    /// is the useful contract, not "a key existed and now doesn't".
    static func remove() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure.keychain(status)
        }
    }

    // MARK: - Showing it without showing it

    /// Enough of a key to recognise which one is installed, not enough to use.
    static func fingerprint(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 12 else { return "••••" }
        return trimmed.prefix(8) + "…" + trimmed.suffix(4)
    }
}
