//
//  TaskCreationAnalytics.swift
//  AceUP-Swift
//
//  Business Question 3.4: Would adding a "quick task creation" feature (e.g., one-tap tasks,
//  voice input, or templates) reduce the effort students spend creating tasks and increase adoption?
//
//  Implementation: Tracks task creation sessions to measure efficiency and adoption
//  Data flows: iOS App → Firestore → BigQuery (via Cloud Function)
//
//  Created by Ángel Farfán Arcila on 2/12/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAnalytics
import FirebaseAuth

/// Tracks task creation sessions for BQ 3.4 analytics
/// Measures effectiveness of quick creation features vs. standard flow
@MainActor
class TaskCreationAnalytics: ObservableObject {
    
    // MARK: - Singleton
    static let shared = TaskCreationAnalytics()
    
    // MARK: - Properties
    private let db = Firestore.firestore()
    private var activeCreationSessions: [String: TaskCreationSession] = [:]
    
    // MARK: - Creation Methods
    enum CreationMethod: String, Codable {
        case standard = "standard"
        case quickCreate = "quick_create"
        case voiceInput = "voice_input"
        case template = "template"
        case importSyllabus = "import"
        
        var displayName: String {
            switch self {
            case .standard: return "Standard Creation"
            case .quickCreate: return "Quick Create"
            case .voiceInput: return "Voice Input"
            case .template: return "Template"
            case .importSyllabus: return "Import"
            }
        }
    }
    
    // MARK: - Task Types
    enum TaskType: String, Codable {
        case assignment = "assignment"
        case exam = "exam"
        case reminder = "reminder"
        case personal = "personal"
        
        var displayName: String {
            switch self {
            case .assignment: return "Assignment"
            case .exam: return "Exam"
            case .reminder: return "Reminder"
            case .personal: return "Personal"
            }
        }
    }
    
    // MARK: - Entry Points
    enum EntryPoint: String, Codable {
        case fab = "fab"
        case todayView = "today_view"
        case assignmentsView = "assignments_view"
        case quickAction = "quick_action"
        case widget = "widget"
        case contextMenu = "context_menu"
        
        var displayName: String {
            switch self {
            case .fab: return "FAB Button"
            case .todayView: return "Today View"
            case .assignmentsView: return "Assignments View"
            case .quickAction: return "Quick Action"
            case .widget: return "Widget"
            case .contextMenu: return "Context Menu"
            }
        }
    }
    
    // MARK: - Task Creation Session Model
    struct TaskCreationSession: Codable {
        let sessionId: String
        let userId: String
        let creationMethod: CreationMethod
        let startTimestamp: Date
        var endTimestamp: Date?
        var durationSeconds: Double?
        var completed: Bool
        var abandoned: Bool
        var interactionCount: Int
        var fieldsCompleted: [String]
        var fieldCount: Int
        var taskType: TaskType?
        var hasSubtasks: Bool
        var subtaskCount: Int
        var usedTemplate: Bool
        var templateId: String?
        var validationErrors: Int
        var retryCount: Int
        var platform: String
        var appVersion: String
        var entryPoint: EntryPoint?
        var satisfactionImplicit: Double?
        
        init(
            sessionId: String = UUID().uuidString,
            userId: String,
            creationMethod: CreationMethod,
            startTimestamp: Date = Date(),
            platform: String = "iOS",
            appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            entryPoint: EntryPoint? = nil
        ) {
            self.sessionId = sessionId
            self.userId = userId
            self.creationMethod = creationMethod
            self.startTimestamp = startTimestamp
            self.endTimestamp = nil
            self.durationSeconds = nil
            self.completed = false
            self.abandoned = false
            self.interactionCount = 0
            self.fieldsCompleted = []
            self.fieldCount = 0
            self.taskType = nil
            self.hasSubtasks = false
            self.subtaskCount = 0
            self.usedTemplate = false
            self.templateId = nil
            self.validationErrors = 0
            self.retryCount = 0
            self.platform = platform
            self.appVersion = appVersion
            self.entryPoint = entryPoint
            self.satisfactionImplicit = nil
        }
        
        mutating func complete(
            withFields fields: [String],
            taskType: TaskType? = nil,
            hasSubtasks: Bool = false,
            subtaskCount: Int = 0
        ) {
            self.endTimestamp = Date()
            self.durationSeconds = endTimestamp?.timeIntervalSince(startTimestamp)
            self.completed = true
            self.fieldsCompleted = fields
            self.fieldCount = fields.count
            self.taskType = taskType
            self.hasSubtasks = hasSubtasks
            self.subtaskCount = subtaskCount
            
            // Calculate implicit satisfaction based on behavior
            self.satisfactionImplicit = calculateImplicitSatisfaction()
        }
        
        mutating func abandon() {
            self.endTimestamp = Date()
            self.durationSeconds = endTimestamp?.timeIntervalSince(startTimestamp)
            self.abandoned = true
            self.satisfactionImplicit = 0.0 // Abandoned = low satisfaction
        }
        
        mutating func incrementInteraction() {
            self.interactionCount += 1
        }
        
        mutating func incrementValidationError() {
            self.validationErrors += 1
        }
        
        mutating func incrementRetry() {
            self.retryCount += 1
        }
        
        mutating func setTemplate(id: String) {
            self.usedTemplate = true
            self.templateId = id
        }
        
        /// Calculate implicit satisfaction score based on user behavior
        /// Range: 0.0 (poor) to 1.0 (excellent)
        private func calculateImplicitSatisfaction() -> Double {
            guard let duration = durationSeconds else { return 0.5 }
            
            var score = 1.0
            
            // Penalize for long duration (diminishing returns)
            if duration > 180 { // More than 3 minutes
                score -= 0.3
            } else if duration > 120 { // More than 2 minutes
                score -= 0.2
            } else if duration > 60 { // More than 1 minute
                score -= 0.1
            }
            
            // Penalize for many interactions (suggests confusion)
            if interactionCount > 20 {
                score -= 0.2
            } else if interactionCount > 15 {
                score -= 0.1
            }
            
            // Penalize for validation errors
            score -= Double(validationErrors) * 0.15
            
            // Penalize for retries
            score -= Double(retryCount) * 0.1
            
            // Bonus for completing with minimal friction
            if duration < 30 && validationErrors == 0 && interactionCount < 10 {
                score += 0.2
            }
            
            return max(0.0, min(1.0, score))
        }
    }
    
    // MARK: - Public Methods
    
    /// Start tracking a task creation session
    /// - Parameters:
    ///   - method: Creation method being used
    ///   - userId: User creating the task
    ///   - entryPoint: Where the user initiated creation
    /// - Returns: Session ID for tracking
    @discardableResult
    func startCreationSession(
        method: CreationMethod,
        userId: String,
        entryPoint: EntryPoint? = nil
    ) -> String {
        let session = TaskCreationSession(
            userId: userId,
            creationMethod: method,
            entryPoint: entryPoint
        )
        
        activeCreationSessions[session.sessionId] = session
        
        // Track event in Firebase Analytics
        Analytics.logEvent("task_creation_started", parameters: [
            "session_id": session.sessionId,
            "creation_method": method.rawValue,
            "entry_point": entryPoint?.rawValue ?? "unknown",
            "timestamp": ISO8601DateFormatter().string(from: session.startTimestamp),
            "platform": session.platform
        ])
        
        // Track in custom analytics pipeline
        Task { @MainActor in
            AppAnalytics.shared.track("task_creation_started", props: [
                "session_id": session.sessionId,
                "creation_method": method.rawValue,
                "entry_point": entryPoint?.rawValue ?? "unknown"
            ])
        }
        
        print("📊 [BQ 3.4] Started task creation: \(method.displayName) - \(session.sessionId)")
        
        return session.sessionId
    }
    
    /// Convenience method: Start session with auto-fetched userId
    @discardableResult
    func startCreationSession(
        method: CreationMethod,
        entryPoint: EntryPoint? = nil
    ) -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ [BQ 3.4] No authenticated user")
            return ""
        }
        return startCreationSession(method: method, userId: userId, entryPoint: entryPoint)
    }
    
    /// Track user interaction during creation
    /// - Parameter sessionId: Active session ID
    func trackInteraction(sessionId: String) {
        guard var session = activeCreationSessions[sessionId] else { return }
        
        session.incrementInteraction()
        activeCreationSessions[sessionId] = session
        
        print("📊 [BQ 3.4] Interaction tracked: Session \(sessionId) - Count: \(session.interactionCount)")
    }
    
    /// Track validation error during creation
    /// - Parameter sessionId: Active session ID
    func trackValidationError(sessionId: String) {
        guard var session = activeCreationSessions[sessionId] else { return }
        
        session.incrementValidationError()
        activeCreationSessions[sessionId] = session
        
        print("⚠️ [BQ 3.4] Validation error: Session \(sessionId) - Total: \(session.validationErrors)")
    }
    
    /// Track retry attempt during creation
    /// - Parameter sessionId: Active session ID
    func trackRetry(sessionId: String) {
        guard var session = activeCreationSessions[sessionId] else { return }
        
        session.incrementRetry()
        activeCreationSessions[sessionId] = session
        
        print("🔄 [BQ 3.4] Retry tracked: Session \(sessionId) - Count: \(session.retryCount)")
    }
    
    /// Set template usage for session
    /// - Parameters:
    ///   - sessionId: Active session ID
    ///   - templateId: Template being used
    func setTemplateUsage(sessionId: String, templateId: String) {
        guard var session = activeCreationSessions[sessionId] else { return }
        
        session.setTemplate(id: templateId)
        activeCreationSessions[sessionId] = session
        
        print("📋 [BQ 3.4] Template used: Session \(sessionId) - Template: \(templateId)")
    }
    
    /// Complete a task creation session successfully
    /// - Parameters:
    ///   - sessionId: Active session ID
    ///   - fieldsCompleted: List of fields that were filled
    ///   - taskType: Type of task created
    ///   - hasSubtasks: Whether subtasks were added
    ///   - subtaskCount: Number of subtasks
    func completeCreationSession(
        sessionId: String,
        fieldsCompleted: [String] = [],
        taskType: TaskType? = nil,
        hasSubtasks: Bool = false,
        subtaskCount: Int = 0
    ) {
        guard var session = activeCreationSessions[sessionId] else {
            print("⚠️ [BQ 3.4] No active session found for ID: \(sessionId)")
            return
        }
        
        session.complete(
            withFields: fieldsCompleted,
            taskType: taskType,
            hasSubtasks: hasSubtasks,
            subtaskCount: subtaskCount
        )
        
        // Track completion in Firebase Analytics
        Analytics.logEvent("task_creation_completed", parameters: [
            "session_id": session.sessionId,
            "creation_method": session.creationMethod.rawValue,
            "duration_seconds": session.durationSeconds ?? 0,
            "interaction_count": session.interactionCount,
            "field_count": session.fieldCount,
            "validation_errors": session.validationErrors,
            "satisfaction_score": session.satisfactionImplicit ?? 0.5,
            "timestamp": ISO8601DateFormatter().string(from: session.endTimestamp ?? Date())
        ])
        
        // Track in custom analytics pipeline
        Task { @MainActor in
            AppAnalytics.shared.track("task_creation_completed", props: [
                "session_id": session.sessionId,
                "creation_method": session.creationMethod.rawValue,
                "duration_seconds": session.durationSeconds ?? 0,
                "interaction_count": session.interactionCount,
                "fields_completed": fieldsCompleted,
                "satisfaction_score": session.satisfactionImplicit ?? 0.5
            ])
        }
        
        // Store in Firestore for BigQuery export
        Task { @MainActor in
            await storeSession(session)
        }
        
        // Remove from active sessions
        activeCreationSessions.removeValue(forKey: sessionId)
        
        print("✅ [BQ 3.4] Completed creation: \(session.creationMethod.displayName) - Duration: \(session.durationSeconds ?? 0)s - Satisfaction: \(session.satisfactionImplicit ?? 0.5)")
    }
    
    /// Abandon a task creation session
    /// - Parameter sessionId: Active session ID
    func abandonCreationSession(sessionId: String) {
        guard var session = activeCreationSessions[sessionId] else {
            print("⚠️ [BQ 3.4] No active session found for ID: \(sessionId)")
            return
        }
        
        session.abandon()
        
        // Track abandonment in Firebase Analytics
        Analytics.logEvent("task_creation_abandoned", parameters: [
            "session_id": session.sessionId,
            "creation_method": session.creationMethod.rawValue,
            "duration_seconds": session.durationSeconds ?? 0,
            "interaction_count": session.interactionCount,
            "timestamp": ISO8601DateFormatter().string(from: session.endTimestamp ?? Date())
        ])
        
        // Track in custom analytics pipeline
        Task { @MainActor in
            AppAnalytics.shared.track("task_creation_abandoned", props: [
                "session_id": session.sessionId,
                "creation_method": session.creationMethod.rawValue,
                "duration_seconds": session.durationSeconds ?? 0,
                "interaction_count": session.interactionCount
            ])
            
            // Store in Firestore
            await storeSession(session)
        }
        
        // Remove from active sessions
        activeCreationSessions.removeValue(forKey: sessionId)
        
        print("⚠️ [BQ 3.4] Abandoned creation: \(session.creationMethod.displayName) - Duration: \(session.durationSeconds ?? 0)s")
    }
    
    // MARK: - Private Methods
    
    /// Store session in Firestore for BigQuery export
    private func storeSession(_ session: TaskCreationSession) async {
        do {
            let encoder = Firestore.Encoder()
            let data = try encoder.encode(session)
            
            try await db.collection("task_creation_sessions")
                .document(session.sessionId)
                .setData(data)
            
            print("✅ [BQ 3.4] Session stored in Firestore: \(session.sessionId)")
            
        } catch {
            print("❌ [BQ 3.4] Error storing session: \(error)")
        }
    }
    
    // MARK: - Analytics Queries
    
    /// Get user's adoption status for quick features
    /// - Parameter userId: User ID to check
    /// - Returns: Dictionary of adoption status
    func getUserAdoptionStatus(userId: String) async -> [String: Any]? {
        do {
            let snapshot = try await db.collection("task_creation_sessions")
                .whereField("userId", isEqualTo: userId)
                .whereField("completed", isEqualTo: true)
                .getDocuments()
            
            var methodCounts: [CreationMethod: Int] = [:]
            var totalDuration: [CreationMethod: Double] = [:]
            
            for doc in snapshot.documents {
                let data = doc.data()
                
                guard let methodRaw = data["creationMethod"] as? String,
                      let method = CreationMethod(rawValue: methodRaw),
                      let duration = data["durationSeconds"] as? Double else {
                    continue
                }
                
                methodCounts[method, default: 0] += 1
                totalDuration[method, default: 0] += duration
            }
            
            var avgDurations: [CreationMethod: Double] = [:]
            for (method, count) in methodCounts {
                avgDurations[method] = totalDuration[method, default: 0] / Double(count)
            }
            
            return [
                "total_sessions": snapshot.documents.count,
                "method_counts": methodCounts.mapValues { $0 },
                "avg_durations": avgDurations.mapValues { $0 },
                "has_adopted_quick": methodCounts[.quickCreate] ?? 0 > 0,
                "has_adopted_voice": methodCounts[.voiceInput] ?? 0 > 0,
                "has_adopted_template": methodCounts[.template] ?? 0 > 0
            ]
            
        } catch {
            print("❌ [BQ 3.4] Error fetching adoption status: \(error)")
            return nil
        }
    }
}
