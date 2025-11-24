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
    @Published var formClassDays: Set<DayOfWeek> = []
    @Published var formStartTime = "09:00"
    @Published var formEndTime = "10:30"
    @Published var formLocation = ""
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
            let classDaysValue = formClassDays.isEmpty ? nil : Array(formClassDays)
            let startTimeValue = formStartTime.isEmpty ? nil : formStartTime
            let endTimeValue = formEndTime.isEmpty ? nil : formEndTime
            let locationValue = formLocation.isEmpty ? nil : formLocation
            
            _ = try await repository.createSubject(
                name: formName,
                code: formCode,
                credits: Double(creditsValue),
                instructor: instructorValue,
                color: formColor,
                semesterId: semesterId,
                classDays: classDaysValue,
                startTime: startTimeValue,
                endTime: endTimeValue,
                location: locationValue
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
            let classDaysValue = formClassDays.isEmpty ? nil : Array(formClassDays)
            let startTimeValue = formStartTime.isEmpty ? nil : formStartTime
            let endTimeValue = formEndTime.isEmpty ? nil : formEndTime
            let locationValue = formLocation.isEmpty ? nil : formLocation
            
            let updated = Subject(
                id: subject.id,
                name: formName,
                code: formCode,
                credits: Double(creditsValue),
                instructor: instructorValue,
                color: formColor,
                currentGrade: subject.currentGrade,
                targetGrade: subject.targetGrade,
                classDays: classDaysValue,
                startTime: startTimeValue,
                endTime: endTimeValue,
                location: locationValue,
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
        formClassDays = Set(subject.classDays ?? [])
        formStartTime = subject.startTime ?? "09:00"
        formEndTime = subject.endTime ?? "10:30"
        formLocation = subject.location ?? ""
    }
    
    func resetForm() {
        formName = ""
        formCode = ""
        formCredits = ""
        formInstructor = ""
        formColor = "#007AFF"
        formClassDays = []
        formStartTime = "09:00"
        formEndTime = "10:30"
        formLocation = ""
        editingSubject = nil
    }
    
    var isFormValid: Bool {
        !formName.isEmpty && !formCode.isEmpty && Int(formCredits) != nil
    }
}
