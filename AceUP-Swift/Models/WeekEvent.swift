//
//  WeekEvent.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/12/25.
//

import Foundation
import SwiftUI

// MARK: - Week Event Models

/// Unified event model representing any time-based activity in the week view
struct WeekEvent: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let description: String?
    let startDate: Date
    let endDate: Date
    let type: WeekEventType
    let color: String
    let location: String?
    let courseId: String?
    let courseName: String?
    let isAllDay: Bool
    let priority: Priority
    let status: EventStatus
    let tags: [String]
    let metadata: [String: String]
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        startDate: Date,
        endDate: Date,
        type: WeekEventType = .other,
        color: String = "#122C4A",
        location: String? = nil,
        courseId: String? = nil,
        courseName: String? = nil,
        isAllDay: Bool = false,
        priority: Priority = .medium,
        status: EventStatus = .active,
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.type = type
        self.color = color
        self.location = location
        self.courseId = courseId
        self.courseName = courseName
        self.isAllDay = isAllDay
        self.priority = priority
        self.status = status
        self.tags = tags
        self.metadata = metadata
    }
    
    // MARK: - Computed Properties
    
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    var durationInMinutes: Int {
        Int(duration / 60)
    }
    
    var startTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }
    
    var endTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: endDate)
    }
    
    var timeRangeString: String {
        "\(startTimeString) - \(endTimeString)"
    }
    
    var uiColor: Color {
        Color(hex: color)
    }
    
    var isOverlapping: Bool {
        metadata["isOverlapping"] == "true"
    }
    
    var conflictCount: Int {
        Int(metadata["conflictCount"] ?? "0") ?? 0
    }
}

// MARK: - Event Type

enum WeekEventType: String, Codable, CaseIterable {
    case classSession = "class_session"
    case assignment = "assignment"
    case exam = "exam"
    case meeting = "meeting"
    case study = "study"
    case holiday = "holiday"
    case personal = "personal"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .classSession: return "Class"
        case .assignment: return "Assignment"
        case .exam: return "Exam"
        case .meeting: return "Meeting"
        case .study: return "Study Session"
        case .holiday: return "Holiday"
        case .personal: return "Personal"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .classSession: return "book.fill"
        case .assignment: return "doc.text.fill"
        case .exam: return "pencil.and.outline"
        case .meeting: return "person.3.fill"
        case .study: return "brain.head.profile"
        case .holiday: return "calendar.badge.exclamationmark"
        case .personal: return "person.fill"
        case .other: return "circle.fill"
        }
    }
    
    var defaultColor: String {
        switch self {
        case .classSession: return "#4A90E2"
        case .assignment: return "#F5A623"
        case .exam: return "#E74C3C"
        case .meeting: return "#50E3C2"
        case .study: return "#9B59B6"
        case .holiday: return "#E67E22"
        case .personal: return "#1ABC9C"
        case .other: return "#95A5A6"
        }
    }
}

// MARK: - Event Status

enum EventStatus: String, Codable {
    case active
    case completed
    case cancelled
    case pending
}

// MARK: - Week Event Filter

struct WeekEventFilter: Equatable {
    var eventTypes: Set<WeekEventType>
    var courseIds: Set<String>
    var statuses: Set<EventStatus>
    var showOverlapping: Bool
    var showFreeTime: Bool
    var searchQuery: String
    
    static var `default`: WeekEventFilter {
        WeekEventFilter(
            eventTypes: Set(WeekEventType.allCases),
            courseIds: [],
            statuses: [.active, .pending],
            showOverlapping: true,
            showFreeTime: false,
            searchQuery: ""
        )
    }
    
    func matches(_ event: WeekEvent) -> Bool {
        // Type filter
        guard eventTypes.contains(event.type) else { return false }
        
        // Course filter
        if !courseIds.isEmpty {
            guard let courseId = event.courseId, courseIds.contains(courseId) else {
                return false
            }
        }
        
        // Status filter
        guard statuses.contains(event.status) else { return false }
        
        // Search query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            let titleMatch = event.title.lowercased().contains(query)
            let descMatch = event.description?.lowercased().contains(query) ?? false
            let courseMatch = event.courseName?.lowercased().contains(query) ?? false
            guard titleMatch || descMatch || courseMatch else { return false }
        }
        
        return true
    }
}

// MARK: - Time Slot

struct TimeSlot: Identifiable, Hashable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    var events: [WeekEvent]
    
    var isFree: Bool {
        events.isEmpty
    }
    
    var hasConflict: Bool {
        events.count > 1
    }
    
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

// MARK: - Day Schedule

struct DaySchedule: Identifiable {
    let id = UUID()
    let date: Date
    var events: [WeekEvent]
    var freeSlots: [TimeSlot]
    var busySlots: [TimeSlot]
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    var shortDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var totalBusyMinutes: Int {
        events.reduce(0) { $0 + $1.durationInMinutes }
    }
    
    var totalFreeMinutes: Int {
        freeSlots.reduce(0) { $0 + Int($1.duration / 60) }
    }
}

// MARK: - Week Summary

struct WeekSummary {
    let weekStart: Date
    let weekEnd: Date
    let totalEvents: Int
    let eventsByType: [WeekEventType: Int]
    let totalBusyHours: Double
    let totalFreeHours: Double
    let upcomingDeadlines: Int
    let conflictingSlots: Int
    let mostBusyDay: Date?
    let leastBusyDay: Date?
    
    var weekRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: weekStart)
        let end = formatter.string(from: weekEnd)
        return "\(start) - \(end)"
    }
}

// MARK: - Conversion Extensions

extension WeekEvent {
    /// Create WeekEvent from Assignment
    static func from(assignment: Assignment) -> WeekEvent {
        WeekEvent(
            id: "assignment_\(assignment.id)",
            title: assignment.title,
            description: assignment.description,
            startDate: assignment.dueDate.addingTimeInterval(-3600), // 1 hour before due
            endDate: assignment.dueDate,
            type: .assignment,
            color: assignment.courseColor,
            courseId: assignment.courseId,
            courseName: assignment.courseName,
            priority: assignment.priority,
            status: assignment.status == .completed ? .completed : .active,
            tags: assignment.tags,
            metadata: [
                "weight": String(assignment.weight),
                "assignmentId": assignment.id
            ]
        )
    }
    
    /// Create WeekEvent from ScheduleSession
    static func from(session: ScheduleSession, on date: Date) -> WeekEvent? {
        guard let startStr = session.start,
              let endStr = session.end,
              let startTime = parseTime(startStr, on: date),
              let endTime = parseTime(endStr, on: date) else {
            return nil
        }
        
        return WeekEvent(
            id: "session_\(date.timeIntervalSince1970)_\(session.course)",
            title: session.course,
            description: session.notes,
            startDate: startTime,
            endDate: endTime,
            type: .classSession,
            color: "#4A90E2",
            location: session.location,
            courseName: session.course,
            metadata: [
                "sessionCourse": session.course
            ]
        )
    }
    
    /// Create WeekEvent from Holiday
    static func from(holiday: Holiday) -> WeekEvent {
        WeekEvent(
            id: "holiday_\(holiday.id)",
            title: holiday.name,
            description: holiday.localName,
            startDate: holiday.dateValue,
            endDate: holiday.dateValue.addingTimeInterval(86400), // Full day
            type: .holiday,
            color: "#E67E22",
            isAllDay: true,
            priority: .low,
            status: .active,
            metadata: [
                "country": holiday.countryCode,
                "isGlobal": String(holiday.global ?? false),
                "originalDate": holiday.date
            ]
        )
    }
    
    private static func parseTime(_ timeString: String, on date: Date) -> Date? {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }
        
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = components[0]
        dateComponents.minute = components[1]
        
        return calendar.date(from: dateComponents)
    }
}
