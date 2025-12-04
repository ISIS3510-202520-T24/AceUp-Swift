//
//  WeekViewModel.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/12/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import CoreData

/// Week View ViewModel with multi-threaded data fetching and processing
@MainActor
class WeekViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentWeekStart: Date = Date().startOfWeek()
    @Published var selectedDate: Date = Date()
    @Published var events: [WeekEvent] = []
    @Published var daySchedules: [DaySchedule] = []
    @Published var weekSummary: WeekSummary?
    @Published var filter: WeekEventFilter = .default
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedEvent: WeekEvent?
    @Published var showEventDetail = false
    
    // MARK: - Dependencies
    
    private let persistenceController: PersistenceController
    private let scheduleStore = ScheduleLocalStore.shared
    private let offlineManager = OfflineManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? "anonymous"
    }
    
    // MARK: - Initialization
    
    init(persistenceController: PersistenceController? = nil) {
        self.persistenceController = persistenceController ?? PersistenceController.shared
        Task { @MainActor in
            self.setupObservers()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load week data with multi-threaded fetching
    func loadWeek() async {
        isLoading = true
        errorMessage = nil
        
        let weekStart = currentWeekStart
        let weekEnd = weekStart.endOfWeek()
        
        // Multi-threaded data fetching using nested task groups
        let fetchedEvents = await fetchAllEventsParallel(
            startDate: weekStart,
            endDate: weekEnd
        )
        
        // Process events on background thread
        let processedData = await processEventsInBackground(
            events: fetchedEvents,
            weekStart: weekStart,
            weekEnd: weekEnd
        )
        
        // Update UI on main thread
        self.events = processedData.events
        self.daySchedules = processedData.daySchedules
        self.weekSummary = processedData.summary
        
        isLoading = false
    }
    
    /// Navigate to next week
    func nextWeek() {
        currentWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? currentWeekStart
        selectedDate = currentWeekStart
        Task {
            await loadWeek()
        }
    }
    
    /// Navigate to previous week
    func previousWeek() {
        currentWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) ?? currentWeekStart
        selectedDate = currentWeekStart
        Task {
            await loadWeek()
        }
    }
    
    /// Go to today's week
    func goToToday() {
        currentWeekStart = Date().startOfWeek()
        selectedDate = Date()
        Task {
            await loadWeek()
        }
    }
    
    /// Select a specific date
    func selectDate(_ date: Date) {
        selectedDate = date
        
        // If date is outside current week, navigate to that week
        let weekEnd = currentWeekStart.endOfWeek()
        if date < currentWeekStart || date > weekEnd {
            currentWeekStart = date.startOfWeek()
            Task {
                await loadWeek()
            }
        }
    }
    
    /// Update filter and reload
    func updateFilter(_ newFilter: WeekEventFilter) {
        filter = newFilter
        applyFilter()
    }
    
    /// Select an event for detail view
    func selectEvent(_ event: WeekEvent) {
        selectedEvent = event
        showEventDetail = true
    }
    
    /// Reschedule event (drag-to-reschedule support)
    func rescheduleEvent(_ event: WeekEvent, to newStartDate: Date) async {
        // TODO: Implement event rescheduling
        // Calculate new end date based on original duration
        // let duration = event.endDate.timeIntervalSince(event.startDate)
        // let newEndDate = newStartDate.addingTimeInterval(duration)
        
        // TODO: Create updated event and persist the change to backend/database
        
        // Reload week to reflect changes
        await loadWeek()
    }
    
    // MARK: - Private Methods - Multi-threaded Fetching
    
    /// Fetch all events in parallel using nested task groups
    private func fetchAllEventsParallel(startDate: Date, endDate: Date) async -> [WeekEvent] {
        await withTaskGroup(of: [WeekEvent].self) { outerGroup in
            // Task 1: Fetch database events (assignments, exams)
            outerGroup.addTask { [weak self] in
                guard let self = self else { return [] }
                return await self.fetchDatabaseEvents(startDate: startDate, endDate: endDate)
            }
            
            // Task 2: Fetch schedule-based events
            outerGroup.addTask { [weak self] in
                guard let self = self else { return [] }
                return await self.fetchScheduleEvents(startDate: startDate, endDate: endDate)
            }
            
            // Task 3: Fetch holidays
            outerGroup.addTask { [weak self] in
                guard let self = self else { return [] }
                return await self.fetchHolidayEvents(startDate: startDate, endDate: endDate)
            }
            
            // Task 4: Fetch external calendar events (if available)
            outerGroup.addTask { [weak self] in
                guard let self = self else { return [] }
                return await self.fetchExternalCalendarEvents(startDate: startDate, endDate: endDate)
            }
            
            // Collect all results
            var allEvents: [WeekEvent] = []
            for await events in outerGroup {
                allEvents.append(contentsOf: events)
            }
            
            return allEvents
        }
    }
    
    /// Fetch assignments and exams from database
    private func fetchDatabaseEvents(startDate: Date, endDate: Date) async -> [WeekEvent] {
        await withTaskGroup(of: [WeekEvent].self) { group in
            // Nested task: Fetch assignments
            group.addTask { [weak self] in
                guard let self = self else { return [] }
                return await self.fetchAssignments(startDate: startDate, endDate: endDate)
            }
            
            // Nested task: Fetch exams (if you have exam entities)
            group.addTask { [weak self] in
                guard let self = self else { return [] }
                return await self.fetchExams(startDate: startDate, endDate: endDate)
            }
            
            var events: [WeekEvent] = []
            for await result in group {
                events.append(contentsOf: result)
            }
            return events
        }
    }
    
    /// Fetch assignments from Core Data
    private func fetchAssignments(startDate: Date, endDate: Date) async -> [WeekEvent] {
        return await persistenceController.performBackgroundTask { context in
            let request = NSFetchRequest<AssignmentEntity>(entityName: "AssignmentEntity")
            request.predicate = NSPredicate(
                format: "userId == %@ AND dueDate >= %@ AND dueDate <= %@",
                self.currentUserId, startDate as NSDate, endDate as NSDate
            )
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \AssignmentEntity.dueDate, ascending: true)
            ]
            
            do {
                let assignments = try context.fetch(request)
                return assignments.map { WeekEvent.from(assignment: $0.toAssignment()) }
            } catch {
                print("❌ Error fetching assignments: \(error)")
                return []
            }
        }
    }
    
    /// Fetch exams (placeholder - implement if you have exam entities)
    private func fetchExams(startDate: Date, endDate: Date) async -> [WeekEvent] {
        // TODO: Implement if you have separate exam entities
        return []
    }
    
    /// Fetch schedule-based events (classes)
    private func fetchScheduleEvents(startDate: Date, endDate: Date) async -> [WeekEvent] {
        return await Task.detached(priority: .userInitiated) { [scheduleStore] in
            guard let schedule = try? await scheduleStore.load() else {
                return []
            }
            
            var events: [WeekEvent] = []
            let calendar = Calendar.current
            var currentDate = startDate
            
            while currentDate <= endDate {
                let weekday = calendar.component(.weekday, from: currentDate)
                
                // Map system weekday (1=Sunday) to Weekday enum
                let weekdayMapping: [Int: Weekday] = [
                    1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday,
                    5: .thursday, 6: .friday, 7: .saturday
                ]
                
                if let scheduleWeekday = weekdayMapping[weekday] {
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
        }.value
    }
    
    /// Fetch holiday events
    private func fetchHolidayEvents(startDate: Date, endDate: Date) async -> [WeekEvent] {
        return await persistenceController.performBackgroundTask { context in
            let request = NSFetchRequest<HolidayEntity>(entityName: "HolidayEntity")
            request.predicate = NSPredicate(
                format: "date >= %@ AND date <= %@",
                startDate as NSDate, endDate as NSDate
            )
            
            do {
                let holidays = try context.fetch(request)
                return holidays.compactMap { holidayEntity -> WeekEvent? in
                    guard holidayEntity.date != nil else { return nil }
                    let holiday = Holiday(
                        date: holidayEntity.id ?? UUID().uuidString,
                        localName: holidayEntity.name ?? "Holiday",
                        name: holidayEntity.name ?? "Holiday",
                        countryCode: holidayEntity.country ?? "",
                        fixed: true,
                        global: holidayEntity.isNational,
                        counties: nil,
                        launchYear: nil,
                        types: [holidayEntity.type ?? ""]
                    )
                    return WeekEvent.from(holiday: holiday)
                }
            } catch {
                print("❌ Error fetching holidays: \(error)")
                return []
            }
        }
    }
    
    /// Fetch external calendar events (placeholder)
    private func fetchExternalCalendarEvents(startDate: Date, endDate: Date) async -> [WeekEvent] {
        // TODO: Implement external calendar integration
        return []
    }
    
    // MARK: - Background Processing
    
    /// Process events in background thread
    private func processEventsInBackground(
        events: [WeekEvent],
        weekStart: Date,
        weekEnd: Date
    ) async -> (events: [WeekEvent], daySchedules: [DaySchedule], summary: WeekSummary) {
        return await Task.detached(priority: .userInitiated) {
            // Nested multi-threading for different processing tasks
            await withTaskGroup(of: ProcessingResult.self) { group in
                // Task 1: Detect conflicts
                group.addTask {
                    let eventsWithConflicts = self.detectConflicts(events: events)
                    return .events(eventsWithConflicts)
                }
                
                // Task 2: Generate day schedules
                group.addTask {
                    let schedules = self.generateDaySchedules(
                        events: events,
                        weekStart: weekStart,
                        weekEnd: weekEnd
                    )
                    return .schedules(schedules)
                }
                
                // Task 3: Calculate summary
                group.addTask {
                    let summary = self.calculateWeekSummary(
                        events: events,
                        weekStart: weekStart,
                        weekEnd: weekEnd
                    )
                    return .summary(summary)
                }
                
                // Collect results
                var processedEvents: [WeekEvent] = events
                var daySchedules: [DaySchedule] = []
                var summary: WeekSummary?
                
                for await result in group {
                    switch result {
                    case .events(let e):
                        processedEvents = e
                    case .schedules(let s):
                        daySchedules = s
                    case .summary(let sum):
                        summary = sum
                    }
                }
                
                return (
                    events: processedEvents,
                    daySchedules: daySchedules,
                    summary: summary ?? WeekSummary(
                        weekStart: weekStart,
                        weekEnd: weekEnd,
                        totalEvents: 0,
                        eventsByType: [:],
                        totalBusyHours: 0,
                        totalFreeHours: 0,
                        upcomingDeadlines: 0,
                        conflictingSlots: 0,
                        mostBusyDay: nil,
                        leastBusyDay: nil
                    )
                )
            }
        }.value
    }
    
    /// Detect overlapping events and mark conflicts
    nonisolated private func detectConflicts(events: [WeekEvent]) -> [WeekEvent] {
        var processedEvents: [WeekEvent] = []
        
        for event in events {
            var conflictCount = 0
            
            // Check for overlaps
            for otherEvent in events where event.id != otherEvent.id {
                if eventsOverlap(event, otherEvent) {
                    conflictCount += 1
                }
            }
            
            var metadata = event.metadata
            metadata["conflictCount"] = String(conflictCount)
            metadata["isOverlapping"] = conflictCount > 0 ? "true" : "false"
            
            let updatedEvent = WeekEvent(
                id: event.id,
                title: event.title,
                description: event.description,
                startDate: event.startDate,
                endDate: event.endDate,
                type: event.type,
                color: event.color,
                location: event.location,
                courseId: event.courseId,
                courseName: event.courseName,
                isAllDay: event.isAllDay,
                priority: event.priority,
                status: event.status,
                tags: event.tags,
                metadata: metadata
            )
            
            processedEvents.append(updatedEvent)
        }
        
        return processedEvents
    }
    
    nonisolated private func eventsOverlap(_ event1: WeekEvent, _ event2: WeekEvent) -> Bool {
        return event1.startDate < event2.endDate && event2.startDate < event1.endDate
    }
    
    /// Generate day schedules with free/busy slots
    nonisolated private func generateDaySchedules(
        events: [WeekEvent],
        weekStart: Date,
        weekEnd: Date
    ) -> [DaySchedule] {
        let calendar = Calendar.current
        var schedules: [DaySchedule] = []
        
        var currentDate = weekStart
        while currentDate <= weekEnd {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            // Filter events for this day
            let dayEvents = events.filter { event in
                event.startDate >= dayStart && event.startDate < dayEnd
            }.sorted { $0.startDate < $1.startDate }
            
            // Calculate free and busy slots
            let (freeSlots, busySlots) = calculateTimeSlots(for: dayEvents, on: dayStart)
            
            let schedule = DaySchedule(
                date: dayStart,
                events: dayEvents,
                freeSlots: freeSlots,
                busySlots: busySlots
            )
            
            schedules.append(schedule)
            currentDate = dayEnd
        }
        
        return schedules
    }
    
    nonisolated private func calculateTimeSlots(for events: [WeekEvent], on date: Date) -> ([TimeSlot], [TimeSlot]) {
        let calendar = Calendar.current
        let dayStart = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: date)!
        let dayEnd = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: date)!
        
        var freeSlots: [TimeSlot] = []
        var busySlots: [TimeSlot] = []
        
        if events.isEmpty {
            freeSlots.append(TimeSlot(startDate: dayStart, endDate: dayEnd, events: []))
            return (freeSlots, busySlots)
        }
        
        var currentTime = dayStart
        
        for event in events {
            // Free slot before event
            if currentTime < event.startDate {
                freeSlots.append(TimeSlot(
                    startDate: currentTime,
                    endDate: event.startDate,
                    events: []
                ))
            }
            
            // Busy slot for event
            busySlots.append(TimeSlot(
                startDate: event.startDate,
                endDate: event.endDate,
                events: [event]
            ))
            
            currentTime = max(currentTime, event.endDate)
        }
        
        // Final free slot
        if currentTime < dayEnd {
            freeSlots.append(TimeSlot(
                startDate: currentTime,
                endDate: dayEnd,
                events: []
            ))
        }
        
        return (freeSlots, busySlots)
    }
    
    /// Calculate week summary statistics
    nonisolated private func calculateWeekSummary(
        events: [WeekEvent],
        weekStart: Date,
        weekEnd: Date
    ) -> WeekSummary {
        var eventsByType: [WeekEventType: Int] = [:]
        var totalBusyMinutes = 0
        var conflictCount = 0
        var upcomingDeadlines = 0
        
        for event in events {
            eventsByType[event.type, default: 0] += 1
            totalBusyMinutes += event.durationInMinutes
            
            if event.conflictCount > 0 {
                conflictCount += 1
            }
            
            if event.type == .assignment && event.status == .active {
                upcomingDeadlines += 1
            }
        }
        
        let totalBusyHours = Double(totalBusyMinutes) / 60.0
        let weekDays = 7.0
        let totalAvailableHours = weekDays * 17.0 // 6 AM to 11 PM
        let totalFreeHours = totalAvailableHours - totalBusyHours
        
        // Find busiest and least busy days
        let eventsByDay = Dictionary(grouping: events) { event in
            Calendar.current.startOfDay(for: event.startDate)
        }
        
        let mostBusyDay = eventsByDay.max { $0.value.count < $1.value.count }?.key
        let leastBusyDay = eventsByDay.min { $0.value.count < $1.value.count }?.key
        
        return WeekSummary(
            weekStart: weekStart,
            weekEnd: weekEnd,
            totalEvents: events.count,
            eventsByType: eventsByType,
            totalBusyHours: totalBusyHours,
            totalFreeHours: max(0, totalFreeHours),
            upcomingDeadlines: upcomingDeadlines,
            conflictingSlots: conflictCount,
            mostBusyDay: mostBusyDay,
            leastBusyDay: leastBusyDay
        )
    }
    
    // MARK: - Filtering
    
    private func applyFilter() {
        // Re-apply filter to current events (without reloading)
        // This is fast since data is already loaded
        Task {
            await loadWeek()
        }
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Observe schedule changes
        NotificationCenter.default.publisher(for: .scheduleDidUpdate)
            .sink { [weak self] _ in
                Task {
                    await self?.loadWeek()
                }
            }
            .store(in: &cancellables)
        
        // Observe assignment changes
        NotificationCenter.default.publisher(for: .assignmentDidUpdate)
            .sink { [weak self] _ in
                Task {
                    await self?.loadWeek()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Processing Result Helper

private enum ProcessingResult {
    case events([WeekEvent])
    case schedules([DaySchedule])
    case summary(WeekSummary)
}

// MARK: - Date Extensions

extension Date {
    func startOfWeek() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    func endOfWeek() -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 6, to: self.startOfWeek()) ?? self
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let scheduleDidUpdate = Notification.Name("scheduleDidUpdate")
    static let assignmentDidUpdate = Notification.Name("assignmentDidUpdate")
}
