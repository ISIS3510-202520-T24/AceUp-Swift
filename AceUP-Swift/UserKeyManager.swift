import Foundation
import CryptoKit

final class UserKeyManager {
    static let shared = UserKeyManager()
    private init() {}
    private let k = "aceup_user_key"

    func userKey() -> String {
        if let s = UserDefaults.standard.string(forKey: k) { return s }
        let uuid = UUID().uuidString
        let digest = SHA256.hash(data: Data(uuid.utf8))
        let key = digest.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(key, forKey: k)
        return key
    }
}