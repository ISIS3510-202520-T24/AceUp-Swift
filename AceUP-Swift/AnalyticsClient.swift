// AnalyticsClient.swift
import Foundation
import FirebaseAnalytics

enum AnalyticsClient {

    static func setUserID(_ uid: String?) {
        FirebaseAnalytics.Analytics.setUserID(uid)
    }

    static func logEvent(_ name: String, parameters: [String: NSObject]?) {
        FirebaseAnalytics.Analytics.logEvent(name, parameters: parameters)
    }

    // Enviado cuando se marca una tarea como completada (TodayView)
    static func sendAssignmentCompleted(assignmentId: String, courseId: String) {
        logEvent("assignment_completed", parameters: [
            "assignment_id": assignmentId as NSString,
            "course_id": courseId as NSString,
            "source": "ios_app" as NSString
        ])
        // También actualiza el timestamp local para la métrica “días desde último progreso”
        LastProgress.shared.update()
    }

    // Métrica: días desde el último progreso
    static func fetchDaysSinceLastProgress() -> Int? {
        LastProgress.shared.daysSinceLast()
    }
}
