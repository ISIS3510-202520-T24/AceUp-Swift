//
//  OfflineManager.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 7/10/25.
//

import Foundation
import Network
import Combine
import SwiftUI
import CoreData

/// Manages offline functionality and data caching for the app
/// Ensures the app works seamlessly even without internet connection
@MainActor
class OfflineManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = OfflineManager()
    
    // MARK: - Published Properties
    
    @Published var isOnline = true
    @Published var hasOfflineData = false
    @Published var offlineDataAge: TimeInterval = 0
    @Published var canWorkOffline = false
    
    // MARK: - Private Properties
    
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "OfflineManagerNetwork")
    private let persistenceController: PersistenceController
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        self.persistenceController = PersistenceController.shared
        setupNetworkMonitoring()
        checkOfflineDataAvailability()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Check if the app can function properly offline
    func canFunctionOffline() -> Bool {
        return hasOfflineData && offlineDataAge < 604800 // 7 days
    }
    
    /// Get offline data status
    func getOfflineStatus() -> OfflineStatus {
        return OfflineStatus(
            isOnline: isOnline,
            hasOfflineData: hasOfflineData,
            dataAge: offlineDataAge,
            canWorkOffline: canWorkOffline
        )
    }
    
    /// Prepare app for offline usage
    func prepareForOffline() async {
        // Ensure all critical data is cached locally
        await cacheEssentialData()
        
        // Update offline availability
        checkOfflineDataAvailability()
    }
    
    /// Handle network restoration
    func handleNetworkRestoration() async {
        // Sync pending changes when back online
        await DataSynchronizationManager.shared.performIncrementalSync()
        
        // Update offline data
        await cacheEssentialData()
    }
    
    /// Get offline message for UI
    func getOfflineMessage() -> String {
        if isOnline {
            return "Connected"
        } else if canWorkOffline {
            return "Working offline with cached data"
        } else {
            return "Limited functionality - no cached data available"
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                let wasOnline = self.isOnline
                self.isOnline = path.status == .satisfied
                
                // Handle network state changes
                if !wasOnline && path.status == .satisfied {
                    // Just came back online
                    await self.handleNetworkRestoration()
                } else if wasOnline && path.status != .satisfied {
                    // Just went offline
                    self.handleGoingOffline()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func handleGoingOffline() {
        // Update UI state
        checkOfflineDataAvailability()
        
        // Show offline notification if needed
        if !canWorkOffline {
            // Could show a notification here
        }
    }
    
    private func cacheEssentialData() async {
        do {
            // Cache assignments
            let assignmentProvider = DataSynchronizationManager.shared.getAssignmentProvider()
            _ = try await assignmentProvider.fetchAll()
            
            // Cache holidays for current year
            let holidayProvider = DataSynchronizationManager.shared.getHolidayProvider()
            let currentYear = Calendar.current.component(.year, from: Date())
            let userCountry = UserPreferencesManager.shared.selectedCountry
            _ = try await holidayProvider.fetchHolidays(for: userCountry, year: currentYear)
            
            // Cache courses
            let courseProvider = DataSynchronizationManager.shared.getCourseProvider()
            _ = try await courseProvider.fetchCourses()
            
            // Update availability
            checkOfflineDataAvailability()
            
        } catch {
            print("Failed to cache essential data: \(error)")
        }
    }
    
    private func checkOfflineDataAvailability() {
        let context = persistenceController.viewContext
        
        // Check if we have any assignments cached
        let assignmentRequest = AssignmentEntity.fetchRequest()
        let assignmentCount = (try? context.count(for: assignmentRequest)) ?? 0
        
        // Check if we have holidays cached
        let holidayRequest = HolidayEntity.fetchRequest()
        let holidayCount = (try? context.count(for: holidayRequest)) ?? 0
        
        // Check if we have courses cached
        let courseRequest = CourseEntity.fetchRequest()
        let courseCount = (try? context.count(for: courseRequest)) ?? 0
        
        hasOfflineData = assignmentCount > 0 || holidayCount > 0 || courseCount > 0
        
        // Calculate data age (simplified - could be more sophisticated)
        if let lastSync = DataSynchronizationManager.shared.lastSyncDate {
            offlineDataAge = Date().timeIntervalSince(lastSync)
        } else {
            offlineDataAge = TimeInterval.infinity
        }
        
        canWorkOffline = hasOfflineData && offlineDataAge < 604800 // 7 days
    }
    
    // MARK: - Offline Data Management
    
    func getOfflineDataSize() -> String {
        // Calculate approximate size of cached data
        // This is a simplified implementation
        let context = persistenceController.viewContext
        
        let assignmentCount = (try? context.count(for: AssignmentEntity.fetchRequest())) ?? 0
        let holidayCount = (try? context.count(for: HolidayEntity.fetchRequest())) ?? 0
        let courseCount = (try? context.count(for: CourseEntity.fetchRequest())) ?? 0
        
        let estimatedSize = (assignmentCount * 1024) + (holidayCount * 512) + (courseCount * 256) // bytes
        
        return ByteCountFormatter.string(fromByteCount: Int64(estimatedSize), countStyle: .file)
    }
    
    func clearOfflineData() async {
        do {
            // Clear all cached data using NSBatchDeleteRequest
            let context = persistenceController.viewContext
            
            // Delete assignments
            let assignmentFetchRequest: NSFetchRequest<NSFetchRequestResult> = AssignmentEntity.fetchRequest()
            let assignmentDeleteRequest = NSBatchDeleteRequest(fetchRequest: assignmentFetchRequest)
            try context.execute(assignmentDeleteRequest)
            
            // Delete holidays
            let holidayFetchRequest: NSFetchRequest<NSFetchRequestResult> = HolidayEntity.fetchRequest()
            let holidayDeleteRequest = NSBatchDeleteRequest(fetchRequest: holidayFetchRequest)
            try context.execute(holidayDeleteRequest)
            
            // Delete courses
            let courseFetchRequest: NSFetchRequest<NSFetchRequestResult> = CourseEntity.fetchRequest()
            let courseDeleteRequest = NSBatchDeleteRequest(fetchRequest: courseFetchRequest)
            try context.execute(courseDeleteRequest)
            
            // Delete shared calendars
            let calendarFetchRequest: NSFetchRequest<NSFetchRequestResult> = SharedCalendarEntity.fetchRequest()
            let calendarDeleteRequest = NSBatchDeleteRequest(fetchRequest: calendarFetchRequest)
            try context.execute(calendarDeleteRequest)
            
            try context.save()
            
            // Update availability
            checkOfflineDataAvailability()
            
        } catch {
            print("Failed to clear offline data: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct OfflineStatus {
    let isOnline: Bool
    let hasOfflineData: Bool
    let dataAge: TimeInterval
    let canWorkOffline: Bool
    
    var formattedDataAge: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        
        return formatter.string(from: dataAge) ?? "Unknown"
    }
    
    var statusColor: String {
        if isOnline {
            return "#66BB6A" // Green
        } else if canWorkOffline {
            return "#FFA726" // Orange
        } else {
            return "#EF5350" // Red
        }
    }
    
    var statusIcon: String {
        if isOnline {
            return "wifi"
        } else if canWorkOffline {
            return "wifi.slash"
        } else {
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - Offline Banner View

struct OfflineBannerView: View {
    @StateObject private var offlineManager = OfflineManager.shared
    
    var body: some View {
        if !offlineManager.isOnline {
            HStack {
                Image(systemName: offlineManager.canWorkOffline ? "wifi.slash" : "exclamationmark.triangle")
                    .foregroundColor(.white)
                
                Text(offlineManager.getOfflineMessage())
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(offlineManager.canWorkOffline ? Color.orange : Color.red)
        }
    }
}

// MARK: - Offline Settings View

struct OfflineSettingsView: View {
    @StateObject private var offlineManager = OfflineManager.shared
    @State private var showingClearAlert = false
    
    var body: some View {
        List {
            Section("Connection Status") {
                HStack {
                    Image(systemName: offlineManager.isOnline ? "wifi" : "wifi.slash")
                        .foregroundColor(offlineManager.isOnline ? .green : .orange)
                    
                    Text(offlineManager.isOnline ? "Online" : "Offline")
                    
                    Spacer()
                    
                    if !offlineManager.isOnline {
                        Text(offlineManager.canWorkOffline ? "Can work offline" : "Limited functionality")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Offline Data") {
                HStack {
                    Text("Cached Data Available")
                    Spacer()
                    Text(offlineManager.hasOfflineData ? "Yes" : "No")
                        .foregroundColor(offlineManager.hasOfflineData ? .green : .red)
                }
                
                if offlineManager.hasOfflineData {
                    HStack {
                        Text("Data Age")
                        Spacer()
                        Text(offlineManager.getOfflineStatus().formattedDataAge)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Estimated Size")
                        Spacer()
                        Text(offlineManager.getOfflineDataSize())
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Actions") {
                Button("Prepare for Offline Use") {
                    Task {
                        await offlineManager.prepareForOffline()
                    }
                }
                .disabled(!offlineManager.isOnline)
                
                if offlineManager.hasOfflineData {
                    Button("Clear Offline Data", role: .destructive) {
                        showingClearAlert = true
                    }
                }
            }
        }
        .navigationTitle("Offline Settings")
        .alert("Clear Offline Data", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await offlineManager.clearOfflineData()
                }
            }
        } message: {
            Text("This will remove all cached data. You'll need an internet connection to use the app until data is cached again.")
        }
    }
}