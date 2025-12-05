//
//  PlannerTask.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/12/25.
//

import Foundation

// MARK: - Planner Task Model
/// Represents a task in the academic planner with scheduling and tracking capabilities
struct PlannerTask: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let description: String?
    let courseId: String?
    let courseName: String?
    let courseColor: String?
    let scheduledDate: Date
    let scheduledTime: Date?
    let estimatedDuration: TimeInterval? // in seconds
    let actualDuration: TimeInterval?
    let priority: Priority
    let status: PlannerTaskStatus
    let category: PlannerTaskCategory
    let tags: [String]
    let isRecurring: Bool
    let recurrenceRule: RecurrenceRule?
    let relatedAssignmentId: String?
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        courseId: String? = nil,
        courseName: String? = nil,
        courseColor: String? = nil,
        scheduledDate: Date,
        scheduledTime: Date? = nil,
        estimatedDuration: TimeInterval? = nil,
        actualDuration: TimeInterval? = nil,
        priority: Priority = .medium,
        status: PlannerTaskStatus = .planned,
        category: PlannerTaskCategory = .study,
        tags: [String] = [],
        isRecurring: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        relatedAssignmentId: String? = nil,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.courseId = courseId
        self.courseName = courseName
        self.courseColor = courseColor
        self.scheduledDate = scheduledDate
        self.scheduledTime = scheduledTime
        self.estimatedDuration = estimatedDuration
        self.actualDuration = actualDuration
        self.priority = priority
        self.status = status
        self.category = category
        self.tags = tags
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.relatedAssignmentId = relatedAssignmentId
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Computed Properties
    
    var isScheduledToday: Bool {
        Calendar.current.isDateInToday(scheduledDate)
    }
    
    var isScheduledTomorrow: Bool {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else {
            return false
        }
        return Calendar.current.isDate(scheduledDate, inSameDayAs: tomorrow)
    }
    
    var isOverdue: Bool {
        status == .planned && Date() > scheduledDate
    }
    
    var formattedDuration: String {
        guard let duration = estimatedDuration else { return "No estimate" }
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    var displayColor: String {
        courseColor ?? category.defaultColor
    }
}

// MARK: - Planner Task Status
enum PlannerTaskStatus: String, Codable, CaseIterable {
    case planned = "planned"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    case postponed = "postponed"
    
    var displayName: String {
        switch self {
        case .planned: return "Planned"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .postponed: return "Postponed"
        }
    }
    
    var icon: String {
        switch self {
        case .planned: return "calendar"
        case .inProgress: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        case .postponed: return "clock.arrow.circlepath"
        }
    }
    
    var color: String {
        switch self {
        case .planned: return "#42A5F5"
        case .inProgress: return "#FFA726"
        case .completed: return "#66BB6A"
        case .cancelled: return "#78909C"
        case .postponed: return "#AB47BC"
        }
    }
}

// MARK: - Planner Task Category
enum PlannerTaskCategory: String, Codable, CaseIterable {
    case study = "study"
    case assignment = "assignment"
    case exam = "exam"
    case reading = "reading"
    case groupWork = "group_work"
    case office = "office_hours"
    case review = "review"
    case project = "project"
    case personal = "personal"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .study: return "Study Session"
        case .assignment: return "Assignment Work"
        case .exam: return "Exam Prep"
        case .reading: return "Reading"
        case .groupWork: return "Group Work"
        case .office: return "Office Hours"
        case .review: return "Review"
        case .project: return "Project Work"
        case .personal: return "Personal"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .study: return "book.fill"
        case .assignment: return "doc.text.fill"
        case .exam: return "graduationcap.fill"
        case .reading: return "book.pages.fill"
        case .groupWork: return "person.2.fill"
        case .office: return "person.crop.square.fill"
        case .review: return "arrow.counterclockwise"
        case .project: return "folder.fill"
        case .personal: return "star.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var defaultColor: String {
        switch self {
        case .study: return "#42A5F5"
        case .assignment: return "#FFA726"
        case .exam: return "#EF5350"
        case .reading: return "#66BB6A"
        case .groupWork: return "#AB47BC"
        case .office: return "#26C6DA"
        case .review: return "#FFCA28"
        case .project: return "#EC407A"
        case .personal: return "#78909C"
        case .other: return "#122C4A"
        }
    }
}

// MARK: - Recurrence Rule
struct RecurrenceRule: Codable, Hashable, Equatable {
    let frequency: RecurrenceFrequency
    let interval: Int // e.g., every 2 weeks
    let daysOfWeek: [Int]? // 1 = Sunday, 2 = Monday, etc.
    let endDate: Date?
    let occurrences: Int? // Number of times to repeat
    
    init(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        daysOfWeek: [Int]? = nil,
        endDate: Date? = nil,
        occurrences: Int? = nil
    ) {
        self.frequency = frequency
        self.interval = interval
        self.daysOfWeek = daysOfWeek
        self.endDate = endDate
        self.occurrences = occurrences
    }
}

// MARK: - Planner Statistics
struct PlannerStatistics: Codable {
    let totalTasks: Int
    let completedTasks: Int
    let plannedTasks: Int
    let inProgressTasks: Int
    let totalPlannedHours: Double
    let totalActualHours: Double
    let completionRate: Double
    let averageTaskDuration: Double
    let tasksThisWeek: Int
    let tasksToday: Int
    
    var completionPercentage: Int {
        guard totalTasks > 0 else { return 0 }
        return Int((Double(completedTasks) / Double(totalTasks)) * 100)
    }
}
