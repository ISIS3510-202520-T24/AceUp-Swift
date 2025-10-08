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
class AssignmentViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var assignments: [Assignment] = []
    @Published var todaysAssignments: [Assignment] = []
    @Published var upcomingAssignments: [Assignment] = []
    @Published var completedAssignments: [Assignment] = []
    @Published var overdueAssignments: [Assignment] = []
    
    @Published var workloadAnalysis: WorkloadAnalysisResult?
    @Published var smartRecommendations: [SmartRecommendation] = []
    @Published var todaysSummary: TodaysSummary?
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingCreateAssignment = false
    @Published var selectedAssignment: Assignment?
    
    // Form properties
    @Published var newAssignmentTitle = ""
    @Published var newAssignmentDescription = ""
    @Published var newAssignmentDueDate = Date()
    @Published var newAssignmentCourse = ""
    @Published var newAssignmentSubject = ""
    @Published var newAssignmentWeight = 0.1
    @Published var newAssignmentPriority = Priority.medium
    @Published var newAssignmentEstimatedHours: Double?
    @Published var newAssignmentDuration: Double = 2.0
    @Published var newAssignmentTags: [String] = []
    @Published var newAssignmentNotes = ""
    
    // Course colors mapping
    @Published var courseColors: [String: String] = [
        "Mathematics": "#FF6B6B",
        "Physics": "#4ECDC4", 
        "Chemistry": "#45B7D1",
        "Biology": "#96CEB4",
        "History": "#FECA57",
        "Literature": "#FF9FF3",
        "Computer Science": "#54A0FF",
        "Art": "#5F27CD"
    ]
    
    // MARK: - Dependencies
    
    private let repository: AssignmentRepositoryProtocol
    private let workloadAnalyzer: WorkloadAnalyzer
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        repository: AssignmentRepositoryProtocol? = nil,
        workloadAnalyzer: WorkloadAnalyzer = WorkloadAnalyzer()
    ) {
        self.repository = repository ?? FirestoreAssignmentRepository()
        self.workloadAnalyzer = workloadAnalyzer
        
        setupBindings()
        Task {
            await loadAssignments()
        }
    }
    
    // MARK: - Public Methods
    
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
        
        let assignment = Assignment(
            title: newAssignmentTitle,
            description: newAssignmentDescription.isEmpty ? nil : newAssignmentDescription,
            subject: newAssignmentSubject,
            courseId: newAssignmentCourse.lowercased().replacingOccurrences(of: " ", with: "_"),
            courseName: newAssignmentCourse,
            dueDate: newAssignmentDueDate,
            weight: newAssignmentWeight,
            estimatedHours: newAssignmentEstimatedHours,
            priority: newAssignmentPriority,
            tags: newAssignmentTags
        )
        
        do {
            try await repository.saveAssignment(assignment)
            await loadAssignments()
            clearForm()
            showingCreateAssignment = false
        } catch {
            errorMessage = "Failed to create assignment: \(error.localizedDescription)"
        }
    }
    
    func updateAssignment(_ assignment: Assignment) async {
        do {
            try await repository.updateAssignment(assignment)
            await loadAssignments()
        } catch {
            errorMessage = "Failed to update assignment: \(error.localizedDescription)"
        }
    }
    
    func deleteAssignment(_ id: String) async {
        do {
            try await repository.deleteAssignment(id)
            await loadAssignments()
        } catch {
            errorMessage = "Failed to delete assignment: \(error.localizedDescription)"
        }
    }
    
    func markAsCompleted(_ id: String) async {
        do {
            try await repository.markAsCompleted(id)
            await loadAssignments()
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
        return assignments.filter { $0.priority == priority && $0.status == .pending }
    }
    
    func getAssignmentsByStatus(_ status: AssignmentStatus) -> [Assignment] {
        return assignments.filter { $0.status == status }
    }
    
    func getAssignmentsByUrgency(_ urgency: UrgencyLevel) -> [Assignment] {
        return assignments.filter { $0.urgencyLevel == urgency }
    }
    
    func searchAssignments(_ query: String) -> [Assignment] {
        guard !query.isEmpty else { return assignments }
        
        let lowercaseQuery = query.lowercased()
        return assignments.filter { assignment in
            assignment.title.lowercased().contains(lowercaseQuery) ||
            assignment.courseName.lowercased().contains(lowercaseQuery) ||
            assignment.description?.lowercased().contains(lowercaseQuery) == true ||
            assignment.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
    
    func clearForm() {
        newAssignmentTitle = ""
        newAssignmentDescription = ""
        newAssignmentDueDate = Date()
        newAssignmentCourse = ""
        newAssignmentSubject = ""
        newAssignmentWeight = 0.1
        newAssignmentPriority = .medium
        newAssignmentEstimatedHours = nil
        newAssignmentDuration = 2.0
        newAssignmentTags = []
        newAssignmentNotes = ""
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Auto-refresh data periodically
        Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                Task {
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
        upcomingAssignments = assignments.filter { assignment in
            assignment.dueDate > now && 
            assignment.dueDate <= nextWeek && 
            assignment.status == .pending
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
    }
    

}

// MARK: - Supporting Models

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