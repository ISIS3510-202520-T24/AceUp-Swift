//
//  FirestoreAssignmentRepository.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FirestoreAssignmentRepository: AssignmentRepositoryProtocol, ObservableObject {
    
    // MARK: - Properties
    
    @Published private(set) var assignments: [Assignment] = []
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    private var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? ""
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await startListening()
        }
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Private Methods
    
    private func startListening() async {
        guard !currentUserId.isEmpty else {
            print("No authenticated user found")
            return
        }
        
        listener = db.collection("assignments")
            .whereField("userId", isEqualTo: currentUserId)
            .order(by: "dueDate")
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching assignments: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("No assignments found")
                    return
                }
                
                Task { @MainActor in
                    self.assignments = documents.compactMap { document in
                        try? document.data(as: AssignmentFirestore.self).toAssignment()
                    }
                }
            }
    }
    
    private func assignmentDocument(id: String) -> DocumentReference {
        return db.collection("assignments").document(id)
    }
    
    // MARK: - AssignmentRepositoryProtocol Implementation
    
    func getAllAssignments() async throws -> [Assignment] {
        await Task.yield()
        return assignments
    }
    
    func getAssignmentById(_ id: String) async throws -> Assignment? {
        await Task.yield()
        return assignments.first { $0.id == id }
    }
    
    func getAssignmentsByDate(_ date: Date) throws -> [Assignment] {
        let calendar = Calendar.current
        return assignments.filter { assignment in
            calendar.isDate(assignment.dueDate, inSameDayAs: date)
        }
    }
    
    func getTodaysAssignments() throws -> [Assignment] {
        return try getAssignmentsByDate(Date())
    }
    
    func getUpcomingAssignments(days: Int = 7) throws -> [Assignment] {
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return assignments.filter { assignment in
            assignment.dueDate >= Date() && assignment.dueDate <= endDate && assignment.status == .pending
        }.sorted { $0.dueDate < $1.dueDate }
    }
    
    func saveAssignment(_ assignment: Assignment) async throws {
        let firestoreAssignment = AssignmentFirestore.from(assignment: assignment, userId: currentUserId)
        try await assignmentDocument(id: assignment.id).setData(from: firestoreAssignment)
    }
    
    func updateAssignment(_ assignment: Assignment) async throws {
        let updatedAssignment = Assignment(
            id: assignment.id,
            title: assignment.title,
            description: assignment.description,
            subject: assignment.subject,
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
        
        let firestoreAssignment = AssignmentFirestore.from(assignment: updatedAssignment, userId: currentUserId)
        try await assignmentDocument(id: updatedAssignment.id).setData(from: firestoreAssignment)
    }
    
    func deleteAssignment(_ id: String) async throws {
        try await assignmentDocument(id: id).delete()
    }
    
    func markAsCompleted(_ id: String) async throws {
        guard let assignment = assignments.first(where: { $0.id == id }) else {
            throw AssignmentError.assignmentNotFound
        }
        
        let completedAssignment = Assignment(
            id: assignment.id,
            title: assignment.title,
            description: assignment.description,
            subject: assignment.subject,
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
            subject: assignment.subject,
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
            subject: assignment.subject,
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
            subject: assignment.subject,
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
}

// MARK: - Firestore Models

struct AssignmentFirestore: Codable {
    let id: String
    let userId: String
    let title: String
    let description: String?
    let subject: String
    let courseId: String
    let courseName: String
    let courseColor: String
    let dueDate: Timestamp
    let weight: Double
    let estimatedHours: Double?
    let actualHours: Double?
    let priority: String
    let status: String
    let tags: [String]
    let attachments: [AssignmentAttachmentFirestore]
    let subtasks: [SubtaskFirestore]
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    static func from(assignment: Assignment, userId: String) -> AssignmentFirestore {
        return AssignmentFirestore(
            id: assignment.id,
            userId: userId,
            title: assignment.title,
            description: assignment.description,
            subject: assignment.subject,
            courseId: assignment.courseId,
            courseName: assignment.courseName,
            courseColor: assignment.courseColor,
            dueDate: Timestamp(date: assignment.dueDate),
            weight: assignment.weight,
            estimatedHours: assignment.estimatedHours,
            actualHours: assignment.actualHours,
            priority: assignment.priority.rawValue,
            status: assignment.status.rawValue,
            tags: assignment.tags,
            attachments: assignment.attachments.map { AssignmentAttachmentFirestore.from($0) },
            subtasks: assignment.subtasks.map { SubtaskFirestore.from($0) },
            createdAt: Timestamp(date: assignment.createdAt),
            updatedAt: Timestamp(date: assignment.updatedAt)
        )
    }
    
    func toAssignment() -> Assignment {
        return Assignment(
            id: id,
            title: title,
            description: description,
            subject: subject,
            courseId: courseId,
            courseName: courseName,
            courseColor: courseColor,
            dueDate: dueDate.dateValue(),
            weight: weight,
            estimatedHours: estimatedHours,
            actualHours: actualHours,
            priority: Priority(rawValue: priority) ?? .medium,
            status: AssignmentStatus(rawValue: status) ?? .pending,
            tags: tags,
            attachments: attachments.map { $0.toAttachment() },
            subtasks: subtasks.map { $0.toSubtask() },
            createdAt: createdAt.dateValue(),
            updatedAt: updatedAt.dateValue()
        )
    }
}

struct AssignmentAttachmentFirestore: Codable {
    let id: String
    let name: String
    let url: String
    let type: String
    let size: Int64?
    let uploadedAt: Timestamp
    
    static func from(_ attachment: AssignmentAttachment) -> AssignmentAttachmentFirestore {
        return AssignmentAttachmentFirestore(
            id: attachment.id,
            name: attachment.name,
            url: attachment.url,
            type: attachment.type.rawValue,
            size: attachment.size,
            uploadedAt: Timestamp(date: attachment.uploadedAt)
        )
    }
    
    func toAttachment() -> AssignmentAttachment {
        return AssignmentAttachment(
            id: id,
            name: name,
            url: url,
            type: AttachmentType(rawValue: type) ?? .other,
            size: size,
            uploadedAt: uploadedAt.dateValue()
        )
    }
}

struct SubtaskFirestore: Codable {
    let id: String
    let title: String
    let description: String?
    let isCompleted: Bool
    let estimatedHours: Double?
    let completedAt: Timestamp?
    let createdAt: Timestamp
    
    static func from(_ subtask: Subtask) -> SubtaskFirestore {
        return SubtaskFirestore(
            id: subtask.id,
            title: subtask.title,
            description: subtask.description,
            isCompleted: subtask.isCompleted,
            estimatedHours: subtask.estimatedHours,
            completedAt: subtask.completedAt.map { Timestamp(date: $0) },
            createdAt: Timestamp(date: subtask.createdAt)
        )
    }
    
    func toSubtask() -> Subtask {
        return Subtask(
            id: id,
            title: title,
            description: description,
            isCompleted: isCompleted,
            estimatedHours: estimatedHours,
            completedAt: completedAt?.dateValue(),
            createdAt: createdAt.dateValue()
        )
    }
}