//
//  EditAvailabilitySlotView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import SwiftUI

struct EditAvailabilitySlotView: View {
    let slot: AvailabilitySlot
    @ObservedObject var repository: FirebaseUserAvailabilityRepository
    let onSave: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedDayOfWeek: Int
    @State private var startTime: TimeOfDay
    @State private var endTime: TimeOfDay
    @State private var title: String
    @State private var availabilityType: AvailabilityType
    @State private var priority: Priority
    
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    private let weekdays = Calendar.current.weekdaySymbols
    
    init(slot: AvailabilitySlot, repository: FirebaseUserAvailabilityRepository, onSave: @escaping () -> Void) {
        self.slot = slot
        self.repository = repository
        self.onSave = onSave
        
        // Initialize state from slot
        _selectedDayOfWeek = State(initialValue: slot.dayOfWeek)
        _startTime = State(initialValue: slot.startTime)
        _endTime = State(initialValue: slot.endTime)
        _title = State(initialValue: slot.title ?? "")
        _availabilityType = State(initialValue: slot.type)
        _priority = State(initialValue: slot.priority)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Day Selection
                daySelectionSection
                
                // Time Selection
                timeSelectionSection
                
                // Details
                detailsSection
                
                // Type and Priority
                typeAndPrioritySection
                
                // Delete Section
                deleteSection
            }
            .navigationTitle("Edit Availability")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(isSaving ? "Saving..." : "Save") {
                    saveAvailabilitySlot()
                }
                .disabled(isSaving || !isValidTimeRange)
            )
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Availability Slot", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteSlot()
                }
            } message: {
                Text("Are you sure you want to delete this availability slot? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Form Sections
    
    private var daySelectionSection: some View {
        Section(header: Text("Day of Week")) {
            Picker("Day", selection: $selectedDayOfWeek) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, day in
                    Text(day).tag(index)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
        }
    }
    
    private var timeSelectionSection: some View {
        Section(header: Text("Time Range")) {
            // Start Time
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TimePickerView(time: $startTime)
            }
            
            // End Time
            VStack(alignment: .leading, spacing: 8) {
                Text("End Time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TimePickerView(time: $endTime)
            }
            
            // Duration display
            if isValidTimeRange {
                HStack {
                    Text("Duration:")
                    Spacer()
                    Text(durationText)
                        .foregroundColor(UI.primary)
                        .fontWeight(.medium)
                }
                .font(.caption)
            }
        }
    }
    
    private var detailsSection: some View {
        Section(header: Text("Details")) {
            TextField("Title (optional)", text: $title)
                .placeholder(when: title.isEmpty) {
                    Text("e.g., Study Time, Work Hours, Available")
                        .foregroundColor(.gray)
                }
        }
    }
    
    private var typeAndPrioritySection: some View {
        Section(header: Text("Type & Priority")) {
            // Availability Type
            Picker("Type", selection: $availabilityType) {
                ForEach(AvailabilityType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.iconName)
                        Text(type.displayName)
                    }
                    .tag(type)
                }
            }
            
            // Priority
            Picker("Priority", selection: $priority) {
                ForEach(Priority.allCases, id: \.self) { priority in
                    HStack {
                        Circle()
                            .fill(priorityColor(priority))
                            .frame(width: 12, height: 12)
                        Text(priority.displayName)
                    }
                    .tag(priority)
                }
            }
            
            // Type description
            Text(availabilityType.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var deleteSection: some View {
        Section {
            Button(action: {
                showingDeleteAlert = true
            }) {
                HStack {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                    }
                    
                    Text(isDeleting ? "Deleting..." : "Delete Availability Slot")
                }
                .foregroundColor(.red)
            }
            .disabled(isDeleting)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isValidTimeRange: Bool {
        startTime.totalMinutes < endTime.totalMinutes
    }
    
    private var durationText: String {
        guard isValidTimeRange else { return "Invalid range" }
        
        let durationMinutes = endTime.totalMinutes - startTime.totalMinutes
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Helper Methods
    
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
    
    private func saveAvailabilitySlot() {
        guard isValidTimeRange else {
            errorMessage = "End time must be after start time"
            showingError = true
            return
        }
        
        // Check for overlapping slots (excluding current slot)
        let existingSlots = repository.currentUserAvailability.filter { 
            $0.dayOfWeek == selectedDayOfWeek && $0.id != slot.id
        }
        let hasOverlap = existingSlots.contains { existingSlot in
            let newStart = startTime.totalMinutes
            let newEnd = endTime.totalMinutes
            let existingStart = existingSlot.startTime.totalMinutes
            let existingEnd = existingSlot.endTime.totalMinutes
            
            return (newStart < existingEnd && newEnd > existingStart)
        }
        
        if hasOverlap {
            errorMessage = "This time slot overlaps with an existing availability slot"
            showingError = true
            return
        }
        
        isSaving = true
        
        let updatedSlot = AvailabilitySlot(
            id: slot.id, // Keep the same ID
            dayOfWeek: selectedDayOfWeek,
            startTime: startTime,
            endTime: endTime,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : title.trimmingCharacters(in: .whitespacesAndNewlines),
            type: availabilityType,
            priority: priority
        )
        
        Task {
            do {
                // Update by removing old and adding new
                var currentSlots = repository.currentUserAvailability
                currentSlots.removeAll { $0.id == slot.id }
                currentSlots.append(updatedSlot)
                
                try await repository.updateUserAvailability(currentSlots)
                
                await MainActor.run {
                    isSaving = false
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to update availability slot: \\(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func deleteSlot() {
        isDeleting = true
        
        Task {
            do {
                try await repository.removeAvailabilitySlot(id: slot.id)
                
                await MainActor.run {
                    isDeleting = false
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = "Failed to delete availability slot: \\(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    EditAvailabilitySlotView(
        slot: AvailabilitySlot(
            id: "1",
            dayOfWeek: 1, // Monday
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 17, minute: 0),
            title: "Work Hours",
            type: .free,
            priority: .medium
        ),
        repository: FirebaseUserAvailabilityRepository()
    ) {
        // onSave
    }
}