//
//  DataSynchronizationManager.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 7/10/25.
//

import Foundation
import Combine
import Network
import FirebaseAnalytics

@MainActor
final class DataSynchronizationManager: ObservableObject {

    static let shared = DataSynchronizationManager()

    // MARK: - Estado observable
    @Published var isOnline = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncProgress: Double = 0.0
    @Published var syncStatus: String = "Ready"
    @Published var pendingSyncCount: Int = 0

    // MARK: - Privado
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "DataSyncNetworkMonitor")

    // Use unified provider for optimized data access
    private let unifiedProvider = UnifiedHybridDataProviders.shared

    private var autoSyncTimer: Timer?
    private var backgroundSyncTimer: Timer?

    // MARK: - Init
    private init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = (path.status == .satisfied)
                if path.status == .satisfied {
                    await self?.triggerFullSync()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)

        refreshPendingCount()
    }

    deinit {
        networkMonitor.cancel()
        autoSyncTimer?.invalidate()
        backgroundSyncTimer?.invalidate()
    }

    // MARK: - API pública
    func setupBackgroundSync() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: 60 * 30, repeats: true) { [weak self] _ in
            Task { await self?.triggerLightSync() }
        }
    }

    func triggerLightSync() async {
        guard isOnline else { 
            print("⚠️ Cannot sync: offline")
            return 
        }
        isSyncing = true
        syncStatus = "Syncing"
        syncProgress = 0.0

        do {
            // Sync pending operations first
            syncProgress = 0.3
            await unifiedProvider.assignments.syncPendingOperations()
            
            // Then perform full sync
            syncProgress = 0.6
            try await unifiedProvider.assignments.performFullSync()
            
            syncProgress = 1.0
            syncStatus = "Completed"
            print("✅ Light sync completed")
        } catch {
            // No rompas la UI; registra el error
            print("❌ Light sync error: \(error)")
            syncStatus = "Error"
        }

        isSyncing = false
        lastSyncDate = Date()
        refreshPendingCount()
    }

    func triggerFullSync() async {
        guard isOnline else { 
            print("⚠️ Cannot sync: offline")
            return 
        }
        isSyncing = true
        syncStatus = "Syncing"
        syncProgress = 0.0

        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // 1. Sync pending assignment operations
            syncProgress = 0.2
            await unifiedProvider.assignments.syncPendingOperations()
            
            // 2. Use batched parallel sync for all data types
            syncProgress = 0.4
            try await unifiedProvider.performBatchedFullSync()
            
            syncProgress = 1.0
            syncStatus = "Completed"
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            
            print("✅ Full sync completed in \(String(format: "%.2f", duration))s")
            
            // Print cache statistics
            let stats = unifiedProvider.getCacheStatistics()
            print("📊 Cache: \(stats.assignmentsCount) assignments, \(stats.coursesCount) courses, \(stats.holidaysCount) holidays")
        } catch {
            print("❌ Full sync error: \(error)")
            syncStatus = "Error"
        }

        isSyncing = false
        lastSyncDate = Date()
        refreshPendingCount()

        // Notificaciones para el BQ 2.4 notificar por inactividad
        NotificationService.scheduleStaleUpdateReminderIfNeeded(thresholdDays: 3)

        Analytics.logEvent("background_full_sync", parameters: [
            "source": "ios_app",
            "sync_status": syncStatus
        ])
    }

    // MARK: - Compatibilidad con llamadas existentes
    func performFullSync() async { await triggerFullSync() }
    func performIncrementalSync() async { await triggerLightSync() }

    func getHolidayProvider() -> HybridHolidayDataProvider { 
        unifiedProvider.holidays
    }
    
    func getAssignmentProvider() -> HybridAssignmentDataProvider { 
        unifiedProvider.assignments
    }
    
    func getCourseProvider() -> HybridCourseDataProvider { 
        unifiedProvider.courses
    }

    func getAssignmentPendingSyncCount() -> Int {
        unifiedProvider.assignments.getPendingOperationsCount()
    }
    
    /// Refresh pending count and update OfflineManager
    private func refreshPendingCount() {
        let count = unifiedProvider.assignments.getPendingOperationsCount()
        pendingSyncCount = count
        
        // Also update OfflineManager
        Task { @MainActor in
            OfflineManager.shared.pendingSyncOperations = count
        }
    }

    // MARK: - Diagnóstico para SettingsView
    struct SyncDiagnostics {
        let autoSyncEnabled: Bool
        let syncFrequency: SyncFrequency
        let formattedLastSync: String
    }

    enum SyncFrequency {
        case thirtyMinutes
        var displayName: String { "Every 30 min" }
    }

    func getSyncDiagnostics() -> SyncDiagnostics {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        let ls = lastSyncDate.map { df.string(from: $0) } ?? "Never"
        return SyncDiagnostics(
            autoSyncEnabled: autoSyncTimer != nil,
            syncFrequency: .thirtyMinutes,
            formattedLastSync: ls
        )
    }

    // MARK: - Utilidades
    // Modelo de item para cola de sync (simple y Codable)
    struct SyncItem: Codable, Equatable {
        let id: String
        let type: String
        let createdAt: Date
        let payload: [String: String]?

        init(id: String = UUID().uuidString,
             type: String,
             createdAt: Date = Date(),
             payload: [String: String]? = nil) {
            self.id = id
            self.type = type
            self.createdAt = createdAt
            self.payload = payload
        }
    }

    private func readPendingSyncItems() -> [SyncItem] {
        guard
            let data = UserDefaults.standard.data(forKey: "pendingSyncItems"),
            let items = try? JSONDecoder().decode([SyncItem].self, from: data)
        else { return [] }
        return items
    }
}
