//
//  DataExportView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/11/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var exportManager = DataExportManager()
    
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var exportedFileURL: URL?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 40))
                            .foregroundColor(UI.primary)
                        
                        Text("Export Your Data")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(UI.navy)
                        
                        Text("Download a copy of all your AceUp data including assignments, grades, calendars, and preferences.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    // Export Options
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What's included in your export:")
                            .font(.headline)
                            .foregroundColor(UI.navy)
                        
                        VStack(spacing: 12) {
                            ExportItemRow(
                                icon: "person.circle",
                                title: "Profile Information",
                                description: "Your name, email, university, and preferences",
                                isSelected: $exportManager.includeProfile
                            )
                            
                            ExportItemRow(
                                icon: "book",
                                title: "Academic Data",
                                description: "Courses, assignments, grades, and deadlines",
                                isSelected: $exportManager.includeAcademicData
                            )
                            
                            ExportItemRow(
                                icon: "calendar",
                                title: "Calendar Events",
                                description: "Personal and shared calendar events",
                                isSelected: $exportManager.includeCalendarData
                            )
                            
                            ExportItemRow(
                                icon: "gear",
                                title: "App Settings",
                                description: "Notification preferences and app configuration",
                                isSelected: $exportManager.includeSettings
                            )
                            
                            ExportItemRow(
                                icon: "chart.bar",
                                title: "Analytics Data",
                                description: "Study patterns and performance analytics (anonymized)",
                                isSelected: $exportManager.includeAnalytics
                            )
                        }
                    }
                    .padding()
                    
                    // Export Format
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Export Format")
                            .font(.headline)
                            .foregroundColor(UI.navy)
                        
                        VStack(spacing: 8) {
                            ForEach(DataExportFormat.allCases, id: \.self) { format in
                                HStack {
                                    Button(action: { exportManager.exportFormat = format }) {
                                        HStack {
                                            Image(systemName: exportManager.exportFormat == format ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(exportManager.exportFormat == format ? UI.primary : .secondary)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(format.displayName)
                                                    .foregroundColor(.primary)
                                                Text(format.description)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                    
                    // Privacy Notice
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.orange)
                            Text("Privacy Notice")
                                .font(.headline)
                                .foregroundColor(UI.navy)
                        }
                        
                        Text("Your exported data will be packaged securely and saved to your device. No data is transmitted to third parties during this process. The export file may contain sensitive academic information, so please store it securely.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Export Button
                    VStack(spacing: 16) {
                        Button(action: exportData) {
                            HStack {
                                if exportManager.isExporting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                }
                                Text(exportManager.isExporting ? "Preparing Export..." : "Export My Data")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(UI.primary)
                            .cornerRadius(12)
                        }
                        .disabled(exportManager.isExporting || !exportManager.hasSelections)
                        
                        if let progress = exportManager.exportProgress {
                            VStack(spacing: 8) {
                                ProgressView(value: progress.completedItems, total: progress.totalItems)
                                    .progressViewStyle(LinearProgressViewStyle(tint: UI.primary))
                                
                                Text(progress.currentTask)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Export Successful", isPresented: $showingSuccessAlert) {
            Button("Share") {
                if let url = exportedFileURL {
                    shareFile(url: url)
                }
            }
            Button("OK") { }
        } message: {
            Text("Your data has been exported successfully. The file has been saved to your device.")
        }
        .alert("Export Failed", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func exportData() {
        Task {
            do {
                let fileURL = try await exportManager.exportUserData()
                exportedFileURL = fileURL
                showingSuccessAlert = true
            } catch {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }
    
    private func shareFile(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// MARK: - Export Item Row

struct ExportItemRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isSelected: Bool
    
    var body: some View {
        Button(action: { isSelected.toggle() }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(UI.primary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isSelected)
                    .labelsHidden()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Data Export Manager

@MainActor
class DataExportManager: ObservableObject {
    @Published var includeProfile = true
    @Published var includeAcademicData = true
    @Published var includeCalendarData = true
    @Published var includeSettings = true
    @Published var includeAnalytics = false
    @Published var exportFormat = DataExportFormat.json
    @Published var isExporting = false
    @Published var exportProgress: ExportProgress?
    
    var hasSelections: Bool {
        includeProfile || includeAcademicData || includeCalendarData || includeSettings || includeAnalytics
    }
    
    func exportUserData() async throws -> URL {
        isExporting = true
        exportProgress = ExportProgress(totalItems: 5, completedItems: 0, currentTask: "Preparing export...")
        
        defer {
            isExporting = false
            exportProgress = nil
        }
        
        var exportData: [String: Any] = [:]
        exportData["exportDate"] = ISO8601DateFormatter().string(from: Date())
        exportData["exportFormat"] = exportFormat.rawValue
        exportData["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        if includeProfile {
            exportProgress?.currentTask = "Exporting profile data..."
            exportData["profile"] = try await exportProfileData()
            exportProgress?.completedItems += 1
        }
        
        if includeAcademicData {
            exportProgress?.currentTask = "Exporting academic data..."
            exportData["academic"] = try await exportAcademicData()
            exportProgress?.completedItems += 1
        }
        
        if includeCalendarData {
            exportProgress?.currentTask = "Exporting calendar data..."
            exportData["calendar"] = try await exportCalendarData()
            exportProgress?.completedItems += 1
        }
        
        if includeSettings {
            exportProgress?.currentTask = "Exporting settings..."
            exportData["settings"] = try await exportSettingsData()
            exportProgress?.completedItems += 1
        }
        
        if includeAnalytics {
            exportProgress?.currentTask = "Exporting analytics..."
            exportData["analytics"] = try await exportAnalyticsData()
            exportProgress?.completedItems += 1
        }
        
        exportProgress?.currentTask = "Finalizing export..."
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = DateFormatter().string(from: Date()).replacingOccurrences(of: "/", with: "-")
        let filename = "AceUp_Export_\(timestamp).\(exportFormat.fileExtension)"
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        switch exportFormat {
        case .json:
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            try jsonData.write(to: fileURL)
        case .csv:
            let csvData = try convertToCSV(data: exportData)
            try csvData.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        return fileURL
    }
    
    private func exportProfileData() async throws -> [String: Any] {
        // Simulate profile data export
        return [
            "displayName": "Sample User",
            "email": "user@example.com",
            "university": "Sample University",
            "studyProgram": "Computer Science",
            "academicYear": "Senior"
        ]
    }
    
    private func exportAcademicData() async throws -> [String: Any] {
        // Simulate academic data export
        return [
            "courses": [],
            "assignments": [],
            "grades": []
        ]
    }
    
    private func exportCalendarData() async throws -> [String: Any] {
        // Simulate calendar data export
        return [
            "events": [],
            "sharedCalendars": []
        ]
    }
    
    private func exportSettingsData() async throws -> [String: Any] {
        // Simulate settings export
        return [
            "notifications": [:],
            "preferences": [:]
        ]
    }
    
    private func exportAnalyticsData() async throws -> [String: Any] {
        // Simulate analytics export
        return [
            "studyPatterns": [],
            "performanceMetrics": []
        ]
    }
    
    private func convertToCSV(data: [String: Any]) throws -> String {
        // Simple CSV conversion - in a real app this would be more sophisticated
        var csv = "Category,Key,Value\n"
        
        func flatten(dict: [String: Any], prefix: String = "") {
            for (key, value) in dict {
                let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"
                if let subDict = value as? [String: Any] {
                    flatten(dict: subDict, prefix: fullKey)
                } else {
                    csv += "\(prefix),\(key),\(value)\n"
                }
            }
        }
        
        flatten(dict: data)
        return csv
    }
}

// MARK: - Supporting Types

enum DataExportFormat: String, CaseIterable {
    case json = "json"
    case csv = "csv"
    
    var displayName: String {
        switch self {
        case .json: return "JSON Format"
        case .csv: return "CSV Format"
        }
    }
    
    var description: String {
        switch self {
        case .json: return "Structured format, easy to import into other apps"
        case .csv: return "Spreadsheet format, compatible with Excel and Google Sheets"
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
}

struct ExportProgress {
    let totalItems: Double
    var completedItems: Double
    var currentTask: String
}

#Preview {
    DataExportView()
}