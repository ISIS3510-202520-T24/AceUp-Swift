//
//  AnalyticsDataView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

import SwiftUI

struct AnalyticsDataView: View {
    @StateObject private var analyticsService = AnalyticsService.shared
    @State private var selectedDataType = 0
    @State private var searchText = ""
    @State private var showingExportSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            dataTypeSelector
            
            if let studentData = analyticsService.studentData {
                dataContentView(data: studentData)
            } else {
                noDataView
            }
        }
        .searchable(text: $searchText, prompt: "Search academic data...")
        .sheet(isPresented: $showingExportSheet) {
            ExportDataSheet()
        }
        .onAppear {
            Task {
                await loadAnalyticsData()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Academic Data")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(UI.navy)
                    
                    Text("Detailed view of your academic information")
                        .font(.subheadline)
                        .foregroundColor(UI.muted)
                }
                
                Spacer()
                
                Button(action: {
                    showingExportSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(UI.primary)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var dataTypeSelector: some View {
        VStack(spacing: 12) {
            Picker("Data Type", selection: $selectedDataType) {
                Text("Events").tag(0)
                Text("Courses").tag(1)
                Text("Summary").tag(2)
                Text("Raw JSON").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
        }
        .padding(.bottom)
    }
    
    private func dataContentView(data: StudentAnalyticsData) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                switch selectedDataType {
                case 0:
                    eventsDataView(events: filteredEvents(data.events))
                case 1:
                    coursesDataView(courses: data.courses)
                case 2:
                    summaryDataView(data: data)
                case 3:
                    rawDataView(data: data)
                default:
                    eventsDataView(events: filteredEvents(data.events))
                }
            }
            .padding()
        }
    }
    
    private func eventsDataView(events: [AcademicEvent]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Academic Events",
                subtitle: "\(events.count) total events",
                icon: "calendar"
            )
            
            ForEach(events) { event in
                EventDataCard(event: event)
            }
            
            if events.isEmpty {
                emptyStateView(
                    title: "No Events Found",
                    subtitle: "No events match your search criteria"
                )
            }
        }
    }
    
    private func coursesDataView(courses: [Course]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Courses",
                subtitle: "\(courses.count) enrolled courses",
                icon: "book"
            )
            
            ForEach(courses) { course in
                CourseDataCard(course: course)
            }
        }
    }
    
    private func summaryDataView(data: StudentAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "Data Summary",
                subtitle: "Overview of your academic profile",
                icon: "chart.bar.doc.horizontal"
            )
            
            // Overview metrics
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                summaryMetric(
                    title: "Total Courses",
                    value: "\(data.courses.count)",
                    icon: "book.fill",
                    color: UI.primary
                )
                
                summaryMetric(
                    title: "Total Events",
                    value: "\(data.events.count)",
                    icon: "calendar.circle.fill",
                    color: UI.navy
                )
                
                summaryMetric(
                    title: "Pending",
                    value: "\(data.pendingEvents.count)",
                    icon: "clock.fill",
                    color: UI.warning
                )
                
                summaryMetric(
                    title: "Overdue",
                    value: "\(data.overdueEvents.count)",
                    icon: "exclamationmark.triangle.fill",
                    color: UI.accent
                )
            }
            
            // Status breakdown
            statusBreakdownView(data: data)
            
            // Priority analysis
            priorityAnalysisView(data: data)
        }
    }
    
    private func rawDataView(data: StudentAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Raw JSON Data",
                subtitle: "Complete data structure",
                icon: "curlybraces"
            )
            
            ScrollView(.horizontal, showsIndicators: true) {
                Text(formatJSON(data))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(UI.neutralDark)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(UI.neutralLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(UI.neutralMedium, lineWidth: 1)
            )
        }
    }
    
    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(UI.muted)
            
            Text("No Data Available")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            Text("Load analytics data to view details")
                .font(.body)
                .foregroundColor(UI.muted)
            
            Button("Load Data") {
                Task {
                    await loadAnalyticsData()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UI.bg)
    }
    
    // Helper views
    private func sectionHeader(title: String, subtitle: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(UI.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(UI.navy)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
            
            Spacer()
        }
    }
    
    private func summaryMetric(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            Text(title)
                .font(.caption)
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private func statusBreakdownView(data: StudentAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status Breakdown")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            let statusCounts = getStatusCounts(events: data.events)
            
            VStack(spacing: 8) {
                ForEach(Array(statusCounts.keys.sorted()), id: \.self) { status in
                    if let count = statusCounts[status] {
                        statusRow(status: status, count: count, total: data.events.count)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(UI.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(UI.neutralMedium, lineWidth: 1)
                )
        )
    }
    
    private func priorityAnalysisView(data: StudentAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Priority Analysis")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            let pendingEvents = data.pendingEvents
            if let topEvent = pendingEvents.max(by: { $0.priorityScore < $1.priorityScore }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Highest Priority Event:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(UI.neutralDark)
                    
                    Text(topEvent.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    HStack {
                        Text("Priority Score: \(String(format: "%.1f", topEvent.priorityScore))")
                        Spacer()
                        Text("Weight: \(topEvent.weightPercentage)%")
                    }
                    .font(.caption)
                    .foregroundColor(UI.muted)
                }
            } else {
                Text("No pending events to analyze")
                    .font(.body)
                    .foregroundColor(UI.muted)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#F0F9FF"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(UI.primary.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func statusRow(status: EventStatus, count: Int, total: Int) -> some View {
        HStack {
            Circle()
                .fill(Color(hex: status.color))
                .frame(width: 10, height: 10)
            
            Text(status.displayName)
                .font(.subheadline)
                .foregroundColor(UI.neutralDark)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(UI.navy)
            
            Text("(\(Int(Double(count) / Double(total) * 100))%)")
                .font(.caption)
                .foregroundColor(UI.muted)
        }
    }
    
    private func emptyStateView(title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(UI.muted)
            
            Text(title)
                .font(.headline)
                .foregroundColor(UI.navy)
            
            Text(subtitle)
                .font(.body)
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // Helper functions
    private func loadAnalyticsData() async {
        do {
            _ = try await analyticsService.getHighestWeightPendingEvent(for: "student123")
        } catch {
            print("Error loading analytics data: \(error)")
        }
    }
    
    private func filteredEvents(_ events: [AcademicEvent]) -> [AcademicEvent] {
        if searchText.isEmpty {
            return events
        }
        
        return events.filter { event in
            event.title.localizedCaseInsensitiveContains(searchText) ||
            event.courseName.localizedCaseInsensitiveContains(searchText) ||
            event.type.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func getStatusCounts(events: [AcademicEvent]) -> [EventStatus: Int] {
        var counts: [EventStatus: Int] = [:]
        
        for event in events {
            counts[event.status, default: 0] += 1
        }
        
        return counts
    }
    
    private func formatJSON(_ data: StudentAnalyticsData) -> String {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(data)
            return String(data: jsonData, encoding: .utf8) ?? "Error encoding data"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}

// Individual data cards
struct EventDataCard: View {
    let event: AcademicEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: event.type.icon)
                    .foregroundColor(Color(hex: event.type == .exam ? "#FF4757" : "#5352ED"))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(UI.navy)
                    
                    Text(event.courseName)
                        .font(.subheadline)
                        .foregroundColor(UI.muted)
                }
                
                Spacer()
                
                statusBadge(status: event.status)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                dataRow(label: "Type", value: event.type.displayName)
                dataRow(label: "Due Date", value: formatDate(event.dueDate))
                dataRow(label: "Weight", value: "\(event.weightPercentage)%")
                dataRow(label: "Priority Score", value: String(format: "%.1f", event.priorityScore))
                dataRow(label: "Days Until Due", value: "\(event.daysUntilDue)")
                
                if let description = event.description {
                    Text("Description:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(UI.neutralDark)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(UI.muted)
                        .padding(.leading, 8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private func statusBadge(status: EventStatus) -> some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: status.color))
            )
    }
    
    private func dataRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(UI.neutralDark)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(UI.muted)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct CourseDataCard: View {
    let course: Course
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color(hex: course.color))
                    .frame(width: 16, height: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(course.name)
                        .font(.headline)
                        .foregroundColor(UI.navy)
                    
                    Text("\(course.code) • \(course.credits) credits")
                        .font(.subheadline)
                        .foregroundColor(UI.muted)
                }
                
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                dataRow(label: "Instructor", value: course.instructor)
                dataRow(label: "Semester", value: "\(course.semester) \(course.year)")
                
                if let currentGrade = course.currentGrade {
                    dataRow(label: "Current Grade", value: String(format: "%.1f%%", currentGrade * 100))
                }
                
                if let targetGrade = course.targetGrade {
                    dataRow(label: "Target Grade", value: String(format: "%.1f%%", targetGrade * 100))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private func dataRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(UI.neutralDark)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(UI.muted)
        }
    }
}

struct ExportDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 48))
                    .foregroundColor(UI.primary)
                
                Text("Export Analytics Data")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(UI.navy)
                
                Text("Choose how you'd like to export your academic data")
                    .font(.body)
                    .foregroundColor(UI.muted)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 12) {
                    exportButton(title: "Export as JSON", icon: "doc.text", action: {
                        // Export JSON logic
                        dismiss()
                    })
                    
                    exportButton(title: "Export as CSV", icon: "tablecells", action: {
                        // Export CSV logic
                        dismiss()
                    })
                    
                    exportButton(title: "Share Summary", icon: "square.and.arrow.up", action: {
                        // Share summary logic
                        dismiss()
                    })
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(UI.primary)
                
                Text(title)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(UI.muted)
                    .font(.caption)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(UI.neutralMedium, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct AnalyticsDataView_Previews: PreviewProvider {
    static var previews: some View {
        AnalyticsDataView()
    }
}