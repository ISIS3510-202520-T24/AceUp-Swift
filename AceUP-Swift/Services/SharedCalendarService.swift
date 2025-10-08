//
//  SharedCalendarService.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
class SharedCalendarService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var groups: [CalendarGroup] = []
    @Published var currentGroup: CalendarGroup?
    @Published var sharedSchedule: SharedSchedule?
    @Published var smartSuggestions: [SmartSuggestion] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? "anonymous_user"
    }
    
    // MARK: - Initialization
    init() {
        Task {
            await loadGroupsFromFirebase()
            await generateSmartSuggestions()
        }
    }
    
    // MARK: - Firebase Data Loading
    func loadGroupsFromFirebase() async {
        await MainActor.run {
            isLoading = true
        }
        
        defer { 
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let groupsSnapshot = try await db.collection("groups")
                .whereField("members", arrayContains: currentUserId)
                .getDocuments()
            
            var loadedGroups: [CalendarGroup] = []
            
            for document in groupsSnapshot.documents {
                if let group = try? document.data(as: CalendarGroupFirestore.self) {
                    
                    let calendarGroup = await convertFirestoreGroupToCalendarGroup(group, documentId: document.documentID)
                    loadedGroups.append(calendarGroup)
                }
            }
            
            await MainActor.run {
                self.groups = loadedGroups
            }
            
            if loadedGroups.isEmpty {
                await createSampleGroupsInFirebase()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Error loading groups: \(error.localizedDescription)"
            }
            print("Error loading groups from Firebase: \(error)")
           
            await MainActor.run {
                loadMockData()
            }
        }
    }
    
    // MARK: - Group Management
    func createGroup(name: String, description: String) async {
        await MainActor.run {
            isLoading = true
        }
        
        defer { 
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let groupId = UUID().uuidString
            
            
            let groupCode = generateGroupCode()
            let groupData: [String: Any] = [
                "name": name,
                "ownerId": currentUserId,
                "members": [currentUserId], 
                "createdAt": Timestamp(date: Date()),
                "description": description,
                "color": generateRandomColor(),
                "inviteCode": groupCode 
            ]
            
            try await db.collection("groups").document(groupId).setData(groupData)
            
           
            let welcomeEventData: [String: Any] = [
                "title": "Grupo creado: \(name)",
                "createdBy": currentUserId,
                "timestamp": Timestamp(date: Date()),
                "type": "group_created"
            ]
            
            try await db.collection("groups").document(groupId)
                .collection("events").addDocument(data: welcomeEventData)
            
            
            await loadGroupsFromFirebase()
            
        } catch {
            await MainActor.run {
                errorMessage = "Error creating group: \(error.localizedDescription)"
            }
            print("Error creating group in Firebase: \(error)")
        }
    }
    
    func joinGroup(groupId: String, inviteCode: String? = nil) async {
        await MainActor.run {
            isLoading = true
        }
        
        defer { 
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            var groupDoc: DocumentSnapshot
            
            if let code = inviteCode {
                
                let groupsQuery = try await db.collection("groups")
                    .whereField("inviteCode", isEqualTo: code)
                    .getDocuments()
                
                guard let foundGroup = groupsQuery.documents.first else {
                    await MainActor.run {
                        errorMessage = "Código de grupo inválido"
                    }
                    return
                }
                
                groupDoc = foundGroup
            } else {
                
                groupDoc = try await db.collection("groups").document(groupId).getDocument()
                
                guard groupDoc.exists else {
                    await MainActor.run {
                        errorMessage = "Grupo no encontrado"
                    }
                    return
                }
            }
            
            
            if let data = groupDoc.data(),
               let members = data["members"] as? [String],
               members.contains(currentUserId) {
                await MainActor.run {
                    errorMessage = "Ya eres miembro de este grupo"
                }
                return
            }
            
            try await db.collection("groups").document(groupDoc.documentID).updateData([
                "members": FieldValue.arrayUnion([currentUserId])
            ])
            
           
            let joinEventData: [String: Any] = [
                "title": "Miembro se unió al grupo",
                "createdBy": currentUserId,
                "timestamp": Timestamp(date: Date()),
                "type": "member_joined"
            ]
            
            try await db.collection("groups").document(groupDoc.documentID)
                .collection("events").addDocument(data: joinEventData)
            
           
            await loadGroupsFromFirebase()
            
        } catch {
            await MainActor.run {
                errorMessage = "Error joining group: \(error.localizedDescription)"
            }
            print("Error joining group in Firebase: \(error)")
        }
    }
    
    func joinGroupByCode(_ inviteCode: String) async {
        await joinGroup(groupId: "", inviteCode: inviteCode)
    }
    
    func leaveGroup(groupId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            
            try await db.collection("groups").document(groupId).updateData([
                "members": FieldValue.arrayRemove([currentUserId])
            ])
            
            
            let leaveEventData: [String: Any] = [
                "title": "Miembro dejó el grupo",
                "createdBy": currentUserId,
                "timestamp": Timestamp(date: Date()),
                "type": "member_left"
            ]
            
            try await db.collection("groups").document(groupId)
                .collection("events").addDocument(data: leaveEventData)
            
            
            groups.removeAll { $0.id == groupId }
            
            if currentGroup?.id == groupId {
                currentGroup = nil
                sharedSchedule = nil
            }
            
        } catch {
            errorMessage = "Error leaving group: \(error.localizedDescription)"
            print("Error leaving group in Firebase: \(error)")
        }
    }
    
    // MARK: - Schedule Generation
    func generateSharedSchedule(for group: CalendarGroup) async {
        isLoading = true
        defer { isLoading = false }
        
        let calendar = Calendar.current
        let today = Date()
        let targetDate = calendar.startOfDay(for: today)
        
        // Generate common free slots
        let commonSlots = findCommonFreeSlots(for: group.members, on: targetDate)
        
        // Identify conflicts
        let conflicts = findScheduleConflicts(for: group.members, on: targetDate)
        
        // Generate smart suggestions
        let suggestions = generateSmartSuggestionsForGroup(group: group, commonSlots: commonSlots)
        
        let newSchedule = SharedSchedule(
            id: UUID().uuidString,
            groupId: group.id,
            date: targetDate,
            commonFreeSlots: commonSlots,
            conflictingSlots: conflicts,
            generatedAt: Date(),
            smartSuggestions: suggestions
        )
        
        sharedSchedule = newSchedule
        smartSuggestions = suggestions
    }
    
    func saveSharedEventToFirebase(event: CalendarEvent, groupId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let eventData: [String: Any] = [
                "title": event.title,
                "description": event.description ?? "",
                "startTime": Timestamp(date: event.startTime),
                "endTime": Timestamp(date: event.endTime),
                "type": event.type.rawValue,
                "priority": event.priority.rawValue,
                "createdBy": currentUserId,
                "attendees": event.attendees,
                "location": event.location ?? "",
                "isRecurring": event.isRecurring,
                "reminderMinutes": event.reminderMinutes,
                "createdAt": Timestamp(date: Date())
            ]
            
            try await db.collection("groups").document(groupId)
                .collection("events").addDocument(data: eventData)
            
            print("Event saved to Firebase successfully")
            
        } catch {
            errorMessage = "Error saving event: \(error.localizedDescription)"
            print("Error saving event to Firebase: \(error)")
        }
    }
    
    func loadSharedEventsFromFirebase(groupId: String) async -> [CalendarEvent] {
        do {
            let eventsSnapshot = try await db.collection("groups").document(groupId)
                .collection("events")
                .order(by: "startTime")
                .getDocuments()
            
            var events: [CalendarEvent] = []
            
            for doc in eventsSnapshot.documents {
                let data = doc.data()
                
                if let title = data["title"] as? String,
                   let startTimeTimestamp = data["startTime"] as? Timestamp,
                   let endTimeTimestamp = data["endTime"] as? Timestamp,
                   let typeString = data["type"] as? String,
                   let type = AvailabilityType(rawValue: typeString),
                   let priorityString = data["priority"] as? String,
                   let priority = Priority(rawValue: priorityString),
                   let createdBy = data["createdBy"] as? String,
                   let attendees = data["attendees"] as? [String],
                   let isRecurring = data["isRecurring"] as? Bool,
                   let reminderMinutes = data["reminderMinutes"] as? [Int] {
                    
                    let event = CalendarEvent(
                        id: doc.documentID,
                        title: title,
                        description: data["description"] as? String,
                        startTime: startTimeTimestamp.dateValue(),
                        endTime: endTimeTimestamp.dateValue(),
                        type: type,
                        priority: priority,
                        isShared: true,
                        groupId: groupId,
                        createdBy: createdBy,
                        attendees: attendees,
                        location: data["location"] as? String,
                        isRecurring: isRecurring,
                        recurrencePattern: nil, 
                        reminderMinutes: reminderMinutes
                    )
                    
                    events.append(event)
                }
            }
            
            return events
            
        } catch {
            print("Error loading events from Firebase: \(error)")
            return []
        }
    }
    
    // MARK: - Public Methods for ViewModels
    func findCommonFreeSlots(for group: CalendarGroup, on date: Date) -> [CommonFreeSlot] {
        return findCommonFreeSlots(for: group.members, on: date)
    }
    
    func findConflictingSlots(for group: CalendarGroup, on date: Date) -> [ConflictingSlot] {
        return findScheduleConflicts(for: group.members, on: date)
    }

    // MARK: - Smart Features
    private func findCommonFreeSlots(for members: [GroupMember], on date: Date) -> [CommonFreeSlot] {
        var commonSlots: [CommonFreeSlot] = []
        
        // Time slots from 6 AM to 11 PM (in 30-minute intervals)
        let timeSlots = generateTimeSlots()
        
        for timeSlot in timeSlots {
            let availableMembers = members.filter { member in
                isTimeSlotFree(for: member, at: timeSlot, on: date)
            }
            
            if availableMembers.count >= 2 { // At least 2 members available
                let confidence = Double(availableMembers.count) / Double(members.count)
                
                let commonSlot = CommonFreeSlot(
                    id: UUID().uuidString,
                    startTime: timeSlot.start,
                    endTime: timeSlot.end,
                    availableMembers: availableMembers.map { $0.id },
                    confidence: confidence,
                    duration: timeSlot.duration
                )
                
                commonSlots.append(commonSlot)
            }
        }
        
        return mergeContinuousSlots(commonSlots)
    }
    
    private func findScheduleConflicts(for members: [GroupMember], on date: Date) -> [ConflictingSlot] {
        var conflicts: [ConflictingSlot] = []
        let timeSlots = generateTimeSlots()
        
        for timeSlot in timeSlots {
            var memberConflicts: [MemberConflict] = []
            
            for member in members {
                if let conflict = findConflictForMember(member, at: timeSlot, on: date) {
                    memberConflicts.append(conflict)
                }
            }
            
            if !memberConflicts.isEmpty {
                let conflictingSlot = ConflictingSlot(
                    id: UUID().uuidString,
                    startTime: timeSlot.start,
                    endTime: timeSlot.end,
                    conflicts: memberConflicts
                )
                conflicts.append(conflictingSlot)
            }
        }
        
        return conflicts
    }
    
    private func generateSmartSuggestionsForGroup(group: CalendarGroup, commonSlots: [CommonFreeSlot]) -> [SmartSuggestion] {
        var suggestions: [SmartSuggestion] = []
        
        // Optimal meeting time suggestion
        if let bestSlot = commonSlots.max(by: { $0.confidence < $1.confidence }) {
            let suggestion = SmartSuggestion(
                id: UUID().uuidString,
                type: .optimalMeetingTime,
                title: "Best Time for Group Meeting",
                description: "All \(group.memberCount) members are available from \(bestSlot.startTime.timeString) to \(bestSlot.endTime.timeString)",
                confidence: bestSlot.confidence,
                actionRequired: false,
                suggestedTime: bestSlot.startTime,
                affectedMembers: bestSlot.availableMembers,
                createdAt: Date()
            )
            suggestions.append(suggestion)
        }
        
        // Study session suggestion
        let longSlots = commonSlots.filter { $0.duration >= 90 } // 1.5+ hours
        if let studySlot = longSlots.first {
            let suggestion = SmartSuggestion(
                id: UUID().uuidString,
                type: .studySession,
                title: "Group Study Session Opportunity",
                description: "Perfect \(studySlot.duration)-minute window for collaborative studying",
                confidence: studySlot.confidence,
                actionRequired: true,
                suggestedTime: studySlot.startTime,
                affectedMembers: studySlot.availableMembers,
                createdAt: Date()
            )
            suggestions.append(suggestion)
        }
        
        // Low availability warning
        let lowAvailabilitySlots = commonSlots.filter { $0.confidence < 0.5 }
        if lowAvailabilitySlots.count > commonSlots.count / 2 {
            let suggestion = SmartSuggestion(
                id: UUID().uuidString,
                type: .groupAvailability,
                title: "Limited Group Availability",
                description: "Consider updating schedules or finding alternative meeting times",
                confidence: 0.8,
                actionRequired: true,
                suggestedTime: nil,
                affectedMembers: group.members.map { $0.id },
                createdAt: Date()
            )
            suggestions.append(suggestion)
        }
        
        return suggestions
    }
    
    // MARK: - Helper Methods
    private func generateTimeSlots() -> [(start: TimeOfDay, end: TimeOfDay, duration: Int)] {
        var slots: [(start: TimeOfDay, end: TimeOfDay, duration: Int)] = []
        
        for hour in 6..<23 {
            for minute in stride(from: 0, to: 60, by: 30) {
                let start = TimeOfDay(hour: hour, minute: minute)
                let endMinute = minute + 30
                let endHour = endMinute >= 60 ? hour + 1 : hour
                let adjustedEndMinute = endMinute >= 60 ? 0 : endMinute
                
                if endHour < 23 {
                    let end = TimeOfDay(hour: endHour, minute: adjustedEndMinute)
                    slots.append((start: start, end: end, duration: 30))
                }
            }
        }
        
        return slots
    }
    
    private func isTimeSlotFree(for member: GroupMember, at timeSlot: (start: TimeOfDay, end: TimeOfDay, duration: Int), on date: Date) -> Bool {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: date) - 1 // Convert to 0-based
        
        // Check member's availability slots
        for availability in member.availability {
            if availability.dayOfWeek == dayOfWeek {
                if availability.type == AvailabilityType.busy || availability.type == AvailabilityType.lecture || availability.type == AvailabilityType.exam {
                    // Check if time slot overlaps with busy period
                    if timeSlot.start >= availability.startTime && timeSlot.end <= availability.endTime {
                        return false
                    }
                }
            }
        }
        
        return true
    }
    
    private func findConflictForMember(_ member: GroupMember, at timeSlot: (start: TimeOfDay, end: TimeOfDay, duration: Int), on date: Date) -> MemberConflict? {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: date) - 1
        
        for availability in member.availability {
            if availability.dayOfWeek == dayOfWeek {
                if availability.type != AvailabilityType.free && timeSlot.start >= availability.startTime && timeSlot.end <= availability.endTime {
                    return MemberConflict(
                        id: UUID().uuidString,
                        memberId: member.id,
                        memberName: member.name,
                        conflictType: availability.type,
                        conflictTitle: availability.title ?? availability.type.displayName,
                        canBeRescheduled: availability.type == AvailabilityType.meeting || availability.type == AvailabilityType.assignment,
                        alternativeTimes: []
                    )
                }
            }
        }
        
        return nil
    }
    
    private func mergeContinuousSlots(_ slots: [CommonFreeSlot]) -> [CommonFreeSlot] {
        var mergedSlots: [CommonFreeSlot] = []
        let sortedSlots = slots.sorted { $0.startTime < $1.startTime }
        
        var currentSlot: CommonFreeSlot?
        
        for slot in sortedSlots {
            if let current = currentSlot {
                // Check if slots are continuous and have same available members
                if current.endTime.minutesFromMidnight == slot.startTime.minutesFromMidnight &&
                   Set(current.availableMembers) == Set(slot.availableMembers) {
                    // Merge slots
                    currentSlot = CommonFreeSlot(
                        id: current.id,
                        startTime: current.startTime,
                        endTime: slot.endTime,
                        availableMembers: current.availableMembers,
                        confidence: current.confidence,
                        duration: current.duration + slot.duration
                    )
                } else {
                    mergedSlots.append(current)
                    currentSlot = slot
                }
            } else {
                currentSlot = slot
            }
        }
        
        if let current = currentSlot {
            mergedSlots.append(current)
        }
        
        return mergedSlots
    }
    
    private func createCurrentUserMember() -> GroupMember {
        return GroupMember(
            id: "current_user_id",
            name: "You",
            email: "you@example.com",
            avatar: nil,
            isAdmin: true,
            joinedAt: Date(),
            availability: generateMockAvailability()
        )
    }
    
    private func generateMockAvailability() -> [AvailabilitySlot] {
        return [
            // Monday - Classes
            AvailabilitySlot(
                id: UUID().uuidString,
                dayOfWeek: 1,
                startTime: TimeOfDay(hour: 9, minute: 0),
                endTime: TimeOfDay(hour: 11, minute: 0),
                title: "Mobile Development",
                type: AvailabilityType.lecture,
                priority: Priority.high
            ),
            AvailabilitySlot(
                id: UUID().uuidString,
                dayOfWeek: 1,
                startTime: TimeOfDay(hour: 14, minute: 0),
                endTime: TimeOfDay(hour: 16, minute: 0),
                title: "Software Architecture",
                type: AvailabilityType.lecture,
                priority: Priority.high
            ),
            // Tuesday - Free time
            AvailabilitySlot(
                id: UUID().uuidString,
                dayOfWeek: 2,
                startTime: TimeOfDay(hour: 10, minute: 0),
                endTime: TimeOfDay(hour: 18, minute: 0),
                title: "Available",
                type: AvailabilityType.free,
                priority: Priority.low
            ),
            // Wednesday - Mixed
            AvailabilitySlot(
                id: UUID().uuidString,
                dayOfWeek: 3,
                startTime: TimeOfDay(hour: 8, minute: 0),
                endTime: TimeOfDay(hour: 12, minute: 0),
                title: "Database Systems",
                type: AvailabilityType.lecture,
                priority: Priority.high
            ),
            AvailabilitySlot(
                id: UUID().uuidString,
                dayOfWeek: 3,
                startTime: TimeOfDay(hour: 15, minute: 0),
                endTime: TimeOfDay(hour: 17, minute: 0),
                title: "Project Meeting",
                type: AvailabilityType.meeting,
                priority: Priority.medium
            )
        ]
    }
    
    private func generateRandomColor() -> String {
        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FECA57", "#FF9FF3", "#54A0FF"]
        return colors.randomElement() ?? "#4ECDC4"
    }
    
    private func generateGroupCode() -> String {
        
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let code = String((0..<6).map { _ in chars.randomElement()! })
        return code
    }
    
    private func generateSmartSuggestions() async {
       
        var suggestions: [SmartSuggestion] = []
        
        do {
            let suggestionsSnapshot = try await db.collection("users")
                .document(currentUserId)
                .collection("smartSuggestions")
                .order(by: "createdAt", descending: true)
                .limit(to: 10)
                .getDocuments()
            
            for doc in suggestionsSnapshot.documents {
                if let suggestion = try? doc.data(as: SmartSuggestionFirestore.self) {
                    let smartSuggestion = SmartSuggestion(
                        id: doc.documentID,
                        type: SuggestionType(rawValue: suggestion.type) ?? .optimalMeetingTime,
                        title: suggestion.title,
                        description: suggestion.description,
                        confidence: suggestion.confidence,
                        actionRequired: suggestion.actionRequired,
                        suggestedTime: suggestion.suggestedTime.map { 
                            TimeOfDay(hour: $0.hour, minute: $0.minute) 
                        },
                        affectedMembers: suggestion.affectedMembers,
                        createdAt: suggestion.createdAt.dateValue()
                    )
                    suggestions.append(smartSuggestion)
                }
            }
        } catch {
            print("Error loading smart suggestions from Firebase: \(error)")
        }
        
        
        if suggestions.isEmpty {
            suggestions = [
                SmartSuggestion(
                    id: UUID().uuidString,
                    type: .deadlineReminder,
                    title: "Upcoming Deadline",
                    description: "Mobile App project is due in 3 days - Consider scheduling a group review",
                    confidence: 0.9,
                    actionRequired: true,
                    suggestedTime: TimeOfDay(hour: 14, minute: 0),
                    affectedMembers: [],
                    createdAt: Date()
                ),
                SmartSuggestion(
                    id: UUID().uuidString,
                    type: .workloadBalance,
                    title: "Heavy Week",
                    description: "Next week you have 3 exams - Plan study sessions accordingly",
                    confidence: 0.85,
                    actionRequired: false,
                    suggestedTime: nil,
                    affectedMembers: [],
                    createdAt: Date()
                )
            ]
        }
        
        self.smartSuggestions = suggestions
    }
    
    // MARK: - Mock Data
    private func loadMockData() {
        groups = [
            CalendarGroup(
                id: "1",
                name: "Mobile Dev Team",
                description: "iOS Development Project Group",
                members: [
                    createCurrentUserMember(),
                    GroupMember(
                        id: "2",
                        name: "Sarah Johnson",
                        email: "sarah@example.com",
                        avatar: nil,
                        isAdmin: false,
                        joinedAt: Date().addingTimeInterval(-86400 * 7),
                        availability: generateMockAvailability()
                    ),
                    GroupMember(
                        id: "3",
                        name: "Mike Chen",
                        email: "mike@example.com",
                        avatar: nil,
                        isAdmin: false,
                        joinedAt: Date().addingTimeInterval(-86400 * 3),
                        availability: generateMockAvailability()
                    )
                ],
                createdAt: Date().addingTimeInterval(-86400 * 14),
                createdBy: "current_user_id",
                color: "#4ECDC4",
                inviteCode: "ABC123"
            ),
            CalendarGroup(
                id: "2",
                name: "Study Buddies",
                description: "General study group for all subjects",
                members: [
                    createCurrentUserMember(),
                    GroupMember(
                        id: "4",
                        name: "Emma Davis",
                        email: "emma@example.com",
                        avatar: nil,
                        isAdmin: false,
                        joinedAt: Date().addingTimeInterval(-86400 * 5),
                        availability: generateMockAvailability()
                    ),
                    GroupMember(
                        id: "5",
                        name: "Alex Rodriguez",
                        email: "alex@example.com",
                        avatar: nil,
                        isAdmin: true,
                        joinedAt: Date().addingTimeInterval(-86400 * 10),
                        availability: generateMockAvailability()
                    ),
                    GroupMember(
                        id: "6",
                        name: "Lisa Wong",
                        email: "lisa@example.com",
                        avatar: nil,
                        isAdmin: false,
                        joinedAt: Date().addingTimeInterval(-86400 * 2),
                        availability: generateMockAvailability()
                    )
                ],
                createdAt: Date().addingTimeInterval(-86400 * 21),
                createdBy: "5",
                color: "#FF6B6B",
                inviteCode: "XYZ789"
            ),
            CalendarGroup(
                id: "3",
                name: "Database Project",
                description: "Final project collaboration",
                members: [
                    createCurrentUserMember(),
                    GroupMember(
                        id: "7",
                        name: "David Kim",
                        email: "david@example.com",
                        avatar: nil,
                        isAdmin: false,
                        joinedAt: Date().addingTimeInterval(-86400 * 4),
                        availability: generateMockAvailability()
                    )
                ],
                createdAt: Date().addingTimeInterval(-86400 * 7),
                createdBy: "current_user_id",
                color: "#45B7D1",
                inviteCode: "DEF456"
            )
        ]
    }
}

// MARK: - Firebase Models
struct CalendarGroupFirestore: Codable {
    let name: String
    let ownerId: String
    let members: [String] // Array de User IDs
    let createdAt: Timestamp
    let description: String
    let color: String
    let inviteCode: String? 
}

struct UserFirestore: Codable {
    let email: String
    let nick: String?
    let uid: String?
    let avatar: String?
    
    // Computed property to get display name
    var displayName: String {
        return nick ?? email.components(separatedBy: "@").first ?? "Usuario"
    }
}

struct GroupEventFirestore: Codable {
    let title: String
    let createdBy: String
    let timestamp: Timestamp
    let type: String
    let description: String?
}

struct SmartSuggestionFirestore: Codable {
    let type: String
    let title: String
    let description: String
    let confidence: Double
    let actionRequired: Bool
    let suggestedTime: TimeOfDayFirestore?
    let affectedMembers: [String]
    let createdAt: Timestamp
}

struct TimeOfDayFirestore: Codable {
    let hour: Int
    let minute: Int
}

// MARK: - Firebase Conversion Methods
extension SharedCalendarService {
    
    private func convertFirestoreGroupToCalendarGroup(_ firestoreGroup: CalendarGroupFirestore, documentId: String) async -> CalendarGroup {
        
        var members: [GroupMember] = []
        
        for memberId in firestoreGroup.members {
            if let member = await loadUserData(userId: memberId) {
                let groupMember = GroupMember(
                    id: memberId,
                    name: member.displayName,
                    email: member.email,
                    avatar: member.avatar,
                    isAdmin: memberId == firestoreGroup.ownerId,
                    joinedAt: firestoreGroup.createdAt.dateValue(),
                    availability: generateMockAvailability() 
                )
                members.append(groupMember)
            }
        }
        
        return CalendarGroup(
            id: documentId,
            name: firestoreGroup.name,
            description: firestoreGroup.description,
            members: members,
            createdAt: firestoreGroup.createdAt.dateValue(),
            createdBy: firestoreGroup.ownerId,
            color: firestoreGroup.color,
            inviteCode: firestoreGroup.inviteCode
        )
    }
    
    private func loadUserData(userId: String) async -> UserFirestore? {
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            if userDoc.exists, let data = userDoc.data() {
                // Manual parsing to handle missing fields gracefully
                let email = data["email"] as? String ?? "user@example.com"
                let nick = data["nick"] as? String
                let uid = data["uid"] as? String
                let avatar = data["avatar"] as? String
                
                print("Loaded user data for \(userId): email=\(email), nick=\(nick ?? "nil")")
                
                return UserFirestore(
                    email: email,
                    nick: nick,
                    uid: uid,
                    avatar: avatar
                )
            } else {
                print("User document doesn't exist for \(userId)")
                return nil
            }
        } catch {
            print("Error loading user data for \(userId): \(error)")
            return nil
        }
    }
    
    private func getCurrentUserData() async -> UserFirestore {
        if let userData = await loadUserData(userId: currentUserId) {
            return userData
        } else {
            
            let currentUserEmail = Auth.auth().currentUser?.email ?? "user@example.com"
            return UserFirestore(
                email: currentUserEmail,
                nick: currentUserEmail.components(separatedBy: "@").first,
                uid: currentUserId,
                avatar: nil
            )
        }
    }
    
    private func createSampleGroupsInFirebase() async {
        
        let sampleGroups = [
            (name: "Mobile Dev Team", description: "iOS Development Project Group"),
            (name: "Study Group - Algorithms", description: "Data Structures and Algorithms Study")
        ]
        
        for group in sampleGroups {
            await createGroup(name: group.name, description: group.description)
        }
    }
}