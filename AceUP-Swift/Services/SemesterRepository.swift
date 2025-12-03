import Foundation
import Combine
import FirebaseAuth
import CoreData

// MARK: - Semester Repository
@MainActor
class SemesterRepository: ObservableObject {
    
    private let persistentContainer: NSPersistentContainer
    
    init(persistentContainer: NSPersistentContainer? = nil) {
        if let container = persistentContainer {
            self.persistentContainer = container
        } else {
            self.persistentContainer = PersistenceController.shared.persistentContainer
        }
    }
    
    // MARK: - Create Semester
    func createSemester(_ semester: Semester) async throws -> Semester {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let entity = SemesterEntity.fromSemester(semester, in: context)
                    try context.save()
                    continuation.resume(returning: entity.toSemester())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Load All Semesters
    func loadAllSemesters(userId: String? = nil) async throws -> [Semester] {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<SemesterEntity> = SemesterEntity.fetchRequest()
                    
                    if let userId = userId ?? Auth.auth().currentUser?.uid {
                        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
                    }
                    
                    fetchRequest.sortDescriptors = [
                        NSSortDescriptor(key: "year", ascending: false),
                        NSSortDescriptor(key: "startDate", ascending: false)
                    ]
                    
                    let entities = try context.fetch(fetchRequest)
                    let semesters = entities.map { $0.toSemester() }
                    
                    continuation.resume(returning: semesters)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Update Semester
    func updateSemester(_ semester: Semester) async throws -> Semester {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<SemesterEntity> = SemesterEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", semester.id.uuidString)
                    
                    let entities = try context.fetch(fetchRequest)
                    guard let entity = entities.first else {
                        throw NSError(domain: "SemesterRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Semester not found"])
                    }
                    
                    entity.updateFromSemester(semester)
                    try context.save()
                    
                    continuation.resume(returning: entity.toSemester())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Delete Semester
    func deleteSemester(_ semesterId: UUID) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<SemesterEntity> = SemesterEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", semesterId.uuidString)
                    
                    let entities = try context.fetch(fetchRequest)
                    guard let entity = entities.first else {
                        throw NSError(domain: "SemesterRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Semester not found"])
                    }
                    
                    context.delete(entity)
                    try context.save()
                    
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Set Active Semester
    func setActiveSemester(_ semesterId: UUID) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let userId = Auth.auth().currentUser?.uid
                    
                    // First, deactivate all semesters for this user
                    let allFetchRequest: NSFetchRequest<SemesterEntity> = SemesterEntity.fetchRequest()
                    if let userId = userId {
                        allFetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
                    }
                    let allEntities = try context.fetch(allFetchRequest)
                    for entity in allEntities {
                        entity.isActive = false
                    }
                    
                    // Now activate the selected semester
                    let fetchRequest: NSFetchRequest<SemesterEntity> = SemesterEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", semesterId.uuidString)
                    
                    let entities = try context.fetch(fetchRequest)
                    guard let entity = entities.first else {
                        throw NSError(domain: "SemesterRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Semester not found"])
                    }
                    
                    entity.isActive = true
                    try context.save()
                    
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Load Courses for a Semester (by date range)
    func loadCoursesForSemester(startDate: Date, endDate: Date, userId: String? = nil) async throws -> [Course] {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
                    
                    var predicates = [NSPredicate]()
                    predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
                    predicates.append(NSPredicate(format: "createdAt <= %@", endDate as NSDate))
                    
                    if let userId = userId ?? Auth.auth().currentUser?.uid {
                        predicates.append(NSPredicate(format: "userId == %@", userId))
                    }
                    
                    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
                    
                    let courseEntities = try context.fetch(fetchRequest)
                    let courses = courseEntities.map { $0.toCourse() }
                    
                    continuation.resume(returning: courses)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Summary Statistics
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

// MARK: - Helper Extensions

extension SemesterType {
    var defaultColor: String {
        switch self {
        case .fall: return "#FF6B6B"
        case .spring: return "#4ECDC4"
        case .summer: return "#FFE66D"
        case .winter: return "#5352ED"
        }
    }
}
