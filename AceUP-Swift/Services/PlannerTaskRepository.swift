//
//  PlannerTaskRepository.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/12/25.
//

import Foundation
import Combine

@MainActor
final class PlannerTaskRepository: ObservableObject {
    
    @Published private(set) var tasks: [PlannerTask] = []
    private let dataProvider: PlannerTaskDataProviderProtocol
    
    init(dataProvider: PlannerTaskDataProviderProtocol) {
        self.dataProvider = dataProvider
    }
    
    convenience init() {
        self.init(dataProvider: CoreDataPlannerTaskDataProvider())
    }
    
    // MARK: - CRUD Operations
    
    func loadAllTasks() async throws {
        let allTasks = try await dataProvider.fetchAll()
        tasks = allTasks
    }
    
    func loadTasksForDateRange(from startDate: Date, to endDate: Date) async throws -> [PlannerTask] {
        return try await dataProvider.fetchByDateRange(from: startDate, to: endDate)
    }
    
    func loadTasksForToday() async throws -> [PlannerTask] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return try await dataProvider.fetchByDateRange(from: startOfDay, to: endOfDay)
    }
    
    func loadTasksForWeek() async throws -> [PlannerTask] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
        return try await dataProvider.fetchByDateRange(from: startOfWeek, to: endOfWeek)
    }
    
    func fetchById(_ id: String) async throws -> PlannerTask? {
        if let cached = tasks.first(where: { $0.id == id }) {
            return cached
        }
        return try await dataProvider.fetchById(id)
    }
    
    func saveTask(_ task: PlannerTask) async throws {
        try await dataProvider.save(task)
        
        if !tasks.contains(where: { $0.id == task.id }) {
            tasks.append(task)
        }
        sortTasks()
    }
    
    func updateTask(_ task: PlannerTask) async throws {
        try await dataProvider.update(task)
        
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
        sortTasks()
    }
    
    func deleteTask(_ id: String) async throws {
        try await dataProvider.delete(id)
        tasks.removeAll { $0.id == id }
    }
    
    func markAsCompleted(_ taskId: String) async throws {
        guard let task = try await fetchById(taskId) else {
            throw PersistenceError.objectNotFound
        }
        
        let updatedTask = PlannerTask(
            id: task.id,
            title: task.title,
            description: task.description,
            courseId: task.courseId,
            courseName: task.courseName,
            courseColor: task.courseColor,
            scheduledDate: task.scheduledDate,
            scheduledTime: task.scheduledTime,
            estimatedDuration: task.estimatedDuration,
            actualDuration: task.actualDuration,
            priority: task.priority,
            status: .completed,
            category: task.category,
            tags: task.tags,
            isRecurring: task.isRecurring,
            recurrenceRule: task.recurrenceRule,
            relatedAssignmentId: task.relatedAssignmentId,
            completedAt: Date(),
            createdAt: task.createdAt,
            updatedAt: Date()
        )
        
        try await updateTask(updatedTask)
    }
    
    func markAsInProgress(_ taskId: String) async throws {
        guard let task = try await fetchById(taskId) else {
            throw PersistenceError.objectNotFound
        }
        
        let updatedTask = PlannerTask(
            id: task.id,
            title: task.title,
            description: task.description,
            courseId: task.courseId,
            courseName: task.courseName,
            courseColor: task.courseColor,
            scheduledDate: task.scheduledDate,
            scheduledTime: task.scheduledTime,
            estimatedDuration: task.estimatedDuration,
            actualDuration: task.actualDuration,
            priority: task.priority,
            status: .inProgress,
            category: task.category,
            tags: task.tags,
            isRecurring: task.isRecurring,
            recurrenceRule: task.recurrenceRule,
            relatedAssignmentId: task.relatedAssignmentId,
            completedAt: task.completedAt,
            createdAt: task.createdAt,
            updatedAt: Date()
        )
        
        try await updateTask(updatedTask)
    }
    
    func postponeTask(_ taskId: String, to newDate: Date) async throws {
        guard let task = try await fetchById(taskId) else {
            throw PersistenceError.objectNotFound
        }
        
        let updatedTask = PlannerTask(
            id: task.id,
            title: task.title,
            description: task.description,
            courseId: task.courseId,
            courseName: task.courseName,
            courseColor: task.courseColor,
            scheduledDate: newDate,
            scheduledTime: task.scheduledTime,
            estimatedDuration: task.estimatedDuration,
            actualDuration: task.actualDuration,
            priority: task.priority,
            status: .postponed,
            category: task.category,
            tags: task.tags,
            isRecurring: task.isRecurring,
            recurrenceRule: task.recurrenceRule,
            relatedAssignmentId: task.relatedAssignmentId,
            completedAt: task.completedAt,
            createdAt: task.createdAt,
            updatedAt: Date()
        )
        
        try await updateTask(updatedTask)
    }
    
    // MARK: - Statistics
    
    func calculateStatistics() async throws -> PlannerStatistics {
        let allTasks = tasks
        
        let totalTasks = allTasks.count
        let completedTasks = allTasks.filter { $0.status == .completed }.count
        let plannedTasks = allTasks.filter { $0.status == .planned }.count
        let inProgressTasks = allTasks.filter { $0.status == .inProgress }.count
        
        let totalPlannedHours = allTasks.compactMap { $0.estimatedDuration }.reduce(0, +) / 3600.0
        let totalActualHours = allTasks.compactMap { $0.actualDuration }.reduce(0, +) / 3600.0
        
        let completionRate = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0.0
        
        let avgDuration = allTasks.compactMap { $0.estimatedDuration }.isEmpty ? 0.0 :
            allTasks.compactMap { $0.estimatedDuration }.reduce(0, +) / Double(allTasks.compactMap { $0.estimatedDuration }.count) / 3600.0
        
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
        let tasksThisWeek = allTasks.filter {
            $0.scheduledDate >= startOfWeek && $0.scheduledDate <= endOfWeek
        }.count
        
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let tasksToday = allTasks.filter {
            $0.scheduledDate >= startOfToday && $0.scheduledDate < endOfToday
        }.count
        
        return PlannerStatistics(
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            plannedTasks: plannedTasks,
            inProgressTasks: inProgressTasks,
            totalPlannedHours: totalPlannedHours,
            totalActualHours: totalActualHours,
            completionRate: completionRate,
            averageTaskDuration: avgDuration,
            tasksThisWeek: tasksThisWeek,
            tasksToday: tasksToday
        )
    }
    
    // MARK: - Private Helpers
    
    private func sortTasks() {
        tasks.sort { lhs, rhs in
            if lhs.scheduledDate != rhs.scheduledDate {
                return lhs.scheduledDate < rhs.scheduledDate
            }
            return statusSortPriority(lhs.status) < statusSortPriority(rhs.status)
        }
    }
    
    private func statusSortPriority(_ status: PlannerTaskStatus) -> Int {
        switch status {
        case .inProgress: return 0
        case .planned: return 1
        case .postponed: return 2
        case .completed: return 3
        case .cancelled: return 4
        }
    }
}
