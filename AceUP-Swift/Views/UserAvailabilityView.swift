//
//  UserAvailabilityView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import SwiftUI

struct UserAvailabilityView: View {
    @StateObject private var repository = FirebaseUserAvailabilityRepository()
    @State private var showingAddSlot = false
    @State private var selectedSlot: AvailabilitySlot?
    @State private var showingSlotDetails = false
    
    let onMenuTapped: () -> Void
    
    init(onMenuTapped: @escaping () -> Void = {}) {
        self.onMenuTapped = onMenuTapped
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Weekly Overview
                        weeklyOverviewSection
                        
                        // Availability Slots by Day
                        availabilityByDaySection
                        
                        // Quick Actions
                        quickActionsSection
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .onAppear {
                setupView()
            }
            .sheet(isPresented: $showingAddSlot) {
                AddAvailabilitySlotView(repository: repository) {
                    // Refresh after adding
                    Task {
                        _ = try? await repository.loadUserAvailability()
                    }
                }
            }
            .sheet(item: $selectedSlot) { slot in
                EditAvailabilitySlotView(
                    slot: slot,
                    repository: repository
                ) {
                    // Refresh after editing
                    Task {
                        _ = try? await repository.loadUserAvailability()
                    }
                    selectedSlot = nil
                }
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onMenuTapped) {
                    Image(systemName: "line.horizontal.3")
                        .font(.title2)
                        .foregroundColor(UI.navy)
                }
                
                Spacer()
                
                Text("Availability")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Button(action: { showingAddSlot = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(UI.primary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Divider()
        }
        .background(.white)
    }
    
    // MARK: - Weekly Overview Section
    private var weeklyOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Overview")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            // Visual representation of weekly availability
            weeklyAvailabilityGrid
            
            // Stats
            availabilityStats
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private var weeklyAvailabilityGrid: some View {
        VStack(spacing: 8) {
            // Days of week header
            HStack {
                ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Time slots grid (simplified - showing morning, afternoon, evening)
            ForEach(["Morning", "Afternoon", "Evening"], id: \.self) { period in
                HStack(spacing: 4) {
                    Text(period)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    
                    ForEach(0..<7, id: \.self) { dayIndex in
                        Rectangle()
                            .fill(availabilityColor(for: dayIndex, period: period))
                            .frame(height: 20)
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
    
    private var availabilityStats: some View {
        HStack(spacing: 16) {
            statCard(
                title: "Total Hours",
                value: "\\(Int(totalAvailableHours))",
                icon: "clock",
                color: UI.primary
            )
            
            statCard(
                title: "Free Slots",
                value: "\\(freeSlots.count)",
                icon: "calendar",
                color: .green
            )
            
            statCard(
                title: "Busy Slots",
                value: "\\(busySlots.count)",
                icon: "exclamationmark.circle",
                color: .orange
            )
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.headline)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Availability by Day Section
    private var availabilityByDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Schedule")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            ForEach(0..<7, id: \.self) { dayIndex in
                dayScheduleCard(for: dayIndex)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private func dayScheduleCard(for dayIndex: Int) -> some View {
        let dayName = Calendar.current.weekdaySymbols[dayIndex]
        let daySlots = repository.currentUserAvailability.filter { $0.dayOfWeek == dayIndex }
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Text("\(daySlots.count) slot\(daySlots.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if daySlots.isEmpty {
                Text("No availability set")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .italic()
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(daySlots.sorted(by: { $0.startTime.hour < $1.startTime.hour })) { slot in
                        availabilitySlotRow(slot)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
    
    private func availabilitySlotRow(_ slot: AvailabilitySlot) -> some View {
        Button(action: {
            selectedSlot = slot
        }) {
            HStack(spacing: 8) {
                // Type indicator
                Circle()
                    .fill(typeColor(slot.type))
                    .frame(width: 8, height: 8)
                
                // Time
                Text("\\(slot.startTime.timeString) - \\(slot.endTime.timeString)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                // Title if available
                if let title = slot.title, !title.isEmpty {
                    Text("• \\(title)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Priority
                priorityBadge(slot.priority)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func priorityBadge(_ priority: Priority) -> some View {
        Text(priority.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(priorityColor(priority).opacity(0.2))
            )
            .foregroundColor(priorityColor(priority))
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                quickActionButton(
                    title: "Set Work Hours",
                    icon: "briefcase",
                    color: UI.primary
                ) {
                    setDefaultWorkHours()
                }
                
                quickActionButton(
                    title: "Clear All",
                    icon: "trash",
                    color: .red
                ) {
                    clearAllAvailability()
                }
                
                quickActionButton(
                    title: "Copy Previous Week",
                    icon: "doc.on.doc",
                    color: .orange
                ) {
                    copyPreviousWeek()
                }
                
                quickActionButton(
                    title: "Import Calendar",
                    icon: "square.and.arrow.down",
                    color: .green
                ) {
                    importFromCalendar()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    private func setupView() {
        Task {
            repository.startRealtimeListener()
            _ = try? await repository.loadUserAvailability()
        }
    }
    
    private func availabilityColor(for dayIndex: Int, period: String) -> Color {
        let slots = repository.currentUserAvailability.filter { $0.dayOfWeek == dayIndex }
        
        let timeRange: ClosedRange<Int>
        switch period {
        case "Morning":
            timeRange = 6...11
        case "Afternoon":
            timeRange = 12...17
        case "Evening":
            timeRange = 18...22
        default:
            return Color(.systemGray5)
        }
        
        let hasAvailability = slots.contains { slot in
            timeRange.contains(slot.startTime.hour) || timeRange.contains(slot.endTime.hour)
        }
        
        if hasAvailability {
            let freeSlots = slots.filter { $0.type == .free && (timeRange.contains($0.startTime.hour) || timeRange.contains($0.endTime.hour)) }
            return freeSlots.isEmpty ? .orange : .green
        } else {
            return Color(.systemGray5)
        }
    }
    
    private func typeColor(_ type: AvailabilityType) -> Color {
        switch type {
        case .free:
            return .green
        case .busy:
            return .orange
        case .tentative:
            return .yellow
        case .lecture:
            return .blue
        case .exam:
            return .red
        case .assignment:
            return .purple
        case .meeting:
            return .cyan
        case .personal:
            return .mint
        }
    }
    
    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }
    
    private var totalAvailableHours: Double {
        repository.currentUserAvailability.reduce(0) { total, slot in
            let duration = slot.endTime.hour - slot.startTime.hour + (slot.endTime.minute - slot.startTime.minute) / 60
            return total + Double(duration)
        }
    }
    
    private var freeSlots: [AvailabilitySlot] {
        repository.currentUserAvailability.filter { $0.type == .free }
    }
    
    private var busySlots: [AvailabilitySlot] {
        repository.currentUserAvailability.filter { $0.type != .free }
    }
    
    // MARK: - Quick Actions
    
    private func setDefaultWorkHours() {
        let defaultSlots = repository.generateDefaultAvailability()
        
        Task {
            _ = try? await repository.updateUserAvailability(defaultSlots)
        }
    }
    
    private func clearAllAvailability() {
        Task {
            _ = try? await repository.updateUserAvailability([])
        }
    }
    
    private func copyPreviousWeek() {
        // For demo purposes, just duplicate current availability
        let duplicatedSlots = repository.currentUserAvailability + repository.currentUserAvailability.map { slot in
            AvailabilitySlot(
                id: UUID().uuidString,
                dayOfWeek: slot.dayOfWeek,
                startTime: slot.startTime,
                endTime: slot.endTime,
                title: slot.title,
                type: slot.type,
                priority: slot.priority
            )
        }
        
        Task {
            _ = try? await repository.updateUserAvailability(Array(Set(duplicatedSlots))) // Remove duplicates
        }
    }
    
    private func importFromCalendar() {
        // TODO: Implement calendar import functionality
        // This would integrate with iOS Calendar framework
    }
}

#Preview {
    UserAvailabilityView()
}