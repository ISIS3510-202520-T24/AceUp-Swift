//
//  EventDetailsView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import SwiftUI

struct EventDetailsView: View {
    let event: CalendarEvent
    @ObservedObject let repository: FirebaseCalendarEventsRepository
    let onUpdate: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var showingEditEvent = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    headerCard
                    
                    // Details Card
                    detailsCard
                    
                    // Time and Location Card
                    timeLocationCard
                    
                    // Recurrence Card
                    if event.isRecurring {
                        recurrenceCard
                    }
                    
                    // Reminders Card
                    if !event.reminderMinutes.isEmpty {
                        remindersCard
                    }
                    
                    // Sharing Card
                    if event.isShared {
                        sharingCard
                    }
                    
                    // Action Buttons
                    actionButtons
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Event Details")
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Edit") {
                    showingEditEvent = true
                }
            )
            .sheet(isPresented: $showingEditEvent) {
                EditCalendarEventView(
                    event: event,
                    repository: repository
                ) {
                    onUpdate()
                }
            }
            .alert("Delete Event", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteEvent()
                }
            } message: {
                Text("Are you sure you want to delete this event? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Priority indicator
                Circle()
                    .fill(priorityColor(event.priority))
                    .frame(width: 12, height: 12)
                
                Text(event.priority.displayName.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(priorityColor(event.priority))
                
                Spacer()
                
                // Event type
                HStack(spacing: 4) {
                    Image(systemName: event.type.iconName)
                    Text(event.type.displayName)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            }
            
            Text(event.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            if let description = event.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Details Card
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            VStack(spacing: 12) {
                detailRow(
                    icon: "calendar",
                    title: "Date",
                    value: DateFormatter.fullDate.string(from: event.startTime)
                )
                
                detailRow(
                    icon: "clock",
                    title: "Duration",
                    value: durationText(from: event.startTime, to: event.endTime)
                )
                
                if let location = event.location, !location.isEmpty {
                    detailRow(
                        icon: "location",
                        title: "Location",
                        value: location
                    )
                }
                
                detailRow(
                    icon: "person.circle",
                    title: "Created by",
                    value: "You" // TODO: Replace with actual creator name
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Time and Location Card
    private var timeLocationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            HStack(spacing: 16) {
                // Start time
                VStack(alignment: .leading, spacing: 4) {
                    Text("Starts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(DateFormatter.timeOnly.string(from: event.startTime))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                
                // End time
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ends")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(DateFormatter.timeOnly.string(from: event.endTime))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Recurrence Card
    private var recurrenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "repeat")
                    .foregroundColor(.orange)
                Text("Recurring Event")
                    .font(.headline)
                    .foregroundColor(UI.navy)
            }
            
            if let pattern = event.recurrencePattern {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repeats \\(pattern.frequency.displayName.lowercased()) every \\(pattern.interval) \\(pattern.frequency.displayName.lowercased())")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    if let daysOfWeek = pattern.daysOfWeek, !daysOfWeek.isEmpty {
                        HStack {
                            Text("On:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(daysOfWeek.sorted(), id: \\.self) { dayIndex in
                                Text(Calendar.current.shortWeekdaySymbols[dayIndex])
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(.systemGray6))
                                    )
                            }
                        }
                    }
                    
                    if let endDate = pattern.endDate {
                        Text("Until \\(DateFormatter.mediumDate.string(from: endDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
    
    // MARK: - Reminders Card
    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell")
                    .foregroundColor(UI.primary)
                Text("Reminders")
                    .font(.headline)
                    .foregroundColor(UI.navy)
            }
            
            ForEach(event.reminderMinutes.sorted(), id: \\.self) { minutes in
                HStack {
                    Image(systemName: "bell.circle.fill")
                        .foregroundColor(UI.primary)
                        .font(.caption)
                    
                    Text(reminderText(minutes: minutes))
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
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
    
    // MARK: - Sharing Card
    private var sharingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2")
                    .foregroundColor(.green)
                Text("Shared Event")
                    .font(.headline)
                    .foregroundColor(UI.navy)
            }
            
            Text("This event is shared with your calendar group and visible to all members.")
                .font(.body)
                .foregroundColor(.secondary)
            
            if !event.attendees.isEmpty {
                Text("\\(event.attendees.count) attendee\\(event.attendees.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingEditEvent = true
            }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit Event")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(UI.primary)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button(action: {
                showingDeleteAlert = true
            }) {
                HStack {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text(isDeleting ? "Deleting..." : "Delete Event")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isDeleting)
        }
    }
    
    // MARK: - Helper Views
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(UI.primary)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
                    .foregroundColor(UI.navy)
            }
            
            Spacer()
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
        }
    }
    
    private func durationText(from startTime: Date, to endTime: Date) -> String {
        let duration = endTime.timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\\(hours)h \\(minutes)m"
        } else {
            return "\\(minutes)m"
        }
    }
    
    private func reminderText(minutes: Int) -> String {
        if minutes == 0 {
            return "At time of event"
        } else if minutes < 60 {
            return "\\(minutes) minutes before"
        } else if minutes < 1440 {
            let hours = minutes / 60
            return "\\(hours) hour\\(hours == 1 ? "" : "s") before"
        } else {
            let days = minutes / 1440
            return "\\(days) day\\(days == 1 ? "" : "s") before"
        }
    }
    
    private func deleteEvent() {
        isDeleting = true
        
        Task {
            do {
                try await repository.deleteEvent(id: event.id)
                
                await MainActor.run {
                    isDeleting = false
                    onUpdate()
                    presentationMode.wrappedValue.dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isDeleting = false
                    // Handle error - could show another alert
                }
            }
        }
    }
}

// MARK: - Date Formatters
extension DateFormatter {
    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

#Preview {
    EventDetailsView(
        event: CalendarEvent(
            id: "1",
            title: "Team Meeting",
            description: "Weekly team sync to discuss project progress and upcoming deadlines.",
            startTime: Date(),
            endTime: Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date(),
            type: .busy,
            priority: .high,
            isShared: true,
            groupId: "group1",
            createdBy: "user1",
            attendees: ["user2", "user3"],
            location: "Conference Room A",
            isRecurring: true,
            recurrencePattern: RecurrencePattern(
                frequency: .weekly,
                interval: 1,
                daysOfWeek: [1], // Monday
                endDate: nil,
                occurrenceCount: nil
            ),
            reminderMinutes: [15, 60]
        ),
        repository: FirebaseCalendarEventsRepository()
    ) {
        // onUpdate
    }
}