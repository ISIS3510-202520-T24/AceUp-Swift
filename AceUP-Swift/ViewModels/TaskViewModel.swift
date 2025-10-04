//
//  TaskViewModel.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 3/10/25.
//

import SwiftUI
import SwiftData

// TaskViewModel.swift
@MainActor
class TaskViewModel: ObservableObject {
    @Published var assignments: [Assignment] = []
    @Published var todaysPending: Int = 0
    @Published var todaysCompleted: Int = 0
    @Published var todaysPendingHours: Int = 0     
    @Published var workloadRecommendation: String = ""

    private let repository: AssignmentRepository
    private let workloadAnalyzer: WorkloadAnalyzer

    init(modelContext: ModelContext) {
        self.repository = AssignmentRepository(modelContext: modelContext)
        self.workloadAnalyzer = WorkloadAnalyzer(repository: repository)
    }

    func loadAssignments() {
        do {
            assignments = try repository.fetchAll()
            updateTodaysSummary()
            analyzeWorkload()
        } catch { print("Error loading assignments: \(error)") }
    }

    func createAssignment(title: String, subject: String, type: String, dueDate: Date) {
        let assignment = Assignment(title: title, subject: subject, type: type, dueDate: dueDate)
        do {
            try repository.create(assignment)
            loadAssignments()
        } catch { print("Error creating assignment: \(error)") }
    }

    func toggleComplete(_ assignment: Assignment, to newValue: Bool? = nil) {
        if let v = newValue { assignment.isCompleted = v } else { assignment.isCompleted.toggle() }
        assignment.completedAt = assignment.isCompleted ? Date() : nil
        if !assignment.isCompleted { assignment.grade = nil } // limpiar nota al deshacer
        do {
            try repository.update()
            loadAssignments()
            NotificationService.shared.sendDailySummary(completed: todaysCompleted, pending: todaysPending)
        } catch { print("Error updating assignment: \(error)") }
    }

    // 👇 set grade (0..5) only if completed
    func setGrade(_ assignment: Assignment, grade: Double?) {
        guard assignment.isCompleted else { return }
        if let g = grade {
            assignment.grade = min(5, max(0, g))
        } else {
            assignment.grade = nil
        }
        do {
            try repository.update()
            loadAssignments()
        } catch { print("Error setting grade: \(error)") }
    }
    
    // Returns assignments due today (any completion state)
    func getTodaysAssignments() -> [Assignment] {
        (try? repository.fetchToday()) ?? []
    }

    private func updateTodaysSummary() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let todayAssignments = assignments.filter { assignment in
            guard let dueDate = assignment.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: today)
        }
        
        todaysCompleted = todayAssignments.filter { $0.isCompleted }.count
        todaysPending = todayAssignments.filter { !$0.isCompleted }.count
        todaysPendingHours = todayAssignments.filter { !$0.isCompleted }.map(\.estimatedHours).reduce(0, +)
    }
    
    // Método para editar una tarea
    func updateAssignment(_ assignment: Assignment, title: String, subject: String, type: String, dueDate: Date, priority: String, estimatedHours: Int) {
        assignment.title = title
        assignment.subject = subject
        assignment.type = type
        assignment.dueDate = dueDate
        assignment.priority = priority
        assignment.estimatedHours = estimatedHours
        
        do {
            try repository.update()
            loadAssignments()
        } catch {
            print("Error updating assignment: \(error)")
        }
    }

    // Método para eliminar una tarea
    func deleteAssignment(_ assignment: Assignment) {
        do {
            try repository.delete(assignment)
            loadAssignments()
        } catch {
            print("Error deleting assignment: \(error)")
        }
    }
    
    private func analyzeWorkload() {
        do {
            let rec = try workloadAnalyzer.analyzeNext7Days()
            workloadRecommendation = rec.message
            if rec.shouldNotify {
                NotificationService.shared.sendWorkloadRecommendation(rec.message)
            }
        } catch {
            print("Error analyzing workload:", error)
        }
    }

}
