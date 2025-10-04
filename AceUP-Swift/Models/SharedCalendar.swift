//
//  SharedCalendar.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25
//

import Foundation

// MARK: - Calendar Group Models
struct CalendarGroup: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let members: [GroupMember]
    let createdAt: Date
    let createdBy: String
    let color: String
    let isPublic: Bool
    let inviteCode: String? 
    
    var memberCount: Int {
        members.count
    }
    
    var qrCodeURL: String? {
        guard let code = inviteCode else { return nil }
        return "aceup://join/\(code)"
    }
}

struct GroupMember: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let email: String
    let avatar: String?
    let isAdmin: Bool
    let joinedAt: Date
    let availability: [AvailabilitySlot]
}

// MARK: - Availability Models
struct AvailabilitySlot: Codable, Identifiable, Hashable {
    let id: String
    let dayOfWeek: Int // 0 = Sunday, 1 = Monday, etc.
    let startTime: TimeOfDay
    let endTime: TimeOfDay
    let title: String?
    let type: AvailabilityType
    let priority: Priority
}

struct TimeOfDay: Codable, Hashable, Comparable {
    let hour: Int
    let minute: Int
    
    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }
    
    var minutesFromMidnight: Int {
        hour * 60 + minute
    }
    
    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesFromMidnight < rhs.minutesFromMidnight
    }
}

enum AvailabilityType: String, Codable, CaseIterable {
    case free = "free"
    case busy = "busy"
    case tentative = "tentative"
    case lecture = "lecture"
    case exam = "exam"
    case assignment = "assignment"
    case meeting = "meeting"
    case personal = "personal"
    
    var color: String {
        switch self {
        case .free: return "#50E3C2"
        case .busy: return "#FF6B6B"
        case .tentative: return "#FFE66D"
        case .lecture: return "#122C4A"
        case .exam: return "#FF4757"
        case .assignment: return "#5352ED"
        case .meeting: return "#2F80ED"
        case .personal: return "#27AE60"
        }
    }
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .busy: return "Busy"
        case .tentative: return "Tentative"
        case .lecture: return "Class"
        case .exam: return "Exam"
        case .assignment: return "Assignment"
        case .meeting: return "Meeting"
        case .personal: return "Personal"
        }
    }
}

enum Priority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var color: String {
        switch self {
        case .low: return "#95A5A6"
        case .medium: return "#F39C12"
        case .high: return "#E74C3C"
        case .urgent: return "#8E44AD"
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
}

// MARK: - Shared Schedule Models
struct SharedSchedule: Codable, Identifiable, Hashable {
    let id: String
    let groupId: String
    let date: Date
    let commonFreeSlots: [CommonFreeSlot]
    let conflictingSlots: [ConflictingSlot]
    let generatedAt: Date
    let smartSuggestions: [SmartSuggestion]
}

struct CommonFreeSlot: Codable, Identifiable, Hashable {
    let id: String
    let startTime: TimeOfDay
    let endTime: TimeOfDay
    let availableMembers: [String] // Member IDs
    let confidence: Double // 0.0 to 1.0
    let duration: Int // in minutes
}

struct ConflictingSlot: Codable, Identifiable, Hashable {
    let id: String
    let startTime: TimeOfDay
    let endTime: TimeOfDay
    let conflicts: [MemberConflict]
}

struct MemberConflict: Codable, Identifiable, Hashable {
    let id: String
    let memberId: String
    let memberName: String
    let conflictType: AvailabilityType
    let conflictTitle: String
    let canBeRescheduled: Bool
    let alternativeTimes: [TimeOfDay]
}

// MARK: - Smart Features Models
struct SmartSuggestion: Codable, Identifiable, Hashable {
    let id: String
    let type: SuggestionType
    let title: String
    let description: String
    let confidence: Double
    let actionRequired: Bool
    let suggestedTime: TimeOfDay?
    let affectedMembers: [String]
    let createdAt: Date
}

enum SuggestionType: String, Codable, CaseIterable {
    case optimalMeetingTime = "optimal_meeting_time"
    case studySession = "study_session"
    case deadlineReminder = "deadline_reminder"
    case scheduleConflict = "schedule_conflict"
    case groupAvailability = "group_availability"
    case workloadBalance = "workload_balance"
    case scheduleOptimization = "schedule_optimization"
    case conflictReduction = "conflict_reduction"
    
    var displayName: String {
        switch self {
        case .optimalMeetingTime: return "Optimal Meeting Time"
        case .studySession: return "Study Session"
        case .deadlineReminder: return "Deadline Reminder"
        case .scheduleConflict: return "Schedule Conflict"
        case .groupAvailability: return "Group Availability"
        case .workloadBalance: return "Workload Balance"
        case .scheduleOptimization: return "Schedule Optimization"
        case .conflictReduction: return "Conflict Reduction"
        }
    }
    
    var icon: String {
        switch self {
        case .optimalMeetingTime: return "clock.badge.checkmark"
        case .studySession: return "book.closed"
        case .deadlineReminder: return "bell.badge"
        case .scheduleConflict: return "exclamationmark.triangle"
        case .groupAvailability: return "person.3.sequence"
        case .workloadBalance: return "scale.3d"
        case .scheduleOptimization: return "gearshape.2"
        case .conflictReduction: return "checkmark.shield"
        }
    }
}

// MARK: - Calendar Event Models
struct CalendarEvent: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let startTime: Date
    let endTime: Date
    let type: AvailabilityType
    let priority: Priority
    let isShared: Bool
    let groupId: String?
    let createdBy: String
    let attendees: [String] // Member IDs
    let location: String?
    let isRecurring: Bool
    let recurrencePattern: RecurrencePattern?
    let reminderMinutes: [Int] // Minutes before event
}

struct RecurrencePattern: Codable, Hashable {
    let frequency: RecurrenceFrequency
    let interval: Int // Every X weeks/days
    let daysOfWeek: [Int]? // For weekly recurrence
    let endDate: Date?
    let occurrenceCount: Int?
}

enum RecurrenceFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}