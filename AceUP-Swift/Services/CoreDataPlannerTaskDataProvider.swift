//
//  CoreDataPlannerTaskDataProvider.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/12/25.
//

import Foundation
import CoreData
import FirebaseAuth

@MainActor
class CoreDataPlannerTaskDataProvider: PlannerTaskDataProviderProtocol {
    
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
    
    // MARK: - PlannerTaskDataProviderProtocol
    
    func fetchAll() async throws -> [PlannerTask] {
        let request: NSFetchRequest<PlannerTaskEntity> = PlannerTaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", currentUserId)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PlannerTaskEntity.scheduledDate, ascending: true)
        ]
        return try context.fetch(request).map { $0.toPlannerTask() }
    }
    
    func fetchById(_ id: String) async throws -> PlannerTask? {
        let request: NSFetchRequest<PlannerTaskEntity> = PlannerTaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND userId == %@", id, currentUserId)
        request.fetchLimit = 1
        return try context.fetch(request).first?.toPlannerTask()
    }
    
    func fetchByDateRange(from startDate: Date, to endDate: Date) async throws -> [PlannerTask] {
        let request: NSFetchRequest<PlannerTaskEntity> = PlannerTaskEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "userId == %@ AND scheduledDate >= %@ AND scheduledDate <= %@",
            currentUserId, startDate as NSDate, endDate as NSDate
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PlannerTaskEntity.scheduledDate, ascending: true)
        ]
        return try context.fetch(request).map { $0.toPlannerTask() }
    }
    
    func fetchByStatus(_ status: PlannerTaskStatus) async throws -> [PlannerTask] {
        let request: NSFetchRequest<PlannerTaskEntity> = PlannerTaskEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "userId == %@ AND status == %@",
            currentUserId, status.rawValue
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PlannerTaskEntity.scheduledDate, ascending: true)
        ]
        return try context.fetch(request).map { $0.toPlannerTask() }
    }
    
    func save(_ task: PlannerTask) async throws {
        if let _ = try await fetchTaskEntity(by: task.id) {
            try await update(task)
            return
        }
        
        _ = PlannerTaskEntity.fromPlannerTask(task, in: context)
        
        do {
            try context.save()
            
            // Analytics tracking
            AnalyticsHooks.onPlannerTaskCreated(
                taskId: task.id,
                category: task.category.rawValue,
                courseId: task.courseId
            )
        } catch {
            context.rollback()
            throw PersistenceError.failedToSave(error)
        }
    }
    
    func update(_ task: PlannerTask) async throws {
        guard let entity = try await fetchTaskEntity(by: task.id) else {
            throw PersistenceError.objectNotFound
        }
        
        let oldStatus = PlannerTaskStatus(rawValue: entity.status ?? "planned") ?? .planned
        
        entity.updateFromPlannerTask(task)
        
        do {
            try context.save()
            
            // Track completion
            let becameCompleted = (oldStatus != .completed && task.status == .completed)
            if becameCompleted {
                AnalyticsHooks.onPlannerTaskCompleted(
                    taskId: task.id,
                    category: task.category.rawValue,
                    courseId: task.courseId
                )
            }
        } catch {
            context.rollback()
            throw PersistenceError.failedToSave(error)
        }
    }
    
    func delete(_ id: String) async throws {
        guard let entity = try await fetchTaskEntity(by: id) else {
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
    
    // MARK: - Helpers
    
    private func fetchTaskEntity(by id: String) async throws -> PlannerTaskEntity? {
        let request: NSFetchRequest<PlannerTaskEntity> = PlannerTaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND userId == %@", id, currentUserId)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

// MARK: - Analytics Hooks Extension

extension AnalyticsHooks {
    static func onPlannerTaskCreated(taskId: String, category: String, courseId: String?) {
        AppAnalytics.shared.track("planner_task_created", props: [
            "task_id": taskId,
            "category": category,
            "course_id": courseId as Any
        ])
    }
    
    static func onPlannerTaskCompleted(taskId: String, category: String, courseId: String?) {
        AppAnalytics.shared.track("planner_task_completed", props: [
            "task_id": taskId,
            "category": category,
            "course_id": courseId as Any
        ])
    }
}
