//
//  OfflineSyncSummaryView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import SwiftUI

struct OfflineSyncSummaryView: View {
    @StateObject private var offlineManager = OfflineManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Connection Status Header
                    connectionStatusHeader
                    
                    // Sync Statistics
                    syncStatisticsSection
                    
                    // Data Categories
                    dataCategoriesSection
                    
                    // Sync Actions
                    syncActionsSection
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Offline & Sync")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Connection Status Header
    private var connectionStatusHeader: some View {
        VStack(spacing: 16) {
            // Connection Icon and Status
            VStack(spacing: 8) {
                Image(systemName: offlineManager.isOnline ? "wifi" : "wifi.slash")
                    .font(.system(size: 60))
                    .foregroundColor(offlineManager.isOnline ? .green : .gray)
                
                Text(offlineManager.isOnline ? "Connected" : "Offline")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(offlineManager.isOnline ? .green : .gray)
                
                if offlineManager.isOnline {
                    Text("via \(offlineManager.connectionDescription)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Current Status
            VStack(spacing: 4) {
                Text(syncStatusDescription)
                    .font(.headline)
                    .foregroundColor(syncStatusColor)
                
                if let lastSync = offlineManager.lastSyncDate {
                    Text("Last synced \(DateFormatter.relativeTime.string(from: lastSync))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Never synced")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Sync Statistics
    private var syncStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sync Statistics")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                OfflineStatCard(
                    title: "Pending Operations",
                    value: "\(offlineManager.pendingOperationsCount)",
                    icon: "clock",
                    color: offlineManager.pendingOperationsCount > 0 ? .orange : .green
                )
                
                OfflineStatCard(
                    title: "Sync Status",
                    value: syncStatusText,
                    icon: syncStatusIcon,
                    color: syncStatusColor
                )
            }
        }
    }
    
    // MARK: - Data Categories
    private var dataCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Categories")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            VStack(spacing: 12) {
                ForEach(DataType.allCases, id: \.self) { dataType in
                    DataCategoryRow(dataType: dataType)
                }
            }
        }
    }
    
    // MARK: - Sync Actions
    private var syncActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sync Actions")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            VStack(spacing: 12) {
                // Force Sync Button
                if offlineManager.isOnline && offlineManager.pendingOperationsCount > 0 {
                    Button(action: {
                        offlineManager.forceSyncNow()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.white)
                            Text("Sync Now")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(UI.primary)
                        .cornerRadius(12)
                    }
                }
                
                // Clear Operations Button (Debug/Admin only)
                if offlineManager.pendingOperationsCount > 0 {
                    Button(action: {
                        offlineManager.clearAllPendingOperations()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Pending Operations")
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                
                // Offline Mode Info
                InfoCard(
                    title: "Offline Mode",
                    description: "Your changes are saved locally and will be synced when you're back online. All core features work offline.",
                    icon: "info.circle"
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    private var syncStatusDescription: String {
        switch offlineManager.syncStatus {
        case .synced:
            return "All data synced"
        case .pending:
            return "Sync pending"
        case .syncing:
            return "Syncing in progress"
        case .failed:
            return "Sync failed"
        case .offline:
            return "Working offline"
        }
    }
    
    private var syncStatusText: String {
        switch offlineManager.syncStatus {
        case .synced: return "Synced"
        case .pending: return "Pending"
        case .syncing: return "Syncing"
        case .failed: return "Failed"
        case .offline: return "Offline"
        }
    }
    
    private var syncStatusIcon: String {
        switch offlineManager.syncStatus {
        case .synced: return "checkmark.circle"
        case .pending: return "clock"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .failed: return "exclamationmark.triangle"
        case .offline: return "wifi.slash"
        }
    }
    
    private var syncStatusColor: Color {
        switch offlineManager.syncStatus {
        case .synced: return .green
        case .pending: return .orange
        case .syncing: return .blue
        case .failed: return .red
        case .offline: return .gray
        }
    }
}

// MARK: - Supporting Views

struct OfflineStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

struct DataCategoryRow: View {
    let dataType: DataType
    @StateObject private var offlineManager = OfflineManager.shared
    
    var body: some View {
        HStack {
            Image(systemName: iconForDataType(dataType))
                .foregroundColor(UI.primary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(dataType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                Text(descriptionForDataType(dataType))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(statusColorForDataType(dataType))
                .frame(width: 8, height: 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private func iconForDataType(_ dataType: DataType) -> String {
        switch dataType {
        case .assignment: return "doc.text"
        case .course: return "book"
        case .teacher: return "person"
        case .calendarEvent: return "calendar"
        case .userAvailability: return "clock"
        case .workloadAnalysis: return "chart.bar"
        case .sharedCalendar: return "person.2"
        }
    }
    
    private func descriptionForDataType(_ dataType: DataType) -> String {
        switch dataType {
        case .assignment: return "Homework and projects"
        case .course: return "Class information"
        case .teacher: return "Instructor details"
        case .calendarEvent: return "Calendar entries"
        case .userAvailability: return "Time availability"
        case .workloadAnalysis: return "Analysis reports"
        case .sharedCalendar: return "Group calendars"
        }
    }
    
    private func statusColorForDataType(_ dataType: DataType) -> Color {
        // In a real app, you'd check the actual sync status for each data type
        return offlineManager.isOnline ? .green : .orange
    }
}

struct InfoCard: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(UI.primary)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(UI.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(UI.primary.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let relativeTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
}

#Preview {
    OfflineSyncSummaryView()
}