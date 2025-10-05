//
//  GroupCalendarViewModel.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25
//

import Foundation
import SwiftUI
import Combine

@MainActor
class GroupCalendarViewModel: ObservableObject {
    @Published var selectedGroup: CalendarGroup?
    @Published var selectedDate = Date()
    @Published var selectedTimeSlot: CommonFreeSlot?
    @Published var isLoading = false
    @Published var showingEventCreation = false
    @Published var commonFreeSlots: [CommonFreeSlot] = []
    @Published var conflictingSlots: [ConflictingSlot] = []
    
    private let sharedCalendarService = SharedCalendarService()
    private var cancellables = Set<AnyCancellable>()
    
    var currentWeek: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: startOfWeek)
        }
    }
    
    var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    nonisolated init() {
        Task { @MainActor in
            setupBindings()
        }
    }
    
    private func setupBindings() {
        // Update schedule when date or group changes
        Publishers.CombineLatest($selectedDate, $selectedGroup)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] date, group in
                self?.updateSchedule()
            }
            .store(in: &cancellables)
    }
    
    func setGroup(_ group: CalendarGroup) {
        selectedGroup = group
    }
    
    func selectDate(_ date: Date) {
        selectedDate = date
    }
    
    func selectTimeSlot(_ slot: CommonFreeSlot) {
        selectedTimeSlot = slot
        showingEventCreation = true
    }
    
    func previousWeek() {
        selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
    }
    
    func nextWeek() {
        selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
    }
    
    func refreshSelectedGroup() {
        updateSchedule()
    }
    
    private func updateSchedule() {
        guard let group = selectedGroup else { return }
        
        isLoading = true
        
        Task { @MainActor in
            do {
                // Simulate network delay
                try await Task.sleep(nanoseconds: 500_000_000)
                
                // Generate free slots and conflicts for the selected date
                
                commonFreeSlots = sharedCalendarService.findCommonFreeSlots(
                    for: group,
                    on: selectedDate
                )
                
                conflictingSlots = sharedCalendarService.findConflictingSlots(
                    for: group,
                    on: selectedDate
                )
                
                isLoading = false
            } catch {
                print("Error updating schedule: \(error)")
                isLoading = false
            }
        }
    }
}