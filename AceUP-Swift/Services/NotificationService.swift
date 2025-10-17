import Foundation
import UserNotifications

enum NotificationService {

    static let lastActivityKey = "lastActivityTs"

    // Pídelo una vez en el arranque de la app (ver abajo)
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    // Utilidad genérica
    static func schedule(id: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date),
            repeats: false
        )

        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    static func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
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

    // MARK: –– Tipo 2B: “Pendientes de hoy” (recordatorio 18:00)
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
}