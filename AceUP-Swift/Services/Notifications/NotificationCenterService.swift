//
//  NotificationCenterService.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 18/10/25.
//

import Foundation
import UserNotifications
extension NotificationCenterService: NotificationScheduling {}


final class NotificationCenterService: NSObject, ObservableObject {
    static let shared = NotificationCenterService()
    private override init() {}

    // Útil si usas el id en cancelaciones
    private func requestId(for assignmentId: String) -> String { "dueSoon-\(assignmentId)" }

    /// Programa una notificación 3h antes. En DEBUG: 10s para probar.
    func scheduleDueSoonNotification(
        id: String,
        title: String,
        courseName: String?,
        dueDate: Date,
        status: AssignmentStatus
    ) {
        // Solo avisamos si aún no está completada/cancelada y la fecha es futura
        guard status != .completed, status != .cancelled, dueDate > Date() else {
            cancelDueSoonNotification(id: id)
            return
        }

        //let fire = dueDate.addingTimeInterval(-3*3600)
        #if DEBUG
        let seconds: TimeInterval = 10   // ← prueba rápida
        #else
        //let seconds = max(fire.timeIntervalSinceNow, 10)
        #endif

        let content = UNMutableNotificationContent()
        content.title = "Entrega en 3 horas"
        let hora = dueDate.formatted(date: .omitted, time: .shortened)
        let materia = (courseName?.isEmpty == false) ? " — \(courseName!)" : ""
        content.body = "“\(title)”\(materia) vence hoy a las \(hora)."
        content.sound = .default

        // Agrupación por día (opcional, útil si hay varias tareas el mismo día)
        content.threadIdentifier = dueDate.formatted(date: .complete, time: .omitted)

        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 0.9
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let req = UNNotificationRequest(identifier: requestId(for: id), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    func cancelDueSoonNotification(id: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [requestId(for: id)])
    }
}

// MARK: - Delegate (solo presentación en foreground)
extension NotificationCenterService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent n: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
