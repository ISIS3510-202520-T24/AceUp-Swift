import Foundation
import UserNotifications
import FirebaseAnalytics

enum NotificationService {

    static let lastActivityKey = "lastActivityTs"
    private static var lastNotificationTime: [String: Date] = [:]

    // Request notification authorization
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if !granted {
                print("Notification permission denied")
            }
        }
    }

    // Utilidad genérica con debouncing
    static func schedule(id: String, title: String, body: String, date: Date) {
        // Debouncing: prevent scheduling same notification ID within 1 second
        let now = Date()
        if let lastTime = lastNotificationTime[id], now.timeIntervalSince(lastTime) < 1.0 {
            return
        }
        lastNotificationTime[id] = now
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date),
            repeats: false
        )

        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("Scheduled notification '\(id)' for \(date)")
            }
        }
    }

    static func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        // Clean up debouncing tracker
        lastNotificationTime.removeValue(forKey: id)
    }
    
    // Utility functions
    static func checkAuthorizationStatus(completion: @escaping (String) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    completion("Not determined - needs permission request")
                case .denied:
                    completion("Denied - go to Settings to enable")
                case .authorized:
                    completion("Authorized")
                case .provisional:
                    completion("Provisional")
                case .ephemeral:
                    completion("Ephemeral")
                @unknown default:
                    completion("Unknown status")
                }
            }
        }
    }
    
    static func checkPendingNotifications(completion: @escaping ([String]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                let ids = requests.map { "\($0.identifier): \($0.trigger?.debugDescription ?? "no trigger")" }
                completion(ids)
            }
        }
    }

    // MARK: –– Tipo 2A: “Stale activity” (días sin actualizar nota o completar)
    static func scheduleStaleUpdateReminderIfNeeded(thresholdDays: Int = 3) {
        let last = UserDefaults.standard.object(forKey: lastActivityKey) as? Date
        guard let last else { return } // si nunca hubo actividad, no molestes aún

        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        guard days >= thresholdDays else {
            cancel(id: "stale_update_reminder")
            return
        }

        // Programa para hoy 10:00 (o en 10 min si ya pasó)
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

        // MARK: –– Tipo 2B: "Pendientes de hoy" (recordatorio 18:00)
    static func scheduleTodayPendingReminderIfNeeded(pendingCount: Int) {
        let id = "today_pending_6pm"
        if pendingCount <= 0 {
            cancel(id: id)
            return
        }

        // hoy 18:00 (o 10 min si ya pasó)
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
    
    // MARK: –– BQ 2.1: "Highest weight pending assignment reminder"
    static func scheduleHighestWeightAssignmentReminder(assignment: Assignment) {
        let id = "highest_weight_assignment_reminder"
        
        // Cancel any existing reminder
        cancel(id: id)
        
        // Calculate when to remind based on assignment due date and weight
        let daysUntilDue = assignment.daysUntilDue
        let weight = assignment.weight
        
        // More important assignments (higher weight) get earlier reminders
        // Critical assignments (weight >= 0.3) get 3-day advance notice
        // High weight assignments (weight >= 0.2) get 2-day advance notice  
        // Medium weight assignments (weight >= 0.1) get 1-day advance notice
        let reminderDays: Int
        if weight >= 0.3 {
            reminderDays = min(3, max(1, daysUntilDue - 1))
        } else if weight >= 0.2 {
            reminderDays = min(2, max(1, daysUntilDue - 1))
        } else {
            reminderDays = min(1, max(0, daysUntilDue))
        }
        
        // Only schedule if we have time to remind
        guard reminderDays > 0 || daysUntilDue >= 0 else { return }
        
        // Calculate fire date: either the calculated reminder days from now, or if urgent, 2 hours from now
        let fireDate: Date
        if daysUntilDue <= 1 && weight >= 0.2 {
            // For urgent high-weight assignments, remind in 2 hours
            fireDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        } else {
            // For planned reminders, remind at 9 AM on the calculated day
            let targetDate = Calendar.current.date(byAdding: .day, value: -reminderDays, to: assignment.dueDate) ?? Date()
            fireDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: targetDate) ?? targetDate
        }
        
        // Don't schedule notifications in the past
        guard fireDate > Date() else { 
            print("Notification not scheduled - fire date is in the past: \(fireDate)")
            return 
        }
        
        print("Scheduling notification for \(fireDate) (in \(fireDate.timeIntervalSinceNow) seconds)")
        
        let weightPercentage = Int(weight * 100)
        let urgencyText = daysUntilDue <= 1 ? "urgent" : "important"
        
        let title = "High Priority Assignment"
        let body = "Your \(urgencyText) assignment '\(assignment.title)' (\(weightPercentage)% of grade) is due in \(daysUntilDue) day\(daysUntilDue == 1 ? "" : "s"). Don't let this high-impact task slip!"
        
        schedule(id: id, title: title, body: body, date: fireDate)
    }
}

extension NotificationService {
    /// Programa una notificación local si han pasado `threshold` días desde la última actividad.
    /// Recibe `daysSince` (calculado por tu capa de analytics) y evita duplicados con una ventana de enfriamiento.
    static func scheduleInactivityReminderIfNeeded(daysSince: Int, threshold: Int = 3) {
        guard daysSince >= threshold else { return }

        // Anti-spam: evita enviar más de 1 notificación de inactividad en 6 horas
        let cooldownKey = "inactivity"
        let now = Date()
        if let last = lastNotificationTime[cooldownKey], now.timeIntervalSince(last) < 6 * 60 * 60 {
            return
        }

        let title = "Time to update your progress"
        let body  = "It's been \(daysSince) days since your last grade update or completed assignment."

        // Dispara en ~5 segundos (visible de inmediato para el usuario)
        schedule(
            id: "inactivity_reminder",
            title: title,
            body: body,
            date: Date().addingTimeInterval(5)
        )

        lastNotificationTime[cooldownKey] = now

        // Evento para GA4/BQ (vía tu colector) – útil para auditoría/embudos
        AnalyticsClient.shared.logEvent(
            AnalyticsEventType.smartReminderTriggered.rawValue,
            parameters: [
                "type": "inactivity" as NSString,
                "days_since": NSNumber(value: daysSince),
                "source": "ios_app" as NSString
            ]
        )
    }
}
