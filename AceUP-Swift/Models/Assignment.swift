//
//  Assignment.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 4/10/25.
//

import Foundation

// MARK: - Assignment Model
/// Core assignment model extending AcademicEvent with assignment-specific properties
struct Assignment: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let description: String?
    let courseId: String
    let courseName: String
    let courseColor: String
    let dueDate: Date
    let weight: Double // Percentage of final grade (0.0 - 1.0)
    let estimatedHours: Double?
    let actualHours: Double?
    let priority: Priority
    let status: AssignmentStatus
    let tags: [String]
    let attachments: [AssignmentAttachment]
    let subtasks: [Subtask]
    let createdAt: Date
    let updatedAt: Date
    let grade: Double?
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        courseId: String,
        courseName: String,
        courseColor: String = "#122C4A",
        dueDate: Date,
        weight: Double = 0.1,
        estimatedHours: Double? = nil,
        actualHours: Double? = nil,
        priority: Priority = .medium,
        status: AssignmentStatus = .pending,
        tags: [String] = [],
        attachments: [AssignmentAttachment] = [],
        subtasks: [Subtask] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        grade: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.courseId = courseId
        self.courseName = courseName
        self.courseColor = courseColor
        self.dueDate = dueDate
        self.weight = weight
        self.estimatedHours = estimatedHours
        self.actualHours = actualHours
        self.priority = priority
        self.status = status
        self.tags = tags
        self.attachments = attachments
        self.subtasks = subtasks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.grade = grade
    }
    
    // MARK: - Computed Properties
    
    var weightPercentage: Int {
        Int(weight * 100)
    }
    
    var isOverdue: Bool {
        status == .pending && Date() > dueDate
    }
    
    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
    }
    
    var isDueToday: Bool {
        Calendar.current.isDate(dueDate, inSameDayAs: Date())
    }
    
    var isDueTomorrow: Bool {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return Calendar.current.isDate(dueDate, inSameDayAs: tomorrow)
    }
    
    var priorityScore: Double {
        // Higher score = higher priority
        // Factors: weight, days until due, course importance
        let weightFactor = weight * 100 // 0-100
        let urgencyFactor = max(0, 14 - Double(daysUntilDue)) * 5 // More urgent = higher score
        let statusPenalty = status == .pending ? 0.0 : -50.0 // Completed items get penalty
        
        return weightFactor + urgencyFactor + statusPenalty
    }
    
    var completionPercentage: Double {
        guard !subtasks.isEmpty else { return status == .completed ? 1.0 : 0.0 }
        let completedSubtasks = subtasks.filter { $0.isCompleted }.count
        return Double(completedSubtasks) / Double(subtasks.count)
    }
    
    var estimatedTimeRemaining: Double? {
        guard let estimated = estimatedHours else { return nil }
        let completed = completionPercentage
        return estimated * (1.0 - completed)
    }
    
    var formattedDueDate: String {
        let formatter = DateFormatter()
        
        if isDueToday {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if isDueTomorrow {
            formatter.dateFormat = "'Tomorrow at' h:mm a"
        } else if daysUntilDue <= 7 {
            formatter.dateFormat = "EEEE 'at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
        }
        
        return formatter.string(from: dueDate)
    }
    
    var urgencyLevel: UrgencyLevel {
        if isOverdue { return .critical }
        if isDueToday || isDueTomorrow { return .high }
        if daysUntilDue <= 3 { return .moderate }
        return .low
    }
    
    // MARK: - Equatable Conformance
    static func == (lhs: Assignment, rhs: Assignment) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Supporting Enums and Models

enum AssignmentStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case overdue = "overdue"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .overdue: return "Overdue"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "#FFA726"
        case .inProgress: return "#42A5F5"
        case .completed: return "#66BB6A"
        case .overdue: return "#EF5350"
        case .cancelled: return "#78909C"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .inProgress: return "play.circle"
        case .completed: return "checkmark.circle.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
}



// UrgencyLevel enum is defined in AcademicModels.swift to avoid duplication

struct AssignmentAttachment: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let name: String
    let url: String
    let type: AttachmentType
    let size: Int64? // in bytes
    let uploadedAt: Date
    
    init(
        id: String = UUID().uuidString,
        name: String,
        url: String,
        type: AttachmentType,
        size: Int64? = nil,
        uploadedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.type = type
        self.size = size
        self.uploadedAt = uploadedAt
    }
    
    // MARK: - Equatable Conformance
    static func == (lhs: AssignmentAttachment, rhs: AssignmentAttachment) -> Bool {
        return lhs.id == rhs.id
    }
}

enum AttachmentType: String, Codable, CaseIterable {
    case pdf = "pdf"
    case doc = "doc"
    case image = "image"
    case url = "url"
    case other = "other"
    
    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .doc: return "doc.text"
        case .image: return "photo"
        case .url: return "link"
        case .other: return "paperclip"
        }
    }
}

struct Subtask: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let description: String?
    let isCompleted: Bool
    let estimatedHours: Double?
    let completedAt: Date?
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        isCompleted: Bool = false,
        estimatedHours: Double? = nil,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.estimatedHours = estimatedHours
        self.completedAt = completedAt
        self.createdAt = createdAt
    }
    
    // MARK: - Equatable Conformance
    static func == (lhs: Subtask, rhs: Subtask) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Assignment Extensions

extension Assignment {
    /// Create an assignment from an AcademicEvent
    static func from(academicEvent: AcademicEvent) -> Assignment {
        // Determine priority based on weight and due date
        let priority: Priority
        if academicEvent.weight >= 0.3 {
            priority = .high
        } else if academicEvent.weight >= 0.15 {
            priority = .medium
        } else {
            priority = .low
        }
        
        return Assignment(
            id: academicEvent.id,
            title: academicEvent.title,
            description: academicEvent.description,
            courseId: academicEvent.courseId,
            courseName: academicEvent.courseName,
            dueDate: academicEvent.dueDate,
            weight: academicEvent.weight,
            estimatedHours: academicEvent.estimatedHours,
            actualHours: academicEvent.actualHours,
            priority: priority,
            status: AssignmentStatus(rawValue: academicEvent.status.rawValue) ?? .pending,
            createdAt: academicEvent.createdAt,
            updatedAt: academicEvent.updatedAt
        )
    }
    
    /// Convert to AcademicEvent for analytics
    func toAcademicEvent() -> AcademicEvent {
        return AcademicEvent(
            id: id,
            title: title,
            description: description,
            courseId: courseId,
            courseName: courseName,
            type: .assignment,
            dueDate: dueDate,
            weight: weight,
            status: AcademicEventStatus(rawValue: status.rawValue) ?? .pending,
            estimatedHours: estimatedHours,
            actualHours: actualHours,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
