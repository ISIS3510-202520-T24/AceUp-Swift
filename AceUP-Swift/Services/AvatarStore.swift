import Foundation

/// Guarda la elección de avatar por email usando el UnifiedHybridDataProviders.
/// Delegates to unified cache for better memory management and consistency.
final class AvatarStore {
    static let shared = AvatarStore()
    private init() {}

    func get(for email: String) -> AvatarKey? {
        return UnifiedHybridDataProviders.shared.getCachedAvatar(email: email)
    }

    /// Persiste el avatar para un email y actualiza el snapshot de perfil.
    func set(for email: String, key: AvatarKey, currentNick: String?) {
        guard !email.isEmpty else { return }
        UnifiedHybridDataProviders.shared.cacheAvatar(email: email, key: key, currentNick: currentNick)
    }
}
