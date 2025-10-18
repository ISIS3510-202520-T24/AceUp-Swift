//
//  AcademicModels.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 4/10/25.
//

import Foundation

// MARK: - Academic Event Models
struct AcademicEvent: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let courseId: String
    let courseName: String
    let type: EventType
    let dueDate: Date
    let weight: Double // Percentage of final grade (0.0 - 1.0)
    let status: EventStatus
    let priority: Priority
    let estimatedHours: Double?
    let actualHours: Double?
    let createdAt: Date
    let updatedAt: Date
    
    var weightPercentage: Int {
        Int(weight * 100)
    }
    
    var isOverdue: Bool {
        status == .pending && Date() > dueDate
    }
    
    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
    }
    
    var priorityScore: Double {
        // Higher score = higher priority
        // Factors: weight, days until due, course importance
        let weightFactor = weight * 100 // 0-100
        let urgencyFactor = max(0, 14 - Double(daysUntilDue)) * 5 // More urgent = higher score
        let statusPenalty = status == .pending ? 0.0 : -50.0 // Completed items get penalty
        
        return weightFactor + urgencyFactor + statusPenalty
    }
}

enum EventType: String, Codable, CaseIterable {
    case assignment = "assignment"
    case exam = "exam"
    case project = "project"
    case quiz = "quiz"
    case presentation = "presentation"
    case lab = "lab"
    case homework = "homework"
    
    var displayName: String {
        switch self {
        case .assignment: return "Assignment"
        case .exam: return "Exam"
        case .project: return "Project"
        case .quiz: return "Quiz"
        case .presentation: return "Presentation"
        case .lab: return "Lab"
        case .homework: return "Homework"
        }
    }
    
    
    var icon: String {
        switch self {
        case .assignment: return "doc.text"
        case .exam: return "graduationcap"
        case .project: return "folder"
        case .quiz: return "questionmark.circle"
        case .presentation: return "person.3"
        case .lab: return "flask"
        case .homework: return "pencil"
        }
    }
}

enum EventStatus: String, Codable, CaseIterable {
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
        case .pending: return "#FFE66D"
        case .inProgress: return "#5352ED"
        case .completed: return "#4ECDC4"
        case .overdue: return "#FF6B6B"
        case .cancelled: return "#8B8680"
        }
    }
}

enum Priority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#4ECDC4"
        case .medium: return "#FFE66D"
        case .high: return "#FF6B6B"
        case .critical: return "#FF4757"
        }
    }
    
    var numericValue: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

// MARK: - Course Models
struct Course: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let code: String
    let credits: Int
    let instructor: String
    let color: String
    let semester: String
    let year: Int
    let gradeWeight: GradeWeight
    let currentGrade: Double?
    let targetGrade: Double?
    let createdAt: Date
    let updatedAt: Date
    
    var isActive: Bool {
        // Consider course active if it's current semester/year
        let now = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        return year >= currentYear
    }
}

struct GradeWeight: Codable, Hashable {
    let assignments: Double
    let exams: Double
    let projects: Double
    let participation: Double
    let other: Double
    
    var total: Double {
        assignments + exams + projects + participation + other
    }
    
    var isValid: Bool {
        abs(total - 1.0) < 0.001 // Allow for small floating point errors
    }
}

// MARK: - Analytics Data Models
struct StudentAnalyticsData: Codable {
    let userId: String
    let courses: [Course]
    let events: [AcademicEvent]
    let lastUpdated: Date
    
    var pendingEvents: [AcademicEvent] {
        events.filter { $0.status == .pending }
    }
    
    var highestWeightPendingEvent: AcademicEvent? {
        pendingEvents.max { $0.priorityScore < $1.priorityScore }
    }
    
    var overdueEvents: [AcademicEvent] {
        events.filter { $0.isOverdue }
    }
    
    var upcomingEvents: [AcademicEvent] {
        let upcoming = events.filter { 
            $0.status == .pending && $0.daysUntilDue <= 7 && $0.daysUntilDue >= 0
        }
        return upcoming.sorted { $0.dueDate < $1.dueDate }
    }
}

// MARK: - Analytics Response Models
struct HighestWeightEventResponse: Codable {
    let success: Bool
    let message: String
    let data: HighestWeightEventData?
    let timestamp: Date
    let userId: String
}

struct HighestWeightEventData: Codable {
    let event: AcademicEvent?
    let analysis: EventAnalysis
    let recommendations: [String]
}

struct EventAnalysis: Codable, Equatable {
    let totalPendingEvents: Int
    let averageWeight: Double
    let daysToDue: Int
    let urgencyLevel: UrgencyLevel
    let impactScore: Double
    let courseLoad: String
    
    static func == (lhs: EventAnalysis, rhs: EventAnalysis) -> Bool {
        return lhs.totalPendingEvents == rhs.totalPendingEvents &&
               lhs.averageWeight == rhs.averageWeight &&
               lhs.daysToDue == rhs.daysToDue &&
               lhs.urgencyLevel == rhs.urgencyLevel &&
               lhs.impactScore == rhs.impactScore &&
               lhs.courseLoad == rhs.courseLoad
    }
}

enum UrgencyLevel: String, Codable, CaseIterable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low Urgency"
        case .moderate: return "Moderate Urgency"
        case .high: return "High Urgency"
        case .critical: return "Critical Urgency"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#4ECDC4"
        case .moderate: return "#FFE66D"
        case .high: return "#FF6B6B"
        case .critical: return "#FF4757"
        }
    }
}
