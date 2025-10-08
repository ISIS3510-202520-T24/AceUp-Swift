//
//  AddAvailabilitySlotView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import SwiftUI

struct AddAvailabilitySlotView: View {
    @ObservedObject var repository: FirebaseUserAvailabilityRepository
    let onSave: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedDayOfWeek = 1 // Monday by default
    @State private var startTime = TimeOfDay(hour: 9, minute: 0)
    @State private var endTime = TimeOfDay(hour: 17, minute: 0)
    @State private var title = ""
    @State private var availabilityType: AvailabilityType = .free
    @State private var priority: Priority = .medium
    
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    private let weekdays = Calendar.current.weekdaySymbols
    
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
            }
            .navigationTitle("Add Availability")
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
        
        // Check for overlapping slots
        let existingSlots = repository.currentUserAvailability.filter { $0.dayOfWeek == selectedDayOfWeek }
        let hasOverlap = existingSlots.contains { slot in
            let newStart = startTime.totalMinutes
            let newEnd = endTime.totalMinutes
            let existingStart = slot.startTime.totalMinutes
            let existingEnd = slot.endTime.totalMinutes
            
            return (newStart < existingEnd && newEnd > existingStart)
        }
        
        if hasOverlap {
            errorMessage = "This time slot overlaps with an existing availability slot"
            showingError = true
            return
        }
        
        isSaving = true
        
        let newSlot = AvailabilitySlot(
            id: UUID().uuidString,
            dayOfWeek: selectedDayOfWeek,
            startTime: startTime,
            endTime: endTime,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : title.trimmingCharacters(in: .whitespacesAndNewlines),
            type: availabilityType,
            priority: priority
        )
        
        Task {
            do {
                try await repository.addAvailabilitySlot(newSlot)
                
                await MainActor.run {
                    isSaving = false
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save availability slot: \\(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Time Picker View
struct TimePickerView: View {
    @Binding var time: TimeOfDay
    
    var body: some View {
        HStack {
            // Hour picker
            Picker("Hour", selection: $time.hour) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(String(format: "%02d", hour)).tag(hour)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 60)
            .clipped()
            
            Text(":")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Minute picker
            Picker("Minute", selection: $time.minute) {
                ForEach(Array(stride(from: 0, to: 60, by: 15)), id: \.self) { minute in
                    Text(String(format: "%02d", minute)).tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 60)
            .clipped()
            
            Spacer()
            
            // Time display
            Text(time.timeString)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(UI.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
        }
    }
}

// MARK: - Extensions
extension TimeOfDay {
    var totalMinutes: Int {
        hour * 60 + minute
    }
}

extension AvailabilityType {
    var iconName: String {
        switch self {
        case .free:
            return "checkmark.circle"
        case .busy:
            return "exclamationmark.circle"
        case .tentative:
            return "questionmark.circle"
        case .lecture:
            return "book"
        case .exam:
            return "doc.text"
        case .assignment:
            return "pencil.circle"
        case .meeting:
            return "person.2"
        case .personal:
            return "person.circle"
        }
    }
    
    var description: String {
        switch self {
        case .free:
            return "Available for meetings and appointments"
        case .busy:
            return "Unavailable for new commitments"
        case .tentative:
            return "Tentatively available, may change"
        case .lecture:
            return "Attending class or lecture"
        case .exam:
            return "Taking an exam or test"
        case .assignment:
            return "Working on assignments"
        case .meeting:
            return "In a meeting or appointment"
        case .personal:
            return "Personal time or activities"
        }
    }
}

// MARK: - View Extension for Placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    AddAvailabilitySlotView(
        repository: FirebaseUserAvailabilityRepository()
    ) {
        // onSave
    }
}