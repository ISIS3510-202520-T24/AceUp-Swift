//
//  CreateCalendarEventView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import SwiftUI

struct CreateCalendarEventView: View {
    @ObservedObject var repository: FirebaseCalendarEventsRepository
    let initialDate: Date
    let onSave: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var title = ""
    @State private var description = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var eventType: AvailabilityType = .busy
    @State private var priority: Priority = .medium
    @State private var location = ""
    @State private var isShared = false
    @State private var isRecurring = false
    @State private var recurrenceFrequency: RecurrenceFrequency = .weekly
    @State private var recurrenceInterval = 1
    @State private var selectedDaysOfWeek: Set<Int> = []
    @State private var recurrenceEndDate: Date?
    @State private var hasRecurrenceEndDate = false
    @State private var reminderMinutes: [Int] = [15]
    @State private var showingReminderPicker = false
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(repository: FirebaseCalendarEventsRepository, initialDate: Date = Date(), onSave: @escaping () -> Void = {}) {
        self.repository = repository
        self.initialDate = initialDate
        self.onSave = onSave
        
        _startDate = State(initialValue: initialDate)
        _endDate = State(initialValue: Calendar.current.date(byAdding: .hour, value: 1, to: initialDate) ?? initialDate)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                basicInfoSection
                
                // Date and Time
                dateTimeSection
                
                // Event Details
                eventDetailsSection
                
                // Recurrence Settings
                if isRecurring {
                    recurrenceSection
                }
                
                // Reminders
                remindersSection
                
                // Sharing Options
                sharingSection
            }
            .navigationTitle("New Event")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveEvent()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Form Sections
    
    private var basicInfoSection: some View {
        Section(header: Text("Event Information")) {
            TextField("Event title", text: $title)
            
            TextField("Description (optional)", text: $description, axis: .vertical)
                .lineLimit(3...6)
            
            TextField("Location (optional)", text: $location)
        }
    }
    
    private var dateTimeSection: some View {
        Section(header: Text("Date & Time")) {
            DatePicker(
                "Start",
                selection: $startDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .onChange(of: startDate) { _, newValue in
                // Auto-adjust end date to maintain duration
                let duration = endDate.timeIntervalSince(startDate)
                if duration <= 0 || duration > 24 * 3600 { // If invalid or too long, set 1 hour
                    endDate = Calendar.current.date(byAdding: .hour, value: 1, to: newValue) ?? newValue
                } else {
                    endDate = newValue.addingTimeInterval(duration)
                }
            }
            
            DatePicker(
                "End",
                selection: $endDate,
                in: startDate...,
                displayedComponents: [.date, .hourAndMinute]
            )
        }
    }
    
    private var eventDetailsSection: some View {
        Section(header: Text("Event Details")) {
            Picker("Type", selection: $eventType) {
                ForEach(AvailabilityType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.iconName)
                        Text(type.displayName)
                    }
                    .tag(type)
                }
            }
            
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
            
            Toggle("Recurring Event", isOn: $isRecurring)
        }
    }
    
    private var recurrenceSection: some View {
        Section(header: Text("Recurrence")) {
            Picker("Repeat", selection: $recurrenceFrequency) {
                ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                    Text(frequency.displayName).tag(frequency)
                }
            }
            
            Stepper("Every \(recurrenceInterval) \(recurrenceFrequency.displayName.lowercased())", 
                    value: $recurrenceInterval, 
                    in: 1...30)
            
            if recurrenceFrequency == .weekly {
                weeklyRecurrenceView
            }
            
            Toggle("End Date", isOn: $hasRecurrenceEndDate)
            
            if hasRecurrenceEndDate {
                DatePicker(
                    "End Date",
                    selection: Binding(
                        get: { recurrenceEndDate ?? Calendar.current.date(byAdding: .month, value: 3, to: startDate)! },
                        set: { recurrenceEndDate = $0 }
                    ),
                    in: startDate...,
                    displayedComponents: .date
                )
            }
        }
    }
    
    private var weeklyRecurrenceView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repeat on")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                ForEach(Array(Calendar.current.shortWeekdaySymbols.enumerated()), id: \.offset) { index, day in
                    Button(action: {
                        if selectedDaysOfWeek.contains(index) {
                            selectedDaysOfWeek.remove(index)
                        } else {
                            selectedDaysOfWeek.insert(index)
                        }
                    }) {
                        Text(day)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedDaysOfWeek.contains(index) ? .white : UI.primary)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(selectedDaysOfWeek.contains(index) ? UI.primary : Color.clear)
                            )
                            .overlay(
                                Circle()
                                    .stroke(UI.primary, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
    
    private var remindersSection: some View {
        Section(header: Text("Reminders")) {
            ForEach(Array(reminderMinutes.enumerated()), id: \.offset) { index, minutes in
                HStack {
                    Text(reminderText(minutes: minutes))
                    
                    Spacer()
                    
                    Button("Remove") {
                        reminderMinutes.remove(at: index)
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                }
            }
            
            Button("Add Reminder") {
                showingReminderPicker = true
            }
            .foregroundColor(UI.primary)
        }
        .sheet(isPresented: $showingReminderPicker) {
            ReminderPickerView(selectedMinutes: Binding(
                get: { 15 },
                set: { newValue in
                    if !reminderMinutes.contains(newValue) {
                        reminderMinutes.append(newValue)
                        reminderMinutes.sort()
                    }
                }
            )) {
                showingReminderPicker = false
            }
        }
    }
    
    private var sharingSection: some View {
        Section(header: Text("Sharing"), footer: Text("Shared events will be visible to group members")) {
            Toggle("Share with group", isOn: $isShared)
            
            if isShared {
                Text("This event will be shared with your active calendar group")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
    
    private func reminderText(minutes: Int) -> String {
        if minutes == 0 {
            return "At time of event"
        } else if minutes < 60 {
            return "\(minutes) minutes before"
        } else if minutes < 1440 {
            let hours = minutes / 60
            return "\(hours) hour\(hours == 1 ? "" : "s") before"
        } else {
            let days = minutes / 1440
            return "\(days) day\(days == 1 ? "" : "s") before"
        }
    }
    
    private func saveEvent() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter an event title"
            showingError = true
            return
        }
        
        guard endDate > startDate else {
            errorMessage = "End time must be after start time"
            showingError = true
            return
        }
        
        let recurrencePattern: RecurrencePattern?
        if isRecurring {
            let daysOfWeek = recurrenceFrequency == .weekly && !selectedDaysOfWeek.isEmpty ? 
                Array(selectedDaysOfWeek) : nil
            
            recurrencePattern = RecurrencePattern(
                frequency: recurrenceFrequency,
                interval: recurrenceInterval,
                daysOfWeek: daysOfWeek,
                endDate: hasRecurrenceEndDate ? recurrenceEndDate : nil,
                occurrenceCount: nil
            )
        } else {
            recurrencePattern = nil
        }
        
        let event = CalendarEvent(
            id: UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            startTime: startDate,
            endTime: endDate,
            type: eventType,
            priority: priority,
            isShared: isShared,
            groupId: isShared ? "current_group_id" : nil, // TODO: Get actual group ID
            createdBy: "current_user_id", // TODO: Get actual user ID
            attendees: [],
            location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
            isRecurring: isRecurring,
            recurrencePattern: recurrencePattern,
            reminderMinutes: reminderMinutes.sorted()
        )
        
        Task {
            do {
                try await repository.createEvent(event)
                
                await MainActor.run {
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create event: \\(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Reminder Picker View
struct ReminderPickerView: View {
    @Binding var selectedMinutes: Int
    let onDismiss: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    private let reminderOptions = [
        (0, "At time of event"),
        (5, "5 minutes before"),
        (10, "10 minutes before"),
        (15, "15 minutes before"),
        (30, "30 minutes before"),
        (60, "1 hour before"),
        (120, "2 hours before"),
        (1440, "1 day before"),
        (2880, "2 days before"),
        (10080, "1 week before")
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(reminderOptions, id: \.0) { minutes, text in
                    Button(action: {
                        selectedMinutes = minutes
                        onDismiss()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(text)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedMinutes == minutes {
                                Image(systemName: "checkmark")
                                    .foregroundColor(UI.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reminder")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

#Preview {
    CreateCalendarEventView(
        repository: FirebaseCalendarEventsRepository(),
        initialDate: Date()
    )
}