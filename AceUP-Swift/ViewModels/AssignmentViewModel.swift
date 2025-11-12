//
//  AssignmentViewModel.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel for assignment management using MVVM pattern
/// Handles assignment business logic and state management
@MainActor
final class AssignmentViewModel: ObservableObject {
    
    // Published Properties
    @Published var assignments: [Assignment] = []
    @Published var todaysAssignments: [Assignment] = []
    @Published var upcomingAssignments: [Assignment] = []
    @Published var completedAssignments: [Assignment] = []
    @Published var overdueAssignments: [Assignment] = []
    
    @Published var workloadAnalysis: WorkloadAnalysis?
    @Published var smartRecommendations: [SmartRecommendation] = []
    @Published var todaysSummary: TodaysSummary?
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingCreateAssignment = false
    @Published var selectedAssignment: Assignment?
    
    // MARK: - BQ 2.1 Computed Property
    /// The highest weight pending assignment (for BQ 2.1 notifications)
    var highestWeightPendingAssignment: Assignment? {
        let allPendingAssignments = assignments.filter { 
            ($0.status == .pending || $0.status == .inProgress) && !$0.isOverdue 
        }
        return allPendingAssignments.max(by: { $0.weight < $1.weight })
    }
    
    // Form properties
    @Published var newAssignmentTitle = ""
    @Published var newAssignmentDescription = ""
    @Published var newAssignmentDueDate = Date()
    @Published var newAssignmentCourse = ""
    @Published var newAssignmentWeight = 0.1
    @Published var newAssignmentPriority = Priority.medium
    @Published var newAssignmentEstimatedHours: Double?
    @Published var newAssignmentTags: [String] = []
    
    // Dependencies
    private let repository: AssignmentRepositoryProtocol
    private let workloadAnalyzer: WorkloadAnalyzer
    private var cancellables = Set<AnyCancellable>()
    private var dataProvider: AssignmentDataProviderProtocol
    
    // Initialization
    init(
        repository: AssignmentRepositoryProtocol? = nil,
        workloadAnalyzer: WorkloadAnalyzer = WorkloadAnalyzer(),
        dataProvider: AssignmentDataProviderProtocol? = nil
    ) {
        // Provider (por defecto híbrido)
        let provider = dataProvider ?? HybridAssignmentDataProvider()
        self.dataProvider = provider
        
        // Repo por defecto, concreto que conforma el protocolo
        self.repository = repository ?? AssignmentRepository(dataProvider: provider)
        self.workloadAnalyzer = workloadAnalyzer
        
        setupBindings()
        Task { await loadAssignments() }
    }
    
    // MARK: - Public Methods

    /// Actualiza la nota usando el repositorio (emite GA4 + colector desde el repo)
    func updateGrade(_ id: String, to newGrade: Double) async {
        do {
            try await repository.updateGrade(id, grade: newGrade)
            await loadAssignments()
        } catch {
            errorMessage = "Failed to update grade: \(error.localizedDescription)"
        }
    }

    func loadAssignments() async {
        isLoading = true
        errorMessage = nil
        do {
            assignments = try await repository.getAllAssignments()
            await updateDerivedData()
            await analyzeWorkload()
            await updateTodaysSummary()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func createAssignment() async {
        guard !newAssignmentTitle.isEmpty && !newAssignmentCourse.isEmpty else {
            errorMessage = "Title and course are required"
            return
        }
        
        // Sanitize inputs before creating assignment
        let sanitizedTitle = InputValidation.sanitizeTitle(newAssignmentTitle)
        let sanitizedCourse = InputValidation.sanitizeCourseName(newAssignmentCourse)
        let sanitizedDescription = newAssignmentDescription.isEmpty ? nil : InputValidation.sanitizeDescription(newAssignmentDescription)
        let sanitizedTags = newAssignmentTags.map { InputValidation.sanitizeTag($0) }
        
        let assignment = Assignment(
            title: sanitizedTitle,
            description: sanitizedDescription,
            courseId: sanitizedCourse.lowercased().replacingOccurrences(of: " ", with: "_"),
            courseName: sanitizedCourse,
            dueDate: newAssignmentDueDate,
            weight: newAssignmentWeight,
            estimatedHours: newAssignmentEstimatedHours,
            priority: newAssignmentPriority,
            tags: sanitizedTags
        )
        
        do {
            try await repository.saveAssignment(assignment)
            await loadAssignments()
            clearForm()
            showingCreateAssignment = false
            // Update BQ 2.1 notification since a new assignment was added
            await scheduleHighestWeightAssignmentNotification()
        } catch {
            errorMessage = "Failed to create assignment: \(error.localizedDescription)"
        }
    }
    
    func updateAssignment(_ assignment: Assignment) async {
        do {
            try await repository.updateAssignment(assignment)
            await loadAssignments()
            // Update BQ 2.1 notification since assignment weights might have changed
            await scheduleHighestWeightAssignmentNotification()
        } catch {
            errorMessage = "Failed to update assignment: \(error.localizedDescription)"
        }
    }
    
    func deleteAssignment(_ id: String) async {
        do {
            try await repository.deleteAssignment(id)
            await loadAssignments()
            // Update BQ 2.1 notification since an assignment was removed
            await scheduleHighestWeightAssignmentNotification()
        } catch {
            errorMessage = "Failed to delete assignment: \(error.localizedDescription)"
        }
    }
    
    /// Marca como completada usando el repositorio (emite GA4 + colector desde el repo)
    func markAsCompleted(_ id: String, finalGrade: Double? = nil) async {
        do {
            try await repository.markCompleted(id, finalGrade: finalGrade)
            await loadAssignments()
            // Update BQ 2.1 notification since the highest weight assignment might have changed
            await scheduleHighestWeightAssignmentNotification()
        } catch {
            errorMessage = "Failed to mark assignment as completed: \(error.localizedDescription)"
        }
    }
    
    func toggleSubtaskCompletion(_ subtaskId: String, in assignmentId: String) async {
        guard let assignment = assignments.first(where: { $0.id == assignmentId }),
              let subtask = assignment.subtasks.first(where: { $0.id == subtaskId }) else {
            return
        }
        
        let updatedSubtask = Subtask(
            id: subtask.id,
            title: subtask.title,
            description: subtask.description,
            isCompleted: !subtask.isCompleted,
            estimatedHours: subtask.estimatedHours,
            completedAt: !subtask.isCompleted ? Date() : nil,
            createdAt: subtask.createdAt
        )
        
        do {
            try await repository.updateSubtask(updatedSubtask, in: assignmentId)
            await loadAssignments()
        } catch {
            errorMessage = "Failed to update subtask: \(error.localizedDescription)"
        }
    }
    
    func addSubtask(to assignmentId: String, title: String, description: String? = nil, estimatedHours: Double? = nil) async {
        let subtask = Subtask(
            title: title,
            description: description,
            estimatedHours: estimatedHours
        )
        
        do {
            try await repository.addSubtask(to: assignmentId, subtask: subtask)
            await loadAssignments()
        } catch {
            errorMessage = "Failed to add subtask: \(error.localizedDescription)"
        }
    }
    
    func getAssignmentsByPriority(_ priority: Priority) -> [Assignment] {
        assignments.filter { $0.priority == priority && $0.status == .pending }
    }
    
    func getAssignmentsByStatus(_ status: AssignmentStatus) -> [Assignment] {
        assignments.filter { $0.status == status }
    }
    
    func getAssignmentsByUrgency(_ urgency: UrgencyLevel) -> [Assignment] {
        assignments.filter { $0.urgencyLevel == urgency }
    }
    
    func searchAssignments(_ query: String) -> [Assignment] {
        guard !query.isEmpty else { return assignments }
        let q = query.lowercased()
        return assignments.filter { a in
            a.title.lowercased().contains(q) ||
            a.courseName.lowercased().contains(q) ||
            a.description?.lowercased().contains(q) == true ||
            a.tags.contains { $0.lowercased().contains(q) }
        }
    }
    
    func clearForm() {
        newAssignmentTitle = ""
        newAssignmentDescription = ""
        newAssignmentDueDate = Date()
        newAssignmentCourse = ""
        newAssignmentWeight = 0.1
        newAssignmentPriority = .medium
        newAssignmentEstimatedHours = nil
        newAssignmentTags = []
    }
    
    // Private Methods
    
    private func setupBindings() {
        // Auto-refresh data periodically
        Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadAssignments()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateDerivedData() async {
        let now = Date()
        let calendar = Calendar.current
        
        // Today's assignments
        todaysAssignments = assignments.filter { assignment in
            calendar.isDate(assignment.dueDate, inSameDayAs: now)
        }
        
        // Upcoming assignments (next 7 days)
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        upcomingAssignments = assignments.filter { a in
            a.dueDate > now && a.dueDate <= nextWeek && a.status == .pending
        }.sorted { $0.dueDate < $1.dueDate }
        
        // Completed assignments
        completedAssignments = assignments.filter { $0.status == .completed }
        
        // Overdue assignments
        overdueAssignments = assignments.filter { $0.isOverdue }
    }
    
    private func analyzeWorkload() async {
        workloadAnalysis = workloadAnalyzer.analyzeWorkload(assignments: assignments)
        smartRecommendations = workloadAnalyzer.generateSmartRecommendations(assignments: assignments)
    }
    
    /// Implements Type 2 BQ: How many of today's assignments has the student completed?
    private func updateTodaysSummary() async {
        let todaysPending = todaysAssignments.filter { $0.status == .pending || $0.status == .inProgress }
        let todaysCompleted = todaysAssignments.filter { $0.status == .completed }
        let todaysTotal = todaysAssignments.count
        
        todaysSummary = TodaysSummary(
            totalAssignments: todaysTotal,
            completedAssignments: todaysCompleted.count,
            pendingAssignments: todaysPending.count,
            completionPercentage: todaysTotal > 0 ? Double(todaysCompleted.count) / Double(todaysTotal) : 0.0,
            highestWeightPending: todaysPending.max { $0.weight < $1.weight },
            estimatedTimeRemaining: todaysPending.compactMap { $0.estimatedTimeRemaining }.reduce(0, +)
        )

        // Notificación para el BQ 2.4 
        NotificationService.scheduleTodayPendingReminderIfNeeded(pendingCount: todaysPending.count)
        
        // BQ 2.1: Schedule notification for highest weight pending assignment
        await scheduleHighestWeightAssignmentNotification()
    }
    
    /// BQ 2.1: Find the highest weight pending assignment and schedule notification
    private func scheduleHighestWeightAssignmentNotification() async {
        // Find the highest weight pending assignment across all assignments (not just today's)
        let allPendingAssignments = assignments.filter { 
            ($0.status == .pending || $0.status == .inProgress) && !$0.isOverdue 
        }
        
        guard let highestWeightAssignment = allPendingAssignments.max(by: { $0.weight < $1.weight }) else {
            return // No pending assignments found
        }
        
        // Only schedule notification if the assignment is significant (weight >= 10%)
        guard highestWeightAssignment.weight >= 0.1 else { return }
        
        NotificationService.scheduleHighestWeightAssignmentReminder(assignment: highestWeightAssignment)
    }
}

// Supporting Models

struct TodaysSummary {
    let totalAssignments: Int
    let completedAssignments: Int
    let pendingAssignments: Int
    let completionPercentage: Double
    let highestWeightPending: Assignment?
    let estimatedTimeRemaining: Double
    
    var isCompletelyDone: Bool {
        pendingAssignments == 0 && totalAssignments > 0
    }
    
    var progressMessage: String {
        if totalAssignments == 0 {
            return "No assignments due today"
        } else if isCompletelyDone {
            return "All assignments completed! 🎉"
        } else {
            return "\(completedAssignments) of \(totalAssignments) completed"
        }
    }
    
    var motivationalMessage: String {
        if isCompletelyDone {
            return "Great job! Time to work on upcoming assignments or take a well-deserved break."
        } else if completionPercentage >= 0.75 {
            return "Almost there! Just \(pendingAssignments) more to go."
        } else if completionPercentage >= 0.5 {
            return "Good progress! Keep it up."
        } else if pendingAssignments > 0 {
            return "Let's get started! Break down your tasks and tackle them one by one."
        } else {
            return "Ready to be productive today!"
        }
    }
}