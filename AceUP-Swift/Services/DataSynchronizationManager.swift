//
//  DataSynchronizationManager.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 7/10/25.
//

import Foundation
import Network
import Combine
import FirebaseAuth

/// Centralized data synchronization manager for all app data
/// Coordinates sync between local and remote data sources
@MainActor
class DataSynchronizationManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DataSynchronizationManager()
    
    // MARK: - Published Properties
    
    @Published var isOnline = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncProgress: Double = 0.0
    @Published var syncStatus: String = "Ready"
    @Published var pendingSyncCount: Int = 0
    
    // MARK: - Private Properties
    
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "DataSyncNetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    // Data providers
    private let assignmentProvider: HybridAssignmentDataProvider
    private let holidayProvider: HybridHolidayDataProvider
    private let courseProvider: HybridCourseDataProvider
    
    // Sync timers
    private var autoSyncTimer: Timer?
    private var backgroundSyncTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        // Initialize providers without defaults to avoid main actor issues
        self.assignmentProvider = HybridAssignmentDataProvider(
            localProvider: nil,
            remoteProvider: nil
        )
        self.holidayProvider = HybridHolidayDataProvider()
        self.courseProvider = HybridCourseDataProvider()
        
        setupNetworkMonitoring()
        setupDataProviderObservers()
        loadLastSyncDate()
    }
    
    deinit {
        networkMonitor.cancel()
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }
    
    // MARK: - Public Methods
    
    /// Perform full synchronization of all data
    func performFullSync() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncProgress = 0.0
        syncStatus = "Synchronizing..."
        
        let totalSteps = 3.0 // assignments, holidays, courses
        var completedSteps = 0.0
        
        // Sync assignments
        syncStatus = "Syncing assignments..."
        await assignmentProvider.performFullSync()
        completedSteps += 1
        syncProgress = completedSteps / totalSteps
        
        // Sync holidays
        syncStatus = "Syncing holidays..."
        await syncHolidays()
        completedSteps += 1
        syncProgress = completedSteps / totalSteps
        
        // Sync courses
        syncStatus = "Syncing courses..."
        await syncCourses()
        completedSteps += 1
        syncProgress = completedSteps / totalSteps
        
        // Update sync timestamp
        lastSyncDate = Date()
        saveLastSyncDate()
        
        syncStatus = "Sync completed"
        
        // Send analytics event
        Analytics.shared.track("sync_completed", props: [
            "sync_type": "full",
            "duration": Date().timeIntervalSince(lastSyncDate ?? Date())
        ])
        
        isSyncing = false
        
        // Reset status after delay
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if !self.isSyncing {
                self.syncStatus = "Ready"
                self.syncProgress = 0.0
            }
        }
    }
    
    /// Perform incremental sync (only changed data)
    func performIncrementalSync() async {
        guard !isSyncing, isOnline else { return }
        
        isSyncing = true
        syncStatus = "Quick sync..."
        
        // Only sync data that has changed since last sync
        // For now, we'll do a lighter version of full sync
        
        await assignmentProvider.performFullSync()
        
        lastSyncDate = Date()
        saveLastSyncDate()
        syncStatus = "Quick sync completed"
        
        isSyncing = false
        
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if !self.isSyncing {
                self.syncStatus = "Ready"
            }
        }
    }
    
    /// Force sync for specific data type
    func syncSpecificData<T>(_ dataType: T.Type) async where T: Codable {
        guard isOnline else { return }
        
        switch dataType {
        case is Assignment.Type:
            await assignmentProvider.performFullSync()
        case is Holiday.Type:
            await syncHolidays()
        case is Course.Type:
            await syncCourses()
        default:
            break
        }
    }
    
    /// Get data providers for dependency injection
    func getAssignmentProvider() -> HybridAssignmentDataProvider {
        return assignmentProvider
    }
    
    func getHolidayProvider() -> HybridHolidayDataProvider {
        return holidayProvider
    }
    
    func getCourseProvider() -> HybridCourseDataProvider {
        return courseProvider
    }
    
    // MARK: - Background Sync
    
    func setupBackgroundSync() {
        // This would be called from AppDelegate for background app refresh
        backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performIncrementalSync()
            }
        }
    }
    
    func invalidateBackgroundSync() {
        backgroundSyncTimer?.invalidate()
        backgroundSyncTimer = nil
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                let wasOnline = self.isOnline
                self.isOnline = path.status == .satisfied
                
                // Auto-sync when coming back online
                if !wasOnline && path.status == .satisfied {
                    await self.performIncrementalSync()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func setupDataProviderObservers() {
        // Observe assignment provider sync status
        assignmentProvider.$syncStatus
            .sink { _ in
                // Update pending sync count based on provider status
                // This would be implemented based on your sync queue
            }
            .store(in: &cancellables)
    }
    
    private func startAutoSync() {
        stopAutoSync() // Clear any existing timer
        
        let frequency = UserPreferencesManager.shared.syncFrequency
        guard let interval = frequency.timeInterval else { return }
        
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performIncrementalSync()
            }
        }
    }
    
    private func stopAutoSync() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }
    
    private func syncHolidays() async {
        do {
            let preferences = UserPreferencesManager.shared
            let currentYear = Calendar.current.component(.year, from: Date())
            
            // Fetch holidays for current and next year
            _ = try await holidayProvider.fetchHolidays(for: preferences.selectedCountry, year: currentYear)
            _ = try await holidayProvider.fetchHolidays(for: preferences.selectedCountry, year: currentYear + 1)
        } catch {
            print("Failed to sync holidays: \(error)")
        }
    }
    
    private func syncCourses() async {
        do {
            _ = try await courseProvider.fetchCourses()
        } catch {
            print("Failed to sync courses: \(error)")
        }
    }
    
    // MARK: - Persistence
    
    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }
    
    private func saveLastSyncDate() {
        if let date = lastSyncDate {
            UserDefaults.standard.set(date, forKey: "lastSyncDate")
        }
    }
    
    // MARK: - Sync Diagnostics
    
    func getSyncDiagnostics() -> SyncDiagnostics {
        return SyncDiagnostics(
            isOnline: isOnline,
            lastSyncDate: lastSyncDate,
            autoSyncEnabled: UserPreferencesManager.shared.autoSyncEnabled,
            syncFrequency: UserPreferencesManager.shared.syncFrequency,
            pendingSyncCount: pendingSyncCount,
            currentStatus: syncStatus
        )
    }
}

// MARK: - Supporting Types

struct SyncDiagnostics {
    let isOnline: Bool
    let lastSyncDate: Date?
    let autoSyncEnabled: Bool
    let syncFrequency: SyncFrequency
    let pendingSyncCount: Int
    let currentStatus: String
    
    var timeSinceLastSync: TimeInterval? {
        guard let lastSync = lastSyncDate else { return nil }
        return Date().timeIntervalSince(lastSync)
    }
    
    var formattedLastSync: String {
        guard let lastSync = lastSyncDate else { return "Never" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
}

// MARK: - Sync Events for Analytics

extension DataSynchronizationManager {
    
    func trackSyncEvent(_ eventType: SyncEventType, metadata: [String: Any] = [:]) {
        var props = metadata
        props["sync_type"] = eventType.rawValue
        props["is_online"] = isOnline
        props["auto_sync_enabled"] = UserPreferencesManager.shared.autoSyncEnabled
        
        Analytics.shared.track("sync_event", props: props)
    }
}

enum SyncEventType: String {
    case started = "started"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    case backgroundRefresh = "background_refresh"
}