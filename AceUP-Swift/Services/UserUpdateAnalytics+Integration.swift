//
//  UserUpdateAnalytics+Integration.swift
//  AceUP-Swift
//
//  Integration hooks for BQ 5.1 analytics across existing services
//
//  Created by Ángel Farfán Arcila on 7/11/25.
//

import Foundation

// MARK: - UserProfileManager Integration

extension UserProfileManager {
    
    /// Start tracking profile update session
    private func startProfileUpdateTracking() -> String {
        guard let userId = currentUserId else { return "" }
        return UserUpdateAnalytics.shared.startProfileUpdate(userId: userId)
    }
    
    /// Enhanced update profile with analytics tracking
    func updateProfileWithTracking(
        displayName: String? = nil,
        university: String? = nil,
        studyProgram: String? = nil,
        academicYear: String? = nil
    ) async {
        guard let userId = currentUserId else { return }
        
        // Start tracking
        let sessionId = UserUpdateAnalytics.shared.startProfileUpdate(userId: userId)
        
        // Track interactions
        if displayName != nil { UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) }
        if university != nil { UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) }
        if studyProgram != nil { UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) }
        if academicYear != nil { UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) }
        
        // Perform the update
        await updateProfile(
            displayName: displayName,
            university: university,
            studyProgram: studyProgram,
            academicYear: academicYear
        )
        
        // Track fields modified
        var fieldsModified: [String] = []
        if displayName != nil { fieldsModified.append("displayName") }
        if university != nil { fieldsModified.append("university") }
        if studyProgram != nil { fieldsModified.append("studyProgram") }
        if academicYear != nil { fieldsModified.append("academicYear") }
        
        // Complete tracking
        await UserUpdateAnalytics.shared.completeUpdateSession(
            sessionId: sessionId,
            fieldsModified: fieldsModified
        )
    }
    
    /// Enhanced profile image update with analytics tracking
    func updateProfileImageWithTracking(_ image: UIImage) async {
        guard let userId = currentUserId else { return }
        
        // Start tracking
        let sessionId = UserUpdateAnalytics.shared.startUpdateSession(
            updateType: .profileImage,
            userId: userId
        )
        
        // Track interaction
        UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId)
        
        // Perform the update
        await updateProfileImage(image)
        
        // Complete tracking
        await UserUpdateAnalytics.shared.completeUpdateSession(
            sessionId: sessionId,
            fieldsModified: ["profileImage"]
        )
    }
}

// MARK: - AssignmentRepository Integration

extension AssignmentRepository {
    
    /// Enhanced create assignment with analytics tracking
    func createAssignmentWithTracking(_ assignment: Assignment) async throws {
        guard let userId = getCurrentUserId() else { return }
        
        // Start tracking
        let sessionId = UserUpdateAnalytics.shared.startAssignmentUpdate(userId: userId)
        
        // Track fields as interactions
        UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) // title
        UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) // courseId
        UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) // dueDate
        if assignment.description != nil { UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) }
        if assignment.estimatedHours != nil { UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) }
        if !assignment.tags.isEmpty { UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) }
        if !assignment.subtasks.isEmpty { UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) }
        
        do {
            // Perform the creation
            try await createAssignment(assignment)
            
            // Track fields modified
            var fieldsModified = ["title", "courseId", "dueDate", "weight", "priority"]
            if assignment.description != nil { fieldsModified.append("description") }
            if assignment.estimatedHours != nil { fieldsModified.append("estimatedHours") }
            if !assignment.tags.isEmpty { fieldsModified.append("tags") }
            if !assignment.subtasks.isEmpty { fieldsModified.append("subtasks") }
            
            // Complete tracking
            await UserUpdateAnalytics.shared.completeUpdateSession(
                sessionId: sessionId,
                fieldsModified: fieldsModified
            )
            
        } catch {
            // Abandon tracking on error
            await UserUpdateAnalytics.shared.abandonUpdateSession(sessionId: sessionId)
            throw error
        }
    }
    
    /// Enhanced update assignment with analytics tracking
    func updateAssignmentWithTracking(_ assignment: Assignment) async throws {
        guard let userId = getCurrentUserId() else { return }
        
        // Start tracking
        let sessionId = UserUpdateAnalytics.shared.startAssignmentUpdate(userId: userId)
        
        // Track interaction for the update
        UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId)
        
        do {
            // Perform the update
            try await updateAssignment(assignment)
            
            // Track all fields as potentially modified
            let fieldsModified = ["title", "description", "dueDate", "weight", "priority", "status"]
            
            // Complete tracking
            await UserUpdateAnalytics.shared.completeUpdateSession(
                sessionId: sessionId,
                fieldsModified: fieldsModified
            )
            
        } catch {
            // Abandon tracking on error
            await UserUpdateAnalytics.shared.abandonUpdateSession(sessionId: sessionId)
            throw error
        }
    }
    
    /// Helper to get current user ID
    private func getCurrentUserId() -> String? {
        // This should be implemented based on your auth service
        return FirebaseAuth.Auth.auth().currentUser?.uid
    }
}

// MARK: - SharedCalendarService Integration

extension SharedCalendarService {
    
    /// Enhanced create calendar group with analytics tracking
    func createGroupWithTracking(
        name: String,
        description: String,
        members: [String],
        color: String,
        userId: String
    ) async throws -> CalendarGroup {
        
        // Start tracking
        let sessionId = UserUpdateAnalytics.shared.startUpdateSession(
            updateType: .sharedCalendar,
            userId: userId
        )
        
        // Track interactions
        UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) // name
        UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) // description
        members.forEach { _ in UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) }
        
        do {
            // Perform the creation
            let group = try await createGroup(
                name: name,
                description: description,
                members: members,
                color: color,
                userId: userId
            )
            
            // Track fields modified
            let fieldsModified = ["name", "description", "members", "color"]
            
            // Complete tracking
            await UserUpdateAnalytics.shared.completeUpdateSession(
                sessionId: sessionId,
                fieldsModified: fieldsModified
            )
            
            return group
            
        } catch {
            // Abandon tracking on error
            await UserUpdateAnalytics.shared.abandonUpdateSession(sessionId: sessionId)
            throw error
        }
    }
    
    /// Enhanced update availability with analytics tracking
    func updateAvailabilityWithTracking(
        userId: String,
        slots: [AvailabilitySlot]
    ) async throws {
        
        // Start tracking
        let sessionId = UserUpdateAnalytics.shared.startAvailabilityUpdate(userId: userId)
        
        // Track interactions based on number of slots
        slots.forEach { _ in UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId) }
        
        do {
            // Perform the update
            try await updateAvailability(userId: userId, slots: slots)
            
            // Complete tracking
            await UserUpdateAnalytics.shared.completeUpdateSession(
                sessionId: sessionId,
                fieldsModified: ["availabilitySlots"]
            )
            
        } catch {
            // Abandon tracking on error
            await UserUpdateAnalytics.shared.abandonUpdateSession(sessionId: sessionId)
            throw error
        }
    }
}

// MARK: - UserPreferencesManager Integration

extension UserPreferencesManager {
    
    /// Enhanced preferences update with analytics tracking
    func updatePreferencesWithTracking(userId: String) async {
        
        // Start tracking
        let sessionId = UserUpdateAnalytics.shared.startUpdateSession(
            updateType: .preferences,
            userId: userId
        )
        
        // Track interaction
        UserUpdateAnalytics.shared.trackInteraction(sessionId: sessionId)
        
        // Note: UserPreferencesManager auto-saves on property changes via didSet
        // This is just to track the session
        
        // Complete tracking after a short delay to capture all changes
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await UserUpdateAnalytics.shared.completeUpdateSession(
            sessionId: sessionId,
            fieldsModified: ["preferences"]
        )
    }
}

// MARK: - Helper for Import

import FirebaseAuth
