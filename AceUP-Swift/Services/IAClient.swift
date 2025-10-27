import Foundation

public struct StraicoConfig {
    public var baseURL: URL
    public var apiKey: String

    public init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    public static func loadFromConfigPlist() -> StraicoConfig? {
        guard
            let baseURL = AppConfigProvider.straicoBaseURL(),
            let key = AppConfigProvider.straicoAPIKey()
        else {
            print("❌ StraicoConfig.loadFromConfigPlist -> faltan baseURL o apiKey")
            return nil
        }

        print("✅ StraicoConfig.loadFromConfigPlist -> OK")
        print("   baseURL =", baseURL.absoluteString)
        print("   keyLength =", key.count)

        return .init(baseURL: baseURL, apiKey: key)
    }
}

public final class StraicoClient {
    private let cfg: StraicoConfig
    private let session: URLSession

    public init(config: StraicoConfig, session: URLSession = .shared) {
        self.cfg = config
        self.session = session
    }

    public func complete(
        prompt: String,
        model: String = "openai/gpt-4o-2024-08-06"
    ) async throws -> String {

        print("🌐 StraicoClient.complete -> baseURL:", cfg.baseURL.absoluteString)

        // Construimos: {base}/prompt/completion
        let fullURL = cfg.baseURL
            .appendingPathComponent("prompt")
            .appendingPathComponent("completion")

        print("🌐 StraicoClient.complete -> fullURL:", fullURL.absoluteString)

        guard fullURL.scheme?.hasPrefix("http") == true else {
            print("❌ StraicoClient.complete -> URL no tiene http/https:", fullURL)
            throw URLError(.unsupportedURL)
        }

        var req = URLRequest(url: fullURL)
        req.httpMethod = "POST"
        req.setValue("Bearer \(cfg.apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "message": prompt
        ]

        if let debugBodyData = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted]),
           let debugBodyString = String(data: debugBodyData, encoding: .utf8) {
            print("📤 StraicoClient.complete -> REQUEST BODY:\n\(debugBodyString)")
        }

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, resp) = try await session.data(for: req)

            guard let http = resp as? HTTPURLResponse else {
                print("❌ StraicoClient.complete -> respuesta NO es HTTPURLResponse")
                throw URLError(.badServerResponse)
            }

            print("📥 StraicoClient.complete -> status \(http.statusCode)")

            let rawText = String(data: data, encoding: .utf8) ?? "<binary?>"
            print("📥 StraicoClient.complete -> RAW RESPONSE:\n\(rawText)")

            guard (200..<300).contains(http.statusCode) else {
                throw NSError(
                    domain: "Straico",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Straico error (\(http.statusCode)): \(rawText)"
                    ]
                )
            }

            // devolvemos el JSON crudo como String
            return rawText
        } catch {
            print("❌ StraicoClient.complete -> URLSession error:", error.localizedDescription)
            throw error
        }
    }
}
