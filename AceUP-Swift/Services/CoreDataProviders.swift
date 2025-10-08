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

/// Core Data implementation of AssignmentDataProviderProtocol
/// Handles local storage and offline access for assignments
@MainActor
class CoreDataAssignmentDataProvider: AssignmentDataProviderProtocol {
    
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    
    private var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? "anonymous"
    }
    
    // MARK: - Initialization
    
    init(persistenceController: PersistenceController? = nil) {
        let controller = persistenceController ?? PersistenceController.shared
        self.persistenceController = controller
        self.context = controller.viewContext
    }
    
    // MARK: - AssignmentDataProviderProtocol Implementation
    
    func fetchAll() async throws -> [Assignment] {
        let request: NSFetchRequest<AssignmentEntity> = AssignmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", currentUserId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AssignmentEntity.dueDate, ascending: true)]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { $0.toAssignment() }
        } catch {
            throw PersistenceError.failedToFetch(error)
        }
    }
    
    func fetchById(_ id: String) async throws -> Assignment? {
        let request: NSFetchRequest<AssignmentEntity> = AssignmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND userId == %@", id, currentUserId)
        request.fetchLimit = 1
        
        do {
            let entities = try context.fetch(request)
            return entities.first?.toAssignment()
        } catch {
            throw PersistenceError.failedToFetch(error)
        }
    }
    
    func save(_ assignment: Assignment) async throws {
        // Check if assignment already exists
        if let existingEntity = try await fetchAssignmentEntity(by: assignment.id) {
            existingEntity.updateFromAssignment(assignment)
        } else {
            let newEntity = AssignmentEntity.fromAssignment(assignment, in: context)
            
            // Handle subtasks
            for subtask in assignment.subtasks {
                let subtaskEntity = SubtaskEntity.fromSubtask(subtask, in: context)
                subtaskEntity.assignment = newEntity
            }
            
            // Handle attachments
            for attachment in assignment.attachments {
                let attachmentEntity = AttachmentEntity.fromAttachment(attachment, in: context)
                attachmentEntity.assignment = newEntity
            }
        }
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw PersistenceError.failedToSave(error)
        }
    }
    
    func update(_ assignment: Assignment) async throws {
        guard let entity = try await fetchAssignmentEntity(by: assignment.id) else {
            throw PersistenceError.objectNotFound
        }
        
        entity.updateFromAssignment(assignment)
        
        // Update subtasks
        if let existingSubtasks = entity.subtasks?.allObjects as? [SubtaskEntity] {
            for existingSubtask in existingSubtasks {
                context.delete(existingSubtask)
            }
        }
        
        for subtask in assignment.subtasks {
            let subtaskEntity = SubtaskEntity.fromSubtask(subtask, in: context)
            subtaskEntity.assignment = entity
        }
        
        // Update attachments
        if let existingAttachments = entity.attachments?.allObjects as? [AttachmentEntity] {
            for existingAttachment in existingAttachments {
                context.delete(existingAttachment)
            }
        }
        
        for attachment in assignment.attachments {
            let attachmentEntity = AttachmentEntity.fromAttachment(attachment, in: context)
            attachmentEntity.assignment = entity
        }
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw PersistenceError.failedToSave(error)
        }
    }
    
    func delete(_ id: String) async throws {
        guard let entity = try await fetchAssignmentEntity(by: id) else {
            throw PersistenceError.objectNotFound
        }
        
        context.delete(entity)
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw PersistenceError.failedToDelete(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchAssignmentEntity(by id: String) async throws -> AssignmentEntity? {
        let request: NSFetchRequest<AssignmentEntity> = AssignmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND userId == %@", id, currentUserId)
        request.fetchLimit = 1
        
        do {
            let entities = try context.fetch(request)
            return entities.first
        } catch {
            throw PersistenceError.failedToFetch(error)
        }
    }
    
    // MARK: - Batch Operations
    
    func deleteAllAssignments() async throws {
        let request: NSFetchRequest<NSFetchRequestResult> = AssignmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", currentUserId)
        
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        do {
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            let objectIDArray = result?.result as? [NSManagedObjectID]
            let changes = [NSDeletedObjectsKey: objectIDArray ?? []]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
        } catch {
            throw PersistenceError.failedToDelete(error)
        }
    }
    
    func getAssignmentsByStatus(_ status: AssignmentStatus) async throws -> [Assignment] {
        let request: NSFetchRequest<AssignmentEntity> = AssignmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND status == %@", currentUserId, status.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AssignmentEntity.dueDate, ascending: true)]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { $0.toAssignment() }
        } catch {
            throw PersistenceError.failedToFetch(error)
        }
    }
    
    func getAssignmentsByDateRange(start: Date, end: Date) async throws -> [Assignment] {
        let request: NSFetchRequest<AssignmentEntity> = AssignmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND dueDate >= %@ AND dueDate <= %@", 
                                       currentUserId, start as NSDate, end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AssignmentEntity.dueDate, ascending: true)]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { $0.toAssignment() }
        } catch {
            throw PersistenceError.failedToFetch(error)
        }
    }
}

// MARK: - Core Data Holiday Data Provider

@MainActor
class CoreDataHolidayDataProvider: ObservableObject {
    
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    
    init(persistenceController: PersistenceController? = nil) {
        let controller = persistenceController ?? PersistenceController.shared
        self.persistenceController = controller
        self.context = controller.viewContext
    }
    
    func fetchHolidays(for country: String, year: Int) async throws -> [Holiday] {
        let request: NSFetchRequest<HolidayEntity> = HolidayEntity.fetchRequest()
        
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        
        request.predicate = NSPredicate(format: "country == %@ AND date >= %@ AND date < %@", 
                                       country, startOfYear as NSDate, endOfYear as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \HolidayEntity.date, ascending: true)]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { $0.toHoliday() }
        } catch {
            throw PersistenceError.failedToFetch(error)
        }
    }
    
    func fetchAllHolidays() async throws -> [Holiday] {
        let request: NSFetchRequest<HolidayEntity> = HolidayEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \HolidayEntity.date, ascending: true)]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { $0.toHoliday() }
        } catch {
            throw PersistenceError.failedToFetch(error)
        }
    }
    
    func saveHoliday(_ holiday: Holiday) async throws {
        // Check if holiday already exists
        if let existingEntity = try await fetchHolidayEntity(by: holiday.id) {
            existingEntity.updateFromHoliday(holiday)
        } else {
            _ = HolidayEntity.fromHoliday(holiday, in: context)
        }
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw PersistenceError.failedToSave(error)
        }
    }
    
    func saveHolidays(_ holidays: [Holiday]) async throws {
        for holiday in holidays {
            if let existingEntity = try await fetchHolidayEntity(by: holiday.id) {
                existingEntity.updateFromHoliday(holiday)
            } else {
                _ = HolidayEntity.fromHoliday(holiday, in: context)
            }
        }
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw PersistenceError.failedToSave(error)
        }
    }
    
    private func fetchHolidayEntity(by id: String) async throws -> HolidayEntity? {
        let request: NSFetchRequest<HolidayEntity> = HolidayEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        do {
            let entities = try context.fetch(request)
            return entities.first
        } catch {
            throw PersistenceError.failedToFetch(error)
        }
    }
}

// MARK: - Core Data Course Data Provider

@MainActor
class CoreDataCourseDataProvider: ObservableObject {
    
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    
    private var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? "anonymous"
    }
    
    init(persistenceController: PersistenceController? = nil) {
        let controller = persistenceController ?? PersistenceController.shared
        self.persistenceController = controller
        self.context = controller.viewContext
    }
    
    func fetchCourses() async throws -> [Course] {
        let request: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", currentUserId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CourseEntity.name, ascending: true)]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { $0.toCourse() }
        } catch {
            throw PersistenceError.failedToFetch(error)
        }
    }
    
    func saveCourse(_ course: Course) async throws {
        // Check if course already exists
        if let existingEntity = try await fetchCourseEntity(by: course.id) {
            existingEntity.updateFromCourse(course)
            existingEntity.gradeWeights?.updateFromGradeWeight(course.gradeWeight)
        } else {
            _ = CourseEntity.fromCourse(course, in: context)
        }
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw PersistenceError.failedToSave(error)
        }
    }
    
    func updateCourse(_ course: Course) async throws {
        guard let entity = try await fetchCourseEntity(by: course.id) else {
            throw PersistenceError.objectNotFound
        }
        
        entity.updateFromCourse(course)
        entity.gradeWeights?.updateFromGradeWeight(course.gradeWeight)
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw PersistenceError.failedToSave(error)
        }
    }
    
    func deleteCourse(_ courseId: String) async throws {
        guard let entity = try await fetchCourseEntity(by: courseId) else {
            throw PersistenceError.objectNotFound
        }
        
        context.delete(entity)
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw PersistenceError.failedToDelete(error)
        }
    }
    
    private func fetchCourseEntity(by id: String) async throws -> CourseEntity? {
        let request: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND userId == %@", id, currentUserId)
        request.fetchLimit = 1
        
        do {
            let entities = try context.fetch(request)
            return entities.first
        } catch {
            throw PersistenceError.failedToFetch(error)
        }
    }
}

// MARK: - Core Data Shared Calendar Data Provider

@MainActor
class CoreDataSharedCalendarDataProvider: ObservableObject {
    
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    
    init(persistenceController: PersistenceController? = nil) {
        let controller = persistenceController ?? PersistenceController.shared
        self.persistenceController = controller
        self.context = controller.viewContext
    }
    
    func fetchSharedCalendars() async throws -> [CalendarGroup] {
        let request: NSFetchRequest<SharedCalendarEntity> = SharedCalendarEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SharedCalendarEntity.createdAt, ascending: false)]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { $0.toCalendarGroup() }
        } catch {
            throw PersistenceError.failedToFetch(error)
        }
    }
    
    func saveSharedCalendar(_ group: CalendarGroup) async throws {
        // Check if group already exists
        if let existingEntity = try await fetchSharedCalendarEntity(by: group.id) {
            existingEntity.updateFromCalendarGroup(group)
            
            // Update members
            if let existingMembers = existingEntity.members?.allObjects as? [GroupMemberEntity] {
                for existingMember in existingMembers {
                    context.delete(existingMember)
                }
            }
            
            for member in group.members {
                let memberEntity = GroupMemberEntity.fromGroupMember(member, in: context)
                memberEntity.sharedCalendar = existingEntity
            }
        } else {
            let newEntity = SharedCalendarEntity.fromCalendarGroup(group, in: context)
            
            for member in group.members {
                let memberEntity = GroupMemberEntity.fromGroupMember(member, in: context)
                memberEntity.sharedCalendar = newEntity
            }
        }
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw PersistenceError.failedToSave(error)
        }
    }
    
    func deleteSharedCalendar(_ groupId: String) async throws {
        guard let entity = try await fetchSharedCalendarEntity(by: groupId) else {
            throw PersistenceError.objectNotFound
        }
        
        context.delete(entity)
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw PersistenceError.failedToDelete(error)
        }
    }
    
    private func fetchSharedCalendarEntity(by id: String) async throws -> SharedCalendarEntity? {
        let request: NSFetchRequest<SharedCalendarEntity> = SharedCalendarEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        do {
            let entities = try context.fetch(request)
            return entities.first
        } catch {
            throw PersistenceError.failedToFetch(error)
        }
    }
}