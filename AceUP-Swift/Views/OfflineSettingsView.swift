//
//  OfflineSettingsView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/11/25.
//

import SwiftUI

struct OfflineSettingsView: View {
    @ObservedObject private var offlineManager = OfflineManager.shared
    @State private var showingClearAlert = false
    @State private var showingRefreshAlert = false
    
    var body: some View {
        List {
            // Network Status Section
            Section {
                HStack {
                    Image(systemName: "wifi")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Network Connection")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(offlineManager.isOnline ? "Connected" : "Offline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if offlineManager.isOnline {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 4)
                
                // Test Connection Button for debugging
                Button(action: {
                    print("🧪 Manual network refresh triggered")
                    offlineManager.refreshNetworkStatus()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Test Network Connection")
                                .foregroundColor(.blue)
                            
                            Text("Force check network status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            } header: {
                Text("Network Status")
            }
            
            // Offline Capability Section
            Section {
                HStack {
                    Image(systemName: offlineManager.offlineCapabilityStatus.icon)
                        .foregroundColor(Color(hex: offlineManager.offlineCapabilityStatus.color))
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Offline Capability")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(offlineManager.offlineCapabilityStatus.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if offlineManager.canWorkOffline {
                        Text("\(offlineManager.getDaysUntilStale()) days left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                if offlineManager.hasOfflineData {
                    VStack(spacing: 12) {
                        OfflineDataRow(
                            title: "Cached Data Size",
                            value: offlineManager.cachedDataSize,
                            icon: "internaldrive"
                        )
                        
                        OfflineDataRow(
                            title: "Last Sync",
                            value: offlineManager.getOfflineDataAge(),
                            icon: "arrow.triangle.2.circlepath"
                        )
                        
                        if offlineManager.pendingSyncOperations > 0 {
                            OfflineDataRow(
                                title: "Pending Syncs",
                                value: "\(offlineManager.pendingSyncOperations) operations",
                                icon: "clock.badge.exclamationmark"
                            )
                        }
                    }
                }
            } header: {
                Text("Offline Data")
            } footer: {
                if offlineManager.hasOfflineData {
                    Text("You can use AceUp offline for up to 7 days with cached data. After that, you'll need to connect to refresh your data.")
                } else {
                    Text("No offline data available. Connect to the internet and refresh cache to enable offline functionality.")
                }
            }
            
            // Cache Management Section
            Section {
                Button(action: { 
                    if offlineManager.isOnline {
                        showingRefreshAlert = true
                    }
                }) {
                    HStack {
                        if offlineManager.isRefreshingCache {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 20)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(offlineManager.isOnline ? UI.primary : .gray)
                                .frame(width: 20)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Refresh Cache")
                                .foregroundColor(offlineManager.isOnline ? .primary : .gray)
                            
                            Text("Download latest data for offline use")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .disabled(!offlineManager.isOnline || offlineManager.isRefreshingCache)
                
                if offlineManager.hasOfflineData {
                    Button(action: { showingClearAlert = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clear Offline Data")
                                    .foregroundColor(.red)
                                
                                Text("Remove all cached data to free up space")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
            } header: {
                Text("Cache Management")
            }
            
            // Sync Diagnostics Section
            if offlineManager.pendingSyncOperations > 0 || offlineManager.lastSyncDate != nil {
                Section {
                    if let lastSync = offlineManager.lastSyncDate {
                        OfflineDataRow(
                            title: "Last Successful Sync",
                            value: RelativeDateTimeFormatter().localizedString(for: lastSync, relativeTo: Date()),
                            icon: "checkmark.circle"
                        )
                    }
                    
                    if offlineManager.pendingSyncOperations > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pending Operations")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("\(offlineManager.pendingSyncOperations) operations waiting to sync")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if offlineManager.isOnline {
                                Button("Sync Now") {
                                    Task {
                                        await offlineManager.performPendingSyncOperations()
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(UI.primary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Sync Diagnostics")
                } footer: {
                    Text("Sync operations will automatically resume when you reconnect to the internet.")
                }
            }
        }
        .navigationTitle("Offline Management")
        .navigationBarTitleDisplayMode(.large)
        .alert("Refresh Cache", isPresented: $showingRefreshAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Refresh") {
                Task {
                    await offlineManager.refreshCache()
                }
            }
        } message: {
            Text("This will download the latest data for offline use. It may take a few moments depending on your connection.")
        }
        .alert("Clear Offline Data", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await offlineManager.clearCache()
                }
            }
        } message: {
            Text("This will remove all cached data. You'll need an internet connection to use the app until data is cached again.")
        }
    }
}

// MARK: - Offline Data Row Component

struct OfflineDataRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(UI.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Offline Banner Component

struct OfflineBannerView: View {
    @ObservedObject private var offlineManager = OfflineManager.shared
    
    var body: some View {
        Group {
            if !offlineManager.isOnline {
                // Offline banner
                offlineBanner
                    .id("offline-banner")
            } else if offlineManager.connectionRestoredRecently {
                // Connection restored banner (temporary)
                connectedBanner
                    .id("connected-banner")
            }
        }
        .animation(.easeInOut(duration: 0.4), value: offlineManager.isOnline)
        .animation(.easeInOut(duration: 0.4), value: offlineManager.connectionRestoredRecently)
        .onReceive(offlineManager.$isOnline) { isOnline in
            print("🔔 Banner received isOnline update: \(isOnline)")
        }
        .onReceive(offlineManager.$connectionRestoredRecently) { restored in
            print("🔔 Banner received connectionRestoredRecently update: \(restored)")
        }
    }
    
    private var offlineBanner: some View {
        HStack {
            Image(systemName: offlineManager.canWorkOffline ? "wifi.slash" : "exclamationmark.triangle")
                .foregroundColor(.white)
                .font(.caption)
            
            Text(offlineManager.canWorkOffline ? "Working offline" : "Limited functionality")
                .font(.caption)
                .foregroundColor(.white)
                .fontWeight(.medium)
            
            Spacer()
            
            if offlineManager.pendingSyncOperations > 0 {
                Text("\(offlineManager.pendingSyncOperations) pending")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(offlineManager.canWorkOffline ? Color.orange : Color.red)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }
    
    private var connectedBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
                .font(.caption)
            
            Text("Connected")
                .font(.caption)
                .foregroundColor(.white)
                .fontWeight(.medium)
            
            Spacer()
            
            if let connectionType = offlineManager.connectionType {
                Text(connectionType.displayName)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.green)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }
}

#Preview {
    NavigationView {
        OfflineSettingsView()
    }
}