//
//  OfflineManager.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/11/25.
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
    @Published var connectionRestoredRecently = false
    
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
        // Get initial network state immediately
        let currentPath = networkMonitor.currentPath
        updateConnectionStatus(currentPath)
        
        // Set up continuous monitoring
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionStatus(path)
            }
        }
        networkMonitor.start(queue: networkQueue)
        
        print("🌐 Network monitoring started. Initial state: \(isOnline ? "Online" : "Offline")")
    }
    
    private func updateConnectionStatus(_ path: NWPath) {
        let wasOnline = isOnline
        let newOnlineStatus = path.status == .satisfied
        
        // Update connection status immediately
        isOnline = newOnlineStatus
        
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
        
        // Handle connection restoration - trigger immediately when going from offline to online
        if newOnlineStatus && !wasOnline {
            print("🌐 Connection restored! Triggering banner update...")
            
            // Immediately show connection restored banner
            connectionRestoredRecently = true
            
            // Auto-sync when connection is restored
            if pendingSyncOperations > 0 {
                Task {
                    await performPendingSyncOperations()
                }
            }
            
            // Hide the "Connected" indication after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                await MainActor.run {
                    print("🌐 Hiding connection restored banner...")
                    self.connectionRestoredRecently = false
                }
            }
        } else if !newOnlineStatus && wasOnline {
            // Connection lost - ensure banner shows immediately
            print("🚫 Connection lost! Showing offline banner...")
            connectionRestoredRecently = false
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
        if !hasOfflineData {
            return .noData
        }
        
        if offlineDataAge > 604800 { // 7 days
            return .stale
        }
        
        return .available
    }
    
    /// Prepare the app for offline mode by caching essential data
    func prepareForOffline() async {
        isRefreshingCache = true
        defer { isRefreshingCache = false }
        
        // Cache data here - this would interact with your data services
        // For now, we'll just update the cache status
        await refreshCacheData()
    }
    
    /// Handle network restoration by syncing pending operations
    func handleNetworkRestoration() async {
        guard isOnline else { return }
        await performPendingSyncOperations()
    }
    
    /// Get user-friendly offline message
    func getOfflineMessage() -> String {
        switch getOfflineStatus() {
        case .available:
            return "Working offline with cached data"
        case .stale:
            return "Offline data is outdated. Connect to refresh."
        case .noData:
            return "No offline data available. Connect to internet."
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func checkOfflineDataAvailability() {
        let context = persistenceController.viewContext
        
        // Check if we have assignments cached
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
    }
    
    private func validateOfflineCapability() {
        // Handle infinite or very large values safely
        let daysSinceSync: Int
        if offlineDataAge == TimeInterval.infinity || offlineDataAge.isInfinite {
            daysSinceSync = Int.max
        } else {
            daysSinceSync = Int(offlineDataAge / 86400) // Convert to days
        }
        
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
        let context = persistenceController.persistentContainer.newBackgroundContext()
        
        return await context.perform {
            var totalSize = 0
            
            // Calculate assignments size
            let assignmentRequest = AssignmentEntity.fetchRequest()
            if let assignments = try? context.fetch(assignmentRequest) {
                totalSize += assignments.count * 1024 // Rough estimate
            }
            
            // Calculate holidays size
            let holidayRequest = HolidayEntity.fetchRequest()
            if let holidays = try? context.fetch(holidayRequest) {
                totalSize += holidays.count * 512 // Rough estimate
            }
            
            // Calculate courses size
            let courseRequest = CourseEntity.fetchRequest()
            if let courses = try? context.fetch(courseRequest) {
                totalSize += courses.count * 256 // Rough estimate
            }
            
            return totalSize
        }
    }
    
    private func refreshCacheData() async {
        // This would typically refresh data from your services
        // For now, just update the sync date and recalculate
        lastSyncDate = Date()
        userDefaults.set(lastSyncDate, forKey: lastSyncKey)
        
        checkOfflineDataAvailability()
        calculateCachedDataSize()
    }
    
    /// Perform pending sync operations
    func performPendingSyncOperations() async {
        guard pendingSyncOperations > 0 else { return }
        
        // Simulate sync operations
        for _ in 0..<pendingSyncOperations {
            // Perform sync operation here
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
            
            // Update UI on main thread
            await MainActor.run {
                self.pendingSyncOperations = max(0, self.pendingSyncOperations - 1)
                userDefaults.set(self.pendingSyncOperations, forKey: pendingSyncKey)
            }
        }
        
        // Refresh cache after sync
        await refreshCacheData()
    }
    
    // MARK: - Cache Management Functions
    
    func clearCache() async {
        let context = persistenceController.persistentContainer.newBackgroundContext()
        
        await context.perform {
            // Clear assignments
            let assignmentRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AssignmentEntity")
            let assignmentDeleteRequest = NSBatchDeleteRequest(fetchRequest: assignmentRequest)
            _ = try? context.execute(assignmentDeleteRequest)
            
            // Clear holidays
            let holidayRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "HolidayEntity")
            let holidayDeleteRequest = NSBatchDeleteRequest(fetchRequest: holidayRequest)
            _ = try? context.execute(holidayDeleteRequest)
            
            // Clear courses
            let courseRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CourseEntity")
            let courseDeleteRequest = NSBatchDeleteRequest(fetchRequest: courseRequest)
            _ = try? context.execute(courseDeleteRequest)
            
            try? context.save()
        }
        
        // Update UI
        await MainActor.run {
            hasOfflineData = false
            cachedDataSize = "0 MB"
            offlineCapabilityStatus = .unavailable
            canWorkOffline = false
            
            // Clear UserDefaults
            userDefaults.removeObject(forKey: lastSyncKey)
            userDefaults.removeObject(forKey: offlineDataKey)
            lastSyncDate = nil
        }
    }
    
    func forceSyncData() async {
        pendingSyncOperations = 5 // Simulate 5 pending operations
        userDefaults.set(pendingSyncOperations, forKey: pendingSyncKey)
        
        if isOnline {
            await performPendingSyncOperations()
        }
    }
    
    /// Get the size of offline data as a formatted string
    func getOfflineDataSize() -> String {
        return cachedDataSize
    }
    
    /// Clear all offline data (alias for clearCache)
    func clearOfflineData() async {
        await clearCache()
    }
    
    /// Get connection status color as hex string
    var connectionStatusColor: String {
        if isOnline {
            return "#10B981" // Green
        } else {
            return "#F59E0B" // Orange
        }
    }
    
    /// Get connection status text
    var connectionStatusText: String {
        if isOnline {
            if let type = connectionType {
                return "Connected via \(type.displayName)"
            } else {
                return "Connected"
            }
        } else {
            return "Offline"
        }
    }
    
    /// Refresh cache data (alias for prepareForOffline)
    func refreshCache() async {
        await prepareForOffline()
    }
    
    /// Get the number of days until cached data becomes stale
    func getDaysUntilStale() -> Int {
        // Handle infinite or very large values safely
        if offlineDataAge == TimeInterval.infinity || offlineDataAge.isInfinite {
            return 0 // No data means 0 days left
        }
        
        let daysSinceSync = Int(offlineDataAge / 86400)
        return max(0, maxOfflineDays - daysSinceSync)
    }
    
    /// Get offline data age as a formatted string
    func getOfflineDataAge() -> String {
        if let lastSync = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: lastSync, relativeTo: Date())
        } else {
            return "Never synced"
        }
    }
    
    /// Manually check and update connection status (useful for testing)
    func checkConnectionStatus() {
        let currentPath = networkMonitor.currentPath
        updateConnectionStatus(currentPath)
        print("🌐 Manual connection check: \(isOnline ? "Online" : "Offline")")
    }
    
    // MARK: - Diagnostic Functions
    
    func getSyncDiagnostics() -> SyncDiagnostics {
        return SyncDiagnostics(
            isOnline: isOnline,
            connectionType: connectionType?.displayName ?? "None",
            hasOfflineData: hasOfflineData,
            lastSyncDate: lastSyncDate,
            offlineDataAge: offlineDataAge,
            canWorkOffline: canWorkOffline,
            pendingSyncOperations: pendingSyncOperations,
            cachedDataSize: cachedDataSize,
            offlineCapabilityStatus: offlineCapabilityStatus
        )
    }
}

// MARK: - Supporting Types

enum OfflineStatus {
    case available
    case stale
    case noData
    
    var description: String {
        switch self {
        case .available:
            return "Data available offline"
        case .stale:
            return "Offline data is outdated"
        case .noData:
            return "No offline data"
        }
    }
    
    var formattedDataAge: String {
        // This would typically be calculated based on actual data age
        // For now, return a placeholder
        return "Less than 1 day"
    }
}

enum OfflineCapabilityStatus {
    case ready
    case stale
    case unavailable
    
    var description: String {
        switch self {
        case .ready:
            return "Ready for offline use"
        case .stale:
            return "Offline data needs refresh"
        case .unavailable:
            return "Offline mode unavailable"
        }
    }
    
    var color: String {
        switch self {
        case .ready:
            return "#10B981" // Green
        case .stale:
            return "#F59E0B" // Orange
        case .unavailable:
            return "#EF4444" // Red
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

struct SyncDiagnostics {
    let isOnline: Bool
    let connectionType: String
    let hasOfflineData: Bool
    let lastSyncDate: Date?
    let offlineDataAge: TimeInterval
    let canWorkOffline: Bool
    let pendingSyncOperations: Int
    let cachedDataSize: String
    let offlineCapabilityStatus: OfflineCapabilityStatus
}

extension NWInterface.InterfaceType {
    var displayName: String {
        switch self {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .wiredEthernet:
            return "Ethernet"
        case .loopback:
            return "Loopback"
        case .other:
            return "Other"
        @unknown default:
            return "Unknown"
        }
    }
}