//
//  TodayInsightsView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 18/10/25.
//

import SwiftUI

/// Enhanced insights view that integrates with TodayInsightsAnalytics service
/// Provides smart insights, analytics, and personalized recommendations for students
struct TodayInsightsView: View {
    @StateObject private var insightsAnalytics = TodayInsightsAnalytics()
    @State private var isRefreshing = false
    @State private var selectedInsight: TodayInsight?
    @State private var refreshID = UUID() // Force refresh
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: geometry.size.width > geometry.size.height ? 15 : 20) {
                    // Header with refresh button
                    insightsHeader
                        .padding(.top, 10) // Add top padding to prevent cutoff
                    
                    // Today's Progress Analysis (BQ 2.2)
                    if let progressAnalysis = insightsAnalytics.progressAnalysis {
                        ProgressAnalysisCard(analysis: progressAnalysis)
                            .onTapGesture {
                                Task {
                                    await AnalyticsClient.shared.track(event: .insightCardTapped, properties: [
                                        "card_type": "progress_analysis",
                                        "completion_rate": progressAnalysis.completionRate
                                    ])
                                }
                            }
                    } else {
                        // Show a placeholder while loading
                        ProgressPlaceholderCard()
                    }
                    
                    // Motivational Message
                    if let motivationalMessage = insightsAnalytics.motivationalMessage {
                        MotivationalMessageCard(message: motivationalMessage)
                            .onTapGesture {
                                Task {
                                    await AnalyticsClient.shared.track(event: .motivationalMessageShown, properties: [
                                        "message_type": motivationalMessage.type.rawValue,
                                        "action_suggestion": motivationalMessage.actionSuggestion
                                    ])
                                }
                            }
                    } else {
                        MotivationalPlaceholderCard()
                    }
                    
                    // Productivity Score
                    if let productivityScore = insightsAnalytics.productivityScore {
                        ProductivityScoreCard(score: productivityScore)
                            .onTapGesture {
                                Task {
                                    await AnalyticsClient.shared.track(event: .insightCardTapped, properties: [
                                        "card_type": "productivity_score",
                                        "score": productivityScore.score,
                                        "level": productivityScore.level.rawValue
                                    ])
                                }
                            }
                    } else {
                        ProductivityPlaceholderCard()
                    }
                    
                    // Workload Prediction
                    if let workloadPrediction = insightsAnalytics.workloadPrediction {
                        WorkloadPredictionCard(prediction: workloadPrediction)
                            .onTapGesture {
                                Task {
                                    await AnalyticsClient.shared.track(event: .insightCardTapped, properties: [
                                        "card_type": "workload_prediction",
                                        "peak_days": workloadPrediction.peakWorkloadDays.count,
                                        "max_workload": workloadPrediction.maxWorkload
                                    ])
                                }
                            }
                    } else {
                        WorkloadPlaceholderCard()
                    }
                    
                    // Smart Reminders
                    if !insightsAnalytics.smartReminders.isEmpty {
                        SmartRemindersSection(reminders: insightsAnalytics.smartReminders)
                    }
                    
                    // Collaboration Opportunities
                    if !insightsAnalytics.collaborationOpportunities.isEmpty {
                        CollaborationOpportunitiesSection(opportunities: insightsAnalytics.collaborationOpportunities)
                    }
                    
                    // Today's Insights Summary
                    if !insightsAnalytics.todaysInsights.isEmpty {
                        TodaysInsightsSummary(insights: insightsAnalytics.todaysInsights)
                    }
                }
                .padding(.horizontal, geometry.size.width > geometry.size.height ? 16 : 20) // Adjust horizontal padding
                .padding(.bottom, geometry.size.width > geometry.size.height ? 80 : 100) // Less padding in landscape
                .id(refreshID) // Force refresh when this changes
            }
            .clipped() // Ensure content doesn't overflow
            .refreshable {
                await refreshInsights()
            }
            .onAppear {
                Task {
                    await insightsAnalytics.generateTodaysInsights()
                    refreshID = UUID() // Force UI refresh
                }
            }
        }
    }
    
    // MARK: - Views
    
    private var insightsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Insights")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(UI.navy)
                
                Text("Personalized analytics for your academic journey")
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
            
            Spacer()
            
            Button(action: {
                Task { await refreshInsights() }
            }) {
                Image(systemName: isRefreshing ? "arrow.clockwise" : "arrow.triangle.2.circlepath")
                    .foregroundColor(UI.primary)
                    .font(.title3)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(.easeInOut(duration: 1).repeatCount(isRefreshing ? .max : 1, autoreverses: false), value: isRefreshing)
            }
            .disabled(isRefreshing)
        }
        .padding(.bottom, 12) // Increased bottom padding
        .frame(minHeight: 50) // Ensure minimum height to prevent clipping
    }
    
    private func refreshInsights() async {
        isRefreshing = true
        await insightsAnalytics.refreshInsights()
        try? await Task.sleep(nanoseconds: 500_000_000) // Small delay for smooth animation
        refreshID = UUID() // Force UI refresh
        isRefreshing = false
    }
}

// MARK: - Progress Analysis Card

struct ProgressAnalysisCard: View {
    let analysis: ProgressAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(UI.primary)
                    .font(.title3)
                
                Text("Today's Progress")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                StatusIndicator(isOnTrack: analysis.isOnTrack)
            }
            
            // Progress statistics
            HStack(spacing: 20) {
                ProgressStat(
                    icon: "checkmark.circle.fill",
                    value: "\(analysis.completedTasks)",
                    label: "Completed",
                    color: UI.success
                )
                
                ProgressStat(
                    icon: "clock.fill",
                    value: "\(analysis.pendingTasks)",
                    label: "Pending",
                    color: UI.warning
                )
                
                ProgressStat(
                    icon: "calendar",
                    value: "\(analysis.totalTasks)",
                    label: "Total",
                    color: UI.primary
                )
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Completion Rate")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(UI.navy)
                    
                    Spacer()
                    
                    Text("\(Int(analysis.completionRate * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(analysis.isOnTrack ? UI.success : UI.warning)
                }
                
                ProgressView(value: analysis.completionRate)
                    .progressViewStyle(LinearProgressViewStyle(tint: analysis.isOnTrack ? UI.success : UI.warning))
            }
            
            // Time context
            HStack {
                Image(systemName: timeIcon(analysis.timeOfDay))
                    .foregroundColor(UI.muted)
                    .font(.caption)
                
                Text("Analyzed at \(analysis.timeOfDay.rawValue)")
                    .font(.caption)
                    .foregroundColor(UI.muted)
                
                Spacer()
                
                if analysis.isOnTrack {
                    Text("On track! 🎯")
                        .font(.caption)
                        .foregroundColor(UI.success)
                } else {
                    Text("Room for improvement 💪")
                        .font(.caption)
                        .foregroundColor(UI.warning)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading) // Ensure proper alignment
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion, constrain horizontal
    }
    
    private func timeIcon(_ timeOfDay: TimePeriod) -> String {
        switch timeOfDay {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.fill"
        }
    }
}

struct ProgressStat: View {
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
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            Text(label)
                .font(.caption)
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatusIndicator: View {
    let isOnTrack: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isOnTrack ? UI.success : UI.warning)
                .frame(width: 8, height: 8)
            
            Text(isOnTrack ? "On Track" : "Behind")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isOnTrack ? UI.success : UI.warning)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((isOnTrack ? UI.success : UI.warning).opacity(0.1))
        )
    }
}

struct PercentageBadge: View {
    let percentage: Int
    
    var body: some View {
        Text("\(percentage)%")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.orange)
            )
    }
}

// MARK: - Other Card Components

struct MotivationalMessageCard: View {
    let message: MotivationalMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: messageIcon)
                    .foregroundColor(messageColor)
                    .font(.title3)
                
                Text("Daily Motivation")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            
            Text(message.text)
                .font(.subheadline)
                .foregroundColor(UI.navy)
                .lineLimit(3)
            
            if !message.actionSuggestion.isEmpty {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(UI.warning)
                        .font(.caption)
                    
                    Text(message.actionSuggestion)
                        .font(.caption)
                        .foregroundColor(UI.muted)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading) // Ensure proper alignment
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(messageColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(messageColor.opacity(0.2), lineWidth: 1)
                )
        )
        .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion, constrain horizontal
    }
    
    private var messageIcon: String {
        switch message.type {
        case .celebratory: return "party.popper.fill"
        case .encouraging: return "hand.thumbsup.fill"
        case .motivational: return "star.fill"
        case .reminder: return "bell.fill"
        }
    }
    
    private var messageColor: Color {
        switch message.type {
        case .celebratory: return UI.success
        case .encouraging: return UI.primary
        case .motivational: return UI.warning
        case .reminder: return .orange
        }
    }
}

struct ProductivityScoreCard: View {
    let score: ProductivityScore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(UI.primary)
                    .font(.title3)
                
                Text("Productivity Score")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Text("\(Int(score.score))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: score.level.color))
            }
            
            Text(score.level.description)
                .font(.subheadline)
                .foregroundColor(Color(hex: score.level.color))
            
            if !score.tips.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(score.tips.prefix(2), id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(UI.success)
                                .font(.caption)
                                .padding(.top, 2)
                            
                            Text(tip)
                                .font(.caption)
                                .foregroundColor(UI.muted)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading) // Ensure proper alignment
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion, constrain horizontal
    }
}

struct WorkloadPredictionCard: View {
    let prediction: WorkloadPrediction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(UI.primary)
                    .font(.title3)
                
                Text("Workload Forecast")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                if prediction.maxWorkload >= 3 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            
            Text(prediction.recommendation)
                .font(.subheadline)
                .foregroundColor(UI.navy)
                .lineLimit(3)
            
            if !prediction.peakWorkloadDays.isEmpty {
                HStack {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("\(prediction.peakWorkloadDays.count) busy day(s) ahead")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading) // Ensure proper alignment
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion, constrain horizontal
    }
}

struct SmartRemindersSection: View {
    let reminders: [SmartReminder]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(UI.primary)
                    .font(.title3)
                
                Text("Smart Reminders")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Text("\(reminders.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(UI.primary)
                    .cornerRadius(8)
            }
            
            ForEach(reminders.prefix(3)) { reminder in
                SmartReminderRow(reminder: reminder)
            }
            
            if reminders.count > 3 {
                Text("+ \(reminders.count - 3) more reminders")
                    .font(.caption)
                    .foregroundColor(UI.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

struct SmartReminderRow: View {
    let reminder: SmartReminder
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reminderIcon)
                .foregroundColor(reminderColor)
                .font(.subheadline)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                Text(reminder.message)
                    .font(.caption)
                    .foregroundColor(UI.muted)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if reminder.actionRequired {
                Image(systemName: "chevron.right")
                    .foregroundColor(UI.muted)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var reminderIcon: String {
        switch reminder.type {
        case .urgentTask: return "exclamationmark.circle.fill"
        case .inactivity: return "clock.badge.exclamationmark"
        case .workloadWarning: return "calendar.badge.clock"
        case .collaboration: return "person.3.fill"
        }
    }
    
    private var reminderColor: Color {
        switch reminder.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return UI.primary
        }
    }
}

struct CollaborationOpportunitiesSection: View {
    let opportunities: [CollaborationOpportunity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.sequence.fill")
                    .foregroundColor(UI.primary)
                    .font(.title3)
                
                Text("Collaboration Opportunities")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            
            ForEach(opportunities.prefix(2)) { opportunity in
                CollaborationOpportunityRow(opportunity: opportunity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

struct CollaborationOpportunityRow: View {
    let opportunity: CollaborationOpportunity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(opportunity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Text("\(Int(opportunity.likelihood * 100))%")
                    .font(.caption)
                    .foregroundColor(UI.success)
            }
            
            HStack {
                Text(opportunity.participants.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(UI.muted)
                
                Spacer()
                
                Text(opportunity.timeSlot)
                    .font(.caption)
                    .foregroundColor(UI.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TodaysInsightsSummary: View {
    let insights: [TodayInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(UI.primary)
                    .font(.title3)
                
                Text("Today's Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(insights.prefix(4)) { insight in
                    InsightSummaryCard(insight: insight)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

struct InsightSummaryCard: View {
    let insight: TodayInsight
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: insight.icon)
                .foregroundColor(Color(hex: insight.color))
                .font(.title3)
            
            Text(insight.value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            Text(insight.title)
                .font(.caption)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: insight.color).opacity(0.05))
        )
        .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion, constrain horizontal
    }
}

// MARK: - Placeholder Cards

struct ProgressPlaceholderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(UI.primary)
                    .font(.title3)
                
                Text("Today's Progress")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            
            Text("Analyzing your progress...")
                .font(.subheadline)
                .foregroundColor(UI.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .redacted(reason: .placeholder)
    }
}

struct MotivationalPlaceholderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(UI.primary)
                    .font(.title3)
                
                Text("Daily Motivation")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            
            Text("Preparing your personalized motivation...")
                .font(.subheadline)
                .foregroundColor(UI.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .redacted(reason: .placeholder)
    }
}

struct ProductivityPlaceholderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(UI.primary)
                    .font(.title3)
                
                Text("Productivity Score")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            
            Text("Calculating your productivity...")
                .font(.subheadline)
                .foregroundColor(UI.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .redacted(reason: .placeholder)
    }
}

struct WorkloadPlaceholderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(UI.primary)
                    .font(.title3)
                
                Text("Workload Forecast")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            
            Text("Predicting your upcoming workload...")
                .font(.subheadline)
                .foregroundColor(UI.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .redacted(reason: .placeholder)
    }
}

#Preview {
    TodayInsightsView()
}