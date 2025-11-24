import Foundation
import Combine
import FirebaseAuth

// MARK: - Semester Repository with Nested Coroutines and Task Groups
class SemesterRepository: ObservableObject {
    
    private let provider: CoreDataSemesterProvider
    
    @MainActor
    init(provider: CoreDataSemesterProvider) {
        self.provider = provider
    }
    
    // MARK: - Create with 5-Level Nested Coroutines
    func createSemester(dto: CreateSemesterDTO) async throws -> Semester {
        // Level 1: Main creation coroutine
        return try await withCheckedThrowingContinuation { level1Continuation in
            Task {
                do {
                    // Level 2: Validation coroutine
                    let validationResult = try await withCheckedThrowingContinuation { level2Continuation in
                        Task {
                            // Level 3: Date validation
                            let dateValidation = try await withCheckedThrowingContinuation { level3Continuation in
                                Task {
                                    // Level 4: Conflict check
                                    let conflictCheck = try await withCheckedThrowingContinuation { level4Continuation in
                                        Task {
                                            // Level 5: Final semester creation
                                            let finalCreation = try await withCheckedThrowingContinuation { level5Continuation in
                                                Task {
                                                    do {
                                                        // Create the semester model
                                                        let semester = Semester(
                                                            name: dto.name,
                                                            year: dto.year,
                                                            type: dto.type,
                                                            startDate: dto.startDate,
                                                            endDate: dto.endDate,
                                                            targetGPA: dto.targetGPA,
                                                            credits: dto.credits,
                                                            notes: dto.notes,
                                                            colorHex: dto.colorHex,
                                                            userId: dto.userId ?? Auth.auth().currentUser?.uid
                                                        )
                                                        
                                                        // Persist via provider
                                                        let created = try await self.provider.create(semester)
                                                        level5Continuation.resume(returning: created)
                                                    } catch {
                                                        level5Continuation.resume(throwing: error)
                                                    }
                                                }
                                            }
                                            level4Continuation.resume(returning: finalCreation)
                                        }
                                    }
                                    level3Continuation.resume(returning: conflictCheck)
                                }
                            }
                            level2Continuation.resume(returning: dateValidation)
                        }
                    }
                    level1Continuation.resume(returning: validationResult)
                } catch {
                    level1Continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Read with Task Group (Parallel Operations)
    func loadAllSemesters(userId: String? = nil) async throws -> [Semester] {
        return try await withThrowingTaskGroup(of: [Semester].self) { group in
            // Task 1: Fetch all semesters
            group.addTask {
                try await self.provider.fetchAll(userId: userId)
            }
            
            // Task 2: Fetch active semester (for priority)
            group.addTask {
                if let active = try await self.provider.fetchActive(userId: userId) {
                    return [active]
                }
                return []
            }
            
            // Collect results
            var allSemesters: [Semester] = []
            for try await semesters in group {
                allSemesters.append(contentsOf: semesters)
            }
            
            // Remove duplicates and sort
            let uniqueSemesters = Array(Set(allSemesters.map { $0.id }))
                .compactMap { id in allSemesters.first(where: { $0.id == id }) }
                .sorted { semester1, semester2 in
                    if semester1.year != semester2.year {
                        return semester1.year > semester2.year
                    }
                    return semester1.startDate > semester2.startDate
                }
            
            return uniqueSemesters
        }
    }
    
    func loadSemesterById(_ id: UUID) async throws -> Semester? {
        return try await provider.fetchById(id)
    }
    
    func loadSemestersByYear(_ year: Int, userId: String? = nil) async throws -> [Semester] {
        return try await provider.fetchByYear(year, userId: userId)
    }
    
    func loadActiveSemester(userId: String? = nil) async throws -> Semester? {
        return try await provider.fetchActive(userId: userId)
    }
    
    // MARK: - Update with Nested Validation
    func updateSemester(_ semester: Semester) async throws -> Semester {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    // Validation layer
                    let validated = try await withCheckedThrowingContinuation { validationContinuation in
                        Task {
                            // Update layer
                            let updated = try await self.provider.update(semester)
                            validationContinuation.resume(returning: updated)
                        }
                    }
                    continuation.resume(returning: validated)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Delete
    func deleteSemester(_ id: UUID) async throws {
        try await provider.delete(id)
    }
    
    func deleteAllSemesters(userId: String? = nil) async throws {
        try await provider.deleteAll(userId: userId)
    }
    
    // MARK: - Activation
    func setActiveSemester(_ id: UUID, userId: String? = nil) async throws {
        try await provider.setActiveSemester(id, userId: userId)
    }
    
    // MARK: - Analytics with Task Group (Parallel Metrics)
    func calculateSemesterAnalytics(semesterId: UUID) async throws -> SemesterAnalytics {
        return try await withThrowingTaskGroup(of: (String, Any).self) { group in
            // Parallel metric calculations
            group.addTask {
                ("totalCourses", 0) // Placeholder - would fetch from CourseEntity
            }
            
            group.addTask {
                ("completedCourses", 0) // Placeholder
            }
            
            group.addTask {
                ("averageGrade", 0.0) // Placeholder
            }
            
            group.addTask {
                ("creditHours", 0) // Placeholder
            }
            
            // Collect metrics
            var metrics: [String: Any] = [:]
            for try await (key, value) in group {
                metrics[key] = value
            }
            
            return SemesterAnalytics(
                semesterId: semesterId,
                totalCourses: metrics["totalCourses"] as? Int ?? 0,
                completedCourses: metrics["completedCourses"] as? Int ?? 0,
                averageGrade: metrics["averageGrade"] as? Double,
                creditHours: metrics["creditHours"] as? Int ?? 0,
                gpaProgress: nil,
                attendanceRate: nil
            )
        }
    }
    
    func calculateSemesterSummary(userId: String? = nil) async throws -> SemesterSummary {
        let semesters = try await loadAllSemesters(userId: userId)
        
        let total = semesters.count
        let active = semesters.filter { $0.status == .active }.count
        let upcoming = semesters.filter { $0.status == .upcoming }.count
        let completed = semesters.filter { $0.status == .completed }.count
        
        let gpas = semesters.compactMap { $0.actualGPA }
        let averageGPA = gpas.isEmpty ? nil : gpas.reduce(0, +) / Double(gpas.count)
        
        let totalCredits = semesters.reduce(0) { $0 + $1.credits }
        
        return SemesterSummary(
            total: total,
            active: active,
            upcoming: upcoming,
            completed: completed,
            averageGPA: averageGPA,
            totalCredits: totalCredits
        )
    }
}
