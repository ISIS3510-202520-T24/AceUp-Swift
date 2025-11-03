//
//  NotificationSettingsManager.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/11/25.
//

import Foundation
import UserNotifications
import UIKit

/// Manages notification settings and permissions
@MainActor
class NotificationSettingsManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NotificationSettingsManager()
    
    // MARK: - Published Properties
    
    @Published var hasPermission = false
    @Published var permissionStatusText = "Checking notification permissions..."
    
    // Assignment notifications
    @Published var assignmentRemindersEnabled: Bool {
        didSet { UserDefaults.standard.set(assignmentRemindersEnabled, forKey: Keys.assignmentRemindersEnabled) }
    }
    @Published var assignmentReminderTime: AssignmentReminderTime {
        didSet { UserDefaults.standard.set(assignmentReminderTime.rawValue, forKey: Keys.assignmentReminderTime) }
    }
    @Published var gradeUpdatesEnabled: Bool {
        didSet { UserDefaults.standard.set(gradeUpdatesEnabled, forKey: Keys.gradeUpdatesEnabled) }
    }
    @Published var priorityAssignmentsEnabled: Bool {
        didSet { UserDefaults.standard.set(priorityAssignmentsEnabled, forKey: Keys.priorityAssignmentsEnabled) }
    }
    
    // Calendar notifications
    @Published var classRemindersEnabled: Bool {
        didSet { UserDefaults.standard.set(classRemindersEnabled, forKey: Keys.classRemindersEnabled) }
    }
    @Published var classReminderTime: ClassReminderTime {
        didSet { UserDefaults.standard.set(classReminderTime.rawValue, forKey: Keys.classReminderTime) }
    }
    @Published var sharedCalendarUpdatesEnabled: Bool {
        didSet { UserDefaults.standard.set(sharedCalendarUpdatesEnabled, forKey: Keys.sharedCalendarUpdatesEnabled) }
    }
    
    // Sync notifications
    @Published var syncStatusEnabled: Bool {
        didSet { UserDefaults.standard.set(syncStatusEnabled, forKey: Keys.syncStatusEnabled) }
    }
    @Published var offlineModeEnabled: Bool {
        didSet { UserDefaults.standard.set(offlineModeEnabled, forKey: Keys.offlineModeEnabled) }
    }
    @Published var inactivityRemindersEnabled: Bool {
        didSet { UserDefaults.standard.set(inactivityRemindersEnabled, forKey: Keys.inactivityRemindersEnabled) }
    }
    
    // Quiet hours
    @Published var quietHoursEnabled: Bool {
        didSet { UserDefaults.standard.set(quietHoursEnabled, forKey: Keys.quietHoursEnabled) }
    }
    @Published var quietHoursStart: Date {
        didSet { UserDefaults.standard.set(quietHoursStart, forKey: Keys.quietHoursStart) }
    }
    @Published var quietHoursEnd: Date {
        didSet { UserDefaults.standard.set(quietHoursEnd, forKey: Keys.quietHoursEnd) }
    }
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private enum Keys {
        static let assignmentRemindersEnabled = "assignmentRemindersEnabled"
        static let assignmentReminderTime = "assignmentReminderTime"
        static let gradeUpdatesEnabled = "gradeUpdatesEnabled"
        static let priorityAssignmentsEnabled = "priorityAssignmentsEnabled"
        static let classRemindersEnabled = "classRemindersEnabled"
        static let classReminderTime = "classReminderTime"
        static let sharedCalendarUpdatesEnabled = "sharedCalendarUpdatesEnabled"
        static let syncStatusEnabled = "syncStatusEnabled"
        static let offlineModeEnabled = "offlineModeEnabled"
        static let inactivityRemindersEnabled = "inactivityRemindersEnabled"
        static let quietHoursEnabled = "quietHoursEnabled"
        static let quietHoursStart = "quietHoursStart"
        static let quietHoursEnd = "quietHoursEnd"
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load settings from UserDefaults
        self.assignmentRemindersEnabled = userDefaults.object(forKey: Keys.assignmentRemindersEnabled) as? Bool ?? true
        self.assignmentReminderTime = AssignmentReminderTime(rawValue: userDefaults.string(forKey: Keys.assignmentReminderTime) ?? "") ?? .oneDay
        self.gradeUpdatesEnabled = userDefaults.object(forKey: Keys.gradeUpdatesEnabled) as? Bool ?? true
        self.priorityAssignmentsEnabled = userDefaults.object(forKey: Keys.priorityAssignmentsEnabled) as? Bool ?? true
        
        self.classRemindersEnabled = userDefaults.object(forKey: Keys.classRemindersEnabled) as? Bool ?? true
        self.classReminderTime = ClassReminderTime(rawValue: userDefaults.string(forKey: Keys.classReminderTime) ?? "") ?? .tenMinutes
        self.sharedCalendarUpdatesEnabled = userDefaults.object(forKey: Keys.sharedCalendarUpdatesEnabled) as? Bool ?? true
        
        self.syncStatusEnabled = userDefaults.object(forKey: Keys.syncStatusEnabled) as? Bool ?? false
        self.offlineModeEnabled = userDefaults.object(forKey: Keys.offlineModeEnabled) as? Bool ?? true
        self.inactivityRemindersEnabled = userDefaults.object(forKey: Keys.inactivityRemindersEnabled) as? Bool ?? true
        
        self.quietHoursEnabled = userDefaults.object(forKey: Keys.quietHoursEnabled) as? Bool ?? false
        self.quietHoursStart = userDefaults.object(forKey: Keys.quietHoursStart) as? Date ?? 
            Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
        self.quietHoursEnd = userDefaults.object(forKey: Keys.quietHoursEnd) as? Date ?? 
            Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    }
    
    // MARK: - Permission Management
    
    /// Check current notification permission status
    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        switch settings.authorizationStatus {
        case .notDetermined:
            hasPermission = false
            permissionStatusText = "Tap 'Enable Notifications' to allow notifications"
        case .denied:
            hasPermission = false
            permissionStatusText = "Notifications are disabled. Enable them in Settings to receive reminders."
        case .authorized, .provisional:
            hasPermission = true
            permissionStatusText = "Notifications are enabled. Customize your preferences below."
        case .ephemeral:
            hasPermission = true
            permissionStatusText = "Temporary notifications are enabled."
        @unknown default:
            hasPermission = false
            permissionStatusText = "Unknown notification status."
        }
    }
    
    /// Request notification permission
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await checkPermissionStatus()
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
    
    /// Open app settings
    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Notification Scheduling
    
    /// Send a test notification
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "AceUp Test Notification"
        content.body = "This is a test notification to verify your settings are working correctly."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending test notification: \(error)")
            }
        }
    }
    
    /// Check if current time is within quiet hours
    func isQuietHoursActive() -> Bool {
        guard quietHoursEnabled else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let startComponents = calendar.dateComponents([.hour, .minute], from: quietHoursStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: quietHoursEnd)
        
        let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        
        if startMinutes <= endMinutes {
            // Same day (e.g., 9 AM to 5 PM)
            return nowMinutes >= startMinutes && nowMinutes <= endMinutes
        } else {
            // Crosses midnight (e.g., 10 PM to 8 AM)
            return nowMinutes >= startMinutes || nowMinutes <= endMinutes
        }
    }
    
    /// Schedule notification respecting user preferences
    func scheduleNotification(
        id: String,
        title: String,
        body: String,
        date: Date,
        type: NotificationType
    ) {
        // Check if this type of notification is enabled
        guard isNotificationTypeEnabled(type) else { return }
        
        // Check quiet hours
        if isQuietHoursActive() && !type.ignoresQuietHours {
            // Reschedule for after quiet hours
            let adjustedDate = adjustDateForQuietHours(date)
            NotificationService.schedule(id: id, title: title, body: body, date: adjustedDate)
        } else {
            NotificationService.schedule(id: id, title: title, body: body, date: date)
        }
    }
    
    // MARK: - Private Methods
    
    private func isNotificationTypeEnabled(_ type: NotificationType) -> Bool {
        switch type {
        case .assignmentReminder:
            return assignmentRemindersEnabled
        case .gradeUpdate:
            return gradeUpdatesEnabled
        case .priorityAssignment:
            return priorityAssignmentsEnabled
        case .classReminder:
            return classRemindersEnabled
        case .sharedCalendarUpdate:
            return sharedCalendarUpdatesEnabled
        case .syncStatus:
            return syncStatusEnabled
        case .offlineMode:
            return offlineModeEnabled
        case .inactivityReminder:
            return inactivityRemindersEnabled
        }
    }
    
    private func adjustDateForQuietHours(_ date: Date) -> Date {
        let calendar = Calendar.current
        let endComponents = calendar.dateComponents([.hour, .minute], from: quietHoursEnd)
        
        var adjustedDate = calendar.dateComponents([.year, .month, .day], from: date)
        adjustedDate.hour = endComponents.hour
        adjustedDate.minute = endComponents.minute
        
        return calendar.date(from: adjustedDate) ?? date
    }
}

// MARK: - Supporting Enums

enum AssignmentReminderTime: String, CaseIterable {
    case oneHour = "1hour"
    case threeHours = "3hours"
    case oneDay = "1day"
    case twoDays = "2days"
    case oneWeek = "1week"
    
    var displayName: String {
        switch self {
        case .oneHour: return "1 hour before"
        case .threeHours: return "3 hours before"
        case .oneDay: return "1 day before"
        case .twoDays: return "2 days before"
        case .oneWeek: return "1 week before"
        }
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .oneHour: return 3600
        case .threeHours: return 10800
        case .oneDay: return 86400
        case .twoDays: return 172800
        case .oneWeek: return 604800
        }
    }
}

enum ClassReminderTime: String, CaseIterable {
    case fiveMinutes = "5min"
    case tenMinutes = "10min"
    case fifteenMinutes = "15min"
    case thirtyMinutes = "30min"
    
    var displayName: String {
        switch self {
        case .fiveMinutes: return "5 minutes before"
        case .tenMinutes: return "10 minutes before"
        case .fifteenMinutes: return "15 minutes before"
        case .thirtyMinutes: return "30 minutes before"
        }
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .fiveMinutes: return 300
        case .tenMinutes: return 600
        case .fifteenMinutes: return 900
        case .thirtyMinutes: return 1800
        }
    }
}

enum NotificationType {
    case assignmentReminder
    case gradeUpdate
    case priorityAssignment
    case classReminder
    case sharedCalendarUpdate
    case syncStatus
    case offlineMode
    case inactivityReminder
    
    var ignoresQuietHours: Bool {
        switch self {
        case .priorityAssignment, .offlineMode:
            return true
        default:
            return false
        }
    }
}