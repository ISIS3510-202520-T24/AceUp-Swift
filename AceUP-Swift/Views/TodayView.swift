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
    @State private var showingCreateAssignment = false
    @StateObject private var assignmentViewModel = AssignmentViewModel()
    
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
                            AssignmentsTabContent(assignmentViewModel: assignmentViewModel)
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
                    Button(action: {
                        showingCreateAssignment = true
                    }) {
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
        .sheet(isPresented: $showingCreateAssignment) {
            CreateAssignmentView(viewModel: assignmentViewModel)
        }
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
    @ObservedObject var assignmentViewModel: AssignmentViewModel
    @State private var days: Int? = nil
    @State private var isSchedulingNotification = false
    private let userKey = UserKeyManager.shared.userKey()
    
    init(assignmentViewModel: AssignmentViewModel) {
        self.assignmentViewModel = assignmentViewModel
    }

    var body: some View {
        VStack(spacing: 16) {
            // Type 2 BQ Card - How many of today's assignments completed vs pending?
            if let summary = assignmentViewModel.todaysSummary {
                TodaysSummaryCard(summary: summary)
            }
            
            // Days since last progress (existing BQ)
            VStack(spacing: 8) {
                Text("Days since last progress").font(.headline)
                if let d = days {
                    Text("\(d) day\(d == 1 ? "" : "s")")
                        .font(.title).fontWeight(.semibold)
                } else {
                    Text("No progress yet").foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Smart Feature: Workload Analysis
            if let analysis = assignmentViewModel.workloadAnalysis {
                WorkloadInsightCard(analysis: analysis)
            }
            
            // BQ 2.1 Card - Highest Weight Pending Assignment
            if let highestWeightAssignment = assignmentViewModel.highestWeightPendingAssignment {
                HighestWeightAssignmentCard(assignment: highestWeightAssignment)
            }
            
            // Today's Assignments List
            TodaysAssignmentsList(viewModel: assignmentViewModel)
            
            // Trigger Highest Weight Assignment Notification
            VStack(spacing: 8) {
                Button {
                    // Prevent rapid successive calls
                    guard !isSchedulingNotification else { return }
                    isSchedulingNotification = true
                    
                    // Check notification authorization and trigger notification
                    NotificationService.checkAuthorizationStatus { status in
                        // If authorized, send notification
                        if status.contains("Authorized") {
                            if let highestWeightAssignment = assignmentViewModel.highestWeightPendingAssignment {
                                NotificationService.scheduleHighestWeightAssignmentReminder(assignment: highestWeightAssignment)
                            }
                        } else if status.contains("Not determined") {
                            // Request permission
                            NotificationService.requestAuthorization()
                        }
                        
                        // Reset flag after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isSchedulingNotification = false
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: isSchedulingNotification ? "hourglass" : "bell.fill")
                        Text(isSchedulingNotification ? "Scheduling..." : "Set Priority Reminder")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isSchedulingNotification || assignmentViewModel.highestWeightPendingAssignment == nil)
                
                // Test button for immediate notification (for development/testing)
                Button {
                    // Prevent rapid successive calls
                    guard !isSchedulingNotification else { return }
                    isSchedulingNotification = true
                    
                    NotificationService.checkAuthorizationStatus { status in
                        if status.contains("Authorized") {
                            let testDate = Calendar.current.date(byAdding: .second, value: 3, to: Date()) ?? Date()
                            
                            if let highestWeightAssignment = assignmentViewModel.highestWeightPendingAssignment {
                                NotificationService.schedule(
                                    id: "test_immediate_\(Int(Date().timeIntervalSince1970))",
                                    title: "High Priority Assignment",
                                    body: "Your assignment '\(highestWeightAssignment.title)' (\(highestWeightAssignment.weightPercentage)% of grade) needs attention!",
                                    date: testDate
                                )
                            } else {
                                NotificationService.schedule(
                                    id: "test_immediate_\(Int(Date().timeIntervalSince1970))",
                                    title: "High Priority Assignment",
                                    body: "Test notification - No pending assignments found.",
                                    date: testDate
                                )
                            }
                        } else if status.contains("Not determined") {
                            NotificationService.requestAuthorization()
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isSchedulingNotification = false
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                        Text("Test (3 sec)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSchedulingNotification)
            }
        }
    }

    // var body: some View {
    //     VStack(spacing: 20) {
    //         Spacer().frame(height: 100)
            
    //         RoundedRectangle(cornerRadius: 12)
    //             .fill(Color(hex: "#E8E8E8"))
    //             .frame(width: 120, height: 120)
    //             .overlay(
    //                 Image(systemName: "photo")
    //                     .font(.system(size: 40))
    //                     .foregroundColor(UI.muted)
    //             )
            
    //         VStack(spacing: 8) {
    //             Text("You have no assignments due for the next 7 days")
    //                 .font(.title3)
    //                 .fontWeight(.semibold)
    //                 .foregroundColor(UI.navy)
    //                 .multilineTextAlignment(.center)
                
    //             Text("Time to work on a hobby of yours!")
    //                 .font(.body)
    //                 .foregroundColor(UI.muted)
    //                 .multilineTextAlignment(.center)
    //         }
            
    //         Spacer()
    //     }
    //     .padding(.horizontal, 40)
    // }
}

#Preview {
    TodayView(onMenuTapped: {
        print("Menu tapped")
    })
}

// MARK: - Today's Summary Card (Type 2 BQ)
/// Created by Ángel Farfán Arcila on 4/10/25
struct TodaysSummaryCard: View {
    let summary: TodaysSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(UI.primary)
                Text("Today's Progress")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                Spacer()
            }
            
            // Progress visualization
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(summary.progressMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(UI.navy)
                    
                    Spacer()
                    
                    if summary.totalAssignments > 0 {
                        Text("\(Int(summary.completionPercentage * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(UI.primary)
                            .cornerRadius(8)
                    }
                }
                
                if summary.totalAssignments > 0 {
                    ProgressView(value: summary.completionPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: UI.primary))
                }
                
                Text(summary.motivationalMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Workload Insight Card (Smart Feature)
/// Created by Ángel Farfán Arcila on 4/10/25
struct WorkloadInsightCard: View {
    let analysis: WorkloadAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(UI.primary)
                Text("Smart Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                Spacer()
                
                // Balance indicator
                HStack(spacing: 4) {
                    Image(systemName: analysis.workloadBalance.icon)
                        .font(.caption)
                    Text(analysis.workloadBalance.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(Color(hex: analysis.workloadBalance.color))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(hex: analysis.workloadBalance.color).opacity(0.1))
                .cornerRadius(6)
            }
            
            if let recommendation = analysis.recommendations.first {
                Text(recommendation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            } else {
                Text("Great workload distribution! Your assignments are well balanced.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Today's Assignments List
/// Created by Ángel Farfán Arcila on 4/10/25
struct TodaysAssignmentsList: View {
    @ObservedObject var viewModel: AssignmentViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Due Today")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                Spacer()
                
                if !viewModel.todaysAssignments.isEmpty {
                    Text("\(viewModel.todaysAssignments.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(UI.primary)
                        .cornerRadius(8)
                }
            }
            
            if viewModel.todaysAssignments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "party.popper")
                        .font(.title)
                        .foregroundColor(UI.success)
                    
                    Text("No assignments due today!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(UI.navy)
                    
                    Text("Great job staying on top of your work.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(UI.success.opacity(0.1))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.todaysAssignments.prefix(3)) { assignment in
                        TodayAssignmentRow(assignment: assignment) {
                            Task {
                                await viewModel.markAsCompleted(assignment.id)
                            }
                        }
                    }
                    
                    if viewModel.todaysAssignments.count > 3 {
                        Text("+ \(viewModel.todaysAssignments.count - 3) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Today Assignment Row
/// Created by Ángel Farfán Arcila on 4/10/25
struct TodayAssignmentRow: View {
    let assignment: Assignment
    let onComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Button(action: onComplete) {
                Image(systemName: assignment.status == .completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(assignment.status == .completed ? UI.success : .secondary)
                    .font(.title3)
            }
            .disabled(assignment.status == .completed)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                    .strikethrough(assignment.status == .completed)
                
                HStack {
                    Text(assignment.courseName)
                        .font(.caption)
                        .foregroundColor(Color(hex: assignment.courseColor))
                    
                    Spacer()
                    
                    Text("\(assignment.weightPercentage)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Priority indicator
            Circle()
                .fill(Color(hex: assignment.priority.color))
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - BQ 2.1: Highest Weight Assignment Card
struct HighestWeightAssignmentCard: View {
    let assignment: Assignment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("High Priority Alert")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Text("\(assignment.weightPercentage)%")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(assignment.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                HStack {
                    Label(assignment.courseName, systemImage: "book.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: assignment.courseColor))
                    
                    Spacer()
                    
                    Label(assignment.formattedDueDate, systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("This is your highest weight pending assignment and will have the greatest impact on your final grade.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}