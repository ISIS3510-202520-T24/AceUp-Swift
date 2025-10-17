import Foundation
import FirebaseAnalytics

enum AnalyticsHooks {

    // MARK: - Assignment Completed (grade opcional)
    static func onAssignmentCompleted(assignmentId: String, courseId: String, grade: Double?) {
        var gaParams: [String: Any] = [
            "assignment_id": assignmentId,
            "course_id": courseId,
            "source": "ios_app"
        ]
        if let g = grade { gaParams["grade"] = g }
        Analytics.logEvent("assignment_completed", parameters: gaParams)

        var props: [String: Any] = [
            "assignment_id": assignmentId,
            "course_id": courseId,
            "source": "ios_app"
        ]
        if let g = grade { props["grade"] = g }
        AppAnalytics.shared.track("assignment_completed", props: props)

        //Notificación
        UserDefaults.standard.set(Date(), forKey: NotificationService.lastActivityKey)
    }

    // MARK: - Grade Updated (grade opcional)
    static func onGradeUpdated(assignmentId: String, courseId: String, grade: Double?) {
        var gaParams: [String: Any] = [
            "assignment_id": assignmentId,
            "course_id": courseId,
            "source": "ios_app"
        ]
        if let g = grade { gaParams["grade"] = g }
        Analytics.logEvent("grade_recorded", parameters: gaParams)

        var props: [String: Any] = [
            "assignment_id": assignmentId,
            "course_id": courseId,
            "source": "ios_app"
        ]
        if let g = grade { props["grade"] = g }
        AppAnalytics.shared.track("grade_recorded", props: props)

        // Notificación
        UserDefaults.standard.set(Date(), forKey: NotificationService.lastActivityKey)
    }

    // Aliases
    static func trackAssignmentCompleted(assignmentId: String, courseId: String, grade: Double?) {
        onAssignmentCompleted(assignmentId: assignmentId, courseId: courseId, grade: grade)
    }

    static func trackGradeRecorded(assignmentId: String, courseId: String, grade: Double?) {
        onGradeUpdated(assignmentId: assignmentId, courseId: courseId, grade: grade)
    }
}
