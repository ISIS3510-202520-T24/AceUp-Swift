//
//  TeacherRepositoryProtocol.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/12/25.
//

import Foundation

/// Protocol defining teacher repository operations
protocol TeacherRepositoryProtocol: AnyObject {
    // MARK: - CRUD Operations
    
    /// Fetches all teachers from cache or remote
    func getAllTeachers() async throws -> [Teacher]
    
    /// Fetches a specific teacher by ID
    func fetchById(_ id: String) async throws -> Teacher?
    
    /// Saves a new teacher
    func saveTeacher(_ teacher: Teacher) async throws
    
    /// Updates an existing teacher
    func updateTeacher(_ teacher: Teacher) async throws
    
    /// Deletes a teacher by ID
    func deleteTeacher(_ id: String) async throws
    
    // MARK: - Course Linking
    
    /// Links a teacher to a course
    func linkCourse(_ courseId: String, to teacherId: String) async throws
    
    /// Unlinks a teacher from a course
    func unlinkCourse(_ courseId: String, from teacherId: String) async throws
    
    /// Fetches all teachers for a specific course
    func getTeachersForCourse(_ courseId: String) async throws -> [Teacher]
    
    // MARK: - Sync Operations
    
    /// Syncs pending operations with remote
    func syncPendingOperations() async
    
    /// Refreshes cache from remote
    func refreshCache() async throws
}
