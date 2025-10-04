//
//  SharedCalendarService.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

import Foundation
import Combine

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
    private let baseURL = "https://api.aceup.app"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        loadMockData()
        generateSmartSuggestions()
    }
    
    // MARK: - Group Management
    func createGroup(name: String, description: String, isPublic: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        
        let newGroup = CalendarGroup(
            id: UUID().uuidString,
            name: name,
            description: description,
            members: [createCurrentUserMember()],
            createdAt: Date(),
            createdBy: "current_user_id",
            color: generateRandomColor(),
            isPublic: isPublic
        )
        
        groups.append(newGroup)
        await generateSharedSchedule(for: newGroup)
    }
    
    func joinGroup(groupId: String, inviteCode: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Mock adding user to existing group
        if let groupIndex = groups.firstIndex(where: { $0.id == groupId }) {
            let newMember = createCurrentUserMember()
            groups[groupIndex] = CalendarGroup(
                id: groups[groupIndex].id,
                name: groups[groupIndex].name,
                description: groups[groupIndex].description,
                members: groups[groupIndex].members + [newMember],
                createdAt: groups[groupIndex].createdAt,
                createdBy: groups[groupIndex].createdBy,
                color: groups[groupIndex].color,
                isPublic: groups[groupIndex].isPublic
            )
        }
    }
    
    func leaveGroup(groupId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        groups.removeAll { $0.id == groupId }
        
        if currentGroup?.id == groupId {
            currentGroup = nil
            sharedSchedule = nil
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
                if availability.type == .busy || availability.type == .lecture || availability.type == .exam {
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
                if availability.type != .free && timeSlot.start >= availability.startTime && timeSlot.end <= availability.endTime {
                    return MemberConflict(
                        id: UUID().uuidString,
                        memberId: member.id,
                        memberName: member.name,
                        conflictType: availability.type,
                        conflictTitle: availability.title ?? availability.type.displayName,
                        canBeRescheduled: availability.type == .meeting || availability.type == .assignment,
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
                type: .lecture,
                priority: .high
            ),
            AvailabilitySlot(
                id: UUID().uuidString,
                dayOfWeek: 1,
                startTime: TimeOfDay(hour: 14, minute: 0),
                endTime: TimeOfDay(hour: 16, minute: 0),
                title: "Software Architecture",
                type: .lecture,
                priority: .high
            ),
            // Tuesday - Free time
            AvailabilitySlot(
                id: UUID().uuidString,
                dayOfWeek: 2,
                startTime: TimeOfDay(hour: 10, minute: 0),
                endTime: TimeOfDay(hour: 18, minute: 0),
                title: "Available",
                type: .free,
                priority: .low
            ),
            // Wednesday - Mixed
            AvailabilitySlot(
                id: UUID().uuidString,
                dayOfWeek: 3,
                startTime: TimeOfDay(hour: 8, minute: 0),
                endTime: TimeOfDay(hour: 12, minute: 0),
                title: "Database Systems",
                type: .lecture,
                priority: .high
            ),
            AvailabilitySlot(
                id: UUID().uuidString,
                dayOfWeek: 3,
                startTime: TimeOfDay(hour: 15, minute: 0),
                endTime: TimeOfDay(hour: 17, minute: 0),
                title: "Project Meeting",
                type: .meeting,
                priority: .medium
            )
        ]
    }
    
    private func generateRandomColor() -> String {
        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FECA57", "#FF9FF3", "#54A0FF"]
        return colors.randomElement() ?? "#4ECDC4"
    }
    
    private func generateSmartSuggestions() {
        // Generate general smart suggestions
        smartSuggestions = [
            SmartSuggestion(
                id: UUID().uuidString,
                type: .deadlineReminder,
                title: "Upcoming Deadline Alert",
                description: "Mobile App project due in 3 days - Consider scheduling group review",
                confidence: 0.9,
                actionRequired: true,
                suggestedTime: TimeOfDay(hour: 14, minute: 0),
                affectedMembers: [],
                createdAt: Date()
            ),
            SmartSuggestion(
                id: UUID().uuidString,
                type: .workloadBalance,
                title: "Heavy Week Ahead",
                description: "Next week has 3 exams - Plan study sessions accordingly",
                confidence: 0.85,
                actionRequired: false,
                suggestedTime: nil,
                affectedMembers: [],
                createdAt: Date()
            )
        ]
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
                isPublic: false
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
                isPublic: true
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
                        joinedAt: Date().addingTimeInterval(-86400),
                        availability: generateMockAvailability()
                    )
                ],
                createdAt: Date().addingTimeInterval(-86400 * 7),
                createdBy: "current_user_id",
                color: "#45B7D1",
                isPublic: false
            )
        ]
    }
}