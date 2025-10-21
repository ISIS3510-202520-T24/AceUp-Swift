import Foundation

/// Fuente de la verdad para persistencia de Assignments.
protocol AssignmentDataProviderProtocol: AnyObject {
    func fetchAll() async throws -> [Assignment]
    func fetchById(_ id: String) async throws -> Assignment?
    func save(_ assignment: Assignment) async throws
    func update(_ assignment: Assignment) async throws
    func delete(_ id: String) async throws
    func updateStatus(_ id: String, status: AssignmentStatus, finalGrade: Double?) async throws
}

// default para quienes no lo implementen (CoreData/Hybrid)
extension AssignmentDataProviderProtocol {
    func updateStatus(_ id: String, status: AssignmentStatus, finalGrade: Double?) async throws {
        guard let current = try await fetchById(id) else { throw PersistenceError.objectNotFound }
        let updated = Assignment(
            id: current.id,
            title: current.title,
            description: current.description,
            courseId: current.courseId,
            courseName: current.courseName,
            courseColor: current.courseColor,
            dueDate: current.dueDate,
            weight: current.weight,
            estimatedHours: current.estimatedHours,
            actualHours: current.actualHours,
            priority: current.priority,
            status: status,
            tags: current.tags,
            attachments: current.attachments,
            subtasks: current.subtasks,
            createdAt: current.createdAt,
            updatedAt: Date(),
            grade: finalGrade ?? current.grade
        )
        try await update(updated)
    }
}
