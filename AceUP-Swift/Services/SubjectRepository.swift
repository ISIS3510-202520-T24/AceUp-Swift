import Foundation
import Combine

// MARK: - Subject Repository (usando UserDefaults como BD Llave/Valor)
class SubjectRepository: ObservableObject {
    
    private let storage: SubjectLocalStorage
    
    init(storage: SubjectLocalStorage? = nil) {
        self.storage = storage ?? SubjectLocalStorage.shared
    }
    
    func createSubject(name: String, code: String, credits: Double,
                      instructor: String?, color: String, semesterId: String?,
                      classDays: [DayOfWeek]?, startTime: String?, endTime: String?, location: String?) async throws -> Subject {
        let subject = Subject(
            id: UUID().uuidString,
            name: name,
            code: code,
            credits: credits,
            instructor: instructor,
            color: color,
            currentGrade: nil,
            targetGrade: nil,
            classDays: classDays,
            startTime: startTime,
            endTime: endTime,
            location: location,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        return try await storage.create(subject, semesterId: semesterId)
    }
    
    func loadSubjects(semesterId: String?) async throws -> (all: [Subject], statistics: SubjectStatistics) {
        return try await withThrowingTaskGroup(of: TaskResult.self) { group in
            group.addTask {
                let subjects = try await self.storage.fetchAll(semesterId: semesterId)
                return .subjects(subjects)
            }
            
            group.addTask {
                let subjects = try await self.storage.fetchAll(semesterId: semesterId)
                let stats = self.calculateStatistics(subjects: subjects)
                return .statistics(stats)
            }
            
            var allSubjects: [Subject] = []
            var stats: SubjectStatistics?
            
            for try await result in group {
                switch result {
                case .subjects(let subjects):
                    allSubjects = subjects
                case .statistics(let s):
                    stats = s
                }
            }
            
            return (all: allSubjects, statistics: stats ?? .empty)
        }
    }
    
    func updateSubject(_ subject: Subject) async throws -> Subject {
        return try await storage.update(subject)
    }
    
    func deleteSubject(_ id: String) async throws {
        try await storage.delete(id)
    }
    
    private func calculateStatistics(subjects: [Subject]) -> SubjectStatistics {
        let totalCredits = subjects.reduce(0.0) { $0 + $1.credits }
        let gradesCount = subjects.compactMap { $0.currentGrade }.count
        let averageGrade = gradesCount > 0 ?
            subjects.compactMap { $0.currentGrade }.reduce(0.0, +) / Double(gradesCount) : 0.0
        let passingCount = subjects.filter { ($0.currentGrade ?? 0) >= 3.0 }.count
        
        return SubjectStatistics(
            totalSubjects: subjects.count,
            totalCredits: totalCredits,
            averageGrade: averageGrade,
            passingCount: passingCount
        )
    }
    
    private enum TaskResult {
        case subjects([Subject])
        case statistics(SubjectStatistics)
    }
}
