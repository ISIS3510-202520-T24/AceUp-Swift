//
//  PlannerTaskCoreDataExtensions.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/12/25.
//

import CoreData
import Foundation
import FirebaseAuth

// MARK: - PlannerTask Core Data Extensions

extension PlannerTaskEntity {
    
    /// Convert Core Data entity to PlannerTask model
    func toPlannerTask() -> PlannerTask {
        let tags = self.tags?.components(separatedBy: ",").filter { !$0.isEmpty } ?? []
        
        // Parse recurrence rule if task is recurring
        let recurrenceRule: RecurrenceRule?
        if self.isRecurring, let freqRaw = self.recurrenceFrequency {
            let frequency = RecurrenceFrequency(rawValue: freqRaw) ?? .weekly
            let daysOfWeek = self.recurrenceDaysOfWeek?
                .components(separatedBy: ",")
                .compactMap { Int($0) }
            
            recurrenceRule = RecurrenceRule(
                frequency: frequency,
                interval: Int(self.recurrenceInterval),
                daysOfWeek: daysOfWeek,
                endDate: self.recurrenceEndDate,
                occurrences: self.recurrenceOccurrences > 0 ? Int(self.recurrenceOccurrences) : nil
            )
        } else {
            recurrenceRule = nil
        }
        
        return PlannerTask(
            id: self.id ?? UUID().uuidString,
            title: self.title ?? "",
            description: self.descriptionText,
            courseId: self.courseId,
            courseName: self.courseName,
            courseColor: self.courseColor,
            scheduledDate: self.scheduledDate ?? Date(),
            scheduledTime: self.scheduledTime,
            estimatedDuration: self.estimatedDuration == 0 ? nil : self.estimatedDuration,
            actualDuration: self.actualDuration == 0 ? nil : self.actualDuration,
            priority: Priority(rawValue: self.priority ?? "medium") ?? .medium,
            status: PlannerTaskStatus(rawValue: self.status ?? "planned") ?? .planned,
            category: PlannerTaskCategory(rawValue: self.category ?? "study") ?? .study,
            tags: tags,
            isRecurring: self.isRecurring,
            recurrenceRule: recurrenceRule,
            relatedAssignmentId: self.relatedAssignmentId,
            completedAt: self.completedAt,
            createdAt: self.createdAt ?? Date(),
            updatedAt: self.updatedAt ?? Date()
        )
    }
    
    /// Update Core Data entity from PlannerTask model
    func updateFromPlannerTask(_ task: PlannerTask) {
        self.id = task.id
        self.title = task.title
        self.descriptionText = task.description
        self.courseId = task.courseId
        self.courseName = task.courseName
        self.courseColor = task.courseColor
        self.scheduledDate = task.scheduledDate
        self.scheduledTime = task.scheduledTime
        self.estimatedDuration = task.estimatedDuration ?? 0
        self.actualDuration = task.actualDuration ?? 0
        self.priority = task.priority.rawValue
        self.status = task.status.rawValue
        self.category = task.category.rawValue
        self.tags = task.tags.joined(separator: ",")
        self.isRecurring = task.isRecurring
        self.relatedAssignmentId = task.relatedAssignmentId
        self.completedAt = task.completedAt
        self.createdAt = task.createdAt
        self.updatedAt = task.updatedAt
        self.userId = Auth.auth().currentUser?.uid
        
        // Handle recurrence rule
        if let rule = task.recurrenceRule {
            self.recurrenceFrequency = rule.frequency.rawValue
            self.recurrenceInterval = Int32(rule.interval)
            self.recurrenceDaysOfWeek = rule.daysOfWeek?.map { String($0) }.joined(separator: ",")
            self.recurrenceEndDate = rule.endDate
            self.recurrenceOccurrences = Int32(rule.occurrences ?? 0)
        } else {
            self.recurrenceFrequency = nil
            self.recurrenceInterval = 0
            self.recurrenceDaysOfWeek = nil
            self.recurrenceEndDate = nil
            self.recurrenceOccurrences = 0
        }
    }
    
    /// Create PlannerTaskEntity from PlannerTask model
    static func fromPlannerTask(_ task: PlannerTask, in context: NSManagedObjectContext) -> PlannerTaskEntity {
        let entity = PlannerTaskEntity(context: context)
        entity.updateFromPlannerTask(task)
        return entity
    }
}
