//
//  WeekEventEntity+CoreData.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/12/25.
//

import Foundation
import CoreData

// MARK: - Core Data Entity Extension

extension NSManagedObjectContext {
    /// Fetch week events with optimized indexed queries
    func fetchWeekEvents(
        from startDate: Date,
        to endDate: Date,
        userId: String
    ) async throws -> [WeekEvent] {
        return try await perform {
            var allEvents: [WeekEvent] = []
            
            // Fetch assignments due in this week
            let assignmentRequest: NSFetchRequest<AssignmentEntity> = AssignmentEntity.fetchRequest()
            assignmentRequest.predicate = NSPredicate(
                format: "userId == %@ AND dueDate >= %@ AND dueDate <= %@",
                userId, startDate as NSDate, endDate as NSDate
            )
            assignmentRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \AssignmentEntity.dueDate, ascending: true)
            ]
            
            let assignments = try self.fetch(assignmentRequest)
            allEvents.append(contentsOf: assignments.map { WeekEvent.from(assignment: $0.toAssignment()) })
            
            return allEvents
        }
    }
    
    /// Fetch events grouped by day for the week
    func fetchWeekEventsByDay(
        from startDate: Date,
        to endDate: Date,
        userId: String
    ) async throws -> [Date: [WeekEvent]] {
        let events = try await fetchWeekEvents(from: startDate, to: endDate, userId: userId)
        
        var eventsByDay: [Date: [WeekEvent]] = [:]
        let calendar = Calendar.current
        
        for event in events {
            let dayStart = calendar.startOfDay(for: event.startDate)
            eventsByDay[dayStart, default: []].append(event)
        }
        
        return eventsByDay
    }
}

// MARK: - Week Event Entity (for caching)

@objc(WeekEventEntity)
public class WeekEventEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var title: String
    @NSManaged public var descriptionText: String?
    @NSManaged public var startDate: Date
    @NSManaged public var endDate: Date
    @NSManaged public var eventType: String
    @NSManaged public var color: String
    @NSManaged public var location: String?
    @NSManaged public var courseId: String?
    @NSManaged public var courseName: String?
    @NSManaged public var isAllDay: Bool
    @NSManaged public var priority: String
    @NSManaged public var status: String
    @NSManaged public var tags: String? // JSON encoded
    @NSManaged public var metadata: String? // JSON encoded
    @NSManaged public var userId: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    
    func toWeekEvent() -> WeekEvent {
        let tagsArray = (try? JSONDecoder().decode([String].self, from: tags?.data(using: .utf8) ?? Data())) ?? []
        let metadataDict = (try? JSONDecoder().decode([String: String].self, from: metadata?.data(using: .utf8) ?? Data())) ?? [:]
        
        return WeekEvent(
            id: id,
            title: title,
            description: descriptionText,
            startDate: startDate,
            endDate: endDate,
            type: WeekEventType(rawValue: eventType) ?? .other,
            color: color,
            location: location,
            courseId: courseId,
            courseName: courseName,
            isAllDay: isAllDay,
            priority: Priority(rawValue: priority) ?? .medium,
            status: EventStatus(rawValue: status) ?? .active,
            tags: tagsArray,
            metadata: metadataDict
        )
    }
    
    static func fromWeekEvent(_ event: WeekEvent, userId: String, in context: NSManagedObjectContext) -> WeekEventEntity {
        let entity = WeekEventEntity(context: context)
        entity.id = event.id
        entity.title = event.title
        entity.descriptionText = event.description
        entity.startDate = event.startDate
        entity.endDate = event.endDate
        entity.eventType = event.type.rawValue
        entity.color = event.color
        entity.location = event.location
        entity.courseId = event.courseId
        entity.courseName = event.courseName
        entity.isAllDay = event.isAllDay
        entity.priority = event.priority.rawValue
        entity.status = event.status.rawValue
        entity.tags = (try? JSONEncoder().encode(event.tags)).flatMap { String(data: $0, encoding: .utf8) }
        entity.metadata = (try? JSONEncoder().encode(event.metadata)).flatMap { String(data: $0, encoding: .utf8) }
        entity.userId = userId
        entity.createdAt = Date()
        entity.updatedAt = Date()
        return entity
    }
}

// MARK: - Indexed Fetch Extensions

extension PersistenceController {
    /// Optimized week event fetch with indexed queries
    func fetchWeekEvents(
        startDate: Date,
        endDate: Date,
        userId: String
    ) async -> [WeekEvent] {
        await performBackgroundTask { context in
            do {
                return try await context.fetchWeekEvents(from: startDate, to: endDate, userId: userId)
            } catch {
                print("❌ Error fetching week events: \(error)")
                return []
            }
        }
    }
    
    /// Fetch events with parallel queries for better performance
    func fetchWeekEventsParallel(
        startDate: Date,
        endDate: Date,
        userId: String,
        schedule: Schedule?,
        holidays: [Holiday]
    ) async -> [WeekEvent] {
        await withTaskGroup(of: [WeekEvent].self) { group in
            // Task 1: Fetch assignments
            group.addTask {
                await self.fetchWeekEvents(startDate: startDate, endDate: endDate, userId: userId)
            }
            
            // Task 2: Convert schedule sessions
            group.addTask {
                guard let schedule = schedule else { return [] }
                return self.generateScheduleEvents(from: schedule, startDate: startDate, endDate: endDate)
            }
            
            // Task 3: Convert holidays
            group.addTask {
                return holidays
                    .filter { $0.date >= startDate && $0.date <= endDate }
                    .map { WeekEvent.from(holiday: $0) }
            }
            
            // Collect all results
            var allEvents: [WeekEvent] = []
            for await events in group {
                allEvents.append(contentsOf: events)
            }
            return allEvents
        }
    }
    
    private func generateScheduleEvents(from schedule: Schedule, startDate: Date, endDate: Date) -> [WeekEvent] {
        var events: [WeekEvent] = []
        let calendar = Calendar.current
        
        var currentDate = startDate
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            if let scheduleWeekday = Weekday(systemWeekday: weekday) {
                let day = schedule.days.first { $0.weekday == scheduleWeekday }
                if let sessions = day?.sessions {
                    for session in sessions {
                        if let event = WeekEvent.from(session: session, on: currentDate) {
                            events.append(event)
                        }
                    }
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return events
    }
}

// MARK: - Helper Extensions

extension Weekday {
    init?(systemWeekday: Int) {
        switch systemWeekday {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
}
