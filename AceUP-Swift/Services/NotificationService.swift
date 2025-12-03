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
    static func scheduleInactivityReminderIfNeeded(
        daysSince: Int,
        threshold: Int = 3,
        nextAssignment: Assignment? = nil,
        daysLeft: Int? = nil,
        fireAfter seconds: TimeInterval = 5,
        force: Bool = false
    ) {
        let cooldownKey = "inactivity"
        let now = Date()

        // Cooldown de 1h (solo si NO forzamos)
        if !force, let last = lastNotificationTime[cooldownKey],
           now.timeIntervalSince(last) < 3600 {
            print("[InactivityReminder] Skip by cooldown")
            return
        }

        // Umbral (solo si NO forzamos)
        if !force && daysSince < threshold {
            print("[InactivityReminder] Skip by threshold daysSince(\(daysSince)) < \(threshold)")
            return
        }

        let plural = (daysSince == 1) ? "" : "s"
        let title = "Time to Update Your Progress"
        let body  = "It's been \(daysSince) day\(plural) since you last updated your assignments."

        // Disparo claro en X segundos (evita que quede “en el pasado”)
        let fireDate = now.addingTimeInterval(seconds)

        schedule(
            id: "\(cooldownKey)_\(Int(now.timeIntervalSince1970))",
            title: title,
            body: body,
            date: fireDate
        )

        lastNotificationTime[cooldownKey] = now

        // Analytics: solo claves válidas en este scope
        var params: [String: NSObject] = [
            "type": "inactivity" as NSString,
            "days_since": NSNumber(value: daysSince),
            "source": "ios_app" as NSString
        ]
        if let daysLeft { params["days_left"] = NSNumber(value: daysLeft) }
        if let a = nextAssignment {
            params["assignment_id"] = a.id as NSString
            params["course_id"]     = a.courseId as NSString
        }

        AnalyticsClient.shared.logEvent(
            AnalyticsEventType.smartReminderTriggered.rawValue,
            parameters: params
        )
    }
    
    // Cuantos días faltan para la próxima tarea?
    static func daysUntilNextImportantEvent(from assignments: [Assignment], weightThreshold: Double) -> (assignment: Assignment, daysLeft: Int)? {
        let now = Date()
        let calendar = Calendar.current
        
        // Filtrar asignaciones por peso y fecha de vencimiento
        let filtered = assignments.filter { assignment in
            assignment.weight >= weightThreshold && assignment.dueDate > now
        }
        
        // Encontrar la asignación más cercana
        guard let next = filtered.min(by: { $0.dueDate < $1.dueDate }) else {
            return nil
        }
        
        // Calcular los días restantes
        let daysLeft = calendar.dateComponents([.day], from: now, to: next.dueDate).day ?? 0
        
        return (assignment: next, daysLeft: daysLeft)
    }
    
    static func scheduleDaysUntilNextDueAssignment(
        assignments: [Assignment],
        cooldownHours: Double = 12.0
    ) {
        let cooldownKey = "next_due_assignment_days"
        let now = Date()
        if let last = lastNotificationTime[cooldownKey],
           now.timeIntervalSince(last) < (cooldownHours * 3600.0) {
            return
        }

        guard let result = daysUntilNextDueAssignment(from: assignments) else {
            return
        }

        let a = result.assignment
        let daysLeft = result.daysLeft

        let title: String
        let body: String
        if daysLeft <= 0 {
            title = "Assignment due today"
            body = "“\(a.title)” assignment it´s for(\(a.formattedDueDate))."
        } else if daysLeft == 1 {
            title = "1 day left for your next assignment"
            body = "“\(a.title)” assignment it´s for (\(a.formattedDueDate))."
        } else {
            title = "\(daysLeft) days left for your next assignment"
            body = "“\(a.title)” of \(a.courseName) it´s for \(a.formattedDueDate)."
        }

        let fireDate = Calendar.current.date(byAdding: .second, value: 10, to: now) ?? now

        schedule(
            id: cooldownKey,
            title: title,
            body: body,
            date: fireDate
        )

        lastNotificationTime[cooldownKey] = now

        AnalyticsClient.shared.logEvent(
            AnalyticsEventType.smartReminderTriggered.rawValue,
            parameters: [
                "type": "days_until_next_due_assignment" as NSString,
                "days_left": NSNumber(value: daysLeft),
                "assignment_id": a.id as NSString,
                "course_id": a.courseId as NSString,
                "source": "ios_app" as NSString
            ]
        )
    }

    @discardableResult
    static func daysUntilNextDueAssignment(
        from assignments: [Assignment]
    ) -> (assignment: Assignment, daysLeft: Int)? {
        let candidates = assignments.filter { a in
            (a.status == .pending || a.status == .inProgress) && !a.isOverdue
        }
        guard let next = candidates.sorted(by: { $0.dueDate < $1.dueDate }).first else {
            return nil
        }
        let daysLeft = max(0, next.daysUntilDue)
        return (next, daysLeft)
    }
    
    // MARK: - BQ 2.2: Daily Progress Notification
    static func scheduleTodayProgressNotification(todaysAssignments: [Assignment]) {
        let id = "today_progress_bq_2_2"
        
        // Cancel any existing notification
        cancel(id: id)
        
        let todaysTotal = todaysAssignments.count
        let todaysCompleted = todaysAssignments.filter { $0.status == .completed }.count
        let todaysPending = todaysTotal - todaysCompleted
        
        let title: String
        let body: String
        
        if todaysTotal == 0 {
            title = "No Assignments Due Today"
            body = "You're all caught up! Great job staying ahead. 🎉"
        } else if todaysCompleted == todaysTotal {
            title = "All Tasks Completed! 🎉"
            body = "You finished all \(todaysTotal) assignment\(todaysTotal == 1 ? "" : "s") due today. Amazing work!"
        } else {
            let completionPercentage = Int((Double(todaysCompleted) / Double(todaysTotal)) * 100)
            title = "Today's Progress: \(todaysCompleted)/\(todaysTotal) Complete"
            body = "You've completed \(completionPercentage)% of today's tasks. \(todaysPending) assignment\(todaysPending == 1 ? "" : "s") remaining. Keep going! 💪"
        }
        
        // Schedule notification for 3 seconds from now (for testing)
        let fireDate = Calendar.current.date(byAdding: .second, value: 3, to: Date()) ?? Date()
        
        schedule(
            id: id,
            title: title,
            body: body,
            date: fireDate
        )
        
        // Track analytics
        AnalyticsClient.shared.logEvent(
            AnalyticsEventType.smartReminderTriggered.rawValue,
            parameters: [
                "type": "daily_progress_bq_2_2" as NSString,
                "total_tasks": NSNumber(value: todaysTotal),
                "completed_tasks": NSNumber(value: todaysCompleted),
                "pending_tasks": NSNumber(value: todaysPending),
                "completion_percentage": NSNumber(value: todaysTotal > 0 ? (todaysCompleted * 100 / todaysTotal) : 0),
                "source": "ios_app" as NSString
            ]
        )
    }
}
