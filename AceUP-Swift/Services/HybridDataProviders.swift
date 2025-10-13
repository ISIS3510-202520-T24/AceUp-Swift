//
//  HybridDataProviders.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 7/10/25.
//

// HybridDataProviders.swift
import Foundation
import Combine
import Network

// =====================================================
// MARK: - Hybrid Assignment Data Provider
// =====================================================

@MainActor
class HybridAssignmentDataProvider: AssignmentDataProviderProtocol, ObservableObject {

    // MARK: Properties
    private let localProvider: CoreDataAssignmentDataProvider
    private let remoteProvider: FirebaseAssignmentDataProvider
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")

    @Published var isOnline = false
    @Published var syncStatus: SyncStatus = .idle

    private var lastSyncTimestamp: Date {
        get { UserDefaults.standard.object(forKey: "lastAssignmentSync") as? Date ?? .distantPast }
        set { UserDefaults.standard.set(newValue, forKey: "lastAssignmentSync") }
    }

    // MARK: Init
    init(localProvider: CoreDataAssignmentDataProvider? = nil,
         remoteProvider: FirebaseAssignmentDataProvider? = nil) {
        self.localProvider = localProvider ?? CoreDataAssignmentDataProvider()
        self.remoteProvider = remoteProvider ?? FirebaseAssignmentDataProvider()

        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = (path.status == .satisfied)
                if path.status == .satisfied {
                    await self?.performFullSync()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    deinit { networkMonitor.cancel() }

    // MARK: AssignmentDataProviderProtocol
    func fetchAll() async throws -> [Assignment] {
        let local = try await localProvider.fetchAll()
        if isOnline {
            Task { @MainActor in await self.syncFromRemote() }
        }
        return local
    }

    func fetchById(_ id: String) async throws -> Assignment? {
        if let a = try await localProvider.fetchById(id) { return a }
        if isOnline, let r = try await remoteProvider.fetchById(id) {
            try await localProvider.save(r)
            return r
        }
        return nil
    }

    func save(_ assignment: Assignment) async throws {
        try await localProvider.save(assignment)
        if isOnline {
            do {
                try await remoteProvider.save(assignment)
                markAsSynced(assignment.id)
            } catch {
                markAsNeedingSync(assignment.id)
                throw error
            }
        } else {
            markAsNeedingSync(assignment.id)
        }
    }

    func update(_ assignment: Assignment) async throws {
        try await localProvider.update(assignment)
        if isOnline {
            do {
                try await remoteProvider.update(assignment)
                markAsSynced(assignment.id)
            } catch {
                markAsNeedingSync(assignment.id)
                throw error
            }
        } else {
            markAsNeedingSync(assignment.id)
        }
    }

    func delete(_ id: String) async throws {
        try await localProvider.delete(id)
        if isOnline {
            do {
                try await remoteProvider.delete(id)
                removeFromSyncQueue(id)
            } catch {
                markAsNeedingDeletion(id)
                throw error
            }
        } else {
            markAsNeedingDeletion(id)
        }
    }

    // MARK: Sync
    func performFullSync() async {
        guard isOnline else { return }
        syncStatus = .syncing
        await syncPendingChangesToRemote()
        await syncFromRemote()
        lastSyncTimestamp = Date()
        syncStatus = .completed
    }

    private func syncFromRemote() async {
        do {
            let remote = try await remoteProvider.fetchAll()
            for a in remote {
                try await localProvider.update(a)
                markAsSynced(a.id)
            }
        } catch { print("Failed to sync from remote: \(error)") }
    }

    private func syncPendingChangesToRemote() async {
        for item in getPendingSyncItems() {
            do {
                switch item.action {
                case .create, .update:
                    if let a = try await localProvider.fetchById(item.assignmentId) {
                        try await remoteProvider.save(a)
                        markAsSynced(item.assignmentId)
                    }
                case .delete:
                    try await remoteProvider.delete(item.assignmentId)
                    removeFromSyncQueue(item.assignmentId)
                }
            } catch { print("Failed to sync item \(item.assignmentId): \(error)") }
        }
    }

    // MARK: Helpers públicos
    func markCompleted(id: String) async throws {
        guard let a = try await localProvider.fetchById(id) else {
            throw PersistenceError.objectNotFound
        }
        let updated = a.copying(status: AssignmentStatus.completed)
        try await update(updated)
    }

    // MARK: Sync queue utils
    private func markAsNeedingSync(_ id: String) {
        var items = getPendingSyncItems()
        items.removeAll { $0.assignmentId == id }
        items.append(SyncItem(assignmentId: id, action: .update, timestamp: Date()))
        savePendingSyncItems(items)
    }

    private func markAsNeedingDeletion(_ id: String) {
        var items = getPendingSyncItems()
        items.removeAll { $0.assignmentId == id }
        items.append(SyncItem(assignmentId: id, action: .delete, timestamp: Date()))
        savePendingSyncItems(items)
    }

    private func markAsSynced(_ id: String) {
        var items = getPendingSyncItems()
        items.removeAll { $0.assignmentId == id }
        savePendingSyncItems(items)
    }

    private func removeFromSyncQueue(_ id: String) {
        var items = getPendingSyncItems()
        items.removeAll { $0.assignmentId == id }
        savePendingSyncItems(items)
    }

    private func getPendingSyncItems() -> [SyncItem] {
        guard let data = UserDefaults.standard.data(forKey: "pendingSyncItems"),
              let items = try? JSONDecoder().decode([SyncItem].self, from: data) else { return [] }
        return items
    }

    private func savePendingSyncItems(_ items: [SyncItem]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "pendingSyncItems")
        }
    }
}

// =====================================================
// MARK: - Hybrid Holiday Data Provider
// =====================================================

@MainActor
class HybridHolidayDataProvider: ObservableObject {

    private let localProvider: CoreDataHolidayDataProvider
    private let remoteProvider: FirebaseHolidayDataProvider
    private let holidayService: HolidayService

    @Published var isOnline = false

    init(localProvider: CoreDataHolidayDataProvider? = nil,
         remoteProvider: FirebaseHolidayDataProvider? = nil,
         holidayService: HolidayService? = nil) {
        self.localProvider = localProvider ?? CoreDataHolidayDataProvider()
        self.remoteProvider = remoteProvider ?? FirebaseHolidayDataProvider()
        self.holidayService = holidayService ?? HolidayService()

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = (path.status == .satisfied)
            }
        }
        monitor.start(queue: DispatchQueue(label: "HolidayNetworkMonitor"))
    }

    func fetchHolidays(for country: String, year: Int) async throws -> [Holiday] {
        let local = try await localProvider.fetchHolidays(for: country, year: year)
        if !local.isEmpty {
            if isOnline {
                Task { @MainActor in
                    do {
                        let ext = try await holidayService.fetchHolidays(countryCode: country, year: year)
                        try await localProvider.saveHolidays(ext)
                        await saveHolidaysToFirebase(ext)
                    } catch { }
                }
            }
            return local
        }

        if isOnline {
            do {
                let ext = try await holidayService.fetchHolidays(countryCode: country, year: year)
                try await localProvider.saveHolidays(ext)
                await saveHolidaysToFirebase(ext)
                return ext
            } catch {
                let remote = try await remoteProvider.fetchHolidays(for: country, year: year)
                if !remote.isEmpty {
                    try await localProvider.saveHolidays(remote)
                    return remote
                }
                throw error
            }
        }

        return []
    }

    private func saveHolidaysToFirebase(_ holidays: [Holiday]) async {
        do {
            for h in holidays { try await remoteProvider.saveHoliday(h) }
        } catch { }
    }

    func fetchAllHolidays() async throws -> [Holiday] {
        let local = try await localProvider.fetchAllHolidays()
        if isOnline {
            Task { @MainActor in
                do {
                    let remote = try await remoteProvider.fetchAllHolidays()
                    try await localProvider.saveHolidays(remote)
                } catch { }
            }
        }
        return local
    }
}

// =====================================================
// MARK: - Hybrid Course Data Provider
// =====================================================

@MainActor
class HybridCourseDataProvider: ObservableObject {

    private let localProvider: CoreDataCourseDataProvider
    private let remoteProvider: FirebaseCourseDataProvider

    @Published var isOnline = false

    init(localProvider: CoreDataCourseDataProvider? = nil,
         remoteProvider: FirebaseCourseDataProvider? = nil) {
        self.localProvider = localProvider ?? CoreDataCourseDataProvider()
        self.remoteProvider = remoteProvider ?? FirebaseCourseDataProvider()

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = (path.status == .satisfied)
            }
        }
        monitor.start(queue: DispatchQueue(label: "CourseNetworkMonitor"))
    }

    func fetchCourses() async throws -> [Course] {
        let local = try await localProvider.fetchCourses()
        if isOnline {
            Task { @MainActor in
                do {
                    let remote = try await remoteProvider.fetchCourses()
                    for c in remote { try await localProvider.saveCourse(c) }
                } catch { }
            }
        }
        return local
    }

    func saveCourse(_ course: Course) async throws {
        try await localProvider.saveCourse(course)
        if isOnline { try await remoteProvider.saveCourse(course) }
    }

    func updateCourse(_ course: Course) async throws {
        try await localProvider.updateCourse(course)
        if isOnline { try await remoteProvider.updateCourse(course) }
    }

    func deleteCourse(_ courseId: String) async throws {
        try await localProvider.deleteCourse(courseId)
        if isOnline { try await remoteProvider.deleteCourse(courseId) }
    }
}

// =====================================================
// MARK: - Tipos de soporte (comparten con HybridAssignment)
// =====================================================

enum SyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case failed(Error)

    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.completed, .completed): return true
        case (.failed, .failed): return true
        default: return false
        }
    }
}

enum SyncAction: String, Codable { case create, update, delete }

struct SyncItem: Codable {
    let assignmentId: String
    let action: SyncAction
    let timestamp: Date
}
