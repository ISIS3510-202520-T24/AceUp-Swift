//
//  OfflineViews.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import SwiftUI
import Combine

// MARK: - Offline Status Indicator
struct OfflineStatusIndicator: View {
    @StateObject private var offlineManager = OfflineManager.shared
    @State private var showingDetails = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Connection Status Icon
            Image(systemName: connectionIcon)
                .foregroundColor(connectionColor)
                .font(.caption)
            
            // Status Text
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(connectionColor)
            
            // Pending Operations Badge
            if offlineManager.pendingOperationsCount > 0 {
                Text("\(offlineManager.pendingOperationsCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
            
            // Sync Button
            if offlineManager.pendingOperationsCount > 0 && offlineManager.isOnline {
                Button(action: {
                    offlineManager.forceSyncNow()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(connectionColor.opacity(0.1))
        )
        .onTapGesture {
            showingDetails.toggle()
        }
        .sheet(isPresented: $showingDetails) {
            OfflineStatusDetailView()
        }
    }
    
    private var connectionIcon: String {
        switch offlineManager.syncStatus {
        case .synced:
            return "checkmark.circle.fill"
        case .pending:
            return "clock.fill"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .offline:
            return "wifi.slash"
        }
    }
    
    private var connectionColor: Color {
        switch offlineManager.syncStatus {
        case .synced:
            return .green
        case .pending:
            return .orange
        case .syncing:
            return .blue
        case .failed:
            return .red
        case .offline:
            return .gray
        }
    }
    
    private var statusText: String {
        switch offlineManager.syncStatus {
        case .synced:
            return "Synced"
        case .pending:
            return "Pending"
        case .syncing:
            return "Syncing..."
        case .failed:
            return "Sync Failed"
        case .offline:
            return "Offline"
        }
    }
}

// MARK: - Offline Status Detail View
struct OfflineStatusDetailView: View {
    @StateObject private var offlineManager = OfflineManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: offlineManager.isOnline ? "wifi" : "wifi.slash")
                        .font(.system(size: 50))
                        .foregroundColor(offlineManager.isOnline ? .green : .gray)
                    
                    Text(offlineManager.isOnline ? "Connected" : "Offline")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if offlineManager.isOnline {
                        Text(offlineManager.connectionDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Sync Status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sync Status")
                        .font(.headline)
                        .foregroundColor(UI.navy)
                    
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Status: \(statusDescription)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let lastSync = offlineManager.lastSyncDate {
                                Text("Last sync: \(DateFormatter.relative.string(from: lastSync))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                }
                
                // Pending Operations
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Pending Operations")
                            .font(.headline)
                            .foregroundColor(UI.navy)
                        
                        Spacer()
                        
                        Text("\(offlineManager.pendingOperationsCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    
                    if offlineManager.pendingOperationsCount > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Changes will be synced when connection is restored")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if offlineManager.isOnline {
                                Button("Sync Now") {
                                    offlineManager.forceSyncNow()
                                }
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding()
                                .background(UI.primary)
                                .cornerRadius(10)
                            }
                        }
                    } else {
                        Text("All changes are synced")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sync Status")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
    
    private var statusDescription: String {
        switch offlineManager.syncStatus {
        case .synced:
            return "All data synced"
        case .pending:
            return "Waiting to sync"
        case .syncing:
            return "Syncing in progress"
        case .failed:
            return "Sync failed - will retry"
        case .offline:
            return "No internet connection"
        }
    }
}

// MARK: - Offline-Aware List View
struct OfflineAwareListView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let isOfflineMode: Bool
    let syncStatus: SyncStatus
    let content: (Item) -> Content
    
    init(
        items: [Item],
        isOfflineMode: Bool,
        syncStatus: SyncStatus,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.isOfflineMode = isOfflineMode
        self.syncStatus = syncStatus
        self.content = content
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Offline Mode Header
            if isOfflineMode {
                OfflineModeHeader(syncStatus: syncStatus)
            }
            
            // List Content
            if items.isEmpty {
                EmptyOfflineStateView(isOfflineMode: isOfflineMode)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        content(item)
                    }
                }
            }
        }
    }
}

// MARK: - Offline Mode Header
struct OfflineModeHeader: View {
    let syncStatus: SyncStatus
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline Mode")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                
                Text("Changes will sync when online")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if syncStatus == .syncing {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.1))
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// MARK: - Empty Offline State
struct EmptyOfflineStateView: View {
    let isOfflineMode: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isOfflineMode ? "wifi.slash" : "tray")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text(isOfflineMode ? "No Offline Data" : "No Data Available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(isOfflineMode 
                 ? "Data will appear here when you're back online"
                 : "Add some items to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }
}

// MARK: - Offline-Aware Button
struct OfflineAwareButton: View {
    let title: String
    let isOfflineMode: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if isOfflineMode {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isOfflineMode ? Color.orange : UI.primary)
            .cornerRadius(10)
        }
        .disabled(false) // Allow offline operations
    }
}

// MARK: - Sync Progress View
struct SyncProgressView: View {
    @StateObject private var offlineManager = OfflineManager.shared
    
    var body: some View {
        if offlineManager.syncStatus == .syncing {
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text("Syncing changes...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let relative: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        OfflineStatusIndicator()
        
        OfflineAwareButton(
            title: "Add Assignment",
            isOfflineMode: true,
            action: {}
        )
        
        SyncProgressView()
    }
    .padding()
}