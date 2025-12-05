//
//  PlannerViewModel.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/12/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class PlannerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var tasks: [PlannerTask] = []
    @Published private(set) var todayTasks: [PlannerTask] = []
    @Published private(set) var weekTasks: [PlannerTask] = []
    @Published private(set) var statistics: PlannerStatistics?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    @Published var selectedDate: Date = Date()
    @Published var selectedCategory: PlannerTaskCategory?
    @Published var selectedStatus: PlannerTaskStatus?
    @Published var searchText: String = ""
    
    // Task Creation Form
    @Published var showCreateTaskSheet = false
    @Published var newTaskTitle = ""
    @Published var newTaskDescription = ""
    @Published var newTaskScheduledDate = Date()
    @Published var newTaskScheduledTime: Date?
    @Published var newTaskEstimatedDuration: TimeInterval = 3600 // 1 hour default
    @Published var newTaskPriority: Priority = .medium
    @Published var newTaskCategory: PlannerTaskCategory = .study
    @Published var newTaskCourseId: String?
    @Published var newTaskCourseName: String?
    @Published var newTaskCourseColor: String?
    @Published var newTaskTags: [String] = []
    @Published var newTaskIsRecurring = false
    @Published var newTaskRecurrenceFrequency: RecurrenceFrequency = .weekly
    
    // MARK: - Private Properties
    
    private let repository: PlannerTaskRepository
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var filteredTasks: [PlannerTask] {
        var filtered = tasks
        
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        if let status = selectedStatus {
            filtered = filtered.filter { $0.status == status }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description?.localizedCaseInsensitiveContains(searchText) ?? false ||
                $0.courseName?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        
        return filtered
    }
    
    var tasksForSelectedDate: [PlannerTask] {
        let calendar = Calendar.current
        return tasks.filter { task in
            calendar.isDate(task.scheduledDate, inSameDayAs: selectedDate)
        }
    }
    
    var completedTasksCount: Int {
        tasks.filter { $0.status == .completed }.count
    }
    
    var plannedTasksCount: Int {
        tasks.filter { $0.status == .planned }.count
    }
    
    var inProgressTasksCount: Int {
        tasks.filter { $0.status == .inProgress }.count
    }
    
    var todayCompletionRate: Double {
        let today = todayTasks
        guard !today.isEmpty else { return 0.0 }
        let completed = today.filter { $0.status == .completed }.count
        return Double(completed) / Double(today.count)
    }
    
    // MARK: - Initialization
    
    init(repository: PlannerTaskRepository? = nil) {
        self.repository = repository ?? PlannerTaskRepository()
    }
    
    // MARK: - Public Methods
    
    func loadTasks() async {
        isLoading = true
        errorMessage = nil
        
        // Setup bindings on first load if needed
        if cancellables.isEmpty {
            setupBindings()
        }
        
        do {
            try await repository.loadAllTasks()
            tasks = repository.tasks
            await updateDerivedData()
            await loadStatistics()
        } catch {
            errorMessage = "Failed to load tasks: \(error.localizedDescription)"
            print("❌ Error loading tasks: \(error)")
        }
        
        isLoading = false
    }
    
    func loadTasksForDate(_ date: Date) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        do {
            let dateTasks = try await repository.loadTasksForDateRange(from: startOfDay, to: endOfDay)
            // Update tasks array with these tasks
            for task in dateTasks {
                if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[index] = task
                } else {
                    tasks.append(task)
                }
            }
            await updateDerivedData()
        } catch {
            errorMessage = "Failed to load tasks for date: \(error.localizedDescription)"
        }
    }
    
    func createTask() async {
        guard !newTaskTitle.isEmpty else {
            errorMessage = "Task title cannot be empty"
            return
        }
        
        let recurrenceRule: RecurrenceRule? = newTaskIsRecurring ?
            RecurrenceRule(frequency: newTaskRecurrenceFrequency) : nil
        
        let task = PlannerTask(
            title: newTaskTitle,
            description: newTaskDescription.isEmpty ? nil : newTaskDescription,
            courseId: newTaskCourseId,
            courseName: newTaskCourseName,
            courseColor: newTaskCourseColor,
            scheduledDate: newTaskScheduledDate,
            scheduledTime: newTaskScheduledTime,
            estimatedDuration: newTaskEstimatedDuration,
            priority: newTaskPriority,
            category: newTaskCategory,
            tags: newTaskTags,
            isRecurring: newTaskIsRecurring,
            recurrenceRule: recurrenceRule
        )
        
        do {
            try await repository.saveTask(task)
            tasks = repository.tasks
            await updateDerivedData()
            await loadStatistics()
            resetCreateTaskForm()
            showCreateTaskSheet = false
        } catch {
            errorMessage = "Failed to create task: \(error.localizedDescription)"
        }
    }
    
    func updateTask(_ task: PlannerTask) async {
        do {
            try await repository.updateTask(task)
            tasks = repository.tasks
            await updateDerivedData()
            await loadStatistics()
        } catch {
            errorMessage = "Failed to update task: \(error.localizedDescription)"
        }
    }
    
    func deleteTask(_ taskId: String) async {
        do {
            try await repository.deleteTask(taskId)
            tasks = repository.tasks
            await updateDerivedData()
            await loadStatistics()
        } catch {
            errorMessage = "Failed to delete task: \(error.localizedDescription)"
        }
    }
    
    func markTaskAsCompleted(_ taskId: String) async {
        do {
            try await repository.markAsCompleted(taskId)
            tasks = repository.tasks
            await updateDerivedData()
            await loadStatistics()
        } catch {
            errorMessage = "Failed to mark task as completed: \(error.localizedDescription)"
        }
    }
    
    func markTaskAsInProgress(_ taskId: String) async {
        do {
            try await repository.markAsInProgress(taskId)
            tasks = repository.tasks
            await updateDerivedData()
            await loadStatistics()
        } catch {
            errorMessage = "Failed to mark task as in progress: \(error.localizedDescription)"
        }
    }
    
    func postponeTask(_ taskId: String, to newDate: Date) async {
        do {
            try await repository.postponeTask(taskId, to: newDate)
            tasks = repository.tasks
            await updateDerivedData()
            await loadStatistics()
        } catch {
            errorMessage = "Failed to postpone task: \(error.localizedDescription)"
        }
    }
    
    func loadStatistics() async {
        do {
            statistics = try await repository.calculateStatistics()
        } catch {
            print("❌ Error loading statistics: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Auto-refresh when date changes
        $selectedDate
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.updateDerivedData()
                }
            }
            .store(in: &cancellables)
        
        // Periodic refresh
        Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.loadTasks()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateDerivedData() async {
        let calendar = Calendar.current
        
        // Today's tasks
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        todayTasks = tasks.filter {
            $0.scheduledDate >= startOfToday && $0.scheduledDate < endOfToday
        }
        
        // Week's tasks
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
        weekTasks = tasks.filter {
            $0.scheduledDate >= startOfWeek && $0.scheduledDate <= endOfWeek
        }
    }
    
    private func resetCreateTaskForm() {
        newTaskTitle = ""
        newTaskDescription = ""
        newTaskScheduledDate = Date()
        newTaskScheduledTime = nil
        newTaskEstimatedDuration = 3600
        newTaskPriority = .medium
        newTaskCategory = .study
        newTaskCourseId = nil
        newTaskCourseName = nil
        newTaskCourseColor = nil
        newTaskTags = []
        newTaskIsRecurring = false
        newTaskRecurrenceFrequency = .weekly
    }
}
