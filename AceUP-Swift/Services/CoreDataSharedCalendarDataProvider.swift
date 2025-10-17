//
//  CoreDataSharedCalendarDataProvider.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 13/10/25.
//

import Foundation
import CoreData

@MainActor
final class CoreDataSharedCalendarDataProvider: ObservableObject {

    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext

    init(persistenceController: PersistenceController? = nil) {
        let c = persistenceController ?? PersistenceController.shared
        self.persistenceController = c
        self.context = c.viewContext
    }

    func fetchSharedCalendars() async throws -> [CalendarGroup] {
        let req: NSFetchRequest<SharedCalendarEntity> = SharedCalendarEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(keyPath: \SharedCalendarEntity.createdAt, ascending: false)]
        return try context.fetch(req).map { $0.toCalendarGroup() }
    }

    func saveSharedCalendar(_ group: CalendarGroup) async throws {
        if let e = try await fetchEntity(by: group.id) {
            e.updateFromCalendarGroup(group)
            if let members = e.members?.allObjects as? [GroupMemberEntity] {
                for m in members { context.delete(m) }
            }
            for m in group.members {
                let me = GroupMemberEntity.fromGroupMember(m, in: context)
                me.sharedCalendar = e
            }
        } else {
            let newE = SharedCalendarEntity.fromCalendarGroup(group, in: context)
            for m in group.members {
                let me = GroupMemberEntity.fromGroupMember(m, in: context)
                me.sharedCalendar = newE
            }
        }
        do { try context.save() } catch { context.rollback(); throw error }
    }

    func deleteSharedCalendar(_ id: String) async throws {
        guard let e = try await fetchEntity(by: id) else {
            throw PersistenceError.objectNotFound
        }
        context.delete(e)
        do { try context.save() } catch { context.rollback(); throw error }
    }

    private func fetchEntity(by id: String) async throws -> SharedCalendarEntity? {
        let req: NSFetchRequest<SharedCalendarEntity> = SharedCalendarEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id)
        req.fetchLimit = 1
        return try context.fetch(req).first
    }
}
