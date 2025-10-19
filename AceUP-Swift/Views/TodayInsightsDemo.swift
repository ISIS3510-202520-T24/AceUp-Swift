//
//  TodayInsightsDemo.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 18/10/25.
//

import SwiftUI

/// Demo view to showcase the insights functionality
/// This can be used for testing and demonstration purposes
struct TodayInsightsDemo: View {
    @StateObject private var insightsAnalytics = TodayInsightsAnalytics()
    @State private var showingAnalytics = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Demo Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🎯 Today's Insights Demo")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(UI.navy)
                        
                        Text("This demonstrates the smart insights functionality answering Business Questions 2.1, 2.2, and 2.4")
                            .font(.subheadline)
                            .foregroundColor(UI.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    
                    // Business Questions Overview
                    BusinessQuestionsOverview()
                    
                    // Live Insights Demo
                    if insightsAnalytics.todaysInsights.isEmpty {
                        LoadingInsightsView()
                    } else {
                        LiveInsightsDemo(analytics: insightsAnalytics)
                    }
                    
                    // Analytics Data Button
                    Button(action: {
                        showingAnalytics = true
                    }) {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal")
                            Text("View Analytics Data")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(UI.primary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    await insightsAnalytics.generateTodaysInsights()
                }
            }
            .sheet(isPresented: $showingAnalytics) {
                AnalyticsDataView(analytics: insightsAnalytics)
            }
        }
    }
}

struct BusinessQuestionsOverview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📊 Business Questions Implemented")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)
            
            VStack(spacing: 12) {
                BusinessQuestionCard(
                    number: "BQ 2.1",
                    question: "What is the next assignment with highest weight toward final grade?",
                    implementation: "Identifies highest-impact pending assignments",
                    color: .orange
                )
                
                BusinessQuestionCard(
                    number: "BQ 2.2", 
                    question: "How many of today's tasks completed vs pending?",
                    implementation: "Real-time progress analysis with completion rates",
                    color: UI.primary
                )
                
                BusinessQuestionCard(
                    number: "BQ 2.4",
                    question: "Days since last progress update?",
                    implementation: "Tracks engagement and triggers smart reminders",
                    color: UI.success
                )
            }
        }
        .padding(.horizontal, 20)
    }
}

struct BusinessQuestionCard: View {
    let number: String
    let question: String
    let implementation: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color)
                    .cornerRadius(6)
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(UI.success)
                    .font(.caption)
            }
            
            Text(question)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(UI.navy)
            
            Text(implementation)
                .font(.caption)
                .foregroundColor(UI.muted)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

struct LoadingInsightsView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: UI.primary))
                .scaleEffect(1.2)
            
            Text("Analyzing your data...")
                .font(.subheadline)
                .foregroundColor(UI.muted)
            
            Text("Generating personalized insights")
                .font(.caption)
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct LiveInsightsDemo: View {
    @ObservedObject var analytics: TodayInsightsAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🤖 Live Insights Generated")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)
                .padding(.horizontal, 20)
            
            // Progress Analysis
            if let progress = analytics.progressAnalysis {
                InsightDemoCard(
                    title: "Progress Analysis (BQ 2.2)",
                    value: "\(Int(progress.completionRate * 100))%",
                    description: "\(progress.completedTasks) of \(progress.totalTasks) tasks completed",
                    icon: "chart.pie.fill",
                    color: progress.isOnTrack ? UI.success : UI.warning
                )
            }
            
            // High Priority Task
            if let task = analytics.nextHighPriorityTask {
                InsightDemoCard(
                    title: "High Priority Task (BQ 2.1)",
                    value: "\(task.weightPercentage)%",
                    description: task.title,
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                )
            }
            
            // Productivity Score
            if let productivity = analytics.productivityScore {
                InsightDemoCard(
                    title: "Productivity Score",
                    value: "\(Int(productivity.score))",
                    description: productivity.level.description,
                    icon: "brain.head.profile",
                    color: Color(hex: productivity.level.color)
                )
            }
            
            // Smart Reminders Count
            if !analytics.smartReminders.isEmpty {
                InsightDemoCard(
                    title: "Smart Reminders",
                    value: "\(analytics.smartReminders.count)",
                    description: "Active notifications based on your progress",
                    icon: "bell.badge.fill",
                    color: UI.primary
                )
            }
        }
    }
}

struct InsightDemoCard: View {
    let title: String
    let value: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(UI.muted)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
    }
}

struct AnalyticsDataView: View {
    @ObservedObject var analytics: TodayInsightsAnalytics
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Raw Analytics Data
                    if let progress = analytics.progressAnalysis {
                        AnalyticsSection(title: "Progress Analysis") {
                            AnalyticsRow(label: "Completed Tasks", value: "\(progress.completedTasks)")
                            AnalyticsRow(label: "Pending Tasks", value: "\(progress.pendingTasks)")
                            AnalyticsRow(label: "Total Tasks", value: "\(progress.totalTasks)")
                            AnalyticsRow(label: "Completion Rate", value: "\(Int(progress.completionRate * 100))%")
                            AnalyticsRow(label: "On Track", value: progress.isOnTrack ? "Yes" : "No")
                            AnalyticsRow(label: "Time of Day", value: progress.timeOfDay.rawValue)
                        }
                    }
                    
                    if let productivity = analytics.productivityScore {
                        AnalyticsSection(title: "Productivity Metrics") {
                            AnalyticsRow(label: "Total Score", value: "\(Int(productivity.score))")
                            AnalyticsRow(label: "Base Score", value: "\(Int(productivity.baseScore))")
                            AnalyticsRow(label: "Time Bonus", value: "\(Int(productivity.timeBonus))")
                            AnalyticsRow(label: "Consistency Bonus", value: "\(Int(productivity.consistencyBonus))")
                            AnalyticsRow(label: "Level", value: productivity.level.description)
                        }
                    }
                    
                    if !analytics.smartReminders.isEmpty {
                        AnalyticsSection(title: "Smart Reminders") {
                            ForEach(analytics.smartReminders) { reminder in
                                VStack(alignment: .leading, spacing: 4) {
                                    AnalyticsRow(label: "Title", value: reminder.title)
                                    AnalyticsRow(label: "Type", value: reminder.type.rawValue)
                                    AnalyticsRow(label: "Priority", value: reminder.priority.rawValue)
                                    AnalyticsRow(label: "Action Required", value: reminder.actionRequired ? "Yes" : "No")
                                }
                                .padding(.vertical, 8)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Analytics Data")
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
}

struct AnalyticsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)
            
            VStack(spacing: 8) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
    }
}

struct AnalyticsRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(UI.muted)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(UI.navy)
        }
    }
}

#Preview {
    TodayInsightsDemo()
}