//
//  AssignmentRepository.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 4/10/25.
//

import Foundation
import Combine

@MainActor
protocol AssignmentRepositoryProtocol {
    func getAllAssignments() async throws -> [Assignment]
    func getAssignmentById(_ id: String) async throws -> Assignment?
    func getAssignmentsByDate(_ date: Date) async throws -> [Assignment]
    func getTodaysAssignments() async throws -> [Assignment]
    func getUpcomingAssignments(days: Int) async throws -> [Assignment]
    func saveAssignment(_ assignment: Assignment) async throws
    func updateAssignment(_ assignment: Assignment) async throws
    func deleteAssignment(_ id: String) async throws
    func markAsCompleted(_ id: String) async throws
    func addSubtask(to assignmentId: String, subtask: Subtask) async throws
    func updateSubtask(_ subtask: Subtask, in assignmentId: String) async throws
    func deleteSubtask(_ subtaskId: String, from assignmentId: String) async throws
}

class AssignmentRepository: AssignmentRepositoryProtocol, ObservableObject {
    
    // MARK: - Properties
    
    @Published private(set) var assignments: [Assignment] = []
    private let dataProvider: AssignmentDataProviderProtocol
    
    // MARK: - Initialization
    
    init(localProvider: CoreDataAssignmentDataProvider? = nil, remoteProvider: FirebaseAssignmentDataProvider? = nil) {
        self.dataProvider = HybridAssignmentDataProvider(
            localProvider: localProvider,
            remoteProvider: remoteProvider
        )
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Public Methods
    
    func getAllAssignments() async throws -> [Assignment] {
        assignments = try await dataProvider.fetchAll()
        return assignments
    }
    
    func getAssignmentById(_ id: String) async throws -> Assignment? {
        if let assignment = assignments.first(where: { $0.id == id }) {
            return assignment
        }
        return try await dataProvider.fetchById(id)
    }
    
    func getAssignmentsByDate(_ date: Date) async throws -> [Assignment] {
        let calendar = Calendar.current
        return assignments.filter { assignment in
            calendar.isDate(assignment.dueDate, inSameDayAs: date)
        }
    }
    
    func getTodaysAssignments() async throws -> [Assignment] {
        return try await getAssignmentsByDate(Date())
    }
    
    func getUpcomingAssignments(days: Int = 7) async throws -> [Assignment] {
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return assignments.filter { assignment in
            assignment.dueDate >= Date() && assignment.dueDate <= endDate && assignment.status == .pending
        }.sorted { $0.dueDate < $1.dueDate }
    }
    
    func saveAssignment(_ assignment: Assignment) async throws {
        try await dataProvider.save(assignment)
        if !assignments.contains(where: { $0.id == assignment.id }) {
            assignments.append(assignment)
        }
        sortAssignments()
    }
    
    func updateAssignment(_ assignment: Assignment) async throws {
        let updatedAssignment = Assignment(
            id: assignment.id,
            title: assignment.title,
            description: assignment.description,
            courseId: assignment.courseId,
            courseName: assignment.courseName,
            courseColor: assignment.courseColor,
            dueDate: assignment.dueDate,
            weight: assignment.weight,
            estimatedHours: assignment.estimatedHours,
            actualHours: assignment.actualHours,
            priority: assignment.priority,
            status: assignment.status,
            tags: assignment.tags,
            attachments: assignment.attachments,
            subtasks: assignment.subtasks,
            createdAt: assignment.createdAt,
            updatedAt: Date()
        )
        
        try await dataProvider.update(updatedAssignment)
        
        if let index = assignments.firstIndex(where: { $0.id == assignment.id }) {
            assignments[index] = updatedAssignment
        }
        sortAssignments()
    }
    
    func deleteAssignment(_ id: String) async throws {
        try await dataProvider.delete(id)
        assignments.removeAll { $0.id == id }
    }
    
    func markAsCompleted(_ id: String) async throws {
        guard let assignment = assignments.first(where: { $0.id == id }) else {
            throw AssignmentError.assignmentNotFound
        }
        
        let completedAssignment = Assignment(
            id: assignment.id,
            title: assignment.title,
            description: assignment.description,
            courseId: assignment.courseId,
            courseName: assignment.courseName,
            courseColor: assignment.courseColor,
            dueDate: assignment.dueDate,
            weight: assignment.weight,
            estimatedHours: assignment.estimatedHours,
            actualHours: assignment.actualHours,
            priority: assignment.priority,
            status: .completed,
            tags: assignment.tags,
            attachments: assignment.attachments,
            subtasks: assignment.subtasks.map { subtask in
                Subtask(
                    id: subtask.id,
                    title: subtask.title,
                    description: subtask.description,
                    isCompleted: true,
                    estimatedHours: subtask.estimatedHours,
                    completedAt: Date(),
                    createdAt: subtask.createdAt
                )
            },
            createdAt: assignment.createdAt,
            updatedAt: Date()
        )
        
        try await updateAssignment(completedAssignment)
    }
    
    func addSubtask(to assignmentId: String, subtask: Subtask) async throws {
        guard let assignment = assignments.first(where: { $0.id == assignmentId }) else {
            throw AssignmentError.assignmentNotFound
        }
        
        let updatedSubtasks = assignment.subtasks + [subtask]
        let updatedAssignment = Assignment(
            id: assignment.id,
            title: assignment.title,
            description: assignment.description,
            courseId: assignment.courseId,
            courseName: assignment.courseName,
            courseColor: assignment.courseColor,
            dueDate: assignment.dueDate,
            weight: assignment.weight,
            estimatedHours: assignment.estimatedHours,
            actualHours: assignment.actualHours,
            priority: assignment.priority,
            status: assignment.status,
            tags: assignment.tags,
            attachments: assignment.attachments,
            subtasks: updatedSubtasks,
            createdAt: assignment.createdAt,
            updatedAt: Date()
        )
        
        try await updateAssignment(updatedAssignment)
    }
    
    func updateSubtask(_ subtask: Subtask, in assignmentId: String) async throws {
        guard let assignment = assignments.first(where: { $0.id == assignmentId }) else {
            throw AssignmentError.assignmentNotFound
        }
        
        let updatedSubtasks = assignment.subtasks.map { existingSubtask in
            existingSubtask.id == subtask.id ? subtask : existingSubtask
        }
        
        let updatedAssignment = Assignment(
            id: assignment.id,
            title: assignment.title,
            description: assignment.description,
            courseId: assignment.courseId,
            courseName: assignment.courseName,
            courseColor: assignment.courseColor,
            dueDate: assignment.dueDate,
            weight: assignment.weight,
            estimatedHours: assignment.estimatedHours,
            actualHours: assignment.actualHours,
            priority: assignment.priority,
            status: assignment.status,
            tags: assignment.tags,
            attachments: assignment.attachments,
            subtasks: updatedSubtasks,
            createdAt: assignment.createdAt,
            updatedAt: Date()
        )
        
        try await updateAssignment(updatedAssignment)
    }
    
    func deleteSubtask(_ subtaskId: String, from assignmentId: String) async throws {
        guard let assignment = assignments.first(where: { $0.id == assignmentId }) else {
            throw AssignmentError.assignmentNotFound
        }
        
        let updatedSubtasks = assignment.subtasks.filter { $0.id != subtaskId }
        let updatedAssignment = Assignment(
            id: assignment.id,
            title: assignment.title,
            description: assignment.description,
            courseId: assignment.courseId,
            courseName: assignment.courseName,
            courseColor: assignment.courseColor,
            dueDate: assignment.dueDate,
            weight: assignment.weight,
            estimatedHours: assignment.estimatedHours,
            actualHours: assignment.actualHours,
            priority: assignment.priority,
            status: assignment.status,
            tags: assignment.tags,
            attachments: assignment.attachments,
            subtasks: updatedSubtasks,
            createdAt: assignment.createdAt,
            updatedAt: Date()
        )
        
        try await updateAssignment(updatedAssignment)
    }
    
    // MARK: - Private Methods
    
    private func loadInitialData() async {
        do {
            let fetchedAssignments = try await dataProvider.fetchAll()
            await MainActor.run {
                assignments = fetchedAssignments
                sortAssignments()
            }
        } catch {
            print("Failed to load initial assignment data: \(error)")
            // Load mock data for development
            await loadMockData()
        }
    }
    
    private func sortAssignments() {
        assignments.sort { lhs, rhs in
            // First, sort by status priority (pending > in progress > completed)
            if lhs.status != rhs.status {
                let lhsPriority = statusSortPriority(lhs.status)
                let rhsPriority = statusSortPriority(rhs.status)
                return lhsPriority < rhsPriority
            }
            
            // Then by due date (sooner first)
            return lhs.dueDate < rhs.dueDate
        }
    }
    
    private func statusSortPriority(_ status: AssignmentStatus) -> Int {
        switch status {
        case .overdue: return 0
        case .pending: return 1
        case .inProgress: return 2
        case .completed: return 3
        case .cancelled: return 4
        }
    }
    
    private func loadMockData() async {
        let calendar = Calendar.current
        let mockAssignments = [
            Assignment(
                title: "Final Programming Project",
                description: "Develop a complete web application using React and Node.js",
                courseId: "cs101",
                courseName: "Introduction to Computer Science",
                courseColor: "#122C4A",
                dueDate: calendar.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                weight: 0.25,
                estimatedHours: 20,
                priority: .high,
                status: .pending,
                tags: ["programming", "web development"],
                subtasks: [
                    Subtask(title: "Setup project repository"),
                    Subtask(title: "Design database schema"),
                    Subtask(title: "Implement backend API"),
                    Subtask(title: "Create frontend components"),
                    Subtask(title: "Write tests"),
                    Subtask(title: "Deploy to production")
                ]
            ),
            Assignment(
                title: "Calculus Midterm Preparation",
                description: "Review chapters 8-12 for comprehensive midterm exam",
                courseId: "math201",
                courseName: "Calculus II",
                courseColor: "#50E3C2",
                dueDate: calendar.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
                weight: 0.30,
                estimatedHours: 8,
                priority: .critical,
                status: .inProgress,
                tags: ["math", "calculus", "exam prep"]
            ),
            Assignment(
                title: "Physics Lab Report #3",
                description: "Analysis of pendulum motion and harmonic oscillation",
                courseId: "phys151",
                courseName: "Physics I",
                courseColor: "#FF6B6B",
                dueDate: Date(),
                weight: 0.08,
                estimatedHours: 4,
                priority: .medium,
                status: .pending,
                tags: ["physics", "lab", "mechanics"]
            ),
            Assignment(
                title: "Research Paper Draft",
                description: "First draft of research paper on machine learning applications",
                courseId: "cs401",
                courseName: "Advanced AI",
                courseColor: "#9C27B0",
                dueDate: calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                weight: 0.15,
                estimatedHours: 12,
                priority: .medium,
                status: .pending,
                tags: ["research", "AI", "paper"],
                subtasks: [
                    Subtask(title: "Literature review", isCompleted: true),
                    Subtask(title: "Write introduction"),
                    Subtask(title: "Methodology section"),
                    Subtask(title: "Results analysis"),
                    Subtask(title: "Conclusions")
                ]
            )
        ]
        
        await MainActor.run {
            assignments = mockAssignments
        }
    }
}

// MARK: - Data Provider Protocol

protocol AssignmentDataProviderProtocol {
    func fetchAll() async throws -> [Assignment]
    func fetchById(_ id: String) async throws -> Assignment?
    func save(_ assignment: Assignment) async throws
    func update(_ assignment: Assignment) async throws
    func delete(_ id: String) async throws
}

// MARK: - Local Data Provider (Mock implementation)

class LocalAssignmentDataProvider: AssignmentDataProviderProtocol {
    private var storage: [String: Assignment] = [:]
    
    func fetchAll() async throws -> [Assignment] {
        return Array(storage.values)
    }
    
    func fetchById(_ id: String) async throws -> Assignment? {
        return storage[id]
    }
    
    func save(_ assignment: Assignment) async throws {
        storage[assignment.id] = assignment
    }
    
    func update(_ assignment: Assignment) async throws {
        storage[assignment.id] = assignment
    }
    
    func delete(_ id: String) async throws {
        storage.removeValue(forKey: id)
    }
}

// MARK: - Assignment Errors

enum AssignmentError: LocalizedError {
    case assignmentNotFound
    case invalidData
    case storageError(String)
    
    var errorDescription: String? {
        switch self {
        case .assignmentNotFound:
            return "Assignment not found"
        case .invalidData:
            return "Invalid assignment data"
        case .storageError(let message):
            return "Storage error: \(message)"
        }
    }
}