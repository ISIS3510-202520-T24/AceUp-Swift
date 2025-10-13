import Foundation
import FirebaseAnalytics

enum AnalyticsHooks {

    static func onAssignmentCompleted(assignmentId: String, courseId: String) {
        FirebaseAnalytics.Analytics.logEvent("assignment_completed", parameters: [
            "assignment_id": assignmentId as NSObject,
            "course_id": courseId as NSObject,
            "source": "ios_app" as NSObject
        ])
    }

    static func onGradeUpdated(assignmentId: String, courseId: String) {
        FirebaseAnalytics.Analytics.logEvent("grade_updated", parameters: [
            "assignment_id": assignmentId as NSObject,
            "course_id": courseId as NSObject,
            "source": "ios_app" as NSObject
        ])
    }
}