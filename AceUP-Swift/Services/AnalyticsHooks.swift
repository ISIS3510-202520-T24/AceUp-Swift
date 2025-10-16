import Foundation
import FirebaseAnalytics

enum AnalyticsHooks {

    // Cuando marques una tarea como completada
    static func onAssignmentCompleted(assignmentId: String, courseId: String) {
        let gaParams: [String: NSObject] = [
            "assignment_id": assignmentId as NSString,
            "course_id": courseId as NSString,
            "source": "ios_app" as NSString
        ]
        Analytics.logEvent("assignment_completed", parameters: gaParams)

        AppAnalytics.shared.track("assignment_completed", props: [
            "assignment_id": assignmentId,
            "course_id": courseId,
            "source": "ios_app"
        ])
    }

    // Cuando actualices la nota (grade puede ser nil si aún no hay nota)
    static func onGradeUpdated(assignmentId: String, courseId: String, grade: Double?) {
        var gaParams: [String: NSObject] = [
            "assignment_id": assignmentId as NSString,
            "course_id": courseId as NSString,
            "source": "ios_app" as NSString
        ]
        if let g = grade {
            gaParams["grade"] = NSNumber(value: g)
        }
        Analytics.logEvent("grade_recorded", parameters: gaParams)

        var props: [String: Any?] = [
            "assignment_id": assignmentId,
            "course_id": courseId,
            "source": "ios_app"
        ]
        props["grade"] = grade
        AppAnalytics.shared.track("grade_recorded", props: props)
    }

    // (Opcional) alias más “verbo-objeto”, por si los prefieres
    static func trackAssignmentCompleted(assignmentId: String, courseId: String) {
        onAssignmentCompleted(assignmentId: assignmentId, courseId: courseId)
    }

    static func trackGradeRecorded(assignmentId: String, courseId: String, grade: Double?) {
        onGradeUpdated(assignmentId: assignmentId, courseId: courseId, grade: grade)
    }
}
