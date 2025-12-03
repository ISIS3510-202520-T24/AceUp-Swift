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
    private let unifiedProvider = UnifiedHybridDataProviders.shared
    private let offlineManager = OfflineManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupConnectivityObserver()
        Task {
            await refreshFromCache()
        }
    }
    
    // MARK: - Setup
    
    /// Observes network connectivity changes and triggers sync when online
    private func setupConnectivityObserver() {
        offlineManager.$isOnline
            .removeDuplicates()
            .sink { [weak self] isOnline in
                guard let self = self, isOnline else { return }
                print("🌐 [TeacherRepository] Connection restored, syncing...")
                Task { await self.syncPendingOperations() }
            }
            .store(in: &cancellables)
    }
    
    /// Refreshes from unified cache
    private func refreshFromCache() async {
        teachers = unifiedProvider.getCachedTeachers()
        if teachers.isEmpty {
            do {
                try await getAllTeachers()
            } catch {
                print("❌ [TeacherRepository] Failed to fetch: \(error)")
            }
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Fetches all teachers from cache or remote
    func getAllTeachers() async throws -> [Teacher] {
        teachers = try await unifiedProvider.teachers.fetchAll()
        return teachers.sorted { $0.name < $1.name }
    }
    
    /// Fetches a specific teacher by ID
    func fetchById(_ id: String) async throws -> Teacher? {
        let allTeachers = try await getAllTeachers()
        return allTeachers.first { $0.id == id }
    }
    
    /// Saves a new teacher
    func saveTeacher(_ teacher: Teacher) async throws {
        try await unifiedProvider.teachers.save(teacher)
        teachers = unifiedProvider.getCachedTeachers()
    }
    
    /// Updates an existing teacher
    func updateTeacher(_ teacher: Teacher) async throws {
        let updated = teacher.copying(updatedAt: Date())
        try await unifiedProvider.teachers.update(updated)
        teachers = unifiedProvider.getCachedTeachers()
    }
    
    /// Deletes a teacher by ID
    func deleteTeacher(_ id: String) async throws {
        try await unifiedProvider.teachers.delete(id)
        teachers = unifiedProvider.getCachedTeachers()
    }
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
        
    
    // MARK: - Sync Operations
    
    /// Syncs pending operations when coming online
    func syncPendingOperations() async {
        guard offlineManager.isOnline else { return }
        isSyncing = true
        await unifiedProvider.teachers.syncPendingOperations()
        teachers = unifiedProvider.getCachedTeachers()
        isSyncing = false
    }
    
    /// Refreshes cache from remote
    func refreshCache() async throws {
        guard offlineManager.isOnline else {
            print("⚠️ [TeacherRepository] Cannot refresh - offline")
            return
        }
        try await getAllTeachers()
    }
}
