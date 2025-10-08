import Foundation
import CryptoKit
import Security
import UIKit

// Config
enum AnalyticsConfig {
    // Get analytics URL from config or environment variable
    static let COLLECTOR_URL: URL = {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let urlString = config["ANALYTICS_COLLECTOR_URL"] as? String,
           let url = URL(string: urlString) {
            return url
        }
        
        if let urlString = ProcessInfo.processInfo.environment["ANALYTICS_COLLECTOR_URL"],
           let url = URL(string: urlString) {
            return url
        }
        return URL(string: "https://your-analytics-endpoint.com")!
    }()
    
    static let DRY_RUN = false
    static let SERVICE = "com.aceup.analytics"
    static let USER_KEYCHAIN_KEY = "analytics_user_key"
    static let SALT_KEYCHAIN_KEY = "analytics_salt"
    static let APP = "AceUp"
}

// JSONValue para props heterogéneas
enum JSONValue: Codable {
    case string(String), int(Int), double(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

    init(_ any: Any?) {
        guard let any = any else { self = .null; return }
        switch any {
        case let v as String: self = .string(v)
        case let v as Int: self = .int(v)
        case let v as Double: self = .double(v)
        case let v as Bool: self = .bool(v)
        case let v as [String: Any]: self = .object(v.mapValues { JSONValue($0) })
        case let v as [Any]: self = .array(v.map { JSONValue($0) })
        default: self = .string("\(any)")
        }
    }
}

// Evento
struct AnalyticsEvent: Codable {
    let event: String
    let ts: String               // ISO8601
    let userKey: String
    let deviceId: String
    let appVersion: String
    let platform: String
    let props: [String: JSONValue]
}

// Keychain helper muy simple
enum KeychainHelper {
    static func set(_ value: Data, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AnalyticsConfig.SERVICE,
            kSecAttrAccount as String: key,
            kSecValueData as String: value
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AnalyticsConfig.SERVICE,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &out)
        return out as? Data
    }
}

// Analytics singleton
final class Analytics {
    static let shared = Analytics()
    private init() {}

    private var cachedUserKey: String?

    // Crea (y persiste) un salt por dispositivo
    private func deviceSalt() -> Data {
        if let d = KeychainHelper.get(AnalyticsConfig.SALT_KEYCHAIN_KEY) { return d }
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let data = Data(bytes)
        KeychainHelper.set(data, key: AnalyticsConfig.SALT_KEYCHAIN_KEY)
        return data
    }

    // Hashea uid con salt -> userKey seudonimizado (no PII en el pipeline)
    private func deriveUserKey(from uid: String) -> String {
        if let cached = cachedUserKey { return cached }
        if let saved = KeychainHelper.get(AnalyticsConfig.USER_KEYCHAIN_KEY),
           let s = String(data: saved, encoding: .utf8) {
            cachedUserKey = s; return s
        }
        let salt = deviceSalt()
        let input = salt + Data(uid.utf8) + Data(AnalyticsConfig.APP.utf8)
        let hash = SHA256.hash(data: input)
        let key = hash.compactMap { String(format: "%02x", $0) }.joined()
        KeychainHelper.set(Data(key.utf8), key: AnalyticsConfig.USER_KEYCHAIN_KEY)
        cachedUserKey = key
        return key
    }

    @discardableResult
    func identify(userId uid: String) -> String {
        let key = deriveUserKey(from: uid)
        return key
    }

    func track(_ name: String, props: [String: Any?] = [:]) {
        // BQ 2.4: Si es progreso académico, actualiza el último timestamp local
        if name == "grade_recorded" || name == "assignment_completed" {
            LastProgress.shared.update()
        }

        guard let userKey = cachedUserKey ?? (KeychainHelper.get(AnalyticsConfig.USER_KEYCHAIN_KEY).flatMap { String(data: $0, encoding: .utf8) }) else {
            print("Analytics.track: no userKey (llama identify() después del login)."); return
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let evt = AnalyticsEvent(
            event: name,
            ts: iso.string(from: Date()),
            userKey: userKey,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            appVersion: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0",
            platform: "iOS",
            props: props.mapValues { JSONValue($0) }
        )

        if AnalyticsConfig.DRY_RUN {
            if let d = try? JSONEncoder().encode(evt),
               let s = String(data: d, encoding: .utf8) {
                print("📦 [DRY-RUN] \(s)")
            }
            return
        }

        // Envío HTTP
        var req = URLRequest(url: AnalyticsConfig.COLLECTOR_URL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(evt)

        URLSession.shared.dataTask(with: req) { _, resp, err in
            if let err = err { print("Analytics POST error:", err.localizedDescription) }
            else if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("Analytics POST status:", http.statusCode)
            }
        }.resume()
    }
}