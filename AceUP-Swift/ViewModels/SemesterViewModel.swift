import SwiftUI
import Combine
import FirebaseAuth

// MARK: - Semester ViewModel
// DISPATCHER: Main Thread (UI)
@MainActor
class SemesterViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var semesters: [Semester] = []
    @Published var activeSemester: Semester?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Form fields
    @Published var formName = ""
    @Published var formYear = Calendar.current.component(.year, from: Date())
    @Published var formType: SemesterType = .fall
    @Published var formStartDate = Date()
    @Published var formEndDate = Date()
    @Published var formTargetGPA = ""
    @Published var formCredits = ""
    @Published var formNotes = ""
    @Published var formColorHex = "#4ECDC4"
    @Published var editingSemester: Semester?
    
    private let repository: SemesterRepository
    private var cancellables = Set<AnyCancellable>()
    
    @MainActor
    init(repository: SemesterRepository? = nil) {
        if let repository = repository {
            self.repository = repository
        } else {
            self.repository = SemesterRepository()
        }
        setupDefaultDates()
    }
    
    // MARK: - Setup
    private func setupDefaultDates() {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        
        // Set default dates based on semester type
        updateDatesForType(formType, year: year)
    }
    
    func updateDatesForType(_ type: SemesterType, year: Int) {
        let calendar = Calendar.current
        
        var startComponents = DateComponents()
        startComponents.year = year
        startComponents.month = type.defaultStartMonth
        startComponents.day = 1
        
        var endComponents = DateComponents()
        endComponents.year = type == .winter ? year + 1 : year
        endComponents.month = type.defaultEndMonth
        endComponents.day = calendar.range(of: .day, in: .month, for: calendar.date(from: endComponents) ?? Date())?.upperBound ?? 30
        
        formStartDate = calendar.date(from: startComponents) ?? Date()
        formEndDate = calendar.date(from: endComponents) ?? Date()
    }
    
    // MARK: - CRUD Operations
    // Esta función se ejecuta en MAIN THREAD
    func loadSemesters() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let userId = Auth.auth().currentUser?.uid
            semesters = try await repository.loadAllSemesters(userId: userId)
            activeSemester = semesters.first { $0.isActive }
        } catch {
            errorMessage = "Failed to load semesters: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false 
    }
    
    func createSemester() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let userId = Auth.auth().currentUser?.uid
            
            let newSemester = Semester(
                id: UUID(),
                name: formName,
                year: formYear,
                type: formType,
                startDate: formStartDate,
                endDate: formEndDate,
                targetGPA: Double(formTargetGPA),
                actualGPA: nil,
                credits: Int(formCredits) ?? 0,
                status: .upcoming,
                notes: formNotes,
                colorHex: formColorHex,
                isActive: false,
                userId: userId,
                createdAt: Date()
            )
            
            _ = try await repository.createSemester(newSemester)
            await loadSemesters()
            resetForm()
        } catch {
            errorMessage = "Failed to create semester: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    func updateSemester(_ semester: Semester) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedSemester = Semester(
                id: semester.id,
                name: formName,
                year: formYear,
                type: formType,
                startDate: formStartDate,
                endDate: formEndDate,
                targetGPA: Double(formTargetGPA),
                actualGPA: semester.actualGPA,
                credits: Int(formCredits) ?? 0,
                status: semester.status,
                notes: formNotes,
                colorHex: formColorHex,
                isActive: semester.isActive,
                userId: semester.userId,
                createdAt: semester.createdAt
            )
            
            _ = try await repository.updateSemester(updatedSemester)
            await loadSemesters()
            resetForm()
        } catch {
            errorMessage = "Failed to update semester: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    func deleteSemester(_ semester: Semester) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await repository.deleteSemester(semester.id)
            await loadSemesters()
        } catch {
            errorMessage = "Failed to delete semester: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    func setActiveSemester(_ semester: Semester) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await repository.setActiveSemester(semester.id)
            await loadSemesters()
        } catch {
            errorMessage = "Failed to set active semester: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    func prepareForEdit(_ semester: Semester) {
        editingSemester = semester
        formName = semester.name
        formYear = semester.year
        formType = semester.type
        formStartDate = semester.startDate
        formEndDate = semester.endDate
        formTargetGPA = semester.targetGPA.map { String($0) } ?? ""
        formCredits = String(semester.credits)
        formNotes = semester.notes
        formColorHex = semester.colorHex
    }
    
    // MARK: - Form Management
    func resetForm() {
        editingSemester = nil
        formName = ""
        formYear = Calendar.current.component(.year, from: Date())
        formType = .fall
        formTargetGPA = ""
        formCredits = ""
        formNotes = ""
        formColorHex = "#4ECDC4"
        setupDefaultDates()
    }
}

