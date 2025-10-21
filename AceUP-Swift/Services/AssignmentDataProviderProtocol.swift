import Foundation

/// Fuente de la verdad para persistencia de Assignments.
protocol AssignmentDataProviderProtocol: AnyObject {
    func fetchAll() async throws -> [Assignment]
    func fetchById(_ id: String) async throws -> Assignment?
    func save(_ assignment: Assignment) async throws
    func update(_ assignment: Assignment) async throws
    func delete(_ id: String) async throws
}
