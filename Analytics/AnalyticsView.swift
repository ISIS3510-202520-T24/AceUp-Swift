//
//  AnalyticsView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

import SwiftUI

struct AnalyticsView: View {
    @StateObject private var analyticsService = AnalyticsService.shared
    @State private var userId = "student123"
    @State private var showingDetails = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Main Analytics Tab
                analyticsMainView
                    .tabItem {
                        Image(systemName: "chart.bar.doc.horizontal")
                        Text("Analysis")
                    }
                    .tag(0)
                
                // Charts Tab
                AnalyticsChartsView()
                    .tabItem {
                        Image(systemName: "chart.pie")
                        Text("Charts")
                    }
                    .tag(1)
                
                // Data Tab
                AnalyticsDataView()
                    .tabItem {
                        Image(systemName: "list.bullet.clipboard")
                        Text("Data")
                    }
                    .tag(2)
            }
            .navigationTitle("Analytics Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var analyticsMainView: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                
                if analyticsService.isLoading {
                    loadingSection
                } else if let response = analyticsService.lastResponse {
                    resultSection(response: response)
                } else {
                    initialSection
                }
                
                Spacer()
            }
            .padding()
        }
        .refreshable {
            await refreshAnalytics()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(UI.primary)
            
            VStack(spacing: 8) {
                Text("Academic Priority Analytics")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(UI.navy)
                
                Text("BQ 2.1: Highest Impact Pending Event")
                    .font(.subheadline)
                    .foregroundColor(UI.muted)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task { await refreshAnalytics() }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Analyze Current Workload")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Analyzing your academic workload...")
                .font(.headline)
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
    
    private var initialSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb")
                .font(.system(size: 32))
                .foregroundColor(UI.warning)
            
            Text("Ready to Analyze")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            Text("Tap the button above to find your highest priority pending academic event based on grade weight and urgency.")
                .font(.body)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func resultSection(response: HighestWeightEventResponse) -> some View {
        VStack(spacing: 20) {
            // Status indicator
            HStack {
                Image(systemName: response.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(response.success ? UI.success : UI.accent)
                
                Text(response.success ? "Analysis Complete" : "Analysis Error")
                    .font(.headline)
                    .foregroundColor(response.success ? UI.success : UI.accent)
                
                Spacer()
                
                Text(formatTimestamp(response.timestamp))
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
            
            if let data = response.data {
                if let event = data.event {
                    eventCard(event: event, analysis: data.analysis)
                    analysisCard(analysis: data.analysis)
                    recommendationsCard(recommendations: data.recommendations)
                } else {
                    noEventsCard(analysis: data.analysis, recommendations: data.recommendations)
                }
            }
            
            // Raw data view for debugging
            if showingDetails {
                debugSection(response: response)
            }
            
            Button(action: {
                showingDetails.toggle()
            }) {
                Text(showingDetails ? "Hide Details" : "Show Technical Details")
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
        }
    }
    
    private func eventCard(event: AcademicEvent, analysis: EventAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🎯 Highest Priority Event")
                        .font(.headline)
                        .foregroundColor(UI.navy)
                    
                    Text("Based on weight and urgency analysis")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                }
                
                Spacer()
                
                priorityBadge(urgency: analysis.urgencyLevel)
            }
            
            Divider()
            
            // Event details
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: event.type.icon)
                        .foregroundColor(Color(hex: event.type == .exam ? "#FF4757" : "#5352ED"))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(UI.navy)
                        
                        Text(event.courseName)
                            .font(.subheadline)
                            .foregroundColor(UI.muted)
                    }
                    
                    Spacer()
                }
                
                // Key metrics
                HStack(spacing: 20) {
                    metricItem(
                        title: "Weight",
                        value: "\(event.weightPercentage)%",
                        color: UI.accent
                    )
                    
                    metricItem(
                        title: "Due in",
                        value: "\(event.daysUntilDue) days",
                        color: event.daysUntilDue <= 3 ? UI.accent : UI.primary
                    )
                    
                    metricItem(
                        title: "Priority Score",
                        value: String(format: "%.1f", event.priorityScore),
                        color: UI.navy
                    )
                }
                
                if let description = event.description {
                    Text(description)
                        .font(.body)
                        .foregroundColor(UI.muted)
                        .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    private func analysisCard(analysis: EventAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📊 Workload Analysis")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                analysisMetric(
                    title: "Pending Events",
                    value: "\(analysis.totalPendingEvents)",
                    subtitle: "Total items"
                )
                
                analysisMetric(
                    title: "Average Weight",
                    value: String(format: "%.1f%%", analysis.averageWeight * 100),
                    subtitle: "Per event"
                )
                
                analysisMetric(
                    title: "Course Load",
                    value: analysis.courseLoad,
                    subtitle: "Current level"
                )
                
                analysisMetric(
                    title: "Impact Score",
                    value: String(format: "%.1f", analysis.impactScore),
                    subtitle: "Priority rating"
                )
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
    
    private func recommendationsCard(recommendations: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("💡 Personalized Recommendations")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(UI.primary))
                        
                        Text(recommendation)
                            .font(.body)
                            .foregroundColor(UI.neutralDark)
                        
                        Spacer()
                    }
                }
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
    
    private func noEventsCard(analysis: EventAnalysis, recommendations: [String]) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(UI.success)
            
            Text("All Caught Up! 🎉")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            Text("You have no pending assignments or exams. Great job staying on top of your coursework!")
                .font(.body)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
            
            if !recommendations.isEmpty {
                recommendationsCard(recommendations: recommendations)
            }
        }
        .padding()
    }
    
    private func debugSection(response: HighestWeightEventResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔧 Technical Details")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            VStack(alignment: .leading, spacing: 8) {
                debugRow(label: "User ID", value: response.userId)
                debugRow(label: "Success", value: String(response.success))
                debugRow(label: "Message", value: response.message)
                debugRow(label: "Timestamp", value: formatTimestamp(response.timestamp))
                
                if let studentData = analyticsService.studentData {
                    debugRow(label: "Total Events", value: String(studentData.events.count))
                    debugRow(label: "Pending Events", value: String(studentData.pendingEvents.count))
                    debugRow(label: "Courses", value: String(studentData.courses.count))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(UI.neutralMedium)
        )
    }
    
    // Helper views
    private func metricItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(UI.muted)
        }
    }
    
    private func analysisMetric(title: String, value: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(UI.neutralDark)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white)
        )
    }
    
    private func priorityBadge(urgency: UrgencyLevel) -> some View {
        Text(urgency.displayName)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: urgency.color))
            )
    }
    
    private func debugRow(label: String, value: String) -> some View {
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
    
    // Helper functions
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func refreshAnalytics() async {
        do {
            _ = try await analyticsService.getHighestWeightPendingEvent(for: userId)
        } catch {
            print("Error refreshing analytics: \(error)")
        }
    }
}

struct AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        AnalyticsView()
    }
}