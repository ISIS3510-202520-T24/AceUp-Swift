import Foundation

/// Guarda la elección de avatar por email en UserDefaults.
/// Además, actualiza el ProfileSnapshotCache para pintar instantáneo.
final class AvatarStore {
    static let shared = AvatarStore(); private init() {}

    private let udKey = "avatar.by.email" // [email: avatarKey]
    private var dict: [String: String] {
        get { (UserDefaults.standard.dictionary(forKey: udKey) as? [String: String]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: udKey) }
    }

    func get(for email: String) -> AvatarKey? {
        guard !email.isEmpty, let raw = dict[email] else { return nil }
        return AvatarKey(rawValue: raw)
    }

    /// Persiste el avatar para un email y actualiza el snapshot de perfil (nick se mantiene si existe).
    func set(for email: String, key: AvatarKey, currentNick: String?) {
        guard !email.isEmpty else { return }
        var m = dict; m[email] = key.rawValue; dict = m

        if let png = key.pngData() {
            ProfileSnapshotCache.shared.set(email: email, nick: currentNick, avatarPNG: png)
        }
        // No NotificationCenter
    }
}
