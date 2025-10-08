//
//  HybridDataProviders.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 7/10/25.
//

import Foundation
import Network
import Combine

/// Hybrid data provider that combines local Core Data storage with Firebase synchronization
/// Provides offline-first experience with automatic cloud sync when available
@MainActor
class HybridAssignmentDataProvider: AssignmentDataProviderProtocol, ObservableObject {
    
    // MARK: - Properties
    
    private let localProvider: CoreDataAssignmentDataProvider
    private let remoteProvider: FirebaseAssignmentDataProvider
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isOnline = false
    @Published var syncStatus: SyncStatus = .idle
    
    private var lastSyncTimestamp: Date {
        get {
            return UserDefaults.standard.object(forKey: "lastAssignmentSync") as? Date ?? Date.distantPast
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastAssignmentSync")
        }
    }
    
    // MARK: - Initialization
    
    init(localProvider: CoreDataAssignmentDataProvider? = nil,
         remoteProvider: FirebaseAssignmentDataProvider? = nil) {
        if let localProvider = localProvider {
            self.localProvider = localProvider
        } else {
            self.localProvider = CoreDataAssignmentDataProvider()
        }
        
        if let remoteProvider = remoteProvider {
            self.remoteProvider = remoteProvider
        } else {
            self.remoteProvider = FirebaseAssignmentDataProvider()
        }
        
        setupNetworkMonitoring()
        
        // Auto-sync on network connection
        if isOnline {
            Task {
                await performFullSync()
            }
        }
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - AssignmentDataProviderProtocol Implementation
    
    func fetchAll() async throws -> [Assignment] {
        // Always return local data first for immediate UI updates
        let localAssignments = try await localProvider.fetchAll()
        
        // If online, sync with remote and return updated data
        if isOnline {
            Task {
                await syncFromRemote()
            }
        }
        
        return localAssignments
    }
    
    func fetchById(_ id: String) async throws -> Assignment? {
        // Try local first
        if let localAssignment = try await localProvider.fetchById(id) {
            return localAssignment
        }
        
        // If not found locally and online, try remote
        if isOnline {
            if let remoteAssignment = try await remoteProvider.fetchById(id) {
                // Save to local for future offline access
                try await localProvider.save(remoteAssignment)
                return remoteAssignment
            }
        }
        
        return nil
    }
    
    func save(_ assignment: Assignment) async throws {
        // Always save locally first
        try await localProvider.save(assignment)
        
        // If online, sync to remote
        if isOnline {
            do {
                try await remoteProvider.save(assignment)
                await markAsSynced(assignment.id)
            } catch {
                await markAsNeedingSync(assignment.id)
                throw error
            }
        } else {
            // Mark for sync when online
            await markAsNeedingSync(assignment.id)
        }
    }
    
    func update(_ assignment: Assignment) async throws {
        // Always update locally first
        try await localProvider.update(assignment)
        
        // If online, sync to remote
        if isOnline {
            do {
                try await remoteProvider.update(assignment)
                await markAsSynced(assignment.id)
            } catch {
                await markAsNeedingSync(assignment.id)
                throw error
            }
        } else {
            // Mark for sync when online
            await markAsNeedingSync(assignment.id)
        }
    }
    
    func delete(_ id: String) async throws {
        // Always delete locally first
        try await localProvider.delete(id)
        
        // If online, sync deletion to remote
        if isOnline {
            do {
                try await remoteProvider.delete(id)
                await removeFromSyncQueue(id)
            } catch {
                await markAsNeedingDeletion(id)
                throw error
            }
        } else {
            // Mark for deletion sync when online
            await markAsNeedingDeletion(id)
        }
    }
    
    // MARK: - Sync Operations
    
    func performFullSync() async {
        guard isOnline else { return }
        
        await updateSyncStatus(.syncing)
        
        do {
            // Sync pending local changes to remote
            await syncPendingChangesToRemote()
            
            // Sync remote changes to local
            await syncFromRemote()
            
            lastSyncTimestamp = Date()
            await updateSyncStatus(.completed)
            
        } catch {
            await updateSyncStatus(.failed(error))
        }
    }
    
    private func syncFromRemote() async {
        do {
            let remoteAssignments = try await remoteProvider.fetchAll()
            
            for assignment in remoteAssignments {
                // Update local with remote data
                try await localProvider.update(assignment)
                await markAsSynced(assignment.id)
            }
        } catch {
            print("Failed to sync from remote: \(error)")
        }
    }
    
    private func syncPendingChangesToRemote() async {
        let pendingItems = await getPendingSyncItems()
        
        for item in pendingItems {
            do {
                switch item.action {
                case .create, .update:
                    if let assignment = try await localProvider.fetchById(item.assignmentId) {
                        try await remoteProvider.save(assignment)
                        await markAsSynced(item.assignmentId)
                    }
                case .delete:
                    try await remoteProvider.delete(item.assignmentId)
                    await removeFromSyncQueue(item.assignmentId)
                }
            } catch {
                print("Failed to sync item \(item.assignmentId): \(error)")
                // Keep in queue for retry
            }
        }
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                
                // Auto-sync when coming back online
                if path.status == .satisfied {
                    Task {
                        await self?.performFullSync()
                    }
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    // MARK: - Sync Status Management
    
    @MainActor
    private func updateSyncStatus(_ status: SyncStatus) {
        syncStatus = status
    }
    
    // MARK: - Sync Queue Management
    
    private func markAsNeedingSync(_ assignmentId: String) async {
        var pendingItems = await getPendingSyncItems()
        let item = SyncItem(assignmentId: assignmentId, action: .update, timestamp: Date())
        
        // Remove existing item and add updated one
        pendingItems.removeAll { $0.assignmentId == assignmentId }
        pendingItems.append(item)
        
        await savePendingSyncItems(pendingItems)
    }
    
    private func markAsNeedingDeletion(_ assignmentId: String) async {
        var pendingItems = await getPendingSyncItems()
        let item = SyncItem(assignmentId: assignmentId, action: .delete, timestamp: Date())
        
        // Remove existing item and add deletion
        pendingItems.removeAll { $0.assignmentId == assignmentId }
        pendingItems.append(item)
        
        await savePendingSyncItems(pendingItems)
    }
    
    private func markAsSynced(_ assignmentId: String) async {
        var pendingItems = await getPendingSyncItems()
        pendingItems.removeAll { $0.assignmentId == assignmentId }
        await savePendingSyncItems(pendingItems)
    }
    
    private func removeFromSyncQueue(_ assignmentId: String) async {
        var pendingItems = await getPendingSyncItems()
        pendingItems.removeAll { $0.assignmentId == assignmentId }
        await savePendingSyncItems(pendingItems)
    }
    
    private func getPendingSyncItems() async -> [SyncItem] {
        guard let data = UserDefaults.standard.data(forKey: "pendingSyncItems"),
              let items = try? JSONDecoder().decode([SyncItem].self, from: data) else {
            return []
        }
        return items
    }
    
    private func savePendingSyncItems(_ items: [SyncItem]) async {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: "pendingSyncItems")
    }
    
    // MARK: - Conflict Resolution
    
    private func resolveConflict(local: Assignment, remote: Assignment) -> Assignment {
        // Simple last-write-wins strategy
        // In a more sophisticated app, you might want to show conflict resolution UI
        return local.updatedAt > remote.updatedAt ? local : remote
    }
}

// MARK: - Supporting Types

enum SyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case failed(Error)
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.completed, .completed):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

enum SyncAction: String, Codable {
    case create = "create"
    case update = "update"
    case delete = "delete"
}

struct SyncItem: Codable {
    let assignmentId: String
    let action: SyncAction
    let timestamp: Date
}

// MARK: - Hybrid Holiday Data Provider

@MainActor
class HybridHolidayDataProvider: ObservableObject {
    
    private let localProvider: CoreDataHolidayDataProvider
    private let remoteProvider: FirebaseHolidayDataProvider
    
    @Published var isOnline = false
    
    init(localProvider: CoreDataHolidayDataProvider? = nil,
         remoteProvider: FirebaseHolidayDataProvider? = nil) {
        self.localProvider = localProvider ?? CoreDataHolidayDataProvider()
        self.remoteProvider = remoteProvider ?? FirebaseHolidayDataProvider()
        
        // Monitor network status
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "HolidayNetworkMonitor"))
    }
    
    func fetchHolidays(for country: String, year: Int) async throws -> [Holiday] {
        // Try local first
        let localHolidays = try await localProvider.fetchHolidays(for: country, year: year)
        
        // If we have local data, return it immediately
        if !localHolidays.isEmpty {
            // If online, sync in background
            if isOnline {
                Task {
                    do {
                        let remoteHolidays = try await remoteProvider.fetchHolidays(for: country, year: year)
                        try await localProvider.saveHolidays(remoteHolidays)
                    } catch {
                        print("Failed to sync holidays: \(error)")
                    }
                }
            }
            return localHolidays
        }
        
        // If no local data and online, fetch from remote
        if isOnline {
            let remoteHolidays = try await remoteProvider.fetchHolidays(for: country, year: year)
            try await localProvider.saveHolidays(remoteHolidays)
            return remoteHolidays
        }
        
        // Offline with no local data
        return []
    }
    
    func fetchAllHolidays() async throws -> [Holiday] {
        // Always return local data first
        let localHolidays = try await localProvider.fetchAllHolidays()
        
        // If online, sync in background
        if isOnline {
            Task {
                do {
                    let remoteHolidays = try await remoteProvider.fetchAllHolidays()
                    try await localProvider.saveHolidays(remoteHolidays)
                } catch {
                    print("Failed to sync all holidays: \(error)")
                }
            }
        }
        
        return localHolidays
    }
}

// MARK: - Hybrid Course Data Provider

@MainActor
class HybridCourseDataProvider: ObservableObject {
    
    private let localProvider: CoreDataCourseDataProvider
    private let remoteProvider: FirebaseCourseDataProvider
    
    @Published var isOnline = false
    
    init(localProvider: CoreDataCourseDataProvider? = nil,
         remoteProvider: FirebaseCourseDataProvider? = nil) {
        self.localProvider = localProvider ?? CoreDataCourseDataProvider()
        self.remoteProvider = remoteProvider ?? FirebaseCourseDataProvider()
        
        // Monitor network status
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "CourseNetworkMonitor"))
    }
    
    func fetchCourses() async throws -> [Course] {
        // Always return local data first
        let localCourses = try await localProvider.fetchCourses()
        
        // If online, sync with remote
        if isOnline {
            Task {
                do {
                    let remoteCourses = try await remoteProvider.fetchCourses()
                    for course in remoteCourses {
                        try await localProvider.saveCourse(course)
                    }
                } catch {
                    print("Failed to sync courses: \(error)")
                }
            }
        }
        
        return localCourses
    }
    
    func saveCourse(_ course: Course) async throws {
        // Always save locally first
        try await localProvider.saveCourse(course)
        
        // If online, sync to remote
        if isOnline {
            try await remoteProvider.saveCourse(course)
        }
    }
    
    func updateCourse(_ course: Course) async throws {
        // Always update locally first
        try await localProvider.updateCourse(course)
        
        // If online, sync to remote
        if isOnline {
            try await remoteProvider.updateCourse(course)
        }
    }
    
    func deleteCourse(_ courseId: String) async throws {
        // Always delete locally first
        try await localProvider.deleteCourse(courseId)
        
        // If online, sync deletion to remote
        if isOnline {
            try await remoteProvider.deleteCourse(courseId)
        }
    }
}