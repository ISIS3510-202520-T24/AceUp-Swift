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
            do {
                try await refreshFromCache()
            } catch {
                print("❌ [TeacherRepository] Failed to refresh from cache: \(error)")
            }
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
    private func refreshFromCache() async throws {
        teachers = try await unifiedProvider.getCachedTeachers()
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
        do {
            let fetchedTeachers = try await unifiedProvider.teachers.fetchAll()
            teachers = fetchedTeachers
            return teachers.sorted { $0.name < $1.name }
        } catch {
            print("❌ [TeacherRepository] Failed to fetch teachers: \(error)")
            throw error
        }
    }
    
    /// Fetches a specific teacher by ID
    func fetchById(_ id: String) async throws -> Teacher? {
        let allTeachers = try await getAllTeachers()
        return allTeachers.first { $0.id == id }
    }
    
    /// Saves a new teacher
    func saveTeacher(_ teacher: Teacher) async throws {
        do {
            try await unifiedProvider.teachers.save(teacher)
            teachers = try await unifiedProvider.getCachedTeachers()
        } catch {
            print("❌ [TeacherRepository] Failed to save teacher: \(error)")
            throw error
        }
    }
    
    /// Updates an existing teacher
    func updateTeacher(_ teacher: Teacher) async throws {
        do {
            let updated = teacher.copying(updatedAt: Date())
            try await unifiedProvider.teachers.update(updated)
            teachers = try await unifiedProvider.getCachedTeachers()
        } catch {
            print("❌ [TeacherRepository] Failed to update teacher: \(error)")
            throw error
        }
    }
    
    /// Deletes a teacher by ID
    func deleteTeacher(_ id: String) async throws {
        do {
            try await unifiedProvider.teachers.delete(id)
            teachers = try await unifiedProvider.getCachedTeachers()
        } catch {
            print("❌ [TeacherRepository] Failed to delete teacher: \(error)")
            throw error
        }
    }
    
    // MARK: - Course Linking
    
    /// Links a teacher to a course
    func linkCourse(_ courseId: String, to teacherId: String) async throws {
        guard let teacher = try await fetchById(teacherId) else {
            throw NSError(domain: "TeacherRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Teacher not found"])
        }
        
        var linkedCourses = teacher.linkedCourseIds
        if !linkedCourses.contains(courseId) {
            linkedCourses.append(courseId)
            let updated = teacher.copying(linkedCourseIds: linkedCourses, updatedAt: Date())
            try await updateTeacher(updated)
        }
    }
    
    /// Unlinks a teacher from a course
    func unlinkCourse(_ courseId: String, from teacherId: String) async throws {
        guard let teacher = try await fetchById(teacherId) else {
            throw NSError(domain: "TeacherRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Teacher not found"])
        }
        
        var linkedCourses = teacher.linkedCourseIds
        linkedCourses.removeAll { $0 == courseId }
        let updated = teacher.copying(linkedCourseIds: linkedCourses, updatedAt: Date())
        try await updateTeacher(updated)
    }
    
    /// Fetches all teachers for a specific course
    func getTeachersForCourse(_ courseId: String) async throws -> [Teacher] {
        let allTeachers = try await getAllTeachers()
        return allTeachers.filter { $0.linkedCourseIds.contains(courseId) }
    }
    
    // MARK: - Sync Operations
    
    /// Syncs pending operations when coming online
    func syncPendingOperations() async {
        guard offlineManager.isOnline else { return }
        isSyncing = true
        await unifiedProvider.teachers.syncPendingOperations()
        do {
            teachers = try await unifiedProvider.getCachedTeachers()
        } catch {
            print("❌ [TeacherRepository] Failed to refresh cache after sync: \(error)")
        }
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
