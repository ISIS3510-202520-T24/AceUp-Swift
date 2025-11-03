//
//  AcademicPreferencesView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/11/25.
//

import SwiftUI

struct AcademicPreferencesView: View {
    @StateObject private var preferencesManager = UserPreferencesManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempGradingScale: GradingScale = .percentage
    @State private var tempGPAScale: GPAScale = .fourPoint
    @State private var tempDefaultCredits: Int = 3
    @State private var tempSemesterStartDate = Date()
    @State private var tempSemesterEndDate = Date()
    
    var body: some View {
        NavigationView {
            List {
                // Assignment Preferences
                assignmentPreferencesSection
                
                // Grading Preferences
                gradingPreferencesSection
                
                // Semester Settings
                semesterSettingsSection
                
                // Workload Analysis
                workloadAnalysisSection
                
                // Smart Features
                smartFeaturesSection
            }
            .navigationTitle("Academic Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    // MARK: - Assignment Preferences Section
    
    private var assignmentPreferencesSection: some View {
        Section("Assignment Defaults") {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Default Duration")
                
                Spacer()
                
                Stepper(
                    "\(String(format: "%.1f", preferencesManager.defaultAssignmentDuration)) hours",
                    value: $preferencesManager.defaultAssignmentDuration,
                    in: 0.5...10.0,
                    step: 0.5
                )
            }
            
            HStack {
                Image(systemName: "arrow.up.circle")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Show Overdue First")
                
                Spacer()
                
                Toggle("", isOn: $preferencesManager.showOverdueFirst)
                    .toggleStyle(SwitchToggleStyle(tint: UI.primary))
            }
            
            HStack {
                Image(systemName: "hand.tap")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Quick Actions")
                
                Spacer()
                
                Toggle("", isOn: $preferencesManager.enableQuickActions)
                    .toggleStyle(SwitchToggleStyle(tint: UI.primary))
            }
            
            HStack {
                Image(systemName: "paintpalette")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Default Course Color")
                
                Spacer()
                
                ColorPicker("", selection: Binding(
                    get: { Color(hex: preferencesManager.defaultCourseColor) },
                    set: { preferencesManager.defaultCourseColor = $0.toHex() }
                ))
                .labelsHidden()
            }
        }
    }
    
    // MARK: - Grading Preferences Section
    
    private var gradingPreferencesSection: some View {
        Section("Grading System") {
            HStack {
                Image(systemName: "percent")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Grading Scale")
                
                Spacer()
                
                Picker("Grading Scale", selection: $tempGradingScale) {
                    Text("Percentage (0-100)").tag(GradingScale.percentage)
                    Text("Letter Grades (A-F)").tag(GradingScale.letter)
                    Text("Points System").tag(GradingScale.points)
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            HStack {
                Image(systemName: "graduationcap")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("GPA Scale")
                
                Spacer()
                
                Picker("GPA Scale", selection: $tempGPAScale) {
                    Text("4.0 Scale").tag(GPAScale.fourPoint)
                    Text("5.0 Scale").tag(GPAScale.fivePoint)
                    Text("10.0 Scale").tag(GPAScale.tenPoint)
                    Text("Percentage").tag(GPAScale.percentage)
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            HStack {
                Image(systemName: "number")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Default Credits per Course")
                
                Spacer()
                
                Stepper(
                    "\(tempDefaultCredits) credits",
                    value: $tempDefaultCredits,
                    in: 1...10
                )
            }
        }
    }
    
    // MARK: - Semester Settings Section
    
    private var semesterSettingsSection: some View {
        Section("Semester Settings") {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Semester Start")
                
                Spacer()
                
                DatePicker("", selection: $tempSemesterStartDate, displayedComponents: .date)
                    .labelsHidden()
            }
            
            HStack {
                Image(systemName: "calendar.badge.minus")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                Text("Semester End")
                
                Spacer()
                
                DatePicker("", selection: $tempSemesterEndDate, displayedComponents: .date)
                    .labelsHidden()
            }
            
            AcademicCalendarRow(
                title: "Academic Calendar",
                description: "Customize holidays and break periods"
            )
        }
    }
    
    // MARK: - Workload Analysis Section
    
    private var workloadAnalysisSection: some View {
        Section("Workload Analysis") {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Workload Analysis")
                    Text("Track and analyze your academic workload")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $preferencesManager.workloadAnalysisEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: UI.primary))
            }
            
            if preferencesManager.workloadAnalysisEnabled {
                WorkloadSettingRow(
                    title: "Weekly Analysis",
                    description: "Get weekly workload reports",
                    isEnabled: true
                )
                
                WorkloadSettingRow(
                    title: "Stress Level Tracking",
                    description: "Track periods of high academic stress",
                    isEnabled: true
                )
                
                WorkloadSettingRow(
                    title: "Productivity Insights",
                    description: "Analyze your most productive times",
                    isEnabled: true
                )
            }
        }
    }
    
    // MARK: - Smart Features Section
    
    private var smartFeaturesSection: some View {
        Section("Smart Features") {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Smart Suggestions")
                    Text("AI-powered study recommendations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $preferencesManager.enableSmartSuggestions)
                    .toggleStyle(SwitchToggleStyle(tint: UI.primary))
            }
            
            SmartFeatureRow(
                title: "Priority Scoring",
                description: "Automatically calculate assignment priority",
                icon: "exclamationmark.triangle"
            )
            
            SmartFeatureRow(
                title: "Study Time Estimation",
                description: "Estimate time needed for assignments",
                icon: "clock.badge.questionmark"
            )
            
            SmartFeatureRow(
                title: "Deadline Predictions",
                description: "Predict optimal completion dates",
                icon: "calendar.badge.clock"
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCurrentSettings() {
        // Load current academic settings
        tempGradingScale = .percentage // Default, could be loaded from preferences
        tempGPAScale = .fourPoint // Default, could be loaded from preferences
        tempDefaultCredits = 3 // Default, could be loaded from preferences
        tempSemesterStartDate = Date()
        tempSemesterEndDate = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
    }
}

// MARK: - Component Views

struct AcademicCalendarRow: View {
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(UI.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

struct WorkloadSettingRow: View {
    let title: String
    let description: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isEnabled ? UI.primary : .secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct SmartFeatureRow: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(UI.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

// MARK: - Supporting Enums

enum GradingScale: String, CaseIterable {
    case percentage = "percentage"
    case letter = "letter"
    case points = "points"
    
    var displayName: String {
        switch self {
        case .percentage: return "Percentage (0-100)"
        case .letter: return "Letter Grades (A-F)"
        case .points: return "Points System"
        }
    }
}

enum GPAScale: String, CaseIterable {
    case fourPoint = "4.0"
    case fivePoint = "5.0"
    case tenPoint = "10.0"
    case percentage = "percentage"
    
    var displayName: String {
        switch self {
        case .fourPoint: return "4.0 Scale"
        case .fivePoint: return "5.0 Scale"
        case .tenPoint: return "10.0 Scale"
        case .percentage: return "Percentage"
        }
    }
}

#Preview {
    AcademicPreferencesView()
}