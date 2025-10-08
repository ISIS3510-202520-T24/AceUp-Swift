//
//  SettingsView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 7/10/25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var preferencesManager = UserPreferencesManager.shared
    @StateObject private var syncManager = DataSynchronizationManager.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var settingsViewModel = UserSettingsViewModel()
    
    @State private var showingOfflineSettings = false
    @State private var showingSyncDiagnostics = false
    @State private var showingDataManagement = false
    @State private var showingAbout = false
    
    let onMenuTapped: () -> Void
    let onLogout: () -> Void
    
    init(onMenuTapped: @escaping () -> Void = {}, onLogout: @escaping () -> Void = {}) {
        self.onMenuTapped = onMenuTapped
        self.onLogout = onLogout
    }
    
    var body: some View {
        NavigationView {
            List {
                // User Profile Section
                userProfileSection
                
                // App Preferences
                appPreferencesSection
                
                // Data & Sync
                dataSyncSection
                
                // Privacy & Security
                privacySecuritySection
                
                // About & Support
                aboutSupportSection
                
                // Logout
                logoutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onMenuTapped) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(UI.navy)
                    }
                }
            }
        }
        .sheet(isPresented: $showingOfflineSettings) {
            NavigationView {
                OfflineSettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingOfflineSettings = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingSyncDiagnostics) {
            NavigationView {
                SyncDiagnosticsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingSyncDiagnostics = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingDataManagement) {
            NavigationView {
                DataManagementView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingDataManagement = false
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - User Profile Section
    
    private var userProfileSection: some View {
        Section("Profile") {
            HStack {
                AsyncImage(url: URL(string: "https://via.placeholder.com/50")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(UI.primary.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(UI.primary)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("John Doe")
                        .font(.headline)
                        .foregroundColor(UI.navy)
                    
                    Text("john.doe@example.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Connection status indicator
                Circle()
                    .fill(offlineManager.isOnline ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - App Preferences Section
    
    private var appPreferencesSection: some View {
        Section("Preferences") {
            // Country Selection
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Country")
                
                Spacer()
                
                Picker("Country", selection: $preferencesManager.selectedCountry) {
                    Text("United States").tag("US")
                    Text("Colombia").tag("CO")
                    Text("United Kingdom").tag("GB")
                    Text("Canada").tag("CA")
                    Text("Mexico").tag("MX")
                    Text("Spain").tag("ES")
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Theme Selection
            HStack {
                Image(systemName: "paintbrush")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Theme")
                
                Spacer()
                
                Picker("Theme", selection: $preferencesManager.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Language Selection
            HStack {
                Image(systemName: "textformat")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Language")
                
                Spacer()
                
                Picker("Language", selection: $preferencesManager.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Notifications
            HStack {
                Image(systemName: "bell")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Notifications")
                
                Spacer()
                
                Toggle("", isOn: $preferencesManager.enableNotifications)
                    .toggleStyle(SwitchToggleStyle(tint: UI.primary))
            }
            
            if preferencesManager.enableNotifications {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("Default Time")
                    
                    Spacer()
                    
                    DatePicker("", selection: $preferencesManager.notificationTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
        }
    }
    
    // MARK: - Data & Sync Section
    
    private var dataSyncSection: some View {
        Section("Data & Sync") {
            // Sync Status
            HStack {
                Image(systemName: syncManager.isOnline ? "icloud" : "icloud.slash")
                    .foregroundColor(syncManager.isOnline ? .green : .orange)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync Status")
                    Text(syncManager.syncStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if syncManager.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Sync Now") {
                        Task {
                            await syncManager.performFullSync()
                        }
                    }
                    .font(.caption)
                    .disabled(!syncManager.isOnline)
                }
            }
            
            // Auto Sync
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Auto Sync")
                
                Spacer()
                
                Toggle("", isOn: $preferencesManager.autoSyncEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: UI.primary))
            }
            
            if preferencesManager.autoSyncEnabled {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("Sync Frequency")
                    
                    Spacer()
                    
                    Picker("Frequency", selection: $preferencesManager.syncFrequency) {
                        ForEach(SyncFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            
            // Offline Settings
            Button(action: { showingOfflineSettings = true }) {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("Offline Settings")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            // Sync Diagnostics
            Button(action: { showingSyncDiagnostics = true }) {
                HStack {
                    Image(systemName: "stethoscope")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("Sync Diagnostics")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            // Data Management
            Button(action: { showingDataManagement = true }) {
                HStack {
                    Image(systemName: "externaldrive")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("Data Management")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Privacy & Security Section
    
    private var privacySecuritySection: some View {
        Section("Privacy & Security") {
            // Biometric Login
            HStack {
                Image(systemName: "faceid")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Biometric Login")
                
                Spacer()
                
                Toggle("", isOn: $preferencesManager.enableBiometricLogin)
                    .toggleStyle(SwitchToggleStyle(tint: UI.primary))
            }
            
            // Analytics
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Analytics")
                
                Spacer()
                
                Toggle("", isOn: $preferencesManager.enableAnalytics)
                    .toggleStyle(SwitchToggleStyle(tint: UI.primary))
            }
            
            // Smart Suggestions
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Smart Suggestions")
                
                Spacer()
                
                Toggle("", isOn: $preferencesManager.enableSmartSuggestions)
                    .toggleStyle(SwitchToggleStyle(tint: UI.primary))
            }
        }
    }
    
    // MARK: - About & Support Section
    
    private var aboutSupportSection: some View {
        Section("About & Support") {
            // App Version
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Version")
                
                Spacer()
                
                Text(preferencesManager.currentAppVersion)
                    .foregroundColor(.secondary)
            }
            
            // Export Settings
            Button(action: { settingsViewModel.exportSettings() }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("Export Settings")
                        .foregroundColor(.primary)
                }
            }
            .disabled(settingsViewModel.isExporting)
            
            // Reset Settings
            Button(action: { settingsViewModel.showingResetAlert = true }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.red)
                        .frame(width: 20)
                    
                    Text("Reset to Defaults")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Logout Section
    
    private var logoutSection: some View {
        Section {
            Button(action: onLogout) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                        .frame(width: 20)
                    
                    Text("Sign Out")
                        .foregroundColor(.red)
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Sync Diagnostics View

struct SyncDiagnosticsView: View {
    @StateObject private var syncManager = DataSynchronizationManager.shared
    
    var body: some View {
        List {
            Section("Current Status") {
                InfoRow(title: "Connection", value: syncManager.isOnline ? "Online" : "Offline")
                InfoRow(title: "Sync Status", value: syncManager.syncStatus)
                InfoRow(title: "Last Sync", value: syncManager.getSyncDiagnostics().formattedLastSync)
                InfoRow(title: "Pending Items", value: "\(syncManager.pendingSyncCount)")
            }
            
            Section("Settings") {
                let diagnostics = syncManager.getSyncDiagnostics()
                InfoRow(title: "Auto Sync", value: diagnostics.autoSyncEnabled ? "Enabled" : "Disabled")
                InfoRow(title: "Frequency", value: diagnostics.syncFrequency.displayName)
            }
            
            Section("Actions") {
                Button("Force Full Sync") {
                    Task {
                        await syncManager.performFullSync()
                    }
                }
                .disabled(!syncManager.isOnline || syncManager.isSyncing)
                
                Button("Test Connection") {
                    // Test connection logic
                }
                .disabled(syncManager.isSyncing)
            }
        }
        .navigationTitle("Sync Diagnostics")
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    @StateObject private var offlineManager = OfflineManager.shared
    @State private var showingClearDataAlert = false
    
    var body: some View {
        List {
            Section("Local Data") {
                InfoRow(title: "Cached Data", value: offlineManager.hasOfflineData ? "Available" : "None")
                InfoRow(title: "Data Size", value: offlineManager.getOfflineDataSize())
                InfoRow(title: "Data Age", value: offlineManager.getOfflineStatus().formattedDataAge)
            }
            
            Section("Actions") {
                Button("Refresh Cache") {
                    Task {
                        await offlineManager.prepareForOffline()
                    }
                }
                .disabled(!offlineManager.isOnline)
                
                Button("Clear All Data", role: .destructive) {
                    showingClearDataAlert = true
                }
                .disabled(!offlineManager.hasOfflineData)
            }
        }
        .navigationTitle("Data Management")
        .alert("Clear All Data", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await offlineManager.clearOfflineData()
                }
            }
        } message: {
            Text("This will remove all locally stored data. You'll need an internet connection to use the app until data is synced again.")
        }
    }
}

// MARK: - Helper Views

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView(onMenuTapped: {}, onLogout: {})
}