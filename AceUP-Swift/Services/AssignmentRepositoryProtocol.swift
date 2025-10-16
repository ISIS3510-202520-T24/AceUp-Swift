import Foundation

protocol AssignmentRepositoryProtocol {
    // Lectura
    func getAllAssignments() async throws -> [Assignment]
    func getAssignment(by id: String) async throws -> Assignment?

    // Escritura básica
    func saveAssignment(_ assignment: Assignment) async throws
    func updateAssignment(_ assignment: Assignment) async throws
    func deleteAssignment(_ id: String) async throws

    // Acciones de conveniencia
    func markAsCompleted(_ id: String) async throws
    func addSubtask(to assignmentId: String, subtask: Subtask) async throws
    func updateSubtask(_ subtask: Subtask, in assignmentId: String) async throws

    // actualizar nota 
    func updateGrade(_ assignmentId: String, grade: Double?) async throws
}
