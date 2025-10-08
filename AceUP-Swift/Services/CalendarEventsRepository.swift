//
//  CalendarEventsRepository.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Firestore Model for Calendar Events
struct CalendarEventFirestore: Codable {
    let userId: String
    let groupId: String?
    let title: String
    let description: String?
    let startTime: Timestamp
    let endTime: Timestamp
    let type: String
    let priority: String
    let isShared: Bool
    let attendees: [String]
    let location: String?
    let isRecurring: Bool
    let recurrencePattern: RecurrencePatternFirestore?
    let reminderMinutes: [Int]
    let createdAt: Timestamp
    let updatedAt: Timestamp
}

struct RecurrencePatternFirestore: Codable {
    let frequency: String
    let interval: Int
    let daysOfWeek: [Int]?
    let endDate: Timestamp?
    let occurrenceCount: Int?
}

// MARK: - Calendar Events Repository Protocol
protocol CalendarEventsRepositoryProtocol {
    func loadEvents() async throws -> [CalendarEvent]
    func loadEventsByGroup(groupId: String) async throws -> [CalendarEvent]
    func createEvent(_ event: CalendarEvent) async throws
    func updateEvent(_ event: CalendarEvent) async throws
    func deleteEvent(id: String) async throws
    func startRealtimeListener()
    func stopRealtimeListener()
}

// MARK: - Firebase Calendar Events Repository
class FirebaseCalendarEventsRepository: ObservableObject, CalendarEventsRepositoryProtocol {
    
    // MARK: - Published Properties
    @Published var events: [CalendarEvent] = []
    @Published var groupEvents: [String: [CalendarEvent]] = [:] // groupId -> events
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var eventsListener: ListenerRegistration?
    private var groupEventsListeners: [String: ListenerRegistration] = [:]
    
    private var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? ""
    }
    
    deinit {
        eventsListener?.remove()
        eventsListener = nil
        
        // Stop group listeners
        for (_, listener) in groupEventsListeners {
            listener.remove()
        }
        groupEventsListeners.removeAll()
    }
    
    // MARK: - Public Methods
    
    func loadEvents() async throws -> [CalendarEvent] {
        guard !currentUserId.isEmpty else {
            throw CalendarEventsError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let querySnapshot = try await db.collection("calendar_events")
                .whereField("userId", isEqualTo: currentUserId)
                .order(by: "startTime", descending: false)
                .getDocuments()
            
            let events = try querySnapshot.documents.compactMap { document in
                try convertFirestoreEventToCalendarEvent(document.data(), documentId: document.documentID)
            }
            
            await MainActor.run {
                self.events = events
            }
            
            return events
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load events: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func loadEventsByGroup(groupId: String) async throws -> [CalendarEvent] {
        guard !currentUserId.isEmpty else {
            throw CalendarEventsError.notAuthenticated
        }
        
        do {
            let querySnapshot = try await db.collection("calendar_events")
                .whereField("groupId", isEqualTo: groupId)
                .whereField("isShared", isEqualTo: true)
                .order(by: "startTime", descending: false)
                .getDocuments()
            
            let events = try querySnapshot.documents.compactMap { document in
                try convertFirestoreEventToCalendarEvent(document.data(), documentId: document.documentID)
            }
            
            await MainActor.run {
                self.groupEvents[groupId] = events
            }
            
            return events
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load group events: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func createEvent(_ event: CalendarEvent) async throws {
        guard !currentUserId.isEmpty else {
            throw CalendarEventsError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let firestoreEvent = convertCalendarEventToFirestore(event)
            
            let docRef = try await db.collection("calendar_events").addDocument(data: [
                "userId": firestoreEvent.userId,
                "groupId": firestoreEvent.groupId ?? NSNull(),
                "title": firestoreEvent.title,
                "description": firestoreEvent.description ?? NSNull(),
                "startTime": firestoreEvent.startTime,
                "endTime": firestoreEvent.endTime,
                "type": firestoreEvent.type,
                "priority": firestoreEvent.priority,
                "isShared": firestoreEvent.isShared,
                "attendees": firestoreEvent.attendees,
                "location": firestoreEvent.location ?? NSNull(),
                "isRecurring": firestoreEvent.isRecurring,
                "recurrencePattern": encodeRecurrencePattern(firestoreEvent.recurrencePattern) ?? NSNull(),
                "reminderMinutes": firestoreEvent.reminderMinutes,
                "createdAt": firestoreEvent.createdAt,
                "updatedAt": firestoreEvent.updatedAt
            ])
            
            print("Event created with ID: \(docRef.documentID)")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create event: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func updateEvent(_ event: CalendarEvent) async throws {
        guard !currentUserId.isEmpty else {
            throw CalendarEventsError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let firestoreEvent = convertCalendarEventToFirestore(event)
            
            try await db.collection("calendar_events").document(event.id).updateData([
                "title": firestoreEvent.title,
                "description": firestoreEvent.description ?? NSNull(),
                "startTime": firestoreEvent.startTime,
                "endTime": firestoreEvent.endTime,
                "type": firestoreEvent.type,
                "priority": firestoreEvent.priority,
                "isShared": firestoreEvent.isShared,
                "attendees": firestoreEvent.attendees,
                "location": firestoreEvent.location ?? NSNull(),
                "isRecurring": firestoreEvent.isRecurring,
                "recurrencePattern": encodeRecurrencePattern(firestoreEvent.recurrencePattern) ?? NSNull(),
                "reminderMinutes": firestoreEvent.reminderMinutes,
                "updatedAt": Timestamp(date: Date())
            ])
            
            print("Event updated successfully")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update event: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func deleteEvent(id: String) async throws {
        guard !currentUserId.isEmpty else {
            throw CalendarEventsError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("calendar_events").document(id).delete()
            
            await MainActor.run {
                self.events.removeAll { $0.id == id }
                
                // Remove from group events as well
                for groupId in self.groupEvents.keys {
                    self.groupEvents[groupId]?.removeAll { $0.id == id }
                }
            }
            
            print("Event deleted successfully")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete event: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    nonisolated func startRealtimeListener() {
        let userId = Auth.auth().currentUser?.uid ?? ""
        guard !userId.isEmpty else { return }
        
        Task {
            await stopRealtimeListenerAsync() // Stop any existing listener
            
            await MainActor.run {
                self.eventsListener = self.db.collection("calendar_events")
                    .whereField("userId", isEqualTo: userId)
                    .order(by: "startTime", descending: false)
                    .addSnapshotListener { [weak self] querySnapshot, error in
                        
                        Task { @MainActor in
                            guard let self = self else { return }
                            
                            if let error = error {
                                self.errorMessage = "Realtime listener error: \(error.localizedDescription)"
                                return
                            }
                            
                            guard let documents = querySnapshot?.documents else { return }
                            
                            do {
                                let events = try documents.compactMap { document in
                                    try self.convertFirestoreEventToCalendarEvent(document.data(), documentId: document.documentID)
                                }
                                
                                self.events = events
                                
                            } catch {
                                self.errorMessage = "Failed to process realtime updates: \(error.localizedDescription)"
                            }
                        }
                    }
            }
        }
    }
    
    nonisolated func stopRealtimeListener() {
        eventsListener?.remove()
        eventsListener = nil
        
        // Stop group listeners
        for (_, listener) in groupEventsListeners {
            listener.remove()
        }
        groupEventsListeners.removeAll()
    }
    
    private func stopRealtimeListenerAsync() async {
        await MainActor.run {
            eventsListener?.remove()
            eventsListener = nil
            
            // Stop group listeners
            for (_, listener) in groupEventsListeners {
                listener.remove()
            }
            groupEventsListeners.removeAll()
        }
    }
    
    func startGroupEventsListener(groupId: String) {
        let userId = Auth.auth().currentUser?.uid ?? ""
        guard !userId.isEmpty else { return }
        
        Task { @MainActor in
            // Stop existing listener for this group
            groupEventsListeners[groupId]?.remove()
            
            groupEventsListeners[groupId] = db.collection("calendar_events")
                .whereField("groupId", isEqualTo: groupId)
                .whereField("isShared", isEqualTo: true)
                .order(by: "startTime", descending: false)
                .addSnapshotListener { [weak self] querySnapshot, error in
                    
                    Task { @MainActor in
                        guard let self = self else { return }
                        
                        if let error = error {
                            self.errorMessage = "Group events listener error: \(error.localizedDescription)"
                            return
                        }
                        
                        guard let documents = querySnapshot?.documents else { return }
                        
                        do {
                            let events = try documents.compactMap { document in
                                try self.convertFirestoreEventToCalendarEvent(document.data(), documentId: document.documentID)
                            }
                            
                            self.groupEvents[groupId] = events
                            
                        } catch {
                            self.errorMessage = "Failed to process group events: \(error.localizedDescription)"
                        }
                    }
                }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func convertCalendarEventToFirestore(_ event: CalendarEvent) -> CalendarEventFirestore {
        return CalendarEventFirestore(
            userId: event.createdBy,
            groupId: event.groupId,
            title: event.title,
            description: event.description,
            startTime: Timestamp(date: event.startTime),
            endTime: Timestamp(date: event.endTime),
            type: event.type.rawValue,
            priority: event.priority.rawValue,
            isShared: event.isShared,
            attendees: event.attendees,
            location: event.location,
            isRecurring: event.isRecurring,
            recurrencePattern: event.recurrencePattern.map(convertRecurrencePatternToFirestore),
            reminderMinutes: event.reminderMinutes,
            createdAt: Timestamp(date: Date()),
            updatedAt: Timestamp(date: Date())
        )
    }
    
    private func convertFirestoreEventToCalendarEvent(_ data: [String: Any], documentId: String) throws -> CalendarEvent {
        guard let userId = data["userId"] as? String,
              let title = data["title"] as? String,
              let startTimeTimestamp = data["startTime"] as? Timestamp,
              let endTimeTimestamp = data["endTime"] as? Timestamp,
              let typeString = data["type"] as? String,
              let priorityString = data["priority"] as? String,
              let isShared = data["isShared"] as? Bool,
              let attendees = data["attendees"] as? [String],
              let isRecurring = data["isRecurring"] as? Bool,
              let reminderMinutes = data["reminderMinutes"] as? [Int] else {
            throw CalendarEventsError.invalidData
        }
        
        let type = AvailabilityType(rawValue: typeString) ?? .busy
        let priority = Priority(rawValue: priorityString) ?? .medium
        let description = data["description"] as? String
        let groupId = data["groupId"] as? String
        let location = data["location"] as? String
        
        var recurrencePattern: RecurrencePattern?
        if let recurrenceData = data["recurrencePattern"] as? [String: Any] {
            recurrencePattern = try convertFirestoreRecurrencePattern(recurrenceData)
        }
        
        return CalendarEvent(
            id: documentId,
            title: title,
            description: description,
            startTime: startTimeTimestamp.dateValue(),
            endTime: endTimeTimestamp.dateValue(),
            type: type,
            priority: priority,
            isShared: isShared,
            groupId: groupId,
            createdBy: userId,
            attendees: attendees,
            location: location,
            isRecurring: isRecurring,
            recurrencePattern: recurrencePattern,
            reminderMinutes: reminderMinutes
        )
    }
    
    private func convertRecurrencePatternToFirestore(_ pattern: RecurrencePattern) -> RecurrencePatternFirestore {
        return RecurrencePatternFirestore(
            frequency: pattern.frequency.rawValue,
            interval: pattern.interval,
            daysOfWeek: pattern.daysOfWeek,
            endDate: pattern.endDate.map { Timestamp(date: $0) },
            occurrenceCount: pattern.occurrenceCount
        )
    }
    
    private func convertFirestoreRecurrencePattern(_ data: [String: Any]) throws -> RecurrencePattern {
        guard let frequencyString = data["frequency"] as? String,
              let frequency = RecurrenceFrequency(rawValue: frequencyString),
              let interval = data["interval"] as? Int else {
            throw CalendarEventsError.invalidData
        }
        
        let daysOfWeek = data["daysOfWeek"] as? [Int]
        let endDate = (data["endDate"] as? Timestamp)?.dateValue()
        let occurrenceCount = data["occurrenceCount"] as? Int
        
        return RecurrencePattern(
            frequency: frequency,
            interval: interval,
            daysOfWeek: daysOfWeek,
            endDate: endDate,
            occurrenceCount: occurrenceCount
        )
    }
    
    private func encodeRecurrencePattern(_ pattern: RecurrencePatternFirestore?) -> [String: Any]? {
        guard let pattern = pattern else { return nil }
        
        var dict: [String: Any] = [
            "frequency": pattern.frequency,
            "interval": pattern.interval
        ]
        
        if let daysOfWeek = pattern.daysOfWeek {
            dict["daysOfWeek"] = daysOfWeek
        }
        
        if let endDate = pattern.endDate {
            dict["endDate"] = endDate
        }
        
        if let occurrenceCount = pattern.occurrenceCount {
            dict["occurrenceCount"] = occurrenceCount
        }
        
        return dict
    }
}

// MARK: - Calendar Events Errors
enum CalendarEventsError: LocalizedError {
    case notAuthenticated
    case invalidData
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidData:
            return "Invalid event data"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}