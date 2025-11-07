//
//  UserUpdateAnalytics.swift
//  AceUP-Swift
//
//  Business Question 5.1: How much time do users typically take to update their 
//  availability, schedules, or personal information within the app?
//
//  Implementation: BigQuery-focused with existing notification system integration
//
//  Created by Ángel Farfán Arcila on 7/11/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAnalytics
import FirebaseAuth

/// Tracks user update sessions for BQ 5.1 analytics
/// Data flows: iOS App → Firestore → BigQuery (via Firebase export)
/// Notifications: Leverages existing NotificationService
@MainActor
class UserUpdateAnalytics: ObservableObject {
    
    // MARK: - Singleton
    static let shared = UserUpdateAnalytics()
    
    // MARK: - Properties
    private let db = Firestore.firestore()
    private var activeUpdateSessions: [String: UpdateSession] = [:]
    
    // User Defaults keys for tracking last update times
    private let lastUpdatePrefix = "lastUpdate_"
    
    // MARK: - Update Types
    enum UpdateType: String, Codable {
        case availability = "availability"
        case schedule = "schedule"
        case personalInfo = "personal_info"
        case profileImage = "profile_image"
        case assignment = "assignment"
        case courseInfo = "course_info"
        case sharedCalendar = "shared_calendar"
        case preferences = "preferences"
        
        var displayName: String {
            switch self {
            case .availability: return "Availability"
            case .schedule: return "Schedule"
            case .personalInfo: return "Personal Information"
            case .profileImage: return "Profile Image"
            case .assignment: return "Assignment"
            case .courseInfo: return "Course Information"
            case .sharedCalendar: return "Shared Calendar"
            case .preferences: return "Preferences"
            }
        }
    }
    
    // MARK: - Update Session Model
    struct UpdateSession: Codable {
        let sessionId: String
        let userId: String
        let updateType: UpdateType
        let startTimestamp: Date
        var endTimestamp: Date?
        var durationSeconds: Double?
        var completed: Bool
        var abandoned: Bool
        var interactionCount: Int
        var fieldsModified: [String]
        var platform: String
        var appVersion: String
        
        init(
            sessionId: String = UUID().uuidString,
            userId: String,
            updateType: UpdateType,
            startTimestamp: Date = Date(),
            platform: String = "iOS",
            appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ) {
            self.sessionId = sessionId
            self.userId = userId
            self.updateType = updateType
            self.startTimestamp = startTimestamp
            self.endTimestamp = nil
            self.durationSeconds = nil
            self.completed = false
            self.abandoned = false
            self.interactionCount = 0
            self.fieldsModified = []
            self.platform = platform
            self.appVersion = appVersion
        }
        
        mutating func complete(with fields: [String]) {
            self.endTimestamp = Date()
            self.durationSeconds = endTimestamp?.timeIntervalSince(startTimestamp)
            self.completed = true
            self.fieldsModified = fields
        }
        
        mutating func abandon() {
            self.endTimestamp = Date()
            self.durationSeconds = endTimestamp?.timeIntervalSince(startTimestamp)
            self.abandoned = true
        }
        
        mutating func incrementInteraction() {
            self.interactionCount += 1
        }
    }
    
    // MARK: - Public Methods
    
    /// Start tracking an update session
    /// - Parameters:
    ///   - updateType: Type of update being performed
    ///   - userId: User performing the update
    /// - Returns: Session ID for tracking
    @discardableResult
    func startUpdateSession(
        updateType: UpdateType,
        userId: String
    ) -> String {
        let session = UpdateSession(
            userId: userId,
            updateType: updateType
        )
        
        activeUpdateSessions[session.sessionId] = session
        
        // Track event in Firebase Analytics
        Analytics.logEvent("update_session_started", parameters: [
            "session_id": session.sessionId,
            "update_type": updateType.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: session.startTimestamp),
            "platform": session.platform
        ])
        
        // Track in custom analytics pipeline (fire and forget)
        Task { @MainActor in
            AppAnalytics.shared.track("update_session_started", props: [
                "session_id": session.sessionId,
                "update_type": updateType.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: session.startTimestamp)
            ])
        }
        
        // 🆕 Persist to Firestore immediately to avoid data loss
        Task { @MainActor in
            await storeSessionInProgress(session)
        }
        
        print("📊 [BQ 5.1] Started update session: \(updateType.displayName) - \(session.sessionId)")
        
        return session.sessionId
    }
    
    /// Track user interaction during an update session
    /// - Parameter sessionId: Active session ID
    func trackInteraction(sessionId: String) {
        guard var session = activeUpdateSessions[sessionId] else { return }
        
        session.incrementInteraction()
        activeUpdateSessions[sessionId] = session
        
        // 🆕 Update interaction count in Firestore
        Task { @MainActor in
            await updateInteractionCount(sessionId: sessionId, count: session.interactionCount)
        }
        
        print("📊 [BQ 5.1] Interaction tracked: Session \(sessionId) - Count: \(session.interactionCount)")
    }
    
    /// Update interaction count in Firestore
    private func updateInteractionCount(sessionId: String, count: Int) async {
        do {
            try await db.collection("analytics_update_sessions")
                .document(sessionId)
                .updateData(["interactionCount": count])
        } catch {
            print("❌ [BQ 5.1] Error updating interaction count: \(error)")
        }
    }
    
    /// Complete an update session successfully
    /// - Parameters:
    ///   - sessionId: Active session ID
    ///   - fieldsModified: List of fields that were modified
    func completeUpdateSession(
        sessionId: String,
        fieldsModified: [String] = []
    ) {
        guard var session = activeUpdateSessions[sessionId] else {
            print("⚠️ [BQ 5.1] No active session found for ID: \(sessionId)")
            return
        }
        
        session.complete(with: fieldsModified)
        
        // Track completion in Firebase Analytics
        Analytics.logEvent("update_session_completed", parameters: [
            "session_id": session.sessionId,
            "update_type": session.updateType.rawValue,
            "duration_seconds": session.durationSeconds ?? 0,
            "interaction_count": session.interactionCount,
            "fields_modified_count": fieldsModified.count,
            "timestamp": ISO8601DateFormatter().string(from: session.endTimestamp ?? Date())
        ])
        
        // Track in custom analytics pipeline
        Task { @MainActor in
            AppAnalytics.shared.track("update_session_completed", props: [
                "session_id": session.sessionId,
                "update_type": session.updateType.rawValue,
                "duration_seconds": session.durationSeconds ?? 0,
                "interaction_count": session.interactionCount,
                "fields_modified": fieldsModified,
                "timestamp": ISO8601DateFormatter().string(from: session.endTimestamp ?? Date())
            ])
        }
        
        // Store in Firestore for BigQuery export
        Task { @MainActor in
            await storeSession(session)
            // Check if notification is needed
            await checkNotificationThreshold(for: session)
        }
        
        // Remove from active sessions
        activeUpdateSessions.removeValue(forKey: sessionId)
        
        print("✅ [BQ 5.1] Completed update session: \(session.updateType.displayName) - Duration: \(session.durationSeconds ?? 0)s")
    }
    
    /// Abandon an update session (user cancelled or navigated away)
    /// - Parameter sessionId: Active session ID
    func abandonUpdateSession(sessionId: String) {
        guard var session = activeUpdateSessions[sessionId] else {
            print("⚠️ [BQ 5.1] No active session found for ID: \(sessionId)")
            return
        }
        
        session.abandon()
        
        // Track abandonment in Firebase Analytics
        Analytics.logEvent("update_session_abandoned", parameters: [
            "session_id": session.sessionId,
            "update_type": session.updateType.rawValue,
            "duration_seconds": session.durationSeconds ?? 0,
            "interaction_count": session.interactionCount,
            "timestamp": ISO8601DateFormatter().string(from: session.endTimestamp ?? Date())
        ])
        
        // Track in custom analytics pipeline
        Task { @MainActor in
            AppAnalytics.shared.track("update_session_abandoned", props: [
                "session_id": session.sessionId,
                "update_type": session.updateType.rawValue,
                "duration_seconds": session.durationSeconds ?? 0,
                "interaction_count": session.interactionCount,
                "timestamp": ISO8601DateFormatter().string(from: session.endTimestamp ?? Date())
            ])
            
            // Store in Firestore
            await storeSession(session)
        }
        
        // Remove from active sessions
        activeUpdateSessions.removeValue(forKey: sessionId)
        
        print("⚠️ [BQ 5.1] Abandoned update session: \(session.updateType.displayName) - Duration: \(session.durationSeconds ?? 0)s")
    }
    
    // MARK: - Convenience Methods (Type-based)
    
    /// Convenience method: Start session by update type (auto-fetches userId)
    @discardableResult
    func startUpdateSession(type: UpdateType) -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ [BQ 5.1] No authenticated user")
            return ""
        }
        return startUpdateSession(updateType: type, userId: userId)
    }
    
    /// Convenience method: Track interaction by update type
    func trackInteraction(type: UpdateType) {
        // Find active session for this update type
        guard let session = activeUpdateSessions.values.first(where: { $0.updateType == type }) else {
            print("⚠️ [BQ 5.1] No active session for type: \(type.displayName)")
            return
        }
        trackInteraction(sessionId: session.sessionId)
    }
    
    /// Convenience method: Complete session by update type
    func completeUpdateSession(type: UpdateType, fieldsUpdated: [String]) {
        guard let session = activeUpdateSessions.values.first(where: { $0.updateType == type }) else {
            print("⚠️ [BQ 5.1] No active session for type: \(type.displayName)")
            return
        }
        completeUpdateSession(sessionId: session.sessionId, fieldsModified: fieldsUpdated)
    }
    
    /// Convenience method: Abandon session by update type
    func abandonUpdateSession(type: UpdateType) {
        guard let session = activeUpdateSessions.values.first(where: { $0.updateType == type }) else {
            print("⚠️ [BQ 5.1] No active session for type: \(type.displayName)")
            return
        }
        abandonUpdateSession(sessionId: session.sessionId)
    }
    
    // MARK: - Analytics Queries
    
    /// Get average update time for a specific update type
    /// - Parameter updateType: Type of update to analyze
    /// - Returns: Average duration in seconds
    func getAverageUpdateTime(for updateType: UpdateType, userId: String) async -> Double? {
        do {
            let snapshot = try await db.collection("analytics_update_sessions")
                .whereField("userId", isEqualTo: userId)
                .whereField("updateType", isEqualTo: updateType.rawValue)
                .whereField("completed", isEqualTo: true)
                .limit(to: 50)
                .getDocuments()
            
            let durations = snapshot.documents.compactMap { doc -> Double? in
                doc.data()["durationSeconds"] as? Double
            }
            
            guard !durations.isEmpty else { return nil }
            
            return durations.reduce(0, +) / Double(durations.count)
            
        } catch {
            print("Error fetching average update time: \(error)")
            return nil
        }
    }
    
    /// Get user's last update timestamp for a specific type
    /// - Parameters:
    ///   - updateType: Type of update
    ///   - userId: User ID
    /// - Returns: Date of last update or nil
    func getLastUpdateDate(for updateType: UpdateType, userId: String) async -> Date? {
        do {
            let snapshot = try await db.collection("analytics_update_sessions")
                .whereField("userId", isEqualTo: userId)
                .whereField("updateType", isEqualTo: updateType.rawValue)
                .whereField("completed", isEqualTo: true)
                .order(by: "endTimestamp", descending: true)
                .limit(to: 1)
                .getDocuments()
            
            guard let doc = snapshot.documents.first,
                  let timestamp = doc.data()["endTimestamp"] as? Timestamp else {
                return nil
            }
            
            return timestamp.dateValue()
            
        } catch {
            print("Error fetching last update date: \(error)")
            return nil
        }
    }
    
    /// Check if user should be reminded to update information
    /// Uses existing NotificationService infrastructure
    /// - Parameters:
    ///   - updateType: Type of update
    ///   - userId: User ID
    ///   - thresholdDays: Days threshold for reminder
    /// - Returns: Whether reminder should be sent
    func shouldRemindUser(
        for updateType: UpdateType,
        userId: String,
        thresholdDays: Int = 7
    ) async -> Bool {
        guard let lastUpdate = await getLastUpdateDate(for: updateType, userId: userId) else {
            return true // No previous update, should remind
        }
        
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: lastUpdate, to: Date()).day ?? 0
        
        return daysSinceUpdate >= thresholdDays
    }
    
    /// Schedule notification for stale update using existing NotificationService
    /// - Parameters:
    ///   - updateType: Type of update that's stale
    ///   - userId: User ID
    func scheduleStaleUpdateNotification(
        for updateType: UpdateType,
        userId: String
    ) async {
        guard let lastUpdate = await getLastUpdateDate(for: updateType, userId: userId) else {
            return
        }
        
        let daysSince = Calendar.current.dateComponents([.day], from: lastUpdate, to: Date()).day ?? 0
        
        // Use existing NotificationService with BQ 5.1 context
        let title = "Update Your \(updateType.displayName)"
        let body = "It's been \(daysSince) days since you updated your \(updateType.displayName.lowercased()). Keep your information current!"
        
        // Schedule for 2 hours from now (user-friendly timing)
        let fireDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        
        NotificationService.schedule(
            id: "update_reminder_\(updateType.rawValue)",
            title: title,
            body: body,
            date: fireDate
        )
        
        // Track notification sent
        Analytics.logEvent("update_reminder_scheduled", parameters: [
            "update_type": updateType.rawValue,
            "days_since": daysSince
        ])
        
        print("📬 [BQ 5.1] Scheduled update reminder: \(updateType.displayName) - \(daysSince) days")
    }
    
    // MARK: - Private Methods
    
    /// Store in-progress session in Firestore immediately (for crash recovery)
    private func storeSessionInProgress(_ session: UpdateSession) async {
        do {
            let data: [String: Any] = [
                "sessionId": session.sessionId,
                "userId": session.userId,
                "updateType": session.updateType.rawValue,
                "startTimestamp": Timestamp(date: session.startTimestamp),
                "endTimestamp": NSNull(),
                "durationSeconds": NSNull(),
                "completed": false,
                "abandoned": false,
                "interactionCount": 0,
                "fieldsModified": [],
                "platform": session.platform,
                "appVersion": session.appVersion,
                "status": "in_progress",
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            try await db.collection("analytics_update_sessions")
                .document(session.sessionId)
                .setData(data)
            
            print("💾 [BQ 5.1] Persisted in-progress session to Firestore: \(session.sessionId)")
            
        } catch {
            print("❌ [BQ 5.1] Error storing in-progress session: \(error)")
        }
    }
    
    /// Store update session in Firestore for BigQuery export
    /// Firebase automatically exports Firestore to BigQuery when configured
    private func storeSession(_ session: UpdateSession) async {
        do {
            let data: [String: Any] = [
                "sessionId": session.sessionId,
                "userId": session.userId,
                "updateType": session.updateType.rawValue,
                "startTimestamp": Timestamp(date: session.startTimestamp),
                "endTimestamp": session.endTimestamp.map { Timestamp(date: $0) } ?? NSNull(),
                "durationSeconds": session.durationSeconds ?? NSNull(),
                "completed": session.completed,
                "abandoned": session.abandoned,
                "interactionCount": session.interactionCount,
                "fieldsModified": session.fieldsModified,
                "platform": session.platform,
                "appVersion": session.appVersion,
                "status": session.completed ? "completed" : (session.abandoned ? "abandoned" : "in_progress"),
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            // Use merge to update existing document created at start
            try await db.collection("analytics_update_sessions")
                .document(session.sessionId)
                .setData(data, merge: true)
            
            // Update last update date in UserDefaults for notification checks
            if session.completed, let endTime = session.endTimestamp {
                let key = lastUpdatePrefix + session.updateType.rawValue
                UserDefaults.standard.set(endTime, forKey: key)
            }
            
            print("📊 [BQ 5.1] Updated session in Firestore (auto-exports to BigQuery): \(session.sessionId)")
            
        } catch {
            print("❌ [BQ 5.1] Error storing update session: \(error)")
        }
    }
    
    /// Check if user took too long and send notification if needed
    private func checkNotificationThreshold(for session: UpdateSession) async {
        guard let duration = session.durationSeconds,
              session.completed else { return }
        
        // Define thresholds for different update types (in seconds)
        let thresholds: [UpdateType: Double] = [
            .availability: 120,      // 2 minutes
            .schedule: 180,          // 3 minutes
            .personalInfo: 120,      // 2 minutes
            .profileImage: 60,       // 1 minute
            .assignment: 180,        // 3 minutes
            .courseInfo: 120,        // 2 minutes
            .sharedCalendar: 150,    // 2.5 minutes
            .preferences: 60         // 1 minute
        ]
        
        guard let threshold = thresholds[session.updateType],
              duration > threshold else { return }
        
        // Track slow update event
        Analytics.logEvent("update_session_slow", parameters: [
            "session_id": session.sessionId,
            "update_type": session.updateType.rawValue,
            "duration_seconds": duration,
            "threshold_seconds": threshold,
            "exceeded_by_seconds": duration - threshold
        ])
        
        AppAnalytics.shared.track("update_session_slow", props: [
            "session_id": session.sessionId,
            "update_type": session.updateType.rawValue,
            "duration_seconds": duration,
            "threshold_seconds": threshold
        ])
        
        print("⏱️ [BQ 5.1] Slow update detected: \(session.updateType.displayName) took \(duration)s (threshold: \(threshold)s)")
    }
}

// MARK: - Convenience Extensions

extension UserUpdateAnalytics {
    
    /// Start tracking profile update
    @discardableResult
    func startProfileUpdate(userId: String) -> String {
        startUpdateSession(updateType: .personalInfo, userId: userId)
    }
    
    /// Start tracking schedule update
    @discardableResult
    func startScheduleUpdate(userId: String) -> String {
        startUpdateSession(updateType: .schedule, userId: userId)
    }
    
    /// Start tracking availability update
    @discardableResult
    func startAvailabilityUpdate(userId: String) -> String {
        startUpdateSession(updateType: .availability, userId: userId)
    }
    
    /// Start tracking assignment update
    @discardableResult
    func startAssignmentUpdate(userId: String) -> String {
        startUpdateSession(updateType: .assignment, userId: userId)
    }
}
