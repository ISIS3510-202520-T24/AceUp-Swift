import Foundation
import SwiftUI
import Combine

@MainActor
class SubjectViewModel: ObservableObject {
    
    @Published var subjects: [Subject] = []
    @Published var statistics: SubjectStatistics = .empty
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    @Published var formName = ""
    @Published var formCode = ""
    @Published var formCredits = ""
    @Published var formInstructor = ""
    @Published var formColor = "#007AFF"
    @Published var editingSubject: Subject?
    
    private let repository: SubjectRepository
    private let semesterId: String?
    
    init(semesterId: String? = nil, repository: SubjectRepository? = nil) {
        self.semesterId = semesterId
        if let repository = repository {
            self.repository = repository
        } else {
            self.repository = SubjectRepository()
        }
    }
    
    func loadSubjects() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await repository.loadSubjects(semesterId: semesterId)
            subjects = result.all
            statistics = result.statistics
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func createSubject() async {
        guard let creditsValue = Int(formCredits) else {
            errorMessage = "Invalid credits value"
            showError = true
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let instructorValue = formInstructor.isEmpty ? nil : formInstructor
            
            _ = try await repository.createSubject(
                name: formName,
                code: formCode,
                credits: Double(creditsValue),
                instructor: instructorValue,
                color: formColor,
                semesterId: semesterId
            )
            
            await loadSubjects()
            resetForm()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func updateSubject() async {
        guard let subject = editingSubject,
              let creditsValue = Int(formCredits) else {
            errorMessage = "Invalid data"
            showError = true
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let instructorValue = formInstructor.isEmpty ? nil : formInstructor
            
            let updated = Subject(
                id: subject.id,
                name: formName,
                code: formCode,
                credits: Double(creditsValue),
                instructor: instructorValue,
                color: formColor,
                currentGrade: subject.currentGrade,
                targetGrade: subject.targetGrade,
                createdAt: subject.createdAt,
                updatedAt: Date()
            )
            
            _ = try await repository.updateSubject(updated)
            await loadSubjects()
            resetForm()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func deleteSubject(_ subject: Subject) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await repository.deleteSubject(subject.id)
            await loadSubjects()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func prepareForEdit(_ subject: Subject) {
        editingSubject = subject
        formName = subject.name
        formCode = subject.code
        formCredits = String(Int(subject.credits))
        formInstructor = subject.instructor ?? ""
        formColor = subject.color
    }
    
    func resetForm() {
        formName = ""
        formCode = ""
        formCredits = ""
        formInstructor = ""
        formColor = "#007AFF"
        editingSubject = nil
    }
    
    var isFormValid: Bool {
        !formName.isEmpty && !formCode.isEmpty && Int(formCredits) != nil
    }
}
