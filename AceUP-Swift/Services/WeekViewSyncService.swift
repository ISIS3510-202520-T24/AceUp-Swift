//
//  WeekViewSyncService.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/12/25.
//

import Foundation
import CoreData
import EventKit
import FirebaseAuth

/// Background synchronization service for WeekView data
/// Handles external calendar integration and transactional updates
@MainActor
class WeekViewSyncService: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private let persistenceController: PersistenceController
    private let eventStore = EKEventStore()
    private var syncTimer: Timer?
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? "anonymous"
    }
    
    // MARK: - Initialization
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        setupPeriodicSync()
    }
    
    // MARK: - Public Methods
    
    /// Perform full synchronization
    func syncAll() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Sync in parallel using task groups
            await withTaskGroup(of: SyncResult.self) { group in
                // Task 1: Sync assignments to local cache
                group.addTask {
                    await self.syncAssignmentsToCache()
                }
                
                // Task 2: Sync external calendars
                group.addTask {
                    await self.syncExternalCalendars()
                }
                
                // Task 3: Sync holidays
                group.addTask {
                    await self.syncHolidays()
                }
                
                // Collect results
                for await result in group {
                    switch result {
                    case .success(let message):
                        print("✅ Sync success: \(message)")
                    case .failure(let error):
                        print("❌ Sync error: \(error)")
                        self.syncError = error
                    }
                }
            }
            
            lastSyncDate = Date()
            isSyncing = false
            
            // Notify observers
            NotificationCenter.default.post(name: .weekDataDidSync, object: nil)
            
        } catch {
            syncError = error
            isSyncing = false
        }
    }
    
    /// Request calendar access
    func requestCalendarAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            return await eventStore.requestFullAccessToEvents()
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // MARK: - Private Sync Methods
    
    /// Sync assignments to local cache for fast queries
    private func syncAssignmentsToCache() async -> SyncResult {
        await persistenceController.performBackgroundTask { context in
            do {
                // Fetch all user assignments
                let request: NSFetchRequest<AssignmentEntity> = AssignmentEntity.fetchRequest()
                request.predicate = NSPredicate(format: "userId == %@", self.currentUserId)
                
                let assignments = try context.fetch(request)
                
                // Create/update week event cache entries
                for assignment in assignments {
                    let weekEvent = WeekEvent.from(assignment: assignment.toAssignment())
                    
                    // Check if cache entry exists
                    let cacheRequest: NSFetchRequest<WeekEventEntity> = WeekEventEntity.fetchRequest()
                    cacheRequest.predicate = NSPredicate(format: "id == %@", weekEvent.id)
                    cacheRequest.fetchLimit = 1
                    
                    if let existingCache = try context.fetch(cacheRequest).first {
                        // Update existing
                        existingCache.title = weekEvent.title
                        existingCache.descriptionText = weekEvent.description
                        existingCache.startDate = weekEvent.startDate
                        existingCache.endDate = weekEvent.endDate
                        existingCache.eventType = weekEvent.type.rawValue
                        existingCache.updatedAt = Date()
                    } else {
                        // Create new
                        _ = WeekEventEntity.fromWeekEvent(weekEvent, userId: self.currentUserId, in: context)
                    }
                }
                
                // Transactional save
                if context.hasChanges {
                    try context.save()
                }
                
                return .success("Synced \(assignments.count) assignments to cache")
                
            } catch {
                return .failure(error)
            }
        }
    }
    
    /// Sync external calendar events
    private func syncExternalCalendars() async -> SyncResult {
        // Check calendar access
        let hasAccess = await requestCalendarAccess()
        guard hasAccess else {
            return .failure(NSError(
                domain: "WeekViewSync",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Calendar access not granted"]
            ))
        }
        
        return await persistenceController.performBackgroundTask { context in
            do {
                // Get calendars
                let calendars = self.eventStore.calendars(for: .event)
                
                // Fetch events for next 4 weeks
                let startDate = Date()
                let endDate = Calendar.current.date(byAdding: .weekOfYear, value: 4, to: startDate) ?? startDate
                
                let predicate = self.eventStore.predicateForEvents(
                    withStart: startDate,
                    end: endDate,
                    calendars: calendars
                )
                
                let events = self.eventStore.events(matching: predicate)
                
                // Convert to WeekEvents and cache
                for event in events {
                    let weekEvent = WeekEvent(
                        id: "external_\(event.eventIdentifier ?? UUID().uuidString)",
                        title: event.title ?? "Untitled",
                        description: event.notes,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        type: .personal,
                        color: "#1ABC9C",
                        location: event.location,
                        isAllDay: event.isAllDay,
                        metadata: [
                            "source": "external_calendar",
                            "calendarIdentifier": event.calendar.calendarIdentifier
                        ]
                    )
                    
                    // Check if cache entry exists
                    let cacheRequest: NSFetchRequest<WeekEventEntity> = WeekEventEntity.fetchRequest()
                    cacheRequest.predicate = NSPredicate(format: "id == %@", weekEvent.id)
                    cacheRequest.fetchLimit = 1
                    
                    if let existingCache = try context.fetch(cacheRequest).first {
                        // Update
                        existingCache.startDate = weekEvent.startDate
                        existingCache.endDate = weekEvent.endDate
                        existingCache.updatedAt = Date()
                    } else {
                        // Create new
                        _ = WeekEventEntity.fromWeekEvent(weekEvent, userId: self.currentUserId, in: context)
                    }
                }
                
                // Transactional save
                if context.hasChanges {
                    try context.save()
                }
                
                return .success("Synced \(events.count) external calendar events")
                
            } catch {
                return .failure(error)
            }
        }
    }
    
    /// Sync holidays from remote/local
    private func syncHolidays() async -> SyncResult {
        // Holidays are typically synced through HolidayService
        // This is a placeholder for additional sync logic if needed
        return .success("Holidays sync not required")
    }
    
    // MARK: - Periodic Sync
    
    private func setupPeriodicSync() {
        // Sync every 15 minutes
        syncTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task {
                await self?.syncAll()
            }
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}

// MARK: - Sync Result

enum SyncResult {
    case success(String)
    case failure(Error)
}

// MARK: - Notification Names

extension Notification.Name {
    static let weekDataDidSync = Notification.Name("weekDataDidSync")
}

// MARK: - Transaction Helper

extension PersistenceController {
    /// Execute multiple operations in a single transaction
    func executeTransaction(_ operations: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    // Begin transaction
                    try operations(context)
                    
                    // Commit transaction
                    if context.hasChanges {
                        try context.save()
                    }
                    
                    continuation.resume()
                } catch {
                    // Rollback on error
                    context.rollback()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
