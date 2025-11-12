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
        print("Setting up network monitoring...")
        
        networkMonitor.pathUpdateHandler = { [weak self] (path: NWPath) in
            print("Network path changed: \(path.status)")
            print("   - WiFi: \(path.usesInterfaceType(.wifi))")
            print("   - Cellular: \(path.usesInterfaceType(.cellular))")
            print("   - Ethernet: \(path.usesInterfaceType(.wiredEthernet))")
            print("   - Is expensive: \(path.isExpensive)")
            
            guard let self = self else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let needsImmediateUpdate = (path.status == .satisfied && !self.isOnline) ||
                                           (path.status != .satisfied && self.isOnline)
                
                if !needsImmediateUpdate {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
                }
                
                self.updateConnectionStatus(path)
                
                if path.status == .satisfied {
                    Task {
                        let delay: UInt64 = needsImmediateUpdate ? 500_000_000 : 1_000_000_000
                        try? await Task.sleep(nanoseconds: delay)
                        await self.testInternetConnectivity()
                    }
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
        networkMonitor.start(queue: queue)
        
        // Initial state
        let currentPath = networkMonitor.currentPath
        print("🌐 Initial network state: \(currentPath.status)")
        
        DispatchQueue.main.async {
            self.updateConnectionStatus(currentPath)
            if currentPath.status == .satisfied {
                Task { await self.testInternetConnectivity() }
            }
        }
    }
    
    /// Force refresh the network status (useful for testing)
    func refreshNetworkStatus() {
        print("🌐 Force refreshing network status...")
        let currentPath = networkMonitor.currentPath
        updateConnectionStatus(currentPath)
    }
    
    /// Test actual internet connectivity (not just network interface)
    @discardableResult
    func testInternetConnectivity() async -> Bool {
        print("🌐 Testing actual internet connectivity...")
        
        guard networkMonitor.currentPath.status == .satisfied else {
            print("🌐 Path not satisfied, no connectivity")
            self.isOnline = false
            return false
        }
        
        // Use a lightweight endpoint
        let testURL = URL(string: "https://www.google.com/generate_204")!
        var req = URLRequest(url: testURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
        req.httpMethod = "GET"
        
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let isConnected = (200...299).contains(code)
            print("🌐 Internet connectivity test: \(isConnected ? "SUCCESS" : "FAILED") (status: \(code))")
            
            let wasOnline = self.isOnline
            self.isOnline = isConnected
            
            if isConnected && !wasOnline {
                self.connectionRestoredRecently = true
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run { self.connectionRestoredRecently = false }
                }
            } else if !isConnected && wasOnline {
                self.connectionRestoredRecently = false
            }
            return isConnected
        } catch {
            print("🌐 Internet connectivity test failed: \(error.localizedDescription)")
            self.isOnline = false
            return false
        }
    }
    
    /// Temporarily force the app into offline state (e.g., after a timeout) and re-check later.
    func markOfflineFor(seconds: Int) async {
        // Force offline immediately
        self.isOnline = false
        self.connectionType = nil
        self.connectionRestoredRecently = false
        
        // Re-check connectivity after a short cooldown
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            _ = await self.testInternetConnectivity()
        }
    }
    
    private func updateConnectionStatus(_ path: NWPath) {
        let wasOnline = isOnline
        
        let hasWifi = path.usesInterfaceType(.wifi)
        let hasCellular = path.usesInterfaceType(.cellular)
        let hasEthernet = path.usesInterfaceType(.wiredEthernet)
        let hasUsableInterface = hasWifi || hasCellular || hasEthernet
        
        let newOnlineStatus = path.status == .satisfied
        
        print("🌐 updateConnectionStatus called:")
        print("   - Previous state: \(wasOnline ? "Online" : "Offline")")
        print("   - Path status: \(path.status)")
        print("   - WiFi: \(hasWifi)")
        print("   - Cellular: \(hasCellular)")
        print("   - Ethernet: \(hasEthernet)")
        print("   - Has usable interface: \(hasUsableInterface)")
        print("   - Is expensive: \(path.isExpensive)")
        print("   - Final online status: \(newOnlineStatus)")
        
        guard newOnlineStatus != wasOnline else {
            print("🌐 No status change, skipping update")
            return
        }
        
        self.isOnline = newOnlineStatus
        
        if hasWifi {
            self.connectionType = .wifi
        } else if hasCellular {
            self.connectionType = .cellular
        } else if hasEthernet {
            self.connectionType = .wiredEthernet
        } else if newOnlineStatus {
            self.connectionType = nil
            print("🌐 Online but interface type not yet determined - will update on next path change")
        } else {
            self.connectionType = nil
        }
        
        self.validateOfflineCapability()
        
        if newOnlineStatus && !wasOnline {
            print("🌐 Connection restored! Banner will disappear...")
            self.connectionRestoredRecently = true
            
            if self.pendingSyncOperations > 0 {
                Task { await self.performPendingSyncOperations() }
            }
            
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    print("🌐 Hiding green connected banner...")
                    self.connectionRestoredRecently = false
                }
            }
        } else if !newOnlineStatus && wasOnline {
            print("🚫 Connection lost! Showing red offline banner...")
            self.connectionRestoredRecently = false
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
    func canFunctionOffline() -> Bool {
        return hasOfflineData && offlineDataAge < 604800 // 7 days
    }
    
    func getOfflineStatus() -> OfflineStatus {
        if !hasOfflineData { return .noData }
        if offlineDataAge > 604800 { return .stale }
        return .available
    }
    
    func prepareForOffline() async {
        isRefreshingCache = true
        defer { isRefreshingCache = false }
        await refreshCacheData()
    }
    
    func handleNetworkRestoration() async {
        guard isOnline else { return }
        await performPendingSyncOperations()
    }
    
    func getOfflineMessage() -> String {
        switch getOfflineStatus() {
        case .available: return "Working offline with cached data"
        case .stale:     return "Offline data is outdated. Connect to refresh."
        case .noData:    return "No offline data available. Connect to internet."
        }
    }
    
    // MARK: - Private Helpers
    private func checkOfflineDataAvailability() {
        let context = persistenceController.viewContext
        
        let assignmentCount = (try? context.count(for: AssignmentEntity.fetchRequest())) ?? 0
        let holidayCount = (try? context.count(for: HolidayEntity.fetchRequest())) ?? 0
        let courseCount = (try? context.count(for: CourseEntity.fetchRequest())) ?? 0
        
        hasOfflineData = assignmentCount > 0 || holidayCount > 0 || courseCount > 0
        userDefaults.set(hasOfflineData, forKey: offlineDataKey)
        
        if let lastSync = lastSyncDate {
            offlineDataAge = Date().timeIntervalSince(lastSync)
        } else {
            offlineDataAge = TimeInterval.infinity
        }
    }
    
    private func validateOfflineCapability() {
        let daysSinceSync: Int
        if offlineDataAge == .infinity || offlineDataAge.isInfinite {
            daysSinceSync = Int.max
        } else {
            daysSinceSync = Int(offlineDataAge / 86400)
        }
        
        canWorkOffline = hasOfflineData && daysSinceSync <= maxOfflineDays
        
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
            if let assignments = try? context.fetch(AssignmentEntity.fetchRequest()) {
                totalSize += assignments.count * 1024
            }
            if let holidays = try? context.fetch(HolidayEntity.fetchRequest()) {
                totalSize += holidays.count * 512
            }
            if let courses = try? context.fetch(CourseEntity.fetchRequest()) {
                totalSize += courses.count * 256
            }
            return totalSize
        }
    }
    
    private func refreshCacheData() async {
        lastSyncDate = Date()
        userDefaults.set(lastSyncDate, forKey: lastSyncKey)
        checkOfflineDataAvailability()
        calculateCachedDataSize()
    }
    
    /// Perform pending sync operations
    func performPendingSyncOperations() async {
        guard pendingSyncOperations > 0 else { return }
        
        for _ in 0..<pendingSyncOperations {
            try? await Task.sleep(nanoseconds: 100_000_000) // simulate 0.1s per op
            self.pendingSyncOperations = max(0, self.pendingSyncOperations - 1)
            userDefaults.set(self.pendingSyncOperations, forKey: pendingSyncKey)
        }
        
        await refreshCacheData()
    }
    
    // MARK: - Cache Management Functions
    func clearCache() async {
        let context = persistenceController.persistentContainer.newBackgroundContext()
        await context.perform {
            _ = try? context.execute(NSBatchDeleteRequest(fetchRequest: NSFetchRequest(entityName: "AssignmentEntity")))
            _ = try? context.execute(NSBatchDeleteRequest(fetchRequest: NSFetchRequest(entityName: "HolidayEntity")))
            _ = try? context.execute(NSBatchDeleteRequest(fetchRequest: NSFetchRequest(entityName: "CourseEntity")))
            try? context.save()
        }
        
        hasOfflineData = false
        cachedDataSize = "0 MB"
        offlineCapabilityStatus = .unavailable
        canWorkOffline = false
        userDefaults.removeObject(forKey: lastSyncKey)
        userDefaults.removeObject(forKey: offlineDataKey)
        lastSyncDate = nil
    }
    
    func forceSyncData() async {
        pendingSyncOperations = 5
        userDefaults.set(pendingSyncOperations, forKey: pendingSyncKey)
        if isOnline { await performPendingSyncOperations() }
    }
    
    func getOfflineDataSize() -> String { cachedDataSize }
    func clearOfflineData() async { await clearCache() }
    
    var connectionStatusColor: String {
        isOnline ? "#10B981" : "#F59E0B"
    }
    
    var connectionStatusText: String {
        if isOnline {
            if let type = connectionType { return "Connected via \(type.displayName)" }
            return "Connected"
        } else {
            return "Offline"
        }
    }
    
    func refreshCache() async { await prepareForOffline() }
    
    func getDaysUntilStale() -> Int {
        if offlineDataAge == .infinity || offlineDataAge.isInfinite { return 0 }
        let daysSinceSync = Int(offlineDataAge / 86400)
        return max(0, maxOfflineDays - daysSinceSync)
    }
    
    func getOfflineDataAge() -> String {
        if let lastSync = lastSyncDate {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .full
            return f.localizedString(for: lastSync, relativeTo: Date())
        } else {
            return "Never synced"
        }
    }
    
    func checkConnectionStatus() {
        let currentPath = networkMonitor.currentPath
        updateConnectionStatus(currentPath)
        print("🌐 Manual connection check: \(isOnline ? "Online" : "Offline")")
    }
    
    // MARK: - Diagnostic
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
        case .available: return "Data available offline"
        case .stale:     return "Offline data is outdated"
        case .noData:    return "No offline data"
        }
    }
    
    var formattedDataAge: String { "Less than 1 day" }
}

enum OfflineCapabilityStatus {
    case ready
    case stale
    case unavailable
    
    var description: String {
        switch self {
        case .ready:       return "Ready for offline use"
        case .stale:       return "Offline data needs refresh"
        case .unavailable: return "Offline mode unavailable"
        }
    }
    
    var color: String {
        switch self {
        case .ready:       return "#10B981"
        case .stale:       return "#F59E0B"
        case .unavailable: return "#EF4444"
        }
    }
    
    var icon: String {
        switch self {
        case .ready:       return "checkmark.circle.fill"
        case .stale:       return "exclamationmark.triangle.fill"
        case .unavailable: return "xmark.circle.fill"
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
        case .wifi:           return "Wi-Fi"
        case .cellular:       return "Cellular"
        case .wiredEthernet:  return "Ethernet"
        case .loopback:       return "Loopback"
        case .other:          return "Other"
        @unknown default:     return "Unknown"
        }
    }
}
