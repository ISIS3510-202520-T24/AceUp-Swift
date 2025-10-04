//
//  TodayView.swift
//  AceUp-Swift
//
//  Created by Ana M. Sánchez on 19/09/25.
//

import SwiftUI

struct TodayView: View {
    let onMenuTapped: () -> Void
    @State private var selectedTab: TodayTab = .assignments
    @StateObject private var smartAnalytics = SmartCalendarAnalytics()
    
    init(onMenuTapped: @escaping () -> Void = {}) {
        self.onMenuTapped = onMenuTapped
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack {
                HStack {
                    Button(action: onMenuTapped) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(UI.navy)
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    Text("Today")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 24)
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 60)
            .background(Color(hex: "#B8C8DB"))
            
            // Main Content
            VStack(spacing: 0) {
                // Tab Navigation
                HStack(spacing: 8) {
                    TabButton(
                        title: "Assignments",
                        isSelected: selectedTab == .assignments,
                        action: { selectedTab = .assignments }
                    )
                    
                    TabButton(
                        title: "Timetable", 
                        isSelected: selectedTab == .timetable,
                        action: { selectedTab = .timetable }
                    )
                    
                    TabButton(
                        title: "Exams",
                        isSelected: selectedTab == .exams,
                        action: { selectedTab = .exams }
                    )
                    
                    TabButton(
                        title: "Insights",
                        isSelected: selectedTab == .insights,
                        action: { selectedTab = .insights }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                // Tab Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .assignments:
                            AssignmentsTabContent()
                        case .timetable:
                            TimetableTabContent()
                        case .exams:
                            ExamsTabContent()
                        case .insights:
                            SmartInsightsTabContent(analytics: smartAnalytics)
                        }
                    }
                    .padding(.bottom, 100) // Extra padding for FAB
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(UI.neutralLight)
        }
        .overlay(
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(UI.primary)
                            .clipShape(Circle())
                            .shadow(color: UI.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 30)
                }
            }
        )
        .navigationBarHidden(true)
    }
}

// MARK: - Updated Tab Enum
enum TodayTab: String, CaseIterable {
    case assignments = "Assignments"
    case timetable = "Timetable"
    case exams = "Exams"
    case insights = "Insights"
}

// MARK: - Smart Insights Tab Content
struct SmartInsightsTabContent: View {
    @ObservedObject var analytics: SmartCalendarAnalytics
    
    var body: some View {
        VStack(spacing: 20) {
            // Today's Smart Highlights
            todayHighlights
            
            // Weekly Insights
            if let latestInsight = analytics.weeklyInsights.first {
                SmartInsightsCard(insight: latestInsight)
                    .padding(.horizontal, 20)
            }
            
            // Productivity Trends
            if !analytics.productivityTrends.isEmpty {
                ProductivityChart(trends: analytics.productivityTrends)
                    .padding(.horizontal, 20)
            }
            
            // Study Patterns
            if !analytics.studyPatterns.isEmpty {
                StudyPatternsView(patterns: analytics.studyPatterns)
                    .padding(.horizontal, 20)
            }
            
            // Collaboration Metrics
            if let metrics = analytics.collaborationMetrics {
                CollaborationMetricsView(metrics: metrics)
                    .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Today's Highlights
    private var todayHighlights: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(UI.primary)
                
                Text("Today's Highlights")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    TodayHighlightCard(
                        icon: "calendar.badge.clock",
                        title: "Next Meeting",
                        subtitle: "Mobile Dev Team",
                        time: "2:00 PM",
                        color: UI.primary
                    )
                    
                    TodayHighlightCard(
                        icon: "clock.badge.checkmark",
                        title: "Focus Time",
                        subtitle: "Best for deep work",
                        time: "10:00 AM",
                        color: UI.success
                    )
                    
                    TodayHighlightCard(
                        icon: "person.3.fill",
                        title: "Group Available",
                        subtitle: "Study Buddies",
                        time: "4:00 PM",
                        color: UI.warning
                    )
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct TodayHighlightCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let time: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
                
                Text(time)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
        }
        .padding(15)
        .frame(width: 140, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

struct CollaborationMetricsView: View {
    let metrics: CollaborationMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.sequence.fill")
                    .foregroundColor(UI.primary)
                
                Text("Collaboration Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                CollaborationMetric(
                    icon: "person.2.circle.fill",
                    value: "\(metrics.totalGroups)",
                    label: "Active Groups",
                    color: UI.primary
                )
                
                CollaborationMetric(
                    icon: "checkmark.circle.fill",
                    value: "\(Int(metrics.meetingSuccessRate * 100))%",
                    label: "Success Rate",
                    color: UI.success
                )
                
                CollaborationMetric(
                    icon: "clock.fill",
                    value: "\(metrics.averageResponseTime)m",
                    label: "Avg Response",
                    color: UI.warning
                )
            }
            
            HStack {
                Text("Most productive hour: **\(metrics.mostProductiveHour):00**")
                    .font(.caption)
                    .foregroundColor(UI.muted)
                
                Spacer()
                
                Text("\(metrics.activeCollaborations) active collaborations")
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

struct CollaborationMetric: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            Text(label)
                .font(.caption)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : UI.navy)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? UI.primary : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}


struct ExamsTabContent: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 100)
            
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(UI.muted)
            
            VStack(spacing: 8) {
                Text("No exams scheduled")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Text("Your upcoming exams will appear here")
                    .font(.body)
                    .foregroundColor(UI.muted)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct TimetableTabContent: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 100)
            
            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundColor(UI.muted)
            
            VStack(spacing: 8) {
                Text("No classes today")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Text("Your class schedule will appear here")
                    .font(.body)
                    .foregroundColor(UI.muted)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct AssignmentsTabContent: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 100)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#E8E8E8"))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(UI.muted)
                )
            
            VStack(spacing: 8) {
                Text("You have no assignments due for the next 7 days")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                    .multilineTextAlignment(.center)
                
                Text("Time to work on a hobby of yours!")
                    .font(.body)
                    .foregroundColor(UI.muted)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    TodayView(onMenuTapped: {
        print("Menu tapped")
    })
}