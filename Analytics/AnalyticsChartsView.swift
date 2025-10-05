//
//  AnalyticsChartsView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

import SwiftUI
import Charts

@available(iOS 16.0, *)
struct AnalyticsChartsView: View {
    @StateObject private var analyticsService = AnalyticsService.shared
    @State private var selectedChartType = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                chartTypeSelector
                
                if let studentData = analyticsService.studentData {
                    Group {
                        switch selectedChartType {
                        case 0:
                            priorityDistributionChart(data: studentData)
                        case 1:
                            dueDateTimelineChart(data: studentData)
                        case 2:
                            courseWorkloadChart(data: studentData)
                        case 3:
                            weeklyProgressChart(data: studentData)
                        default:
                            priorityDistributionChart(data: studentData)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    noDataView
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            Task {
                await loadAnalyticsData()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 32))
                .foregroundColor(UI.primary)
            
            Text("Analytics Charts")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            Text("Visual insights into your academic workload")
                .font(.subheadline)
                .foregroundColor(UI.muted)
        }
    }
    
    private var chartTypeSelector: some View {
        VStack(spacing: 16) {
            Text("Chart Type")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            Picker("Chart Type", selection: $selectedChartType) {
                Text("Priority Distribution").tag(0)
                Text("Due Date Timeline").tag(1)
                Text("Course Workload").tag(2)
                Text("Weekly Progress").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private func priorityDistributionChart(data: StudentAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            chartHeader(
                title: "Priority Distribution",
                subtitle: "Events by urgency level"
            )
            
            let priorityData = getPriorityDistributionData(data: data)
            
            Chart(priorityData, id: \.priority) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 2.0
                )
                .foregroundStyle(Color(hex: item.color))
                .cornerRadius(4.0)
            }
            .frame(height: 200)
            
            // Legend
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(priorityData, id: \.priority) { item in
                    HStack {
                        Circle()
                            .fill(Color(hex: item.color))
                            .frame(width: 12, height: 12)
                        
                        Text("\(item.priority) (\(item.count))")
                            .font(.caption)
                            .foregroundColor(UI.neutralDark)
                        
                        Spacer()
                    }
                }
            }
        }
        .chartCard()
    }
    
    private func dueDateTimelineChart(data: StudentAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            chartHeader(
                title: "Due Date Timeline",
                subtitle: "Upcoming deadlines by day"
            )
            
            let timelineData = getDueDateTimelineData(data: data)
            
            Chart(timelineData, id: \.date) { item in
                BarMark(
                    x: .value("Date", item.date),
                    y: .value("Events", item.eventCount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [UI.primary, UI.navy],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4.0)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
        .chartCard()
    }
    
    private func courseWorkloadChart(data: StudentAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            chartHeader(
                title: "Course Workload",
                subtitle: "Pending events by course"
            )
            
            let courseData = getCourseWorkloadData(data: data)
            
            Chart(courseData, id: \.courseName) { item in
                BarMark(
                    x: .value("Course", item.courseName),
                    y: .value("Events", item.eventCount)
                )
                .foregroundStyle(Color(hex: item.color))
                .cornerRadius(4.0)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel(orientation: .automatic)
                }
            }
        }
        .chartCard()
    }
    
    private func weeklyProgressChart(data: StudentAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            chartHeader(
                title: "Weekly Progress",
                subtitle: "Completion rate over time"
            )
            
            let progressData = getWeeklyProgressData(data: data)
            
            Chart(progressData, id: \.week) { item in
                LineMark(
                    x: .value("Week", item.week),
                    y: .value("Completion %", item.completionRate)
                )
                .foregroundStyle(UI.primary)
                .lineStyle(StrokeStyle(lineWidth: 3.0))
                
                PointMark(
                    x: .value("Week", item.week),
                    y: .value("Completion %", item.completionRate)
                )
                .foregroundStyle(UI.primary)
                .symbolSize(50)
            }
            .frame(height: 200)
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel(format: .percent)
                }
            }
        }
        .chartCard()
    }
    
    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(UI.muted)
            
            Text("No Data Available")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            Text("Load analytics data to view charts")
                .font(.body)
                .foregroundColor(UI.muted)
            
            Button("Load Data") {
                Task {
                    await loadAnalyticsData()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // Helper views
    private func chartHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(UI.navy)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(UI.muted)
        }
    }
    
    // Helper functions
    private func loadAnalyticsData() async {
        do {
            _ = try await analyticsService.getHighestWeightPendingEvent(for: "student123")
        } catch {
            print("Error loading analytics data: \(error)")
        }
    }
    
    private func getPriorityDistributionData(data: StudentAnalyticsData) -> [PriorityDistributionItem] {
        let pendingEvents = data.pendingEvents
        
        let criticalCount = pendingEvents.filter { $0.daysUntilDue <= 1 }.count
        let highCount = pendingEvents.filter { $0.daysUntilDue > 1 && $0.daysUntilDue <= 3 }.count
        let moderateCount = pendingEvents.filter { $0.daysUntilDue > 3 && $0.daysUntilDue <= 7 }.count
        let lowCount = pendingEvents.filter { $0.daysUntilDue > 7 }.count
        
        return [
            PriorityDistributionItem(priority: "Critical", count: criticalCount, color: "#FF4757"),
            PriorityDistributionItem(priority: "High", count: highCount, color: "#FF6B6B"),
            PriorityDistributionItem(priority: "Moderate", count: moderateCount, color: "#FFE66D"),
            PriorityDistributionItem(priority: "Low", count: lowCount, color: "#4ECDC4")
        ].filter { $0.count > 0 }
    }
    
    private func getDueDateTimelineData(data: StudentAnalyticsData) -> [DueDateTimelineItem] {
        let calendar = Calendar.current
        let today = Date()
        let pendingEvents = data.pendingEvents
        
        var eventsByDate: [Date: Int] = [:]
        
        for event in pendingEvents {
            let eventDate = calendar.startOfDay(for: event.dueDate)
            eventsByDate[eventDate, default: 0] += 1
        }
        
        // Generate next 14 days
        let dateRange = (0..<14).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: today)
        }
        
        return dateRange.map { date in
            DueDateTimelineItem(
                date: date,
                eventCount: eventsByDate[calendar.startOfDay(for: date)] ?? 0
            )
        }
    }
    
    private func getCourseWorkloadData(data: StudentAnalyticsData) -> [CourseWorkloadItem] {
        let pendingEvents = data.pendingEvents
        var eventsByCourse: [String: (count: Int, color: String)] = [:]
        
        for event in pendingEvents {
            if eventsByCourse[event.courseName] == nil {
                // Assign colors based on course
                let colors = ["#122C4A", "#50E3C2", "#FF6B6B", "#FFE66D", "#5352ED"]
                let colorIndex = eventsByCourse.count % colors.count
                eventsByCourse[event.courseName] = (count: 0, color: colors[colorIndex])
            }
            eventsByCourse[event.courseName]?.count += 1
        }
        
        return eventsByCourse.map { courseName, info in
            CourseWorkloadItem(
                courseName: courseName,
                eventCount: info.count,
                color: info.color
            )
        }.sorted { $0.eventCount > $1.eventCount }
    }
    
    private func getWeeklyProgressData(data: StudentAnalyticsData) -> [WeeklyProgressItem] {
        // Mock weekly progress data for demonstration
        let weeks = ["Week 1", "Week 2", "Week 3", "Week 4", "Current"]
        let completionRates = [85.0, 92.0, 78.0, 88.0, 75.0] // Mock data
        
        return zip(weeks, completionRates).map { week, rate in
            WeeklyProgressItem(week: week, completionRate: rate)
        }
    }
}

// Data structures for charts
struct PriorityDistributionItem {
    let priority: String
    let count: Int
    let color: String
}

struct DueDateTimelineItem {
    let date: Date
    let eventCount: Int
}

struct CourseWorkloadItem {
    let courseName: String
    let eventCount: Int
    let color: String
}

struct WeeklyProgressItem {
    let week: String
    let completionRate: Double
}

// Chart card modifier
extension View {
    func chartCard() -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            )
    }
}

// Fallback for iOS < 16
struct AnalyticsChartsViewFallback: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundColor(UI.muted)
            
            Text("Charts Not Available")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            Text("Charts require iOS 16.0 or later")
                .font(.body)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UI.bg)
    }
}

// Main view that handles iOS version check
struct AnalyticsChartsView: View {
    var body: some View {
        if #available(iOS 16.0, *) {
            AnalyticsChartsView()
        } else {
            AnalyticsChartsViewFallback()
        }
    }
}