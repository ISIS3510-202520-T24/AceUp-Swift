//
//  UserPreferencesManager.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 7/10/25.
//

import Foundation
import Combine
import SwiftUI

/// Manages user preferences and app settings with persistent storage
@MainActor
class UserPreferencesManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = UserPreferencesManager()
    
    // MARK: - Published Properties
    
    @Published var selectedCountry: String {
        didSet { UserDefaults.standard.set(selectedCountry, forKey: Keys.selectedCountry) }
    }
    
    @Published var enableNotifications: Bool {
        didSet { UserDefaults.standard.set(enableNotifications, forKey: Keys.enableNotifications) }
    }
    
    @Published var notificationTime: Date {
        didSet { UserDefaults.standard.set(notificationTime, forKey: Keys.notificationTime) }
    }
    
    @Published var enableBiometricLogin: Bool {
        didSet { UserDefaults.standard.set(enableBiometricLogin, forKey: Keys.enableBiometricLogin) }
    }
    
    @Published var theme: AppTheme {
        didSet { 
            UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme)
            applyTheme()
        }
    }
    
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Keys.language) }
    }
    
    @Published var enableAnalytics: Bool {
        didSet { UserDefaults.standard.set(enableAnalytics, forKey: Keys.enableAnalytics) }
    }
    
    @Published var autoSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(autoSyncEnabled, forKey: Keys.autoSyncEnabled) }
    }
    
    @Published var syncFrequency: SyncFrequency {
        didSet { UserDefaults.standard.set(syncFrequency.rawValue, forKey: Keys.syncFrequency) }
    }
    
    @Published var defaultAssignmentDuration: Double {
        didSet { UserDefaults.standard.set(defaultAssignmentDuration, forKey: Keys.defaultAssignmentDuration) }
    }
    
    @Published var showOverdueFirst: Bool {
        didSet { UserDefaults.standard.set(showOverdueFirst, forKey: Keys.showOverdueFirst) }
    }
    
    @Published var enableQuickActions: Bool {
        didSet { UserDefaults.standard.set(enableQuickActions, forKey: Keys.enableQuickActions) }
    }
    
    @Published var defaultCourseColor: String {
        didSet { UserDefaults.standard.set(defaultCourseColor, forKey: Keys.defaultCourseColor) }
    }
    
    @Published var enableSmartSuggestions: Bool {
        didSet { UserDefaults.standard.set(enableSmartSuggestions, forKey: Keys.enableSmartSuggestions) }
    }
    
    @Published var workloadAnalysisEnabled: Bool {
        didSet { UserDefaults.standard.set(workloadAnalysisEnabled, forKey: Keys.workloadAnalysisEnabled) }
    }
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private enum Keys {
        static let selectedCountry = "selectedCountry"
        static let enableNotifications = "enableNotifications"
        static let notificationTime = "notificationTime"
        static let enableBiometricLogin = "enableBiometricLogin"
        static let theme = "theme"
        static let language = "language"
        static let enableAnalytics = "enableAnalytics"
        static let autoSyncEnabled = "autoSyncEnabled"
        static let syncFrequency = "syncFrequency"
        static let defaultAssignmentDuration = "defaultAssignmentDuration"
        static let showOverdueFirst = "showOverdueFirst"
        static let enableQuickActions = "enableQuickActions"
        static let defaultCourseColor = "defaultCourseColor"
        static let enableSmartSuggestions = "enableSmartSuggestions"
        static let workloadAnalysisEnabled = "workloadAnalysisEnabled"
        static let firstLaunch = "firstLaunch"
        static let onboardingCompleted = "onboardingCompleted"
        static let lastAppVersion = "lastAppVersion"
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load saved preferences or set defaults
        self.selectedCountry = userDefaults.string(forKey: Keys.selectedCountry) ?? "CO" // Colombia default
        self.enableNotifications = userDefaults.object(forKey: Keys.enableNotifications) as? Bool ?? true
        self.notificationTime = userDefaults.object(forKey: Keys.notificationTime) as? Date ?? 
            Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
        self.enableBiometricLogin = userDefaults.object(forKey: Keys.enableBiometricLogin) as? Bool ?? false
        self.theme = AppTheme(rawValue: userDefaults.string(forKey: Keys.theme) ?? "") ?? .system
        self.language = AppLanguage(rawValue: userDefaults.string(forKey: Keys.language) ?? "") ?? .system
        self.enableAnalytics = userDefaults.object(forKey: Keys.enableAnalytics) as? Bool ?? true
        self.autoSyncEnabled = userDefaults.object(forKey: Keys.autoSyncEnabled) as? Bool ?? true
        self.syncFrequency = SyncFrequency(rawValue: userDefaults.string(forKey: Keys.syncFrequency) ?? "") ?? .automatic
        self.defaultAssignmentDuration = userDefaults.object(forKey: Keys.defaultAssignmentDuration) as? Double ?? 2.0
        self.showOverdueFirst = userDefaults.object(forKey: Keys.showOverdueFirst) as? Bool ?? true
        self.enableQuickActions = userDefaults.object(forKey: Keys.enableQuickActions) as? Bool ?? true
        self.defaultCourseColor = userDefaults.string(forKey: Keys.defaultCourseColor) ?? "#122C4A"
        self.enableSmartSuggestions = userDefaults.object(forKey: Keys.enableSmartSuggestions) as? Bool ?? true
        self.workloadAnalysisEnabled = userDefaults.object(forKey: Keys.workloadAnalysisEnabled) as? Bool ?? true
        
        // Apply current theme on initialization
        applyTheme()
        
        // Handle first launch
        handleFirstLaunch()
    }
    
    // MARK: - Public Methods
    
    /// Reset all preferences to defaults
    func resetToDefaults() {
        selectedCountry = "CO"
        enableNotifications = true
        notificationTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
        enableBiometricLogin = false
        theme = .system
        language = .system
        enableAnalytics = true
        autoSyncEnabled = true
        syncFrequency = .automatic
        defaultAssignmentDuration = 2.0
        showOverdueFirst = true
        enableQuickActions = true
        defaultCourseColor = "#122C4A"
        enableSmartSuggestions = true
        workloadAnalysisEnabled = true
    }
    
    /// Check if this is the first app launch
    var isFirstLaunch: Bool {
        return !userDefaults.bool(forKey: Keys.firstLaunch)
    }
    
    /// Mark first launch as completed
    func completeFirstLaunch() {
        userDefaults.set(true, forKey: Keys.firstLaunch)
    }
    
    /// Check if onboarding was completed
    var isOnboardingCompleted: Bool {
        return userDefaults.bool(forKey: Keys.onboardingCompleted)
    }
    
    /// Mark onboarding as completed
    func completeOnboarding() {
        userDefaults.set(true, forKey: Keys.onboardingCompleted)
    }
    
    /// Get app version when settings were last saved
    var lastAppVersion: String? {
        return userDefaults.string(forKey: Keys.lastAppVersion)
    }
    
    /// Get current app version
    var currentAppVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Check if app was updated
    var wasAppUpdated: Bool {
        return lastAppVersion != currentAppVersion
    }
    
    /// Update stored app version
    func updateAppVersion() {
        userDefaults.set(currentAppVersion, forKey: Keys.lastAppVersion)
    }
    
    // MARK: - Theme Management
    
    private func applyTheme() {
        // This would apply the theme to the app
        // Implementation depends on your theming system
    }
    
    // MARK: - Export/Import Settings
    
    /// Export user preferences as dictionary
    func exportPreferences() -> [String: Any] {
        return [
            Keys.selectedCountry: selectedCountry,
            Keys.enableNotifications: enableNotifications,
            Keys.notificationTime: notificationTime,
            Keys.enableBiometricLogin: enableBiometricLogin,
            Keys.theme: theme.rawValue,
            Keys.language: language.rawValue,
            Keys.enableAnalytics: enableAnalytics,
            Keys.autoSyncEnabled: autoSyncEnabled,
            Keys.syncFrequency: syncFrequency.rawValue,
            Keys.defaultAssignmentDuration: defaultAssignmentDuration,
            Keys.showOverdueFirst: showOverdueFirst,
            Keys.enableQuickActions: enableQuickActions,
            Keys.defaultCourseColor: defaultCourseColor,
            Keys.enableSmartSuggestions: enableSmartSuggestions,
            Keys.workloadAnalysisEnabled: workloadAnalysisEnabled
        ]
    }
    
    /// Import user preferences from dictionary
    func importPreferences(_ preferences: [String: Any]) {
        if let country = preferences[Keys.selectedCountry] as? String {
            selectedCountry = country
        }
        if let notifications = preferences[Keys.enableNotifications] as? Bool {
            enableNotifications = notifications
        }
        if let time = preferences[Keys.notificationTime] as? Date {
            notificationTime = time
        }
        if let biometric = preferences[Keys.enableBiometricLogin] as? Bool {
            enableBiometricLogin = biometric
        }
        if let themeString = preferences[Keys.theme] as? String,
           let themeValue = AppTheme(rawValue: themeString) {
            theme = themeValue
        }
        if let langString = preferences[Keys.language] as? String,
           let langValue = AppLanguage(rawValue: langString) {
            language = langValue
        }
        if let analytics = preferences[Keys.enableAnalytics] as? Bool {
            enableAnalytics = analytics
        }
        if let autoSync = preferences[Keys.autoSyncEnabled] as? Bool {
            autoSyncEnabled = autoSync
        }
        if let freqString = preferences[Keys.syncFrequency] as? String,
           let freqValue = SyncFrequency(rawValue: freqString) {
            syncFrequency = freqValue
        }
        if let duration = preferences[Keys.defaultAssignmentDuration] as? Double {
            defaultAssignmentDuration = duration
        }
        if let overdue = preferences[Keys.showOverdueFirst] as? Bool {
            showOverdueFirst = overdue
        }
        if let quickActions = preferences[Keys.enableQuickActions] as? Bool {
            enableQuickActions = quickActions
        }
        if let color = preferences[Keys.defaultCourseColor] as? String {
            defaultCourseColor = color
        }
        if let suggestions = preferences[Keys.enableSmartSuggestions] as? Bool {
            enableSmartSuggestions = suggestions
        }
        if let workload = preferences[Keys.workloadAnalysisEnabled] as? Bool {
            workloadAnalysisEnabled = workload
        }
    }
    
    // MARK: - Private Methods
    
    private func handleFirstLaunch() {
        if isFirstLaunch {
            // Set up default preferences for first launch
            completeFirstLaunch()
        }
        
        if wasAppUpdated {
            // Handle app update logic
            updateAppVersion()
        }
    }
}

// MARK: - Supporting Enums

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case spanish = "es"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .system: return "System"
        }
    }
}

enum SyncFrequency: String, CaseIterable {
    case manual = "manual"
    case hourly = "hourly"
    case daily = "daily"
    case automatic = "automatic"
    
    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .hourly: return "Every Hour"
        case .daily: return "Daily"
        case .automatic: return "Automatic"
        }
    }
    
    var timeInterval: TimeInterval? {
        switch self {
        case .manual: return nil
        case .hourly: return 3600
        case .daily: return 86400
        case .automatic: return nil // Triggered by app state changes
        }
    }
}

// MARK: - User Settings View Model

@MainActor
class UserSettingsViewModel: ObservableObject {
    
    @Published var preferences = UserPreferencesManager.shared
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var exportURL: URL?
    @Published var showingResetAlert = false
    
    func exportSettings() {
        isExporting = true
        
        let settings = preferences.exportPreferences()
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportURL = documentsPath.appendingPathComponent("AceUp_Settings_\(Date().timeIntervalSince1970).json")
        
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            try data.write(to: exportURL)
            self.exportURL = exportURL
        } catch {
            print("Failed to export settings: \(error)")
        }
        
        isExporting = false
    }
    
    func importSettings(from url: URL) {
        isImporting = true
        
        do {
            let data = try Data(contentsOf: url)
            let settings = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            if let settings = settings {
                preferences.importPreferences(settings)
            }
        } catch {
            print("Failed to import settings: \(error)")
        }
        
        isImporting = false
    }
    
    func resetSettings() {
        preferences.resetToDefaults()
    }
}