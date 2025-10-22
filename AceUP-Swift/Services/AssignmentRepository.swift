import Foundation
import Combine

@MainActor
final class AssignmentRepository: ObservableObject, AssignmentRepositoryProtocol {

    @Published private(set) var assignments: [Assignment] = []
    private let dataProvider: AssignmentDataProviderProtocol

    init(dataProvider: AssignmentDataProviderProtocol) { self.dataProvider = dataProvider }
    convenience init() { self.init(dataProvider: HybridAssignmentDataProvider()) }

    // CRUD
    func getAllAssignments() async throws -> [Assignment] {
        let all = try await dataProvider.fetchAll()
        assignments = all
        return all
    }

    func fetchById(_ id: String) async throws -> Assignment? {
        if let cached = assignments.first(where: { $0.id == id }) { return cached }
        return try await dataProvider.fetchById(id)
    }

    func saveAssignment(_ assignment: Assignment) async throws {
        try await dataProvider.save(assignment)
        if !assignments.contains(where: { $0.id == assignment.id }) {
            assignments.append(assignment)
        }
        sortAssignments()
    }

    func updateAssignment(_ assignment: Assignment) async throws {
        let updated = assignment.copying(updatedAt: Date())
        try await dataProvider.update(updated)
        if let idx = assignments.firstIndex(where: { $0.id == assignment.id }) {
            assignments[idx] = updated
        } else {
            assignments.append(updated)
        }
        sortAssignments()
    }

    func deleteAssignment(_ id: String) async throws {
        try await dataProvider.delete(id)
        assignments.removeAll { $0.id == id }
    }

    // Subtareas (sin exigir métodos al provider)
    func addSubtask(to assignmentId: String, subtask: Subtask) async throws {
        guard let current = try await dataProvider.fetchById(assignmentId) else {
            throw PersistenceError.objectNotFound
        }
        let updated = current.copying(subtasks: current.subtasks + [subtask], updatedAt: Date())
        try await dataProvider.update(updated)
        if let idx = assignments.firstIndex(where: { $0.id == assignmentId }) { assignments[idx] = updated }
    }

    func updateSubtask(_ subtask: Subtask, in assignmentId: String) async throws {
        guard let current = try await dataProvider.fetchById(assignmentId) else {
            throw PersistenceError.objectNotFound
        }
        let newSubtasks = current.subtasks.map { $0.id == subtask.id ? subtask : $0 }
        let updated = current.copying(subtasks: newSubtasks, updatedAt: Date())
        try await dataProvider.update(updated)
        if let idx = assignments.firstIndex(where: { $0.id == assignmentId }) { assignments[idx] = updated }
    }

    // Grades / Completed
    func updateGrade(_ assignmentId: String, grade: Double?) async throws {
        guard let current = try await dataProvider.fetchById(assignmentId) else {
            throw PersistenceError.objectNotFound
        }
        let updated = current.copying(
            updatedAt: Date(),
            grade: Optional<Double?>.some(grade) // Double?? = .some(Double?)
        )
        try await dataProvider.update(updated)
        if let idx = assignments.firstIndex(where: { $0.id == assignmentId }) { assignments[idx] = updated }

        AnalyticsHooks.onGradeUpdated(assignmentId: assignmentId, courseId: updated.courseId, grade: grade)
        AppAnalytics.shared.track("grade_recorded", props: [
            "assignment_id": assignmentId,
            "course_id": updated.courseId,
            "grade": grade as Any
        ])
    }

    func markCompleted(_ assignmentId: String, finalGrade: Double?) async throws {
        guard let current = try await dataProvider.fetchById(assignmentId) else {
            throw PersistenceError.objectNotFound
        }
        let updated = current.copying(
            status: .completed,
            updatedAt: Date(),
            grade: Optional<Double?>.some(finalGrade)
        )
        try await dataProvider.update(updated)
        if let idx = assignments.firstIndex(where: { $0.id == assignmentId }) { assignments[idx] = updated }

        AnalyticsHooks.onAssignmentCompleted(assignmentId: assignmentId, courseId: updated.courseId, grade: finalGrade)
        AppAnalytics.shared.track("assignment_completed", props: [
            "assignment_id": assignmentId,
            "course_id": updated.courseId,
            "grade": finalGrade as Any
        ])
    }
    
    func fetchDueTodayNotDone(now: Date) async throws -> [Assignment] {
        // Asegura cache
        let all = try await getAllAssignments()

        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        // fin exclusivo = inicio del día siguiente
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }

        // Estados válidos (no completed/cancelled)
        let validStatuses: Set<AssignmentStatus> = [.pending, .inProgress, .overdue]

        return all
            .filter { a in
                validStatuses.contains(a.status) &&
                a.dueDate >= start && a.dueDate < end
            }
            .sorted { $0.dueDate < $1.dueDate }
    }
    func markCompleted(_ assignmentId: String) async throws {
        try await markCompleted(assignmentId, finalGrade: nil)
    }

    // Helpers
    private func sortAssignments() {
        assignments.sort { lhs, rhs in
            if lhs.status != rhs.status { return statusSortPriority(lhs.status) < statusSortPriority(rhs.status) }
            return lhs.dueDate < rhs.dueDate
        }
    }
    private func statusSortPriority(_ s: AssignmentStatus) -> Int {
        switch s {
        case .overdue: return 0
        case .pending: return 1
        case .inProgress: return 2
        case .completed: return 3
        case .cancelled: return 4
        }
    }
}
