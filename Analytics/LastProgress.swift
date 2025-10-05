import Foundation

extension Notification.Name {
    static let lastProgressUpdated = Notification.Name("lastProgressUpdated")
}

// Guarda el último timestamp en UserDefaults y calcula días transcurridos
final class LastProgress {
    static let shared = LastProgress()
    private init() {}
    
    private let key = "last_progress_at_epoch"

    func update(date: Date = Date()) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key)
        NotificationCenter.default.post(name: .lastProgressUpdated, object: nil)
    }

    /// Retorna nil si nunca hubo progreso
    func daysSinceNow() -> Int? {
        let t = UserDefaults.standard.double(forKey: key)
        guard t > 0 else { return nil }
        let now = Date().timeIntervalSince1970
        let days = Int( (now - t) / 86_400.0 )
        return max(days, 0)
    }
}