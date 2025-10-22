import Foundation
import UserNotifications
import FirebaseAnalytics

enum NotificationService {

    static let lastActivityKey = "lastActivityTs"
    private static var lastNotificationTime: [String: Date] = [:]

    // MARK: - Permisos
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if !granted { print("Notification permission denied") }
        }
    }

    static func checkAuthorizationStatus(completion: @escaping (String) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined: completion("Not determined - needs permission request")
                case .denied:        completion("Denied - go to Settings to enable")
                case .authorized:    completion("Authorized")
                case .provisional:   completion("Provisional")
                case .ephemeral:     completion("Ephemeral")
                @unknown default:    completion("Unknown status")
                }
            }
        }
    }

    // MARK: - Utilidades de scheduling
    static func schedule(id: String, title: String, body: String, date: Date) {
        // Debounce por id (1s)
        let now = Date()
        if let lastTime = lastNotificationTime[id], now.timeIntervalSince(lastTime) < 1.0 { return }
        lastNotificationTime[id] = now

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }

        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(req) { error in
            if let error = error {
                print("Failed to schedule notification (\(id)): \(error.localizedDescription)")
            } else {
                print("Scheduled notification '\(id)' for \(date)")
            }
        }
    }

    static func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        lastNotificationTime.removeValue(forKey: id)
    }

    static func checkPendingNotifications(completion: @escaping ([String]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                let ids = requests.map { "\($0.identifier): \($0.trigger?.debugDescription ?? "no trigger")" }
                completion(ids)
            }
        }
    }

    // MARK: –– Tipo 2A: “Stale activity”
    static func scheduleStaleUpdateReminderIfNeeded(thresholdDays: Int = 3) {
        let last = UserDefaults.standard.object(forKey: lastActivityKey) as? Date
        guard let last else { return }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        guard days >= thresholdDays else {
            cancel(id: "stale_update_reminder")
            return
        }

        var fire = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        if fire < Date() { fire = Calendar.current.date(byAdding: .minute, value: 10, to: Date())! }

        cancel(id: "stale_update_reminder")
        schedule(
            id: "stale_update_reminder",
            title: "¿Hace rato no actualizas?",
            body: "Han pasado \(days) días sin registrar notas o marcar tareas. ¿Quieres ponerte al día?",
            date: fire
        )
    }

    // MARK: –– Tipo 2B: "Pendientes de hoy" (18:00)
    static func scheduleTodayPendingReminderIfNeeded(pendingCount: Int) {
        let id = "today_pending_6pm"
        if pendingCount <= 0 {
            cancel(id: id)
            return
        }

        var fire = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!
        if fire < Date() { fire = Calendar.current.date(byAdding: .minute, value: 10, to: Date())! }

        cancel(id: id)
        schedule(
            id: id,
            title: "\(pendingCount) Assignments left for today",
            body: "You can still complete them. Keep it up!",
            date: fire
        )
    }

    // MARK: –– BQ 2.1 (se deja tal cual lo tenías)
    static func scheduleHighestWeightAssignmentReminder(assignment: Assignment) {
        let id = "highest_weight_assignment_reminder"
        cancel(id: id)

        let daysUntilDue = assignment.daysUntilDue
        let weight = assignment.weight

        let reminderDays: Int
        if weight >= 0.3 {
            reminderDays = min(3, max(1, daysUntilDue - 1))
        } else if weight >= 0.2 {
            reminderDays = min(2, max(1, daysUntilDue - 1))
        } else {
            reminderDays = min(1, max(0, daysUntilDue))
        }

        guard reminderDays > 0 || daysUntilDue >= 0 else { return }

        let fireDate: Date
        if daysUntilDue <= 1 && weight >= 0.2 {
            fireDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        } else {
            let targetDate = Calendar.current.date(byAdding: .day, value: -reminderDays, to: assignment.dueDate) ?? Date()
            fireDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: targetDate) ?? targetDate
        }

        guard fireDate > Date() else {
            print("Notification not scheduled - fire date is in the past: \(fireDate)")
            return
        }

        let weightPercentage = Int(weight * 100)
        let urgencyText = daysUntilDue <= 1 ? "urgent" : "important"
        let title = "High Priority Assignment"
        let body = "Your \(urgencyText) assignment '\(assignment.title)' (\(weightPercentage)% of grade) is due in \(daysUntilDue) day\(daysUntilDue == 1 ? "" : "s")."

        schedule(id: id, title: title, body: body, date: fireDate)
    }
}

// MARK: - Extensiones (eventos y ≤3h)
extension NotificationService {

    static func scheduleInactivityReminderIfNeeded(daysSince: Int, threshold: Int = 3) {
        guard daysSince >= threshold else { return }

        let cooldownKey = "inactivity"
        let now = Date()
        if let last = lastNotificationTime[cooldownKey], now.timeIntervalSince(last) < 6 * 60 * 60 {
            return
        }

        schedule(
            id: "inactivity_reminder",
            title: "Time to update your progress",
            body: "It's been \(daysSince) days since your last grade update or completed assignment.",
            date: Date().addingTimeInterval(5)
        )
        lastNotificationTime[cooldownKey] = now

        AnalyticsClient.shared.logEvent(
            AnalyticsEventType.smartReminderTriggered.rawValue,
            parameters: [
                "type": "inactivity" as NSString,
                "days_since": NSNumber(value: daysSince),
                "source": "ios_app" as NSString
            ]
        )
    }

    /// Notifica en ~5s si hay assignments con dueDate en ≤ 3 horas y status != .completed
    @MainActor
    static func notifyAssignmentsDueWithin3Hours(using repo: AssignmentRepositoryProtocol) async {
        // Permisos (si hace falta, solicita)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus != .authorized {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                guard granted else {
                    print("🔐 Notifs denied")
                    return
                }
            } catch {
                print("🔐 requestAuthorization error: \(error)")
                return
            }
        }

        do {
            let now = Date()
            let upper = Calendar.current.date(byAdding: .hour, value: 3, to: now) ?? now

            // Usa SOLO el protocolo: trae todo y filtra aquí.
            let all = try await repo.getAllAssignments()

            let dueSoon = all
                .filter { a in
                    a.status != .completed &&
                    a.dueDate >= now &&
                    a.dueDate <= upper
                }
                .sorted(by: { $0.dueDate < $1.dueDate })

            print("📚 dueSoon (<3h) count:", dueSoon.count)

            let id = "assignments.dueWithin3h.summary"
            guard !dueSoon.isEmpty else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
                return
            }

            let titles = dueSoon.map(\.title)
            let preview = titles.prefix(3).joined(separator: " • ")
            let remaining = max(0, titles.count - 3)
            let body = remaining > 0 ? "\(preview) • +\(remaining) más" : preview

            cancel(id: id) // evita duplicados
            let fire = now.addingTimeInterval(5)
            schedule(id: id,
                     title: "Tareas que vencen en ≤ 3 horas (\(dueSoon.count))",
                     body: body.isEmpty ? "Revisa tus entregas próximas y marca done si ya las hiciste." : body,
                     date: fire)

            print("⏰ summary scheduled at:", fire)

        } catch {
            print("❌ notifyAssignmentsDueWithin3Hours error:", error.localizedDescription)
        }
    }

    /// Test: dispara una notificación en 10s
    @MainActor
    static func debugFireIn10Seconds() async {
        let center = UNUserNotificationCenter.current()
        let s = await center.notificationSettings()
        if s.authorizationStatus != .authorized {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { print("⛔️ Sin permiso"); return }
        }
        let fire = Date().addingTimeInterval(10)
        schedule(id: "test_10s",
                 title: "Test 10s",
                 body: "Si ves esto, las notificaciones funcionan",
                 date: fire)
        print("🧪 Programada test_10s para:", fire)
    }
}

