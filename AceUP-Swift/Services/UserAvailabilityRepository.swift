//
//  UserAvailabilityRepository.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Firestore Model for User Availability
struct UserAvailabilityFirestore: Codable {
    let userId: String
    let availability: [AvailabilitySlotFirestore]
    let updatedAt: Timestamp
}

struct AvailabilitySlotFirestore: Codable {
    let id: String
    let dayOfWeek: Int // 0-6 (Sunday-Saturday)
    let startTime: TimeOfDayFirestore
    let endTime: TimeOfDayFirestore
    let title: String?
    let type: String
    let priority: String
}

// MARK: - User Availability Repository Protocol
protocol UserAvailabilityRepositoryProtocol {
    func loadUserAvailability() async throws -> [AvailabilitySlot]
    func loadUserAvailability(userId: String) async throws -> [AvailabilitySlot]
    func updateUserAvailability(_ availability: [AvailabilitySlot]) async throws
    func addAvailabilitySlot(_ slot: AvailabilitySlot) async throws
    func removeAvailabilitySlot(id: String) async throws
    func startRealtimeListener()
    func stopRealtimeListener()
}

// MARK: - Firebase User Availability Repository
@MainActor
class FirebaseUserAvailabilityRepository: ObservableObject, UserAvailabilityRepositoryProtocol {
    
    // MARK: - Published Properties
    @Published var currentUserAvailability: [AvailabilitySlot] = []
    @Published var userAvailabilityCache: [String: [AvailabilitySlot]] = [:] // userId -> availability
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var availabilityListener: ListenerRegistration?
    
    private var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? ""
    }
    
    deinit {
        stopRealtimeListener()
    }
    
    // MARK: - Public Methods
    
    func loadUserAvailability() async throws -> [AvailabilitySlot] {
        guard !currentUserId.isEmpty else {
            throw UserAvailabilityError.notAuthenticated
        }
        
        return try await loadUserAvailability(userId: currentUserId)
    }
    
    func loadUserAvailability(userId: String) async throws -> [AvailabilitySlot] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let document = try await db.collection("user_availability").document(userId).getDocument()
            
            if document.exists, let data = document.data() {
                let firestoreAvailability = try convertFirestoreToUserAvailability(data)
                let availability = convertFirestoreAvailabilityToLocal(firestoreAvailability.availability)
                
                await MainActor.run {
                    if userId == self.currentUserId {
                        self.currentUserAvailability = availability
                    }
                    self.userAvailabilityCache[userId] = availability
                }
                
                return availability
            } else {
                // No availability data exists, return empty array
                let emptyAvailability: [AvailabilitySlot] = []
                
                await MainActor.run {
                    if userId == self.currentUserId {
                        self.currentUserAvailability = emptyAvailability
                    }
                    self.userAvailabilityCache[userId] = emptyAvailability
                }
                
                return emptyAvailability
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load availability: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func updateUserAvailability(_ availability: [AvailabilitySlot]) async throws {
        guard !currentUserId.isEmpty else {
            throw UserAvailabilityError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let firestoreAvailability = convertLocalAvailabilityToFirestore(availability)
            
            let data: [String: Any] = [
                "userId": currentUserId,
                "availability": firestoreAvailability.map { slot in
                    [
                        "id": slot.id,
                        "dayOfWeek": slot.dayOfWeek,
                        "startTime": [
                            "hour": slot.startTime.hour,
                            "minute": slot.startTime.minute
                        ],
                        "endTime": [
                            "hour": slot.endTime.hour,
                            "minute": slot.endTime.minute
                        ],
                        "title": slot.title as Any,
                        "type": slot.type,
                        "priority": slot.priority
                    ]
                },
                "updatedAt": Timestamp(date: Date())
            ]
            
            try await db.collection("user_availability").document(currentUserId).setData(data)
            
            await MainActor.run {
                self.currentUserAvailability = availability
                self.userAvailabilityCache[self.currentUserId] = availability
            }
            
            print("User availability updated successfully")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update availability: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func addAvailabilitySlot(_ slot: AvailabilitySlot) async throws {
        var currentSlots = currentUserAvailability
        currentSlots.append(slot)
        try await updateUserAvailability(currentSlots)
    }
    
    func removeAvailabilitySlot(id: String) async throws {
        var currentSlots = currentUserAvailability
        currentSlots.removeAll { $0.id == id }
        try await updateUserAvailability(currentSlots)
    }
    
    nonisolated func startRealtimeListener() {
        let userId = Auth.auth().currentUser?.uid ?? ""
        guard !userId.isEmpty else { return }
        
        Task { @MainActor in
            stopRealtimeListener() // Stop any existing listener
            
            availabilityListener = db.collection("user_availability")
                .document(userId)
                .addSnapshotListener { [weak self] documentSnapshot, error in
                    
                    Task { @MainActor in
                        guard let self = self else { return }
                        
                        if let error = error {
                            self.errorMessage = "Availability listener error: \(error.localizedDescription)"
                            return
                        }
                        
                        guard let document = documentSnapshot,
                              document.exists,
                              let data = document.data() else {
                            // No data exists, set empty availability
                            self.currentUserAvailability = []
                            self.userAvailabilityCache[userId] = []
                            return
                        }
                        
                        do {
                            let firestoreAvailability = try self.convertFirestoreToUserAvailability(data)
                            let availability = self.convertFirestoreAvailabilityToLocal(firestoreAvailability.availability)
                            
                            self.currentUserAvailability = availability
                            self.userAvailabilityCache[userId] = availability
                            
                        } catch {
                            self.errorMessage = "Failed to process availability update: \(error.localizedDescription)"
                        }
                    }
                }
        }
    }
    
    nonisolated func stopRealtimeListener() {
        Task { @MainActor in
            availabilityListener?.remove()
            availabilityListener = nil
        }
    }
    
    // MARK: - Helper Methods for Group Scheduling
    
    func loadGroupMembersAvailability(memberIds: [String]) async throws -> [String: [AvailabilitySlot]] {
        var memberAvailability: [String: [AvailabilitySlot]] = [:]
        
        for memberId in memberIds {
            // Check cache first
            if let cachedAvailability = userAvailabilityCache[memberId] {
                memberAvailability[memberId] = cachedAvailability
            } else {
                // Load from Firestore
                do {
                    let availability = try await loadUserAvailability(userId: memberId)
                    memberAvailability[memberId] = availability
                } catch {
                    // If we can't load a member's availability, use empty array
                    memberAvailability[memberId] = []
                }
            }
        }
        
        return memberAvailability
    }
    
    func generateDefaultAvailability() -> [AvailabilitySlot] {
        var defaultSlots: [AvailabilitySlot] = []
        
        // Create typical weekday schedule (Monday-Friday, 9 AM - 5 PM)
        for dayOfWeek in 1...5 { // Monday to Friday
            let slot = AvailabilitySlot(
                id: UUID().uuidString,
                dayOfWeek: dayOfWeek,
                startTime: TimeOfDay(hour: 9, minute: 0),
                endTime: TimeOfDay(hour: 17, minute: 0),
                title: "Available",
                type: .free,
                priority: .medium
            )
            defaultSlots.append(slot)
        }
        
        return defaultSlots
    }
    
    // MARK: - Private Helper Methods
    
    private func convertFirestoreToUserAvailability(_ data: [String: Any]) throws -> UserAvailabilityFirestore {
        guard let userId = data["userId"] as? String,
              let availabilityData = data["availability"] as? [[String: Any]],
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
            throw UserAvailabilityError.invalidData
        }
        
        let availability = try availabilityData.map { slotData in
            try convertFirestoreToAvailabilitySlot(slotData)
        }
        
        return UserAvailabilityFirestore(
            userId: userId,
            availability: availability,
            updatedAt: updatedAtTimestamp
        )
    }
    
    private func convertFirestoreToAvailabilitySlot(_ data: [String: Any]) throws -> AvailabilitySlotFirestore {
        guard let id = data["id"] as? String,
              let dayOfWeek = data["dayOfWeek"] as? Int,
              let startTimeData = data["startTime"] as? [String: Any],
              let endTimeData = data["endTime"] as? [String: Any],
              let typeString = data["type"] as? String,
              let priorityString = data["priority"] as? String else {
            throw UserAvailabilityError.invalidData
        }
        
        let startTime = try convertFirestoreToTimeOfDay(startTimeData)
        let endTime = try convertFirestoreToTimeOfDay(endTimeData)
        let title = data["title"] as? String
        
        return AvailabilitySlotFirestore(
            id: id,
            dayOfWeek: dayOfWeek,
            startTime: startTime,
            endTime: endTime,
            title: title,
            type: typeString,
            priority: priorityString
        )
    }
    
    private func convertFirestoreToTimeOfDay(_ data: [String: Any]) throws -> TimeOfDayFirestore {
        guard let hour = data["hour"] as? Int,
              let minute = data["minute"] as? Int else {
            throw UserAvailabilityError.invalidData
        }
        
        return TimeOfDayFirestore(hour: hour, minute: minute)
    }
    
    private func convertFirestoreAvailabilityToLocal(_ firestore: [AvailabilitySlotFirestore]) -> [AvailabilitySlot] {
        return firestore.compactMap { slot in
            guard let type = AvailabilityType(rawValue: slot.type),
                  let priority = Priority(rawValue: slot.priority) else {
                return nil
            }
            
            return AvailabilitySlot(
                id: slot.id,
                dayOfWeek: slot.dayOfWeek,
                startTime: TimeOfDay(hour: slot.startTime.hour, minute: slot.startTime.minute),
                endTime: TimeOfDay(hour: slot.endTime.hour, minute: slot.endTime.minute),
                title: slot.title,
                type: type,
                priority: priority
            )
        }
    }
    
    private func convertLocalAvailabilityToFirestore(_ local: [AvailabilitySlot]) -> [AvailabilitySlotFirestore] {
        return local.map { slot in
            AvailabilitySlotFirestore(
                id: slot.id,
                dayOfWeek: slot.dayOfWeek,
                startTime: TimeOfDayFirestore(hour: slot.startTime.hour, minute: slot.startTime.minute),
                endTime: TimeOfDayFirestore(hour: slot.endTime.hour, minute: slot.endTime.minute),
                title: slot.title,
                type: slot.type.rawValue,
                priority: slot.priority.rawValue
            )
        }
    }
}

// MARK: - User Availability Errors
enum UserAvailabilityError: LocalizedError {
    case notAuthenticated
    case invalidData
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidData:
            return "Invalid availability data"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}