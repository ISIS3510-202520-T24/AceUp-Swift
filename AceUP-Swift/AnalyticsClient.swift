// AnalyticsClient.swift
import Foundation
import FirebaseAnalytics

/// Enhanced Analytics Client supporting both Firebase Analytics and custom insights analytics
final class AnalyticsClient: ObservableObject {
    static let shared = AnalyticsClient()
    
    private init() {}
    
    // MARK: - Firebase Analytics Methods
    
    func setUserID(_ uid: String?) {
        FirebaseAnalytics.Analytics.setUserID(uid)
        
        // Also set user for custom analytics
        if let uid = uid {
            AppAnalytics.shared.identify(userId: uid)
        }
    }

    func logEvent(_ name: String, parameters: [String: NSObject]?) {
        FirebaseAnalytics.Analytics.logEvent(name, parameters: parameters)
    }

    // Enviado cuando se marca una tarea como completada (TodayView)
    func sendAssignmentCompleted(assignmentId: String, courseId: String) {
        logEvent("assignment_completed", parameters: [
            "assignment_id": assignmentId as NSString,
            "course_id": courseId as NSString,
            "source": "ios_app" as NSString
        ])
        // También actualiza el timestamp local para la métrica "días desde último progreso"
        LastProgress.shared.update()
    }

    // Métrica: días desde el último progreso
    func fetchDaysSinceLastProgress() -> Int? {
        LastProgress.shared.daysSinceLast()
    }
    
    // MARK: - Enhanced Analytics for Insights
    
    /// Track analytics events with custom properties
    func track(event: AnalyticsEventType, properties: [String: Any] = [:]) async {
        // Send to Firebase
        let firebaseParams = properties.compactMapValues { value -> NSObject? in
            switch value {
            case let string as String:
                return string as NSString
            case let int as Int:
                return NSNumber(value: int)
            case let double as Double:
                return NSNumber(value: double)
            case let bool as Bool:
                return NSNumber(value: bool)
            default:
                return "\(value)" as NSString
            }
        }
        
        logEvent(event.rawValue, parameters: firebaseParams)
        
        // Send to custom analytics pipeline
        AppAnalytics.shared.track(event.rawValue, props: properties)
        
        // Update progress tracking for relevant events
        if event.updatesProgress {
            LastProgress.shared.update()
        }
    }
    
    /// Convenience method for tracking insights generation
    func trackInsightsGenerated(insights: [String: Any]) async {
        await track(event: .todaysInsightsGenerated, properties: insights)
    }
    
    /// Convenience method for tracking progress analysis
    func trackProgressAnalysis(completed: Int, pending: Int, total: Int, rate: Double) async {
        await track(event: .todaysProgressAnalyzed, properties: [
            "completed_tasks": completed,
            "pending_tasks": pending,
            "total_tasks": total,
            "completion_rate": rate,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
}

// MARK: - Analytics Event Types

enum AnalyticsEventType: String, CaseIterable {
    // Existing events
    case assignmentCompleted = "assignment_completed"
    case gradeRecorded = "grade_recorded"
    
    // Insights analytics events
    case todaysInsightsGenerated = "todays_insights_generated"
    case todaysProgressAnalyzed = "todays_progress_analyzed"
    case highPriorityTaskIdentified = "high_priority_task_identified"
    case daysSinceLastActivityCalculated = "days_since_last_activity_calculated"
    case workloadAnalysisCompleted = "workload_analysis_completed"
    case motivationalMessageShown = "motivational_message_shown"
    case productivityScoreCalculated = "productivity_score_calculated"
    case smartReminderTriggered = "smart_reminder_triggered"
    case collaborationOpportunityFound = "collaboration_opportunity_found"
    
    // User interaction events
    case insightCardTapped = "insight_card_tapped"
    case reminderActionTaken = "reminder_action_taken"
    case motivationalMessageDismissed = "motivational_message_dismissed"
    
    var updatesProgress: Bool {
        switch self {
        case .assignmentCompleted, .gradeRecorded:
            return true
        default:
            return false
        }
    }
}

// MARK: - Legacy Support

/// Legacy enum for backward compatibility
enum LegacyAnalyticsClient {
    static func setUserID(_ uid: String?) {
        AnalyticsClient.shared.setUserID(uid)
    }

    static func logEvent(_ name: String, parameters: [String: NSObject]?) {
        AnalyticsClient.shared.logEvent(name, parameters: parameters)
    }

    static func sendAssignmentCompleted(assignmentId: String, courseId: String) {
        AnalyticsClient.shared.sendAssignmentCompleted(assignmentId: assignmentId, courseId: courseId)
    }

    static func fetchDaysSinceLastProgress() -> Int? {
        AnalyticsClient.shared.fetchDaysSinceLastProgress()
    }
}