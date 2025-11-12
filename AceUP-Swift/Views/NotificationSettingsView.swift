//
//  NotificationSettingsView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/11/25.
//

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @StateObject private var preferencesManager = UserPreferencesManager.shared
    @StateObject private var notificationManager = NotificationSettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Overall notification toggle
                masterNotificationSection
                
                if preferencesManager.enableNotifications {
                    // Assignment notifications
                    assignmentNotificationSection
                    
                    // Calendar notifications
                    calendarNotificationSection
                    
                    // Sync notifications
                    syncNotificationSection
                    
                    // Quiet hours
                    quietHoursSection
                    
                    // Notification test
                    testNotificationSection
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await notificationManager.checkPermissionStatus()
        }
    }
    
    // MARK: - Master Notification Section
    
    private var masterNotificationSection: some View {
        Section(footer: Text(notificationManager.permissionStatusText)) {
            HStack {
                Image(systemName: "bell")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Enable Notifications")
                
                Spacer()
                
                Toggle("", isOn: $preferencesManager.enableNotifications)
                    .toggleStyle(SwitchToggleStyle(tint: UI.primary))
                    .disabled(!notificationManager.hasPermission)
            }
            
            if !notificationManager.hasPermission && preferencesManager.enableNotifications {
                Button("Open Settings") {
                    notificationManager.openSettings()
                }
                .foregroundColor(UI.primary)
            }
        }
    }
    
    // MARK: - Assignment Notification Section
    
    private var assignmentNotificationSection: some View {
        Section("Assignment Reminders") {
            NotificationToggleRow(
                title: "Assignment Due Reminders",
                description: "Get notified when assignments are due soon",
                icon: "calendar.badge.exclamationmark",
                isOn: $notificationManager.assignmentRemindersEnabled
            )
            
            if notificationManager.assignmentRemindersEnabled {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("Remind me")
                    
                    Spacer()
                    
                    Picker("Reminder Time", selection: $notificationManager.assignmentReminderTime) {
                        Text("1 hour before").tag(AssignmentReminderTime.oneHour)
                        Text("3 hours before").tag(AssignmentReminderTime.threeHours)
                        Text("1 day before").tag(AssignmentReminderTime.oneDay)
                        Text("2 days before").tag(AssignmentReminderTime.twoDays)
                        Text("1 week before").tag(AssignmentReminderTime.oneWeek)
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            
            NotificationToggleRow(
                title: "Grade Updates",
                description: "Notifications when grades are posted",
                icon: "graduationcap",
                isOn: $notificationManager.gradeUpdatesEnabled
            )
            
            NotificationToggleRow(
                title: "Priority Assignments",
                description: "Special alerts for high-weight assignments",
                icon: "exclamationmark.triangle",
                isOn: $notificationManager.priorityAssignmentsEnabled
            )
        }
    }
    
    // MARK: - Calendar Notification Section
    
    private var calendarNotificationSection: some View {
        Section("Calendar Events") {
            NotificationToggleRow(
                title: "Class Reminders",
                description: "Get reminded before classes start",
                icon: "bell.badge",
                isOn: $notificationManager.classRemindersEnabled
            )
            
            if notificationManager.classRemindersEnabled {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("Remind me")
                    
                    Spacer()
                    
                    Picker("Class Reminder Time", selection: $notificationManager.classReminderTime) {
                        Text("5 minutes before").tag(ClassReminderTime.fiveMinutes)
                        Text("10 minutes before").tag(ClassReminderTime.tenMinutes)
                        Text("15 minutes before").tag(ClassReminderTime.fifteenMinutes)
                        Text("30 minutes before").tag(ClassReminderTime.thirtyMinutes)
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            
            NotificationToggleRow(
                title: "Shared Calendar Updates",
                description: "When shared calendars are updated",
                icon: "person.2",
                isOn: $notificationManager.sharedCalendarUpdatesEnabled
            )
        }
    }
    
    // MARK: - Sync Notification Section
    
    private var syncNotificationSection: some View {
        Section("Data & Sync") {
            NotificationToggleRow(
                title: "Sync Status",
                description: "Notifications about data synchronization",
                icon: "icloud",
                isOn: $notificationManager.syncStatusEnabled
            )
            
            NotificationToggleRow(
                title: "Offline Mode",
                description: "Alerts when app goes offline",
                icon: "wifi.slash",
                isOn: $notificationManager.offlineModeEnabled
            )
            
            NotificationToggleRow(
                title: "Inactivity Reminders",
                description: "Reminders to update your progress",
                icon: "clock.badge.questionmark",
                isOn: $notificationManager.inactivityRemindersEnabled
            )
        }
    }
    
    // MARK: - Quiet Hours Section
    
    private var quietHoursSection: some View {
        Section("Quiet Hours") {
            HStack {
                Image(systemName: "moon")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Enable Quiet Hours")
                
                Spacer()
                
                Toggle("", isOn: $notificationManager.quietHoursEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: UI.primary))
            }
            
            if notificationManager.quietHoursEnabled {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("Start Time")
                    
                    Spacer()
                    
                    DatePicker("", selection: $notificationManager.quietHoursStart, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("End Time")
                    
                    Spacer()
                    
                    DatePicker("", selection: $notificationManager.quietHoursEnd, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
        }
    }
    
    // MARK: - Test Notification Section
    
    private var testNotificationSection: some View {
        Section("Test") {
            Button(action: {
                notificationManager.sendTestNotification()
            }) {
                HStack {
                    Image(systemName: "paperplane")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("Send Test Notification")
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Notification Toggle Row Component

struct NotificationToggleRow: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(UI.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: UI.primary))
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NotificationSettingsView()
}