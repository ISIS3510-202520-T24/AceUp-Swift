//
//  ImportExportSettingsView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/11/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportExportSettingsView: View {
    @StateObject private var settingsViewModel = UserSettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingExportSuccess = false
    @State private var showingImportPicker = false
    @State private var showingResetAlert = false
    @State private var exportedFileURL: URL?
    @State private var importError: String?
    @State private var exportError: String?
    
    var body: some View {
        NavigationView {
            List {
                // Export Section
                exportSection
                
                // Import Section
                importSection
                
                // Reset Section
                resetSection
                
                // Data Summary
                dataSummarySection
            }
            .navigationTitle("Import/Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert("Settings Exported", isPresented: $showingExportSuccess) {
            Button("Share") {
                if let url = exportedFileURL {
                    shareFile(url)
                }
            }
            Button("OK") { }
        } message: {
            Text("Your settings have been exported successfully. You can share or save the file to import on another device.")
        }
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settingsViewModel.resetSettings()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section("Export Settings") {
            Button(action: { exportSettings() }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export All Settings")
                        Text("Create a backup file of all your preferences")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if settingsViewModel.isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(settingsViewModel.isExporting)
            .buttonStyle(.plain)
            
            ExportOptionRow(
                title: "User Profile",
                description: "Personal information and preferences",
                icon: "person.crop.circle"
            )
            
            ExportOptionRow(
                title: "Academic Settings",
                description: "Grading scales, course defaults",
                icon: "graduationcap"
            )
            
            ExportOptionRow(
                title: "Notification Preferences",
                description: "All notification settings",
                icon: "bell"
            )
            
            ExportOptionRow(
                title: "App Preferences",
                description: "Theme, language, and sync settings",
                icon: "gear"
            )
            
            if let exportError = exportError {
                Text(exportError)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Import Section
    
    private var importSection: some View {
        Section("Import Settings") {
            Button(action: { showingImportPicker = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import Settings File")
                        Text("Restore settings from a backup file")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if settingsViewModel.isImporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(settingsViewModel.isImporting)
            .buttonStyle(.plain)
            
            if let importError = importError {
                Text(importError)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Import Guidelines")
                    .font(.headline)
                    .foregroundColor(UI.navy)
                
                ImportGuidelineRow(text: "Only import files exported from AceUp")
                ImportGuidelineRow(text: "Importing will overwrite current settings")
                ImportGuidelineRow(text: "A backup will be created automatically")
                ImportGuidelineRow(text: "App will restart after import")
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Reset Section
    
    private var resetSection: some View {
        Section("Reset") {
            Button(action: { showingResetAlert = true }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.red)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset to Defaults")
                            .foregroundColor(.red)
                        Text("Restore all settings to default values")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Data Summary Section
    
    private var dataSummarySection: some View {
        Section("Data Summary") {
            DataSummaryRow(
                title: "Settings Categories",
                value: "8 categories",
                icon: "folder"
            )
            
            DataSummaryRow(
                title: "User Preferences",
                value: "25+ settings",
                icon: "slider.horizontal.3"
            )
            
            DataSummaryRow(
                title: "Last Export",
                value: lastExportDate,
                icon: "clock"
            )
            
            DataSummaryRow(
                title: "File Format",
                value: "JSON (.json)",
                icon: "doc.text"
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var lastExportDate: String {
        if let lastExport = UserDefaults.standard.object(forKey: "lastSettingsExport") as? Date {
            let formatter = RelativeDateTimeFormatter()
            return formatter.localizedString(for: lastExport, relativeTo: Date())
        }
        return "Never"
    }
    
    // MARK: - Methods
    
    private func exportSettings() {
        Task {
            do {
                exportError = nil
                let url = try await settingsViewModel.exportSettingsWithFeedback()
                exportedFileURL = url
                showingExportSuccess = true
                
                // Save export timestamp
                UserDefaults.standard.set(Date(), forKey: "lastSettingsExport")
            } catch {
                exportError = "Export failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                do {
                    importError = nil
                    try await settingsViewModel.importSettingsWithFeedback(from: url)
                    dismiss()
                } catch {
                    importError = "Import failed: \(error.localizedDescription)"
                }
            }
        case .failure(let error):
            importError = "File selection failed: \(error.localizedDescription)"
        }
    }
    
    private func shareFile(_ url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Component Views

struct ExportOptionRow: View {
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
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding(.vertical, 2)
    }
}

struct ImportGuidelineRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(UI.primary)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct DataSummaryRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(UI.primary)
                .frame(width: 20)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Enhanced Settings View Model

extension UserSettingsViewModel {
    func exportSettingsWithFeedback() async throws -> URL {
        await MainActor.run {
            isExporting = true
        }
        
        defer {
            Task { @MainActor in
                isExporting = false
            }
        }
        
        // Create enhanced export data
        let exportData = createEnhancedExportData()
        
        // Generate filename with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "AceUp_Settings_\(timestamp).json"
        
        // Get documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportURL = documentsPath.appendingPathComponent(filename)
        
        // Write data
        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        try jsonData.write(to: exportURL)
        
        return exportURL
    }
    
    func importSettingsWithFeedback(from url: URL) async throws {
        await MainActor.run {
            isImporting = true
        }
        
        defer {
            Task { @MainActor in
                isImporting = false
            }
        }
        
        // Read and validate file
        let data = try Data(contentsOf: url)
        guard let importData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw ImportError.invalidFormat
        }
        
        // Validate file structure
        try validateImportData(importData)
        
        // Create backup before import
        try await createBackupBeforeImport()
        
        // Import settings
        if let settings = importData["settings"] as? [String: Any] {
            await MainActor.run {
                preferences.importPreferences(settings)
            }
        }
        
        // Import additional data if present
        if let profileData = importData["profile"] as? [String: Any] {
            await importProfileData(profileData)
        }
    }
    
    private func createEnhancedExportData() -> [String: Any] {
        return [
            "version": "1.0",
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "settings": preferences.exportPreferences(),
            "profile": UserProfileManager.shared.exportProfileData(),
            "metadata": [
                "deviceModel": UIDevice.current.model,
                "systemVersion": UIDevice.current.systemVersion,
                "exportType": "full"
            ]
        ]
    }
    
    private func validateImportData(_ data: [String: Any]) throws {
        guard let version = data["version"] as? String else {
            throw ImportError.missingVersion
        }
        
        guard version == "1.0" else {
            throw ImportError.unsupportedVersion(version)
        }
        
        guard data["settings"] is [String: Any] else {
            throw ImportError.invalidSettings
        }
    }
    
    private func createBackupBeforeImport() async throws {
        let backupData = createEnhancedExportData()
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let backupURL = documentsPath.appendingPathComponent("AceUp_Backup_Before_Import.json")
        
        let jsonData = try JSONSerialization.data(withJSONObject: backupData, options: .prettyPrinted)
        try jsonData.write(to: backupURL)
    }
    
    private func importProfileData(_ profileData: [String: Any]) async {
        // Import profile data if UserProfileManager supports it
        // This would be implemented based on the profile manager's capabilities
    }
}

enum ImportError: LocalizedError {
    case invalidFormat
    case missingVersion
    case unsupportedVersion(String)
    case invalidSettings
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "The selected file is not a valid AceUp settings file."
        case .missingVersion:
            return "The settings file is missing version information."
        case .unsupportedVersion(let version):
            return "Settings file version \(version) is not supported."
        case .invalidSettings:
            return "The settings data in the file is corrupted or invalid."
        }
    }
}

#Preview {
    ImportExportSettingsView()
}