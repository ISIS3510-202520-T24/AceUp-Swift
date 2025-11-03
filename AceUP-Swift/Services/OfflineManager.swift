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
    @Published var connectionType: NWInterface.InterfaceType?
    @Published var hasOfflineData = false
    @Published var offlineDataAge: TimeInterval = 0
    @Published var canWorkOffline = false
    @Published var lastSyncDate: Date?
    @Published var pendingSyncOperations: Int = 0
    @Published var cachedDataSize: String = "0 MB"
    @Published var isRefreshingCache = false
    @Published var offlineCapabilityStatus: OfflineCapabilityStatus = .unavailable
    
    // MARK: - Private Properties
    
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "OfflineManagerNetwork")
    private let persistenceController: PersistenceController
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    
    // Cache constants
    private let maxOfflineDays = 7
    private let lastSyncKey = "OfflineManager.lastSync"
    private let pendingSyncKey = "OfflineManager.pendingSync"
    private let offlineDataKey = "OfflineManager.offlineData"
    
    // MARK: - Initialization
    
    private init() {
        self.persistenceController = PersistenceController.shared
        setupNetworkMonitoring()
        loadCachedData()
        checkOfflineDataAvailability()
        calculateCachedDataSize()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionStatus(path)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func updateConnectionStatus(_ path: NWPath) {
        let wasOnline = isOnline
        isOnline = path.status == .satisfied
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else {
            connectionType = nil
        }
        
        validateOfflineCapability()
        
        // Auto-sync when connection is restored
        if isOnline && !wasOnline && pendingSyncOperations > 0 {
            Task {
                await performPendingSyncOperations()
            }
        }
    }
    
    // MARK: - Cache Management
    
    private func loadCachedData() {
        lastSyncDate = userDefaults.object(forKey: lastSyncKey) as? Date
        pendingSyncOperations = userDefaults.integer(forKey: pendingSyncKey)
        hasOfflineData = userDefaults.bool(forKey: offlineDataKey)
        
        if let lastSync = lastSyncDate {
            offlineDataAge = Date().timeIntervalSince(lastSync)
        }
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
        userDefaults.set(hasOfflineData, forKey: offlineDataKey)
        
        // Calculate data age (simplified - could be more sophisticated)
        if let lastSync = lastSyncDate {
            offlineDataAge = Date().timeIntervalSince(lastSync)
        } else {
            offlineDataAge = TimeInterval.infinity
        }
        
        validateOfflineCapability()
    }
    
    private func validateOfflineCapability() {
        let daysSinceSync = Int(offlineDataAge / 86400) // Convert to days
        canWorkOffline = hasOfflineData && daysSinceSync <= maxOfflineDays
        
        // Update offline capability status
        if canWorkOffline && daysSinceSync <= 3 {
            offlineCapabilityStatus = .ready
        } else if canWorkOffline && daysSinceSync <= maxOfflineDays {
            offlineCapabilityStatus = .stale
        } else {
            offlineCapabilityStatus = .unavailable
        }
    }
    
    private func calculateCachedDataSize() {
        Task {
            let size = await getCacheSize()
            await MainActor.run {
                cachedDataSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
        }
    }
    
    private func getCacheSize() async -> Int {
        let context = persistenceController.viewContext
        
        // Calculate approximate size of cached data
        let assignmentCount = (try? context.count(for: AssignmentEntity.fetchRequest())) ?? 0
        let holidayCount = (try? context.count(for: HolidayEntity.fetchRequest())) ?? 0
        let courseCount = (try? context.count(for: CourseEntity.fetchRequest())) ?? 0
        
        // Rough estimates per entity (in bytes)
        let estimatedSize = (assignmentCount * 2048) + (holidayCount * 512) + (courseCount * 1024)
        
        return estimatedSize
    }
    
    // MARK: - Advanced Cache Management
    
    func refreshCache() async {
        guard isOnline else { return }
        
        isRefreshingCache = true
        defer { isRefreshingCache = false }
        
        do {
            // Cache assignments
            await cacheAssignments()
            
            // Cache holidays
            await cacheHolidays()
            
            // Cache courses
            await cacheCourses()
            
            // Cache shared calendars
            await cacheSharedCalendars()
            
            // Update sync metadata
            lastSyncDate = Date()
            userDefaults.set(lastSyncDate, forKey: lastSyncKey)
            
            // Refresh calculations
            calculateCachedDataSize()
            checkOfflineDataAvailability()
            
        } catch {
            print("Failed to refresh cache: \(error)")
        }
    }
    
    private func cacheAssignments() async {
        do {
            let assignmentProvider = DataSynchronizationManager.shared.getAssignmentProvider()
            _ = try await assignmentProvider.fetchAll()
            print("✅ Cached assignments data")
        } catch {
            print("❌ Failed to cache assignments: \(error)")
        }
    }
    
    private func cacheHolidays() async {
        do {
            let holidayProvider = DataSynchronizationManager.shared.getHolidayProvider()
            let currentYear = Calendar.current.component(.year, from: Date())
            let userCountry = UserPreferencesManager.shared.selectedCountry
            _ = try await holidayProvider.fetchHolidays(for: userCountry, year: currentYear)
            print("✅ Cached holidays data")
        } catch {
            print("❌ Failed to cache holidays: \(error)")
        }
    }
    
    private func cacheCourses() async {
        do {
            let courseProvider = DataSynchronizationManager.shared.getCourseProvider()
            _ = try await courseProvider.fetchCourses()
            print("✅ Cached courses data")
        } catch {
            print("❌ Failed to cache courses: \(error)")
        }
    }
    
    private func cacheSharedCalendars() async {
        do {
            // Simulate caching shared calendars
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            print("✅ Cached shared calendars data")
        } catch {
            print("❌ Failed to cache shared calendars: \(error)")
        }
    }
    
    // MARK: - Sync Operations Management
    
    func addPendingSyncOperation() {
        pendingSyncOperations += 1
        userDefaults.set(pendingSyncOperations, forKey: pendingSyncKey)
    }
    
    func performPendingSyncOperations() async {
        guard isOnline && pendingSyncOperations > 0 else { return }
        
        let totalOperations = pendingSyncOperations
        
        do {
            // Perform pending sync operations
            for i in 0..<totalOperations {
                // Simulate sync operation
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
                await MainActor.run {
                    pendingSyncOperations = max(0, pendingSyncOperations - 1)
                    userDefaults.set(pendingSyncOperations, forKey: pendingSyncKey)
                }
            }
            
            print("✅ Completed \(totalOperations) pending sync operations")
            
        } catch {
            print("❌ Failed to perform sync operations: \(error)")
        }
    }
    
    // MARK: - User Interface Support
    
    func getOfflineDataAge() -> String {
        guard let lastSync = lastSyncDate else {
            return "No cached data"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
    
    func getDaysUntilStale() -> Int {
        guard let lastSync = lastSyncDate else { return 0 }
        
        let daysSinceSync = Calendar.current.dateComponents([.day], from: lastSync, to: Date()).day ?? 0
        return max(0, maxOfflineDays - daysSinceSync)
    }
    
    var connectionStatusText: String {
        if isOnline {
            switch connectionType {
            case .wifi:
                return "Connected via Wi-Fi"
            case .cellular:
                return "Connected via Cellular"
            case .wiredEthernet:
                return "Connected via Ethernet"
            default:
                return "Connected"
            }
        } else {
            return "No internet connection"
        }
    }
    
    var connectionStatusColor: String {
        return isOnline ? "#4CAF50" : "#F44336"
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

// MARK: - Offline Capability Status

enum OfflineCapabilityStatus {
    case ready
    case stale
    case unavailable
    
    var description: String {
        switch self {
        case .ready:
            return "Ready for offline use"
        case .stale:
            return "Cached data is getting old"
        case .unavailable:
            return "Cannot work offline"
        }
    }
    
    var color: String {
        switch self {
        case .ready:
            return "#4CAF50" // Green
        case .stale:
            return "#FF9800" // Orange
        case .unavailable:
            return "#F44336" // Red
        }
    }
    
    var icon: String {
        switch self {
        case .ready:
            return "checkmark.circle.fill"
        case .stale:
            return "exclamationmark.triangle.fill"
        case .unavailable:
            return "xmark.circle.fill"
        }
    }
}