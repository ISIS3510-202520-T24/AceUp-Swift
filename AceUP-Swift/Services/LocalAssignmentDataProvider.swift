import Foundation

final class LocalAssignmentDataProvider: AssignmentDataProviderProtocol {
    private var storage: [String: Assignment] = [:]

    func fetchAll() async throws -> [Assignment] {
        Array(storage.values)
    }

    func fetchById(_ id: String) async throws -> Assignment? {
        storage[id]
    }

    func save(_ assignment: Assignment) async throws {
        storage[assignment.id] = assignment
    }

    func update(_ assignment: Assignment) async throws {
        storage[assignment.id] = assignment
    }

    func delete(_ id: String) async throws {
        storage.removeValue(forKey: id)
    }
}