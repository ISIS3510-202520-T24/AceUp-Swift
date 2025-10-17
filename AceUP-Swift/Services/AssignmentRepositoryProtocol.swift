import Foundation

protocol AssignmentRepositoryProtocol: AnyObject {
    // Lectura / escritura principales
    func getAllAssignments() async throws -> [Assignment]
    func fetchById(_ id: String) async throws -> Assignment?
    func saveAssignment(_ assignment: Assignment) async throws
    func updateAssignment(_ assignment: Assignment) async throws
    func deleteAssignment(_ id: String) async throws

    // Subtareas
    func addSubtask(to assignmentId: String, subtask: Subtask) async throws
    func updateSubtask(_ subtask: Subtask, in assignmentId: String) async throws

    // Grades y completado
    func updateGrade(_ assignmentId: String, grade: Double?) async throws
    func markCompleted(_ assignmentId: String, finalGrade: Double?) async throws
}