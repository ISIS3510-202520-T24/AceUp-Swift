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

    private let assignmentProvider: HybridAssignmentDataProvider
    private let holidayProvider: HybridHolidayDataProvider
    private let courseProvider: HybridCourseDataProvider

    private var autoSyncTimer: Timer?
    private var backgroundSyncTimer: Timer?

    // MARK: - Init
    private init() {
        self.assignmentProvider = HybridAssignmentDataProvider()
        self.holidayProvider = HybridHolidayDataProvider()
        self.courseProvider = HybridCourseDataProvider()

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
        guard isOnline else { return }
        isSyncing = true
        syncStatus = "Syncing"

        await assignmentProvider.performFullSync()

        isSyncing = false
        lastSyncDate = Date()
        refreshPendingCount()
    }

    func triggerFullSync() async {
        guard isOnline else { return }
        isSyncing = true
        syncStatus = "Syncing"

        await assignmentProvider.performFullSync()
        _ = try? await holidayProvider.fetchAllHolidays()
        _ = try? await courseProvider.fetchCourses()

        isSyncing = false
        syncStatus = "Completed"
        lastSyncDate = Date()
        refreshPendingCount()

        FirebaseAnalytics.Analytics.logEvent("background_full_sync", parameters: [
            "source": "ios_app" as NSString
        ])
    }

    // MARK: - Compatibilidad con llamadas existentes
    func performFullSync() async { await triggerFullSync() }
    func performIncrementalSync() async { await triggerLightSync() }

    func getHolidayProvider() -> HybridHolidayDataProvider { holidayProvider }
    func getAssignmentProvider() -> HybridAssignmentDataProvider { assignmentProvider }
    func getCourseProvider() -> HybridCourseDataProvider { courseProvider }

    func getAssignmentPendingSyncCount() -> Int {
        readPendingSyncItems().count
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
    private func refreshPendingCount() {
        pendingSyncCount = readPendingSyncItems().count
    }

    private func readPendingSyncItems() -> [SyncItem] {
        guard let data = UserDefaults.standard.data(forKey: "pendingSyncItems"),
              let items = try? JSONDecoder().decode([SyncItem].self, from: data) else { return [] }
        return items
    }
}
