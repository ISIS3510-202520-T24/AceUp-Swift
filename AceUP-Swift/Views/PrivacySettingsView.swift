//
//  PrivacySettingsView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/11/25.
//

import SwiftUI

struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var privacyManager = PrivacySettingsManager()
    
    @State private var showingDataDeletionAlert = false
    @State private var showingAnalyticsInfo = false
    
    var body: some View {
        NavigationView {
            List {
                // Data Collection Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "eye.slash")
                                .foregroundColor(UI.primary)
                            Text("Data Collection")
                                .font(.headline)
                                .foregroundColor(UI.navy)
                        }
                        
                        Text("Control what data AceUp collects and how it's used to improve your experience.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    PrivacyToggleRow(
                        title: "Usage Analytics",
                        description: "Help improve the app by sharing anonymous usage data",
                        isEnabled: $privacyManager.allowAnalytics,
                        infoAction: { showingAnalyticsInfo = true }
                    )
                    
                    PrivacyToggleRow(
                        title: "Crash Reports",
                        description: "Automatically send crash reports to help fix bugs",
                        isEnabled: $privacyManager.allowCrashReports
                    )
                    
                    PrivacyToggleRow(
                        title: "Performance Monitoring",
                        description: "Share app performance data to optimize experience",
                        isEnabled: $privacyManager.allowPerformanceMonitoring
                    )
                } header: {
                    Text("Data Collection Preferences")
                }
                
                // Sharing & Visibility Section
                Section {
                    PrivacyToggleRow(
                        title: "Profile Visibility",
                        description: "Allow classmates to find your profile in shared calendars",
                        isEnabled: $privacyManager.profileVisible
                    )
                    
                    PrivacyToggleRow(
                        title: "Activity Status",
                        description: "Show when you're active to shared calendar members",
                        isEnabled: $privacyManager.showActivityStatus
                    )
                    
                    PrivacyToggleRow(
                        title: "Study Progress Sharing",
                        description: "Allow progress sharing with study group members",
                        isEnabled: $privacyManager.allowProgressSharing
                    )
                } header: {
                    Text("Sharing & Visibility")
                }
                
                // Location & Device Section
                Section {
                    PrivacyToggleRow(
                        title: "Location for Reminders",
                        description: "Use location to provide campus-based notifications",
                        isEnabled: $privacyManager.allowLocationReminders
                    )
                    
                    PrivacyToggleRow(
                        title: "Calendar Integration",
                        description: "Allow AceUp to read your device calendar for context",
                        isEnabled: $privacyManager.allowCalendarIntegration
                    )
                    
                    PrivacyToggleRow(
                        title: "Contacts Access",
                        description: "Access contacts to suggest classmates for sharing",
                        isEnabled: $privacyManager.allowContactsAccess
                    )
                } header: {
                    Text("Device Permissions")
                }
                
                // Data Management Section
                Section {
                    Button(action: { showingDataDeletionAlert = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Delete All Data")
                                    .foregroundColor(.red)
                                Text("Permanently remove all your data from AceUp")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    NavigationLink(destination: DataRetentionView()) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(UI.primary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Data Retention")
                                    .foregroundColor(.primary)
                                Text("Manage how long your data is stored")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink(destination: ThirdPartyServicesView()) {
                        HStack {
                            Image(systemName: "building.2")
                                .foregroundColor(UI.primary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Third-Party Services")
                                    .foregroundColor(.primary)
                                Text("View services that may access your data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Data Management")
                }
                
                // Legal Section
                Section {
                    NavigationLink(destination: PrivacyPolicyView()) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(UI.primary)
                            Text("Privacy Policy")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    NavigationLink(destination: TermsOfServiceView()) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(UI.primary)
                            Text("Terms of Service")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Button("Request Data Copy") {
                        privacyManager.requestDataCopy()
                    }
                    .foregroundColor(UI.primary)
                } header: {
                    Text("Legal & Rights")
                }
            }
            .navigationTitle("Privacy Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Delete All Data", isPresented: $showingDataDeletionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                privacyManager.deleteAllUserData()
            }
        } message: {
            Text("This will permanently delete all your data including assignments, grades, and preferences. This action cannot be undone.")
        }
        .sheet(isPresented: $showingAnalyticsInfo) {
            AnalyticsInfoView()
        }
        .task {
            await privacyManager.loadSettings()
        }
    }
}

// MARK: - Privacy Toggle Row

struct PrivacyToggleRow: View {
    let title: String
    let description: String
    @Binding var isEnabled: Bool
    var infoAction: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .foregroundColor(.primary)
                    
                    if let action = infoAction {
                        Button(action: action) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Spacer()
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Analytics Info View

struct AnalyticsInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Usage Analytics")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(UI.navy)
                        
                        Text("We collect anonymous usage data to improve AceUp and provide better features for students.")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What we collect:")
                            .font(.headline)
                            .foregroundColor(UI.navy)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            AnalyticsDetailRow(
                                icon: "chart.bar",
                                title: "Feature Usage",
                                description: "Which features you use most to prioritize improvements"
                            )
                            
                            AnalyticsDetailRow(
                                icon: "timer",
                                title: "Session Duration",
                                description: "How long you use the app to optimize performance"
                            )
                            
                            AnalyticsDetailRow(
                                icon: "exclamationmark.triangle",
                                title: "Error Reports",
                                description: "Technical issues to help us fix bugs faster"
                            )
                            
                            AnalyticsDetailRow(
                                icon: "speedometer",
                                title: "Performance Metrics",
                                description: "App load times and responsiveness data"
                            )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What we DON'T collect:")
                            .font(.headline)
                            .foregroundColor(UI.navy)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            AnalyticsDetailRow(
                                icon: "person.slash",
                                title: "Personal Information",
                                description: "Your name, email, or any identifying data",
                                isProtected: true
                            )
                            
                            AnalyticsDetailRow(
                                icon: "book.closed",
                                title: "Academic Content",
                                description: "Your assignments, grades, or course details",
                                isProtected: true
                            )
                            
                            AnalyticsDetailRow(
                                icon: "message.slash",
                                title: "Communications",
                                description: "Messages or shared calendar content",
                                isProtected: true
                            )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.green)
                            Text("Your privacy is protected")
                                .font(.headline)
                                .foregroundColor(UI.navy)
                        }
                        
                        Text("All analytics data is anonymized and encrypted. We cannot trace any data back to individual users, and we never share this data with third parties.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Analytics Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AnalyticsDetailRow: View {
    let icon: String
    let title: String
    let description: String
    var isProtected: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isProtected ? .red : UI.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Supporting Views

struct DataRetentionView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("We retain your data for the following periods:")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    DataRetentionRow(
                        category: "Account Data",
                        period: "Until account deletion",
                        description: "Your profile and preferences"
                    )
                    
                    DataRetentionRow(
                        category: "Academic Data",
                        period: "5 years after graduation",
                        description: "Assignments, grades, and course history"
                    )
                    
                    DataRetentionRow(
                        category: "Analytics Data",
                        period: "24 months",
                        description: "Anonymous usage statistics"
                    )
                    
                    DataRetentionRow(
                        category: "Support Logs",
                        period: "3 years",
                        description: "Customer service interactions"
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Data Retention")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataRetentionRow: View {
    let category: String
    let period: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(period)
                    .font(.caption)
                    .foregroundColor(UI.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(UI.primary.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ThirdPartyServicesView: View {
    var body: some View {
        List {
            Section {
                ThirdPartyServiceRow(
                    name: "Firebase",
                    purpose: "Authentication and data storage",
                    dataAccess: "Account information, app data"
                )
                
                ThirdPartyServiceRow(
                    name: "Apple Analytics",
                    purpose: "App performance monitoring",
                    dataAccess: "Anonymous usage statistics"
                )
            } header: {
                Text("Current Services")
            } footer: {
                Text("These services help us provide and improve AceUp. Click on any service to learn more about their privacy practices.")
            }
        }
        .navigationTitle("Third-Party Services")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ThirdPartyServiceRow: View {
    let name: String
    let purpose: String
    let dataAccess: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(UI.primary)
                    .font(.caption)
            }
            
            Text(purpose)
                .font(.caption)
                .foregroundColor(.primary)
            
            Text("Data access: \(dataAccess)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Privacy Settings Manager

@MainActor
class PrivacySettingsManager: ObservableObject {
    @Published var allowAnalytics = true
    @Published var allowCrashReports = true
    @Published var allowPerformanceMonitoring = true
    @Published var profileVisible = true
    @Published var showActivityStatus = false
    @Published var allowProgressSharing = true
    @Published var allowLocationReminders = false
    @Published var allowCalendarIntegration = false
    @Published var allowContactsAccess = false
    
    func loadSettings() async {
        // Load settings from UserDefaults or server
        allowAnalytics = UserDefaults.standard.bool(forKey: "privacy_analytics")
        allowCrashReports = UserDefaults.standard.bool(forKey: "privacy_crash_reports")
        // ... load other settings
    }
    
    func deleteAllUserData() {
        // Implementation would delete all user data
        print("Deleting all user data...")
    }
    
    func requestDataCopy() {
        // Implementation would trigger data export
        print("Requesting data copy...")
    }
}

#Preview {
    PrivacySettingsView()
}