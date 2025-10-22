//
//  TodayInsightsAnalytics.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 18/10/25.
//

import Foundation
import Combine
import SwiftUI

/// Service responsible for analyzing user data to provide insights for the Today view
/// Implements Type 2 Business Questions for real-time analytics and personalized insights
@MainActor
final class TodayInsightsAnalytics: ObservableObject {
    
    // MARK: - Published Properties
    @Published var todaysInsights: [TodayInsight] = []
    @Published var progressAnalysis: ProgressAnalysis?
    @Published var workloadPrediction: WorkloadPrediction?
    @Published var motivationalMessage: MotivationalMessage?
    @Published var productivityScore: ProductivityScore?
    @Published var nextHighPriorityTask: Assignment?
    @Published var collaborationOpportunities: [CollaborationOpportunity] = []
    @Published var smartReminders: [SmartReminder] = []
    
    // Dependencies
    private let assignmentRepository: AssignmentRepositoryProtocol
    private let analyticsCollector: AnalyticsClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        assignmentRepository: AssignmentRepositoryProtocol? = nil,
        analyticsCollector: AnalyticsClient? = nil
    ) {
        self.assignmentRepository = assignmentRepository ?? AssignmentRepository(dataProvider: HybridAssignmentDataProvider())
        self.analyticsCollector = analyticsCollector ?? AnalyticsClient.shared
        
        Task {
            await generateTodaysInsights()
        }
    }
    
    // MARK: - Public Methods
    
    /// Generates all insights for today's view
    func generateTodaysInsights() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.analyzeTodaysProgress() }
            group.addTask { await self.predictWorkload() }
            group.addTask { await self.generateMotivationalMessage() }
            group.addTask { await self.calculateProductivityScore() }
            group.addTask { await self.identifyHighPriorityTasks() }
            group.addTask { await self.findCollaborationOpportunities() }
            group.addTask { await self.generateSmartReminders() }
        }
        
        // Combine all insights
        compileInsights()
        
        // Send analytics event
        await sendInsightsAnalytics()
    }
    
    /// Refreshes insights with latest data
    func refreshInsights() async {
        await generateTodaysInsights()
    }
    
    // MARK: - BQ 2.2 Implementation
    /// How many of today's tasks and exams has the student completed, and how many remain pending?
    private func analyzeTodaysProgress() async {
        do {
            let allAssignments = try await assignmentRepository.getAllAssignments()
            let todaysAssignments = allAssignments.filter { $0.isDueToday }
            
            let completed = todaysAssignments.filter { $0.status == .completed }.count
            let pending = todaysAssignments.filter { $0.status == .pending || $0.status == .inProgress }.count
            let total = todaysAssignments.count
            
            let completionRate = total > 0 ? Double(completed) / Double(total) : 0.0
            
            progressAnalysis = ProgressAnalysis(
                completedTasks: completed,
                pendingTasks: pending,
                totalTasks: total,
                completionRate: completionRate,
                isOnTrack: completionRate >= 0.7,
                timeOfDay: getCurrentTimeOfDay()
            )
            
            // Send BQ 2.2 analytics
            await analyticsCollector.track(event: .todaysProgressAnalyzed, properties: [
                "completed_tasks": completed,
                "pending_tasks": pending,
                "total_tasks": total,
                "completion_rate": completionRate,
                "time_of_day": getCurrentTimeOfDay().rawValue
            ])
            
        } catch {
            print("Error analyzing today's progress: \(error)")
        }
    }
    
    // MARK: - BQ 2.1 Implementation
    /// For a student, what is the next assignment or exam that carries the highest weight toward their final grade?
    private func identifyHighPriorityTasks() async {
        do {
            let allAssignments = try await assignmentRepository.getAllAssignments()
            let pendingAssignments = allAssignments.filter { 
                ($0.status == .pending || $0.status == .inProgress) && !$0.isOverdue 
            }
            
            nextHighPriorityTask = pendingAssignments.max { $0.weight < $1.weight }
            
            if let highPriorityTask = nextHighPriorityTask {
                await analyticsCollector.track(event: .highPriorityTaskIdentified, properties: [
                    "assignment_id": highPriorityTask.id,
                    "weight_percentage": highPriorityTask.weightPercentage,
                    "days_until_due": highPriorityTask.daysUntilDue,
                    "course_name": highPriorityTask.courseName
                ])
            }
            
        } catch {
            print("Error identifying high priority tasks: \(error)")
        }
    }
    
    // MARK: - BQ 2.4 Implementation
    /// How many days have passed since the student last updated their grades or marked an assignment as completed?
    private func calculateDaysSinceLastActivity() async -> Int {
        do {
            let allAssignments = try await assignmentRepository.getAllAssignments()
            let completedAssignments = allAssignments.filter { $0.status == .completed }
            
            guard !completedAssignments.isEmpty else { return -1 }
            
            let lastUpdateDate = completedAssignments.map { $0.updatedAt }.max() ?? Date.distantPast
            let daysSinceLastUpdate = Calendar.current.dateComponents([.day], from: lastUpdateDate, to: Date()).day ?? 0
            
            // Send BQ 2.4 analytics
            await analyticsCollector.track(event: .daysSinceLastActivityCalculated, properties: [
                "days_since_last_activity": daysSinceLastUpdate,
                "last_activity_date": ISO8601DateFormatter().string(from: lastUpdateDate)
            ])
            
            return daysSinceLastUpdate
            
        } catch {
            print("Error calculating days since last activity: \(error)")
            return -1
        }
    }
    
    // MARK: - Smart Analytics
    
    private func predictWorkload() async {
        do {
            let allAssignments = try await assignmentRepository.getAllAssignments()
            let next7Days = getNext7Days()
            
            var dailyWorkload: [Date: Int] = [:]
            
            for day in next7Days {
                let assignmentsForDay = allAssignments.filter { assignment in
                    Calendar.current.isDate(assignment.dueDate, inSameDayAs: day) && 
                    (assignment.status == .pending || assignment.status == .inProgress)
                }
                dailyWorkload[day] = assignmentsForDay.count
            }
            
            let maxWorkload = dailyWorkload.values.max() ?? 0
            let averageWorkload = dailyWorkload.values.reduce(0, +) / dailyWorkload.count
            let peakDays = dailyWorkload.filter { $0.value >= 3 }.map { $0.key }
            
            workloadPrediction = WorkloadPrediction(
                next7DaysWorkload: dailyWorkload,
                peakWorkloadDays: peakDays,
                averageWorkload: Double(averageWorkload),
                maxWorkload: maxWorkload,
                recommendation: generateWorkloadRecommendation(peakDays: peakDays, maxWorkload: maxWorkload)
            )
            
        } catch {
            print("Error predicting workload: \(error)")
        }
    }
    
    private func generateMotivationalMessage() async {
        guard let progress = progressAnalysis else { return }
        
        let daysSinceActivity = await calculateDaysSinceLastActivity()
        
        let message: String
        let type: MotivationalMessageType
        
        switch (progress.completionRate, daysSinceActivity) {
        case (0.8..., _):
            message = "Outstanding progress today! 🎉 You're crushing your goals!"
            type = .celebratory
        case (0.5..<0.8, _):
            message = "Good work! You're on track. Keep the momentum going!"
            type = .encouraging
        case (0.0..<0.5, 0...2):
            message = "It's still early in the day. You've got this!"
            type = .motivational
        case (_, 3...):
            message = "It's been \(daysSinceActivity) days since your last update. Time to get back on track! 🚀"
            type = .reminder
        default:
            message = "Every small step counts. Start with one task! ✨"
            type = .motivational
        }
        
        motivationalMessage = MotivationalMessage(
            text: message,
            type: type,
            actionSuggestion: generateActionSuggestion(progress: progress, daysSinceActivity: daysSinceActivity)
        )
    }
    
    private func calculateProductivityScore() async {
        guard let progress = progressAnalysis else { return }
        
        let baseScore = progress.completionRate * 100
        let timeBonus = getTimeOfDayBonus(progress.timeOfDay)
        let consistencyBonus = await getConsistencyBonus()
        
        let totalScore = min(100, baseScore + timeBonus + consistencyBonus)
        
        productivityScore = ProductivityScore(
            score: totalScore,
            baseScore: baseScore,
            timeBonus: timeBonus,
            consistencyBonus: consistencyBonus,
            level: getProductivityLevel(totalScore),
            tips: generateProductivityTips(totalScore)
        )
    }
    
    private func findCollaborationOpportunities() async {
        // Mock implementation - in real app would integrate with SharedCalendarService
        collaborationOpportunities = [
            CollaborationOpportunity(
                type: .studyGroup,
                title: "Mobile Dev Study Session",
                participants: ["Ana", "Sebastian", "Julian"],
                timeSlot: "2:00 PM - 4:00 PM",
                likelihood: 0.85
            ),
            CollaborationOpportunity(
                type: .peerReview,
                title: "Assignment Review Exchange",
                participants: ["Fabrizio", "Laura"],
                timeSlot: "Evening",
                likelihood: 0.70
            )
        ]
    }
    
    private func generateSmartReminders() async {
        var reminders: [SmartReminder] = []
        
        // High priority task reminder
        if let highPriorityTask = nextHighPriorityTask {
            if highPriorityTask.daysUntilDue <= 2 {
                reminders.append(SmartReminder(
                    type: .urgentTask,
                    title: "High Priority Assignment Due Soon",
                    message: "\(highPriorityTask.title) is due in \(highPriorityTask.daysUntilDue) day(s) and worth \(highPriorityTask.weightPercentage)% of your grade",
                    priority: .high,
                    actionRequired: true
                ))
            }
        }
        
        // Inactivity reminder
        let daysSinceActivity = await calculateDaysSinceLastActivity()
        if daysSinceActivity >= 3 {
            reminders.append(SmartReminder(
                type: .inactivity,
                title: "Time to Update Your Progress",
                message: "It's been \(daysSinceActivity) days since you last updated your assignments",
                priority: .medium,
                actionRequired: true
            ))
        }

        // BQ 2.4
        NotificationService.scheduleInactivityReminderIfNeeded(daysSince: daysSinceActivity, threshold: 3)
        
        // Workload warning
        if let workload = workloadPrediction, !workload.peakWorkloadDays.isEmpty {
            let nextPeakDay = workload.peakWorkloadDays.first!
            let dayName = DateFormatter().weekdaySymbols[Calendar.current.component(.weekday, from: nextPeakDay) - 1]
            
            reminders.append(SmartReminder(
                type: .workloadWarning,
                title: "Heavy Workload Ahead",
                message: "\(dayName) has multiple assignments due. Consider starting early!",
                priority: .medium,
                actionRequired: false
            ))
        }
        
        smartReminders = reminders
    }
    
    // MARK: - Helper Methods
    
    private func compileInsights() {
        var insights: [TodayInsight] = []
        
        // Progress insight
        if let progress = progressAnalysis {
            insights.append(TodayInsight(
                id: "progress",
                type: .progress,
                title: "Today's Progress",
                description: "\(progress.completedTasks) of \(progress.totalTasks) tasks completed",
                value: "\(Int(progress.completionRate * 100))%",
                icon: "chart.pie.fill",
                color: progress.isOnTrack ? "#27AE60" : "#E74C3C",
                priority: .high
            ))
        }
        
        // High priority task insight
        if let highPriorityTask = nextHighPriorityTask {
            insights.append(TodayInsight(
                id: "high_priority",
                type: .highPriorityTask,
                title: "Next High Impact Task",
                description: highPriorityTask.title,
                value: "\(highPriorityTask.weightPercentage)%",
                icon: "exclamationmark.triangle.fill",
                color: "#F39C12",
                priority: .high
            ))
        }
        
        // Productivity insight
        if let productivity = productivityScore {
            insights.append(TodayInsight(
                id: "productivity",
                type: .productivity,
                title: "Productivity Score",
                description: productivity.level.description,
                value: "\(Int(productivity.score))",
                icon: "brain.head.profile",
                color: productivity.level.color,
                priority: .medium
            ))
        }
        
        todaysInsights = insights
    }
    
    private func sendInsightsAnalytics() async {
        await analyticsCollector.track(event: .todaysInsightsGenerated, properties: [
            "total_insights": todaysInsights.count,
            "high_priority_insights": todaysInsights.filter { $0.priority == .high }.count,
            "smart_reminders": smartReminders.count,
            "collaboration_opportunities": collaborationOpportunities.count
        ])
    }
    
    private func getCurrentTimeOfDay() -> TimePeriod {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
    
    private func getNext7Days() -> [Date] {
        var days: [Date] = []
        let calendar = Calendar.current
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: Date()) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func generateWorkloadRecommendation(peakDays: [Date], maxWorkload: Int) -> String {
        if peakDays.isEmpty {
            return "Great workload distribution! Your assignments are well balanced."
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let peakDayNames = peakDays.map { formatter.string(from: $0) }
        
        if maxWorkload >= 4 {
            return "Heavy workload on \(peakDayNames.joined(separator: " and ")). Consider starting some tasks early."
        } else {
            return "\(peakDayNames.joined(separator: " and ")) look busy. Plan accordingly!"
        }
    }
    
    private func generateActionSuggestion(progress: ProgressAnalysis, daysSinceActivity: Int) -> String {
        if daysSinceActivity >= 3 {
            return "Update your assignment progress"
        } else if progress.completionRate < 0.3 {
            return "Start with your highest priority task"
        } else if progress.completionRate >= 0.8 {
            return "Celebrate your progress!"
        } else {
            return "Keep up the momentum"
        }
    }
    
    private func getTimeOfDayBonus(_ timeOfDay: TimePeriod) -> Double {
        switch timeOfDay {
        case .morning: return 10
        case .afternoon: return 5
        case .evening: return 0
        case .night: return -5
        }
    }
    
    private func getConsistencyBonus() async -> Double {
        let daysSinceActivity = await calculateDaysSinceLastActivity()
        switch daysSinceActivity {
        case 0: return 15
        case 1: return 10
        case 2: return 5
        case 3: return 0
        default: return -10
        }
    }
    
    private func getProductivityLevel(_ score: Double) -> ProductivityLevel {
        switch score {
        case 90...: return .exceptional
        case 80..<90: return .high
        case 60..<80: return .good
        case 40..<60: return .average
        default: return .needsImprovement
        }
    }
    
    private func generateProductivityTips(_ score: Double) -> [String] {
        switch score {
        case 90...: return ["You're crushing it! Keep this momentum going!", "Consider helping peers with their assignments"]
        case 80..<90: return ["Great work! Try to maintain consistency", "Focus on your highest priority tasks"]
        case 60..<80: return ["Good progress! Eliminate distractions", "Break large tasks into smaller chunks"]
        case 40..<60: return ["Room for improvement. Set specific goals", "Use time-blocking techniques"]
        default: return ["Start small with one task", "Remove barriers to getting started", "Ask for help if needed"]
        }
    }
}

// MARK: - Data Models

struct TodayInsight: Identifiable, Equatable {
    let id: String
    let type: InsightType
    let title: String
    let description: String
    let value: String
    let icon: String
    let color: String
    let priority: InsightPriority
}

struct ProgressAnalysis: Equatable {
    let completedTasks: Int
    let pendingTasks: Int
    let totalTasks: Int
    let completionRate: Double
    let isOnTrack: Bool
    let timeOfDay: TimePeriod
}

struct WorkloadPrediction: Equatable {
    let next7DaysWorkload: [Date: Int]
    let peakWorkloadDays: [Date]
    let averageWorkload: Double
    let maxWorkload: Int
    let recommendation: String
}

struct MotivationalMessage: Equatable {
    let text: String
    let type: MotivationalMessageType
    let actionSuggestion: String
}

struct ProductivityScore: Equatable {
    let score: Double
    let baseScore: Double
    let timeBonus: Double
    let consistencyBonus: Double
    let level: ProductivityLevel
    let tips: [String]
}

struct CollaborationOpportunity: Identifiable, Equatable {
    let id = UUID()
    let type: CollaborationType
    let title: String
    let participants: [String]
    let timeSlot: String
    let likelihood: Double
}

struct SmartReminder: Identifiable, Equatable {
    let id = UUID()
    let type: ReminderType
    let title: String
    let message: String
    let priority: ReminderPriority
    let actionRequired: Bool
}

// MARK: - Enums

enum InsightType: String, CaseIterable {
    case progress = "progress"
    case highPriorityTask = "high_priority_task"
    case productivity = "productivity"
    case workload = "workload"
    case collaboration = "collaboration"
}

enum InsightPriority: String, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
}

enum TimePeriod: String, CaseIterable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"
}

enum MotivationalMessageType: String, CaseIterable {
    case celebratory = "celebratory"
    case encouraging = "encouraging"
    case motivational = "motivational"
    case reminder = "reminder"
}

enum ProductivityLevel: String, CaseIterable {
    case exceptional = "exceptional"
    case high = "high"
    case good = "good"
    case average = "average"
    case needsImprovement = "needs_improvement"
    
    var description: String {
        switch self {
        case .exceptional: return "Exceptional Performance!"
        case .high: return "High Productivity"
        case .good: return "Good Progress"
        case .average: return "Average Performance"
        case .needsImprovement: return "Room for Growth"
        }
    }
    
    var color: String {
        switch self {
        case .exceptional: return "#27AE60"
        case .high: return "#2ECC71"
        case .good: return "#F39C12"
        case .average: return "#E67E22"
        case .needsImprovement: return "#E74C3C"
        }
    }
}

enum CollaborationType: String, CaseIterable {
    case studyGroup = "study_group"
    case peerReview = "peer_review"
    case projectMeeting = "project_meeting"
}

enum ReminderType: String, CaseIterable {
    case urgentTask = "urgent_task"
    case inactivity = "inactivity"
    case workloadWarning = "workload_warning"
    case collaboration = "collaboration"
}

enum ReminderPriority: String, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
}