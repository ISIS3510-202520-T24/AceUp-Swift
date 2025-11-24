import SwiftUI
import Combine
import FirebaseAuth

// MARK: - Semester ViewModel
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
            let persistentContainer = PersistenceController.shared.persistentContainer
            let provider = CoreDataSemesterProvider(persistentContainer: persistentContainer)
            self.repository = SemesterRepository(provider: provider)
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
    func loadSemesters() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let userId = Auth.auth().currentUser?.uid
            semesters = try await repository.loadAllSemesters(userId: userId)
            activeSemester = try await repository.loadActiveSemester(userId: userId)
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
            let dto = CreateSemesterDTO(
                name: formName.isEmpty ? "\(formType.rawValue) \(formYear)" : formName,
                year: formYear,
                type: formType,
                startDate: formStartDate,
                endDate: formEndDate,
                targetGPA: Double(formTargetGPA),
                credits: Int(formCredits) ?? 0,
                notes: formNotes,
                colorHex: formColorHex,
                userId: Auth.auth().currentUser?.uid
            )
            
            _ = try await repository.createSemester(dto: dto)
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
            var updated = semester
            updated.name = formName
            updated.year = formYear
            updated.type = formType
            updated.startDate = formStartDate
            updated.endDate = formEndDate
            updated.targetGPA = Double(formTargetGPA)
            updated.credits = Int(formCredits) ?? 0
            updated.notes = formNotes
            updated.colorHex = formColorHex
            
            _ = try await repository.updateSemester(updated)
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
            let userId = Auth.auth().currentUser?.uid
            try await repository.setActiveSemester(semester.id, userId: userId)
            await loadSemesters()
        } catch {
            errorMessage = "Failed to set active semester: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Form Management
    func prepareForEdit(_ semester: Semester) {
        editingSemester = semester
        formName = semester.name
        formYear = semester.year
        formType = semester.type
        formStartDate = semester.startDate
        formEndDate = semester.endDate
        formTargetGPA = semester.targetGPA != nil ? String(format: "%.2f", semester.targetGPA!) : ""
        formCredits = String(semester.credits)
        formNotes = semester.notes
        formColorHex = semester.colorHex
    }
    
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

