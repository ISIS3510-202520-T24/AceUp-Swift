//
//
//  CoreDataProviders.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 7/10/25.
//
//

import Foundation
import CoreData
import FirebaseAuth

@MainActor
class CoreDataAssignmentDataProvider: AssignmentDataProviderProtocol {

    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext

    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? "anonymous"
    }

    init(persistenceController: PersistenceController? = nil) {
        let controller = persistenceController ?? PersistenceController.shared
        self.persistenceController = controller
        self.context = controller.viewContext
    }

    // MARK: - AssignmentDataProviderProtocol

    func fetchAll() async throws -> [Assignment] {
        let request: NSFetchRequest<AssignmentEntity> = AssignmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", currentUserId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AssignmentEntity.dueDate, ascending: true)]
        return try context.fetch(request).map { $0.toAssignment() }
    }

    func fetchById(_ id: String) async throws -> Assignment? {
        let request: NSFetchRequest<AssignmentEntity> = AssignmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND userId == %@", id, currentUserId)
        request.fetchLimit = 1
        return try context.fetch(request).first?.toAssignment()
    }

    func save(_ assignment: Assignment) async throws {
        if let _ = try await fetchAssignmentEntity(by: assignment.id) {
            try await update(assignment)
            return
        }
        let newEntity = AssignmentEntity.fromAssignment(assignment, in: context)

        for s in assignment.subtasks {
            let e = SubtaskEntity.fromSubtask(s, in: context)
            e.assignment = newEntity
        }
        for a in assignment.attachments {
            let e = AttachmentEntity.fromAttachment(a, in: context)
            e.assignment = newEntity
        }

        do { try context.save() }
        catch { context.rollback(); throw PersistenceError.failedToSave(error) }
    }

    func update(_ assignment: Assignment) async throws {
        guard let entity = try await fetchAssignmentEntity(by: assignment.id) else {
            throw PersistenceError.objectNotFound
        }
        entity.updateFromAssignment(assignment)
        // reemplaza subtareas/adjuntos si tu mapeo lo necesita
        if let subs = entity.subtasks?.allObjects as? [SubtaskEntity] {
            for s in subs { context.delete(s) }
        }
        for s in assignment.subtasks {
            let e = SubtaskEntity.fromSubtask(s, in: context)
            e.assignment = entity
        }
        if let atts = entity.attachments?.allObjects as? [AttachmentEntity] {
            for a in atts { context.delete(a) }
        }
        for a in assignment.attachments {
            let e = AttachmentEntity.fromAttachment(a, in: context)
            e.assignment = entity
        }

        do { try context.save() }
        catch { context.rollback(); throw PersistenceError.failedToSave(error) }
    }

    func delete(_ id: String) async throws {
        guard let entity = try await fetchAssignmentEntity(by: id) else {
            throw PersistenceError.objectNotFound
        }
        context.delete(entity)
        do { try context.save() }
        catch { context.rollback(); throw PersistenceError.failedToDelete(error) }
    }

    // MARK: - Helpers

    private func fetchAssignmentEntity(by id: String) async throws -> AssignmentEntity? {
        let request: NSFetchRequest<AssignmentEntity> = AssignmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND userId == %@", id, currentUserId)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
