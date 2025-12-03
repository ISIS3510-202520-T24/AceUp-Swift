//
//  SharedCalendarViewModel.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class SharedCalendarViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var groups: [CalendarGroup] = []
    @Published var selectedGroup: CalendarGroup?
    @Published var sharedSchedule: SharedSchedule?
    @Published var smartSuggestions: [SmartSuggestion] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingCreateGroup: Bool = false
    @Published var showingJoinGroup: Bool = false
    @Published var showingGroupDetails: Bool = false
    
    // MARK: - Form Properties
    @Published var newGroupName: String = ""
    @Published var newGroupDescription: String = ""
    @Published var joinGroupCode: String = ""
    
    // MARK: - Private Properties
    private let sharedCalendarService = SharedCalendarService()
    private let coreDataProvider = CoreDataSharedCalendarDataProvider()
    private let syncManager = DataSynchronizationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var totalGroups: Int {
        groups.count
    }
    
    var activeGroups: [CalendarGroup] {
        groups.filter { group in
            group.members.contains { $0.id == "current_user_id" }
        }
    }
    
    var recentSuggestions: [SmartSuggestion] {
        smartSuggestions.prefix(3).map { $0 }
    }
    
    // MARK: - Initialization
    init() {
        setupBindings()
        loadGroups()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        sharedCalendarService.$groups
            .receive(on: DispatchQueue.main)
            .assign(to: &$groups)
        
        sharedCalendarService.$sharedSchedule
            .receive(on: DispatchQueue.main)
            .assign(to: &$sharedSchedule)
        
        sharedCalendarService.$smartSuggestions
            .receive(on: DispatchQueue.main)
            .assign(to: &$smartSuggestions)
        
        sharedCalendarService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        sharedCalendarService.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
    }
    
    // MARK: - Public Methods
    func loadGroups() {
        // Groups are loaded from the service initialization
        // In a real app, this would trigger a network call
    }
    
    func selectGroup(_ group: CalendarGroup) {
        selectedGroup = group
        sharedCalendarService.currentGroup = group
        
        Task {
            await sharedCalendarService.generateSharedSchedule(for: group)
        }
    }
    
    func createGroup() {
        guard !newGroupName.isEmpty else {
            errorMessage = "Group name is required"
            return
        }
        
        // Sanitize inputs
        let sanitizedName = InputValidation.sanitizeGroupName(newGroupName)
        let sanitizedDescription = InputValidation.sanitizeDescription(newGroupDescription)
        
        Task {
            do {
                try await sharedCalendarService.createGroup(
                    name: sanitizedName,
                    description: sanitizedDescription
                )
                
                // Reset form
                newGroupName = ""
                newGroupDescription = ""
                showingCreateGroup = false
            } catch {
                errorMessage = "Failed to create group: \(error.localizedDescription)"
            }
        }
    }
    
    func joinGroup() {
        guard !joinGroupCode.isEmpty else {
            errorMessage = "Group code is required"
            return
        }
        
        Task {
            do {
                try await sharedCalendarService.joinGroup(groupId: joinGroupCode)
                
                // Reset form
                joinGroupCode = ""
                showingJoinGroup = false
            } catch {
                errorMessage = "Failed to join group: \(error.localizedDescription)"
            }
        }
    }
    
    func leaveGroup(_ group: CalendarGroup) {
        Task {
            do {
                try await sharedCalendarService.leaveGroup(groupId: group.id)
                
                if selectedGroup?.id == group.id {
                    selectedGroup = nil
                }
            } catch {
                errorMessage = "Failed to leave group: \(error.localizedDescription)"
            }
        }
    }
    
    func refreshSelectedGroup() {
        guard let group = selectedGroup else { return }
        
        Task {
            await sharedCalendarService.generateSharedSchedule(for: group)
        }
    }
    
    func dismissSuggestion(_ suggestion: SmartSuggestion) {
        smartSuggestions.removeAll { $0.id == suggestion.id }
    }
    
    func acceptSuggestion(_ suggestion: SmartSuggestion) {
        // Handle suggestion acceptance based on type
        switch suggestion.type {
        case .optimalMeetingTime:
            // Create a meeting event
            createMeetingFromSuggestion(suggestion)
        case .studySession:
            // Create a study session event
            createStudySessionFromSuggestion(suggestion)
        case .deadlineReminder:
            // Set reminder
            createReminderFromSuggestion(suggestion)
        default:
            break
        }
        
        dismissSuggestion(suggestion)
    }
    
    // MARK: - Private Helper Methods
    private func createMeetingFromSuggestion(_ suggestion: SmartSuggestion) {
        // In a real app, this would create a calendar event
        print("Creating meeting from suggestion: \(suggestion.title)")
    }
    
    private func createStudySessionFromSuggestion(_ suggestion: SmartSuggestion) {
        // In a real app, this would create a study session event
        print("Creating study session from suggestion: \(suggestion.title)")
    }
    
    private func createReminderFromSuggestion(_ suggestion: SmartSuggestion) {
        // In a real app, this would set up a notification
        print("Creating reminder from suggestion: \(suggestion.title)")
    }
}

