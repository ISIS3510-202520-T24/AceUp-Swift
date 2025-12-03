//
//  TeacherViewModel.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/12/25.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel for teacher management using MVVM pattern
/// Handles teacher business logic and state management
@MainActor
final class TeacherViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var teachers: [Teacher] = []
    @Published var filteredTeachers: [Teacher] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingCreateTeacher = false
    @Published var showingEditTeacher = false
    @Published var selectedTeacher: Teacher?
    @Published var isSyncing = false
    @Published var pendingOperationsCount = 0
    
    // Form properties for creating/editing teachers
    @Published var teacherName = ""
    @Published var teacherEmail = ""
    @Published var teacherPhone = ""
    @Published var teacherOfficeLocation = ""
    @Published var teacherOfficeHours = ""
    @Published var teacherDepartment = ""
    @Published var teacherNotes = ""
    @Published var linkedCourseIds: [String] = []
    
    // Search and filter
    @Published var searchText = ""
    
    // Dependencies
    private let repository: TeacherRepositoryProtocol
    private let authService = AuthService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(repository: TeacherRepositoryProtocol? = nil) {
        self.repository = repository ?? TeacherRepository()
        setupBindings()
        Task { await loadTeachers() }
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind repository state
        if let repo = repository as? TeacherRepository {
            repo.$teachers
                .receive(on: DispatchQueue.main)
                .assign(to: &$teachers)
            
            repo.$isSyncing
                .receive(on: DispatchQueue.main)
                .assign(to: &$isSyncing)
            
            repo.$pendingOperationsCount
                .receive(on: DispatchQueue.main)
                .assign(to: &$pendingOperationsCount)
        }
        
        // Search text binding
        $searchText
            .combineLatest($teachers)
            .map { searchText, teachers in
                guard !searchText.isEmpty else { return teachers }
                return teachers.filter { teacher in
                    teacher.name.localizedCaseInsensitiveContains(searchText) ||
                    teacher.email?.localizedCaseInsensitiveContains(searchText) == true ||
                    teacher.department?.localizedCaseInsensitiveContains(searchText) == true
                }
            }
            .assign(to: &$filteredTeachers)
    }
    
    // MARK: - Public Methods
    
    /// Loads all teachers from repository
    func loadTeachers() async {
        isLoading = true
        errorMessage = nil
        do {
            teachers = try await repository.getAllTeachers()
            filteredTeachers = teachers
        } catch {
            errorMessage = "Failed to load teachers: \(error.localizedDescription)"
            print("❌ [TeacherViewModel] Load error: \(error)")
        }
        isLoading = false
    }
    
    /// Creates a new teacher
    func createTeacher() async {
        guard validateForm() else { return }
        guard let userId = authService.user?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let newTeacher = Teacher(
            userId: userId,
            name: teacherName.trimmingCharacters(in: .whitespaces),
            email: teacherEmail.isEmpty ? nil : teacherEmail.trimmingCharacters(in: .whitespaces),
            phoneNumber: teacherPhone.isEmpty ? nil : teacherPhone.trimmingCharacters(in: .whitespaces),
            officeLocation: teacherOfficeLocation.isEmpty ? nil : teacherOfficeLocation.trimmingCharacters(in: .whitespaces),
            officeHours: teacherOfficeHours.isEmpty ? nil : teacherOfficeHours.trimmingCharacters(in: .whitespaces),
            department: teacherDepartment.isEmpty ? nil : teacherDepartment.trimmingCharacters(in: .whitespaces),
            linkedCourseIds: linkedCourseIds,
            notes: teacherNotes.isEmpty ? nil : teacherNotes.trimmingCharacters(in: .whitespaces)
        )
        
        do {
            try await repository.saveTeacher(newTeacher)
            await loadTeachers()
            clearForm()
            showingCreateTeacher = false
            print("✅ [TeacherViewModel] Teacher created: \(newTeacher.name)")
        } catch {
            errorMessage = "Failed to create teacher: \(error.localizedDescription)"
            print("❌ [TeacherViewModel] Create error: \(error)")
        }
        
        isLoading = false
    }
    
    /// Updates an existing teacher
    func updateTeacher() async {
        guard let teacher = selectedTeacher, validateForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        let updatedTeacher = teacher.copying(
            name: teacherName.trimmingCharacters(in: .whitespaces),
            email: teacherEmail.isEmpty ? nil : teacherEmail.trimmingCharacters(in: .whitespaces),
            phoneNumber: teacherPhone.isEmpty ? nil : teacherPhone.trimmingCharacters(in: .whitespaces),
            officeLocation: teacherOfficeLocation.isEmpty ? nil : teacherOfficeLocation.trimmingCharacters(in: .whitespaces),
            officeHours: teacherOfficeHours.isEmpty ? nil : teacherOfficeHours.trimmingCharacters(in: .whitespaces),
            department: teacherDepartment.isEmpty ? nil : teacherDepartment.trimmingCharacters(in: .whitespaces),
            linkedCourseIds: linkedCourseIds,
            notes: teacherNotes.isEmpty ? nil : teacherNotes.trimmingCharacters(in: .whitespaces)
        )
        
        do {
            try await repository.updateTeacher(updatedTeacher)
            await loadTeachers()
            clearForm()
            showingEditTeacher = false
            selectedTeacher = nil
            print("✅ [TeacherViewModel] Teacher updated: \(updatedTeacher.name)")
        } catch {
            errorMessage = "Failed to update teacher: \(error.localizedDescription)"
            print("❌ [TeacherViewModel] Update error: \(error)")
        }
        
        isLoading = false
    }
    
    /// Deletes a teacher
    func deleteTeacher(_ teacher: Teacher) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await repository.deleteTeacher(teacher.id)
            await loadTeachers()
            print("✅ [TeacherViewModel] Teacher deleted: \(teacher.name)")
        } catch {
            errorMessage = "Failed to delete teacher: \(error.localizedDescription)"
            print("❌ [TeacherViewModel] Delete error: \(error)")
        }
        
        isLoading = false
    }
    
    /// Links a course to a teacher
    func linkCourse(_ courseId: String, to teacherId: String) async {
        do {
            try await repository.linkCourse(courseId, to: teacherId)
            await loadTeachers()
            print("✅ [TeacherViewModel] Course linked: \(courseId) -> \(teacherId)")
        } catch {
            errorMessage = "Failed to link course: \(error.localizedDescription)"
            print("❌ [TeacherViewModel] Link error: \(error)")
        }
    }
    
    /// Unlinks a course from a teacher
    func unlinkCourse(_ courseId: String, from teacherId: String) async {
        do {
            try await repository.unlinkCourse(courseId, from: teacherId)
            await loadTeachers()
            print("✅ [TeacherViewModel] Course unlinked: \(courseId) -> \(teacherId)")
        } catch {
            errorMessage = "Failed to unlink course: \(error.localizedDescription)"
            print("❌ [TeacherViewModel] Unlink error: \(error)")
        }
    }
    
    /// Gets teachers for a specific course
    func getTeachersForCourse(_ courseId: String) async -> [Teacher] {
        do {
            return try await repository.getTeachersForCourse(courseId)
        } catch {
            errorMessage = "Failed to get teachers for course: \(error.localizedDescription)"
            return []
        }
    }
    
    /// Syncs pending operations
    func syncPendingOperations() async {
        await repository.syncPendingOperations()
    }
    
    /// Refreshes cache from remote
    func refreshCache() async {
        isLoading = true
        do {
            try await repository.refreshCache()
            await loadTeachers()
        } catch {
            errorMessage = "Failed to refresh: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // MARK: - Form Management
    
    /// Prepares form for editing a teacher
    func editTeacher(_ teacher: Teacher) {
        selectedTeacher = teacher
        teacherName = teacher.name
        teacherEmail = teacher.email ?? ""
        teacherPhone = teacher.phoneNumber ?? ""
        teacherOfficeLocation = teacher.officeLocation ?? ""
        teacherOfficeHours = teacher.officeHours ?? ""
        teacherDepartment = teacher.department ?? ""
        teacherNotes = teacher.notes ?? ""
        linkedCourseIds = teacher.linkedCourseIds
        showingEditTeacher = true
    }
    
    /// Clears the form
    func clearForm() {
        teacherName = ""
        teacherEmail = ""
        teacherPhone = ""
        teacherOfficeLocation = ""
        teacherOfficeHours = ""
        teacherDepartment = ""
        teacherNotes = ""
        linkedCourseIds = []
        selectedTeacher = nil
        errorMessage = nil
    }
    
    /// Validates form input
    private func validateForm() -> Bool {
        let trimmedName = teacherName.trimmingCharacters(in: .whitespaces)
        
        if trimmedName.isEmpty {
            errorMessage = "Teacher name is required"
            return false
        }
        
        if !teacherEmail.isEmpty {
            let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
            if !emailPredicate.evaluate(with: teacherEmail.trimmingCharacters(in: .whitespaces)) {
                errorMessage = "Invalid email format"
                return false
            }
        }
        
        return true
    }
    
    /// Computed property for form validation
    var isFormValid: Bool {
        !teacherName.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
