//
//  TeacherRepository.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/12/25.
//
//  NSCACHE WITH FIRESTORE FALLBACK + EVENTUAL CONNECTIVITY STRATEGY
//  - Uses NSCache for automatic memory-managed caching of teacher profiles
//  - Firestore as persistent fallback for data synchronization
//  - Queues all changes when offline for eventual sync when connectivity is restored
//  - Provides immediate feedback in UI while handling background sync
//  - NSCache provides automatic eviction under memory pressure

import Foundation
import Combine
import FirebaseFirestore

// MARK: - NSCache Wrapper
/// Wrapper class to store Teacher objects in NSCache (NSCache requires reference types)
private final class TeacherCacheWrapper {
    let teacher: Teacher
    
    init(teacher: Teacher) {
        self.teacher = teacher
    }
}

// MARK: - Pending Operation Types
/// Represents operations queued for eventual sync
enum TeacherPendingOperation: Codable {
    case create(Teacher)
    case update(Teacher)
    case delete(String) // teacher ID
    case linkCourse(teacherId: String, courseId: String)
    case unlinkCourse(teacherId: String, courseId: String)
    
    enum CodingKeys: String, CodingKey {
        case type
        case teacher
        case teacherId
        case courseId
    }
    
    enum OperationType: String, Codable {
        case create, update, delete, linkCourse, unlinkCourse
    }
    
    // Custom encoding for heterogeneous enum
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .create(let teacher):
            try container.encode(OperationType.create, forKey: .type)
            try container.encode(teacher, forKey: .teacher)
        case .update(let teacher):
            try container.encode(OperationType.update, forKey: .type)
            try container.encode(teacher, forKey: .teacher)
        case .delete(let teacherId):
            try container.encode(OperationType.delete, forKey: .type)
            try container.encode(teacherId, forKey: .teacherId)
        case .linkCourse(let teacherId, let courseId):
            try container.encode(OperationType.linkCourse, forKey: .type)
            try container.encode(teacherId, forKey: .teacherId)
            try container.encode(courseId, forKey: .courseId)
        case .unlinkCourse(let teacherId, let courseId):
            try container.encode(OperationType.unlinkCourse, forKey: .type)
            try container.encode(teacherId, forKey: .teacherId)
            try container.encode(courseId, forKey: .courseId)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(OperationType.self, forKey: .type)
        
        switch type {
        case .create:
            let teacher = try container.decode(Teacher.self, forKey: .teacher)
            self = .create(teacher)
        case .update:
            let teacher = try container.decode(Teacher.self, forKey: .teacher)
            self = .update(teacher)
        case .delete:
            let teacherId = try container.decode(String.self, forKey: .teacherId)
            self = .delete(teacherId)
        case .linkCourse:
            let teacherId = try container.decode(String.self, forKey: .teacherId)
            let courseId = try container.decode(String.self, forKey: .courseId)
            self = .linkCourse(teacherId: teacherId, courseId: courseId)
        case .unlinkCourse:
            let teacherId = try container.decode(String.self, forKey: .teacherId)
            let courseId = try container.decode(String.self, forKey: .courseId)
            self = .unlinkCourse(teacherId: teacherId, courseId: courseId)
        }
    }
}

// MARK: - Teacher Repository
@MainActor
final class TeacherRepository: ObservableObject, TeacherRepositoryProtocol {
    
    // MARK: - Published Properties
    @Published private(set) var teachers: [Teacher] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var pendingOperationsCount = 0
    
    // MARK: - Private Properties
    private let teacherCache = NSCache<NSString, TeacherCacheWrapper>() // NSCache for automatic memory management
    private var teacherIds: Set<String> = [] // Track IDs since NSCache doesn't support enumeration
    private var pendingOperations: [TeacherPendingOperation] = []
    private let db = Firestore.firestore()
    private let offlineManager = OfflineManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // UserDefaults keys for persistence
    private let pendingOpsKey = "TeacherRepository.pendingOperations"
    private let lastSyncKey = "TeacherRepository.lastSync"
    
    // MARK: - Initialization
    init() {
        configureCache()
        loadPendingOperations()
        setupConnectivityObserver()
        Task {
            await refreshCacheIfNeeded()
        }
    }
    
    // MARK: - Setup
    
    /// Configures NSCache settings
    private func configureCache() {
        teacherCache.countLimit = 100 // Maximum number of teachers to cache
        teacherCache.totalCostLimit = 1024 * 1024 * 10 // 10 MB cache limit
        teacherCache.name = "TeacherCache"
    }
    
    /// Observes network connectivity changes and triggers sync when online
    private func setupConnectivityObserver() {
        offlineManager.$isOnline
            .removeDuplicates()
            .sink { [weak self] isOnline in
                guard let self = self, isOnline else { return }
                print("🌐 [TeacherRepository] Connection restored, syncing pending operations...")
                Task { await self.syncPendingOperations() }
            }
            .store(in: &cancellables)
    }
    
    /// Loads pending operations from persistent storage
    private func loadPendingOperations() {
        guard let data = UserDefaults.standard.data(forKey: pendingOpsKey),
              let ops = try? JSONDecoder().decode([TeacherPendingOperation].self, from: data) else {
            return
        }
        pendingOperations = ops
        pendingOperationsCount = ops.count
        print("📦 [TeacherRepository] Loaded \(ops.count) pending operations from storage")
    }
    
    /// Saves pending operations to persistent storage
    private func savePendingOperations() {
        guard let data = try? JSONEncoder().encode(pendingOperations) else { return }
        UserDefaults.standard.set(data, forKey: pendingOpsKey)
        pendingOperationsCount = pendingOperations.count
    }
    
    /// Refreshes cache from Firestore if needed (on app launch or manual refresh)
    private func refreshCacheIfNeeded() async {
        guard offlineManager.isOnline else {
            print("⚠️ [TeacherRepository] Offline - using cached data")
            return
        }
        
        let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        let shouldRefresh = lastSync == nil || Date().timeIntervalSince(lastSync!) > 3600 // 1 hour
        
        if shouldRefresh {
            do {
                try await refreshCache()
            } catch {
                print("❌ [TeacherRepository] Failed to refresh cache: \(error)")
            }
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Fetches all teachers from cache or remote
    func getAllTeachers() async throws -> [Teacher] {
        // Try cache first
        let cachedTeachers = getAllCachedTeachers()
        if !cachedTeachers.isEmpty {
            teachers = cachedTeachers.sorted { $0.name < $1.name }
            return teachers
        }
        
        // Fetch from Firestore if online
        guard offlineManager.isOnline else {
            print("⚠️ [TeacherRepository] Offline - returning empty array")
            return []
        }
        
        do {
            try await refreshCache()
            return teachers
        } catch {
            print("❌ [TeacherRepository] Failed to fetch teachers: \(error)")
            throw error
        }
    }
    
    /// Fetches a specific teacher by ID
    func fetchById(_ id: String) async throws -> Teacher? {
        // Check cache first
        if let wrapper = teacherCache.object(forKey: id as NSString) {
            return wrapper.teacher
        }
        
        // Fetch from Firestore if online
        guard offlineManager.isOnline else {
            print("⚠️ [TeacherRepository] Offline - teacher not in cache")
            return nil
        }
        
        let snapshot = try await db.collection("teachers").document(id).getDocument()
        guard let data = snapshot.data(),
              let teacher = Teacher.fromFirestoreData(data, id: id) else {
            return nil
        }
        
        // Update cache
        teacherCache.setObject(TeacherCacheWrapper(teacher: teacher), forKey: id as NSString)
        teacherIds.insert(id)
        updateTeachersArray()
        
        return teacher
    }
    
    /// Saves a new teacher
    func saveTeacher(_ teacher: Teacher) async throws {
        // Update cache immediately for instant UI feedback
        teacherCache.setObject(TeacherCacheWrapper(teacher: teacher), forKey: teacher.id as NSString)
        teacherIds.insert(teacher.id)
        updateTeachersArray()
        
        // Queue operation if offline
        if !offlineManager.isOnline {
            queueOperation(.create(teacher))
            print("📝 [TeacherRepository] Queued teacher creation (offline): \(teacher.name)")
            return
        }
        
        // Save to Firestore if online
        do {
            try await db.collection("teachers").document(teacher.id).setData(teacher.toFirestoreData())
            print("✅ [TeacherRepository] Teacher saved to Firestore: \(teacher.name)")
        } catch {
            // Queue for later sync on error
            queueOperation(.create(teacher))
            print("⚠️ [TeacherRepository] Failed to save, queued for sync: \(error)")
        }
    }
    
    /// Updates an existing teacher
    func updateTeacher(_ teacher: Teacher) async throws {
        let updated = teacher.copying(updatedAt: Date())
        
        // Update cache immediately
        teacherCache.setObject(TeacherCacheWrapper(teacher: updated), forKey: updated.id as NSString)
        teacherIds.insert(updated.id)
        updateTeachersArray()
        
        // Queue operation if offline
        if !offlineManager.isOnline {
            queueOperation(.update(updated))
            print("📝 [TeacherRepository] Queued teacher update (offline): \(updated.name)")
            return
        }
        
        // Update in Firestore if online
        do {
            try await db.collection("teachers").document(updated.id).updateData(updated.toFirestoreData())
            print("✅ [TeacherRepository] Teacher updated in Firestore: \(updated.name)")
        } catch {
            // Queue for later sync on error
            queueOperation(.update(updated))
            print("⚠️ [TeacherRepository] Failed to update, queued for sync: \(error)")
        }
    }
    
    /// Deletes a teacher by ID
    func deleteTeacher(_ id: String) async throws {
        // Remove from cache immediately
        teacherCache.removeObject(forKey: id as NSString)
        teacherIds.remove(id)
        updateTeachersArray()
        
        // Queue operation if offline
        if !offlineManager.isOnline {
            queueOperation(.delete(id))
            print("📝 [TeacherRepository] Queued teacher deletion (offline): \(id)")
            return
        }
        
        // Delete from Firestore if online
        do {
            try await db.collection("teachers").document(id).delete()
            print("✅ [TeacherRepository] Teacher deleted from Firestore: \(id)")
        } catch {
            // Queue for later sync on error
            queueOperation(.delete(id))
            print("⚠️ [TeacherRepository] Failed to delete, queued for sync: \(error)")
        }
    }
    
    // MARK: - Course Linking
    
    /// Links a teacher to a course
    func linkCourse(_ courseId: String, to teacherId: String) async throws {
        guard let wrapper = teacherCache.object(forKey: teacherId as NSString) else {
            throw NSError(domain: "TeacherRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Teacher not found"])
        }
        let teacher = wrapper.teacher
        
        // Update local cache
        var linkedCourses = teacher.linkedCourseIds
        if !linkedCourses.contains(courseId) {
            linkedCourses.append(courseId)
            let updated = teacher.copying(linkedCourseIds: linkedCourses, updatedAt: Date())
            teacherCache.setObject(TeacherCacheWrapper(teacher: updated), forKey: teacherId as NSString)
            teacherIds.insert(teacherId)
            updateTeachersArray()
        }
        
        // Queue operation if offline
        if !offlineManager.isOnline {
            queueOperation(.linkCourse(teacherId: teacherId, courseId: courseId))
            print("📝 [TeacherRepository] Queued course link (offline): \(courseId) -> \(teacherId)")
            return
        }
        
        // Update in Firestore if online
        do {
            try await db.collection("teachers").document(teacherId).updateData([
                "linkedCourseIds": FieldValue.arrayUnion([courseId]),
                "updatedAt": Date()
            ])
            print("✅ [TeacherRepository] Course linked in Firestore")
        } catch {
            queueOperation(.linkCourse(teacherId: teacherId, courseId: courseId))
            print("⚠️ [TeacherRepository] Failed to link course, queued for sync: \(error)")
        }
    }
    
    /// Unlinks a teacher from a course
    func unlinkCourse(_ courseId: String, from teacherId: String) async throws {
        guard let wrapper = teacherCache.object(forKey: teacherId as NSString) else {
            throw NSError(domain: "TeacherRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Teacher not found"])
        }
        let teacher = wrapper.teacher
        
        // Update local cache
        var linkedCourses = teacher.linkedCourseIds
        linkedCourses.removeAll { $0 == courseId }
        let updated = teacher.copying(linkedCourseIds: linkedCourses, updatedAt: Date())
        teacherCache.setObject(TeacherCacheWrapper(teacher: updated), forKey: teacherId as NSString)
        teacherIds.insert(teacherId)
        updateTeachersArray()
        
        // Queue operation if offline
        if !offlineManager.isOnline {
            queueOperation(.unlinkCourse(teacherId: teacherId, courseId: courseId))
            print("📝 [TeacherRepository] Queued course unlink (offline): \(courseId) -> \(teacherId)")
            return
        }
        
        // Update in Firestore if online
        do {
            try await db.collection("teachers").document(teacherId).updateData([
                "linkedCourseIds": FieldValue.arrayRemove([courseId]),
                "updatedAt": Date()
            ])
            print("✅ [TeacherRepository] Course unlinked in Firestore")
        } catch {
            queueOperation(.unlinkCourse(teacherId: teacherId, courseId: courseId))
            print("⚠️ [TeacherRepository] Failed to unlink course, queued for sync: \(error)")
        }
    }
    
    /// Fetches all teachers for a specific course
    func getTeachersForCourse(_ courseId: String) async throws -> [Teacher] {
        let allTeachers = try await getAllTeachers()
        return allTeachers.filter { $0.linkedCourseIds.contains(courseId) }
    }
    
    // MARK: - Sync Operations
    
    /// Syncs pending operations with remote when connectivity is restored
    func syncPendingOperations() async {
        guard offlineManager.isOnline, !pendingOperations.isEmpty else { return }
        
        isSyncing = true
        print("🔄 [TeacherRepository] Starting sync of \(pendingOperations.count) pending operations...")
        
        var successfulOps = 0
        var failedOps: [TeacherPendingOperation] = []
        
        for operation in pendingOperations {
            do {
                try await executeOperation(operation)
                successfulOps += 1
            } catch {
                print("❌ [TeacherRepository] Failed to sync operation: \(error)")
                failedOps.append(operation)
            }
        }
        
        // Keep only failed operations for retry
        pendingOperations = failedOps
        savePendingOperations()
        
        isSyncing = false
        print("✅ [TeacherRepository] Sync complete: \(successfulOps) successful, \(failedOps.count) failed")
    }
    
    /// Executes a pending operation against Firestore
    private func executeOperation(_ operation: TeacherPendingOperation) async throws {
        switch operation {
        case .create(let teacher):
            try await db.collection("teachers").document(teacher.id).setData(teacher.toFirestoreData())
            
        case .update(let teacher):
            try await db.collection("teachers").document(teacher.id).updateData(teacher.toFirestoreData())
            
        case .delete(let teacherId):
            try await db.collection("teachers").document(teacherId).delete()
            
        case .linkCourse(let teacherId, let courseId):
            try await db.collection("teachers").document(teacherId).updateData([
                "linkedCourseIds": FieldValue.arrayUnion([courseId]),
                "updatedAt": Date()
            ])
            
        case .unlinkCourse(let teacherId, let courseId):
            try await db.collection("teachers").document(teacherId).updateData([
                "linkedCourseIds": FieldValue.arrayRemove([courseId]),
                "updatedAt": Date()
            ])
        }
    }
    
    /// Refreshes cache from Firestore
    func refreshCache() async throws {
        guard offlineManager.isOnline else {
            print("⚠️ [TeacherRepository] Cannot refresh cache - offline")
            return
        }
        
        print("🔄 [TeacherRepository] Refreshing cache from Firestore...")
        
        let snapshot = try await db.collection("teachers").getDocuments()
        
        // Clear existing cache and ID tracking
        teacherCache.removeAllObjects()
        teacherIds.removeAll()
        
        // Populate cache with fetched teachers
        var teacherCount = 0
        for document in snapshot.documents {
            if let teacher = Teacher.fromFirestoreData(document.data(), id: document.documentID) {
                teacherCache.setObject(TeacherCacheWrapper(teacher: teacher), forKey: teacher.id as NSString)
                teacherIds.insert(teacher.id)
                teacherCount += 1
            }
        }
        
        updateTeachersArray()
        
        UserDefaults.standard.set(Date(), forKey: lastSyncKey)
        print("✅ [TeacherRepository] Cache refreshed with \(teacherCount) teachers")
    }
    
    // MARK: - Helper Methods
    
    /// Queues an operation for eventual sync
    private func queueOperation(_ operation: TeacherPendingOperation) {
        pendingOperations.append(operation)
        savePendingOperations()
    }
    
    /// Updates the published teachers array from cache
    private func updateTeachersArray() {
        teachers = getAllCachedTeachers().sorted { $0.name < $1.name }
    }
    
    /// Helper method to get all cached teachers from NSCache using tracked IDs
    private func getAllCachedTeachers() -> [Teacher] {
        return teacherIds.compactMap { id in
            teacherCache.object(forKey: id as NSString)?.teacher
        }
    }
}
