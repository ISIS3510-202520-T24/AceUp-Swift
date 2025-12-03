//
//  WeekFilterView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/12/25.
//

import SwiftUI

/// Filter configuration view for Week View
struct WeekFilterView: View {
    @Binding var filter: WeekEventFilter
    let onApply: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var tempFilter: WeekEventFilter
    
    init(filter: Binding<WeekEventFilter>, onApply: @escaping () -> Void) {
        self._filter = filter
        self.onApply = onApply
        self._tempFilter = State(initialValue: filter.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Event Type Section
                Section(header: Text("Event Types")) {
                    ForEach(WeekEventType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(Color(hex: type.defaultColor))
                                .frame(width: 24)
                            
                            Text(type.displayName)
                                .foregroundColor(UI.navy)
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { tempFilter.eventTypes.contains(type) },
                                set: { isOn in
                                    if isOn {
                                        tempFilter.eventTypes.insert(type)
                                    } else {
                                        tempFilter.eventTypes.remove(type)
                                    }
                                }
                            ))
                        }
                    }
                }
                
                // Status Section
                Section(header: Text("Event Status")) {
                    ForEach([EventStatus.active, .pending, .completed, .cancelled], id: \.self) { status in
                        HStack {
                            Text(status.rawValue.capitalized)
                                .foregroundColor(UI.navy)
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { tempFilter.statuses.contains(status) },
                                set: { isOn in
                                    if isOn {
                                        tempFilter.statuses.insert(status)
                                    } else {
                                        tempFilter.statuses.remove(status)
                                    }
                                }
                            ))
                        }
                    }
                }
                
                // Display Options
                Section(header: Text("Display Options")) {
                    Toggle("Show Overlapping Events", isOn: $tempFilter.showOverlapping)
                    Toggle("Show Free Time Slots", isOn: $tempFilter.showFreeTime)
                }
                
                // Search
                Section(header: Text("Search")) {
                    TextField("Search events...", text: $tempFilter.searchQuery)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Quick Filters
                Section(header: Text("Quick Filters")) {
                    Button("Show All") {
                        tempFilter = .default
                    }
                    .foregroundColor(UI.primary)
                    
                    Button("Classes Only") {
                        tempFilter.eventTypes = [.classSession]
                    }
                    .foregroundColor(UI.primary)
                    
                    Button("Assignments & Exams") {
                        tempFilter.eventTypes = [.assignment, .exam]
                    }
                    .foregroundColor(UI.primary)
                    
                    Button("Meetings & Study Sessions") {
                        tempFilter.eventTypes = [.meeting, .study]
                    }
                    .foregroundColor(UI.primary)
                }
            }
            .navigationTitle("Filter Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        filter = tempFilter
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

/// Detail view for a week event
struct WeekEventDetailView: View {
    let event: WeekEvent
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    eventHeader
                    
                    Divider()
                    
                    // Time Info
                    timeInfoSection
                    
                    Divider()
                    
                    // Location (if available)
                    if let location = event.location {
                        locationSection(location: location)
                        Divider()
                    }
                    
                    // Description (if available)
                    if let description = event.description {
                        descriptionSection(description: description)
                        Divider()
                    }
                    
                    // Course Info (if available)
                    if let courseName = event.courseName {
                        courseInfoSection(courseName: courseName)
                        Divider()
                    }
                    
                    // Metadata
                    metadataSection
                    
                    Spacer()
                }
                .padding(20)
            }
            .background(UI.neutralLight)
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var eventHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.type.icon)
                .font(.title)
                .foregroundColor(event.uiColor)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(event.uiColor.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(UI.navy)
                
                Text(event.type.displayName)
                    .font(.subheadline)
                    .foregroundColor(UI.muted)
                
                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor(for: event.status))
                        .frame(width: 8, height: 8)
                    
                    Text(event.status.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(UI.muted)
                }
            }
        }
    }
    
    private var timeInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "clock.fill", title: "Time")
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Date", value: formatDate(event.startDate))
                InfoRow(label: "Time", value: event.timeRangeString)
                InfoRow(label: "Duration", value: "\(event.durationInMinutes) minutes")
                
                if event.isAllDay {
                    Text("All Day Event")
                        .font(.caption)
                        .foregroundColor(UI.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(UI.primary.opacity(0.1))
                        )
                }
            }
        }
    }
    
    private func locationSection(location: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "location.fill", title: "Location")
            
            Text(location)
                .font(.body)
                .foregroundColor(UI.navy)
        }
    }
    
    private func descriptionSection(description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "text.alignleft", title: "Description")
            
            Text(description)
                .font(.body)
                .foregroundColor(UI.navy)
        }
    }
    
    private func courseInfoSection(courseName: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "book.fill", title: "Course")
            
            HStack {
                Text(courseName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Circle()
                    .fill(event.uiColor)
                    .frame(width: 12, height: 12)
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "info.circle.fill", title: "Details")
            
            VStack(alignment: .leading, spacing: 8) {
                if !event.tags.isEmpty {
                    InfoRow(label: "Tags", value: event.tags.joined(separator: ", "))
                }
                
                InfoRow(label: "Priority", value: event.priority.rawValue.capitalized)
                
                if event.isOverlapping {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("This event overlaps with \(event.conflictCount) other event(s)")
                            .font(.caption)
                            .foregroundColor(UI.muted)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func statusColor(for status: EventStatus) -> Color {
        switch status {
        case .active: return .green
        case .completed: return .blue
        case .cancelled: return .red
        case .pending: return .orange
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(UI.primary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(UI.navy)
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(UI.muted)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(UI.navy)
            
            Spacer()
        }
    }
}

// MARK: - Preview

struct WeekFilterView_Previews: PreviewProvider {
    static var previews: some View {
        WeekFilterView(filter: .constant(.default), onApply: {})
    }
}

struct WeekEventDetailView_Previews: PreviewProvider {
    static var previews: some View {
        WeekEventDetailView(
            event: WeekEvent(
                title: "iOS Development",
                description: "Mobile development class covering Swift and SwiftUI",
                startDate: Date(),
                endDate: Date().addingTimeInterval(5400),
                type: .classSession,
                location: "ML-509",
                courseName: "Mobile Development",
                priority: .high
            )
        )
    }
}
