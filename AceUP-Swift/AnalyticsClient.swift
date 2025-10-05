import Foundation

enum AnalyticsEnv {
    static let collector = URL(string: "https://us-central1-aceup-app-123.cloudfunctions.net/collect")!
    static let days = URL(string: "https://us-central1-aceup-app-123.cloudfunctions.net/daysSinceLastProgress")!
}

struct AnalyticsClient {
    static func sendAssignmentCompleted(userKey: String,
                                        assignmentId: String,
                                        completion: ((Bool) -> Void)? = nil) {
        let payload: [String: Any] = [
            "event": "assignment_completed",
            "userKey": userKey,
            "ts": ISO8601DateFormatter().string(from: Date()),
            "props": ["assignment_id": assignmentId]
        ]
        postJSON(url: AnalyticsEnv.collector, json: payload) { ok in
            completion?(ok)
        }
    }

    static func fetchDaysSinceLastProgress(userKey: String,
                                           completion: @escaping (Int?) -> Void) {
        var comps = URLComponents(url: AnalyticsEnv.days, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "userKey", value: userKey)]
        guard let url = comps.url else { completion(nil); return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let d = data else { completion(nil); return }
            struct Resp: Decodable { let ok: Bool; let days: Int? }
            let r = try? JSONDecoder().decode(Resp.self, from: d)
            completion(r?.days)
        }.resume()
    }

    private static func postJSON(url: URL,
                                 json: [String: Any],
                                 completion: @escaping (Bool) -> Void) {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: json, options: [])

        URLSession.shared.dataTask(with: req) { _, resp, err in
            if let http = resp as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               err == nil { completion(true) } else { completion(false) }
        }.resume()
    }
}