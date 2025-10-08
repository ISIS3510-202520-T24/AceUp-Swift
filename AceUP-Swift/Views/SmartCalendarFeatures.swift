//
//  SmartCalendarFeatures.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

import SwiftUI
import Foundation

// MARK: - Smart Calendar Analytics Service
class SmartCalendarAnalytics: ObservableObject {
    
    @Published var weeklyInsights: [WeeklyInsight] = []
    @Published var studyPatterns: [StudyPattern] = []
    @Published var collaborationMetrics: CollaborationMetrics?
    @Published var productivityTrends: [ProductivityTrend] = []
    @Published var upcomingDeadlines: [Assignment] = []
    @Published var subjectPerformance: [SubjectPerformance] = []
    @Published var studySessionRecommendations: [StudySessionRecommendation] = []
    @Published var workloadForecast: WorkloadForecast?
    
    // Real-time analytics
    @Published var todaysProductivityScore: Double = 0.0
    @Published var weeklyGoalProgress: Double = 0.0
    @Published var assignmentCompletionRate: Double = 0.0
    @Published var averageTimeEstimationAccuracy: Double = 0.0
    
    // Business Questions Implementation
    @Published var daysSinceLastProgress: Int = 0
    @Published var mostProductiveTimeSlot: TimeOfDay?
    @Published var priorityDistribution: [Priority: Int] = [:]
    
    private let assignmentRepository: AssignmentRepositoryProtocol
    private let workloadAnalyzer = WorkloadAnalyzer()
    
    init(assignmentRepository: AssignmentRepositoryProtocol? = nil) {
        // Use lazy initialization to avoid main actor issues
        if let repository = assignmentRepository {
            self.assignmentRepository = repository
        } else {
            // Create a deferred repository that will be initialized on main actor when needed
            self.assignmentRepository = DeferredAssignmentRepository()
        }
        Task {
            await refreshData()
        }
    }
    
    // MARK: - Data Analysis Methods
    
    @MainActor
    func refreshData() async {
        do {
            let assignments = try await assignmentRepository.getAllAssignments()
            await analyzeAssignmentData(assignments)
            generateInsights(from: assignments)
            generateMockCollaborationData() // Keep mock data for collaboration features
        } catch {
            print("Error refreshing analytics data: \(error)")
            generateMockInsights() // Fallback to mock data
        }
    }
    
    // MARK: - Action Methods
    
    func handleInsightAction(_ actionType: InsightActionType) {
        switch actionType {
        case .viewAllDeadlines:
            // This could navigate to a detailed deadlines view
            print("Navigate to all deadlines")
        case .viewSubjectDetails(let courseId):
            // This could navigate to subject-specific analytics
            print("Navigate to details for course: \(courseId)")
        case .optimizeSchedule:
            // This could open schedule optimization suggestions
            print("Open schedule optimization")
        case .reviewProgress:
            // This could open progress tracking details
            print("Open progress review")
        }
    }
    
    private func analyzeAssignmentData(_ assignments: [Assignment]) async {
        // BQ: How many days since last progress?
        let completedAssignments = assignments.filter { $0.status == .completed }
        if let lastCompleted = completedAssignments.max(by: { $0.updatedAt < $1.updatedAt }) {
            daysSinceLastProgress = Calendar.current.dateComponents([.day], from: lastCompleted.updatedAt, to: Date()).day ?? 0
        } else {
            daysSinceLastProgress = -1 // No progress yet
        }
        
        // Calculate productivity metrics
        await calculateProductivityMetrics(assignments)
        
        // Analyze priority distribution
        priorityDistribution = Dictionary(grouping: assignments.filter { $0.status == .pending }, by: \.priority)
            .mapValues { $0.count }
        
        // Generate upcoming deadlines (next 7 days)
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        upcomingDeadlines = assignments.filter { 
            $0.dueDate > Date() && $0.dueDate <= nextWeek && $0.status == .pending 
        }.sorted { $0.dueDate < $1.dueDate }
        
        // Analyze subject performance
        await analyzeSubjectPerformance(assignments)
        
        // Generate workload forecast
        workloadForecast = generateWorkloadForecast(assignments)
    }
    
    private func calculateProductivityMetrics(_ assignments: [Assignment]) async {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        
        // Today's productivity score
        let todaysAssignments = assignments.filter { Calendar.current.isDate($0.dueDate, inSameDayAs: today) }
        let completedToday = todaysAssignments.filter { $0.status == .completed }
        todaysProductivityScore = todaysAssignments.isEmpty ? 1.0 : Double(completedToday.count) / Double(todaysAssignments.count)
        
        // Weekly goal progress (assignments completed vs planned)
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let weekAssignments = assignments.filter { $0.dueDate >= weekStart && $0.dueDate <= now }
        let completedWeek = weekAssignments.filter { $0.status == .completed }
        weeklyGoalProgress = weekAssignments.isEmpty ? 0.0 : Double(completedWeek.count) / Double(weekAssignments.count)
        
        // Overall completion rate
        let totalAssignments = assignments.count
        let totalCompleted = assignments.filter { $0.status == .completed }.count
        assignmentCompletionRate = totalAssignments == 0 ? 0.0 : Double(totalCompleted) / Double(totalAssignments)
        
        // Time estimation accuracy
        let assignmentsWithBothTimes = assignments.filter { 
            $0.estimatedHours != nil && $0.actualHours != nil 
        }
        if !assignmentsWithBothTimes.isEmpty {
            let accuracyScores = assignmentsWithBothTimes.map { assignment in
                guard let estimated = assignment.estimatedHours, let actual = assignment.actualHours, estimated > 0 else { return 0.0 }
                return 1.0 - abs(estimated - actual) / max(estimated, actual)
            }
            averageTimeEstimationAccuracy = accuracyScores.reduce(0, +) / Double(accuracyScores.count)
        }
    }
    
    private func analyzeSubjectPerformance(_ assignments: [Assignment]) async {
        let groupedByCourse = Dictionary(grouping: assignments, by: \.courseId)
        
        subjectPerformance = groupedByCourse.map { courseId, courseAssignments in
            let completed = courseAssignments.filter { $0.status == .completed }.count
            let total = courseAssignments.count
            let completionRate = total == 0 ? 0.0 : Double(completed) / Double(total)
            
            let averageGrade = courseAssignments.compactMap { assignment in
                // Mock grade calculation based on completion and priority
                if assignment.status == .completed {
                    return assignment.priority == .high ? 95.0 : 
                           assignment.priority == .medium ? 88.0 : 82.0
                }
                return nil
            }.reduce(0, +) / Double(max(completed, 1))
            
            return SubjectPerformance(
                courseId: courseId,
                courseName: courseAssignments.first?.courseName ?? "Unknown Course",
                completionRate: completionRate,
                averageGrade: averageGrade,
                totalAssignments: total,
                upcomingAssignments: courseAssignments.filter { $0.status == .pending }.count,
                trend: completionRate > 0.8 ? .improving : completionRate > 0.5 ? .stable : .declining
            )
        }.sorted { $0.completionRate > $1.completionRate }
    }
    
    private func generateWorkloadForecast(_ assignments: [Assignment]) -> WorkloadForecast {
        let nextTwoWeeks = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        let upcomingAssignments = assignments.filter { 
            $0.dueDate > Date() && $0.dueDate <= nextTwoWeeks && $0.status == .pending 
        }
        
        let totalHours = upcomingAssignments.compactMap { $0.estimatedHours }.reduce(0, +)
        let highPriorityCount = upcomingAssignments.filter { $0.priority == .high || $0.priority == .critical }.count
        
        let intensity: WorkloadIntensity = {
            if totalHours > 40 || highPriorityCount > 5 {
                return .high
            } else if totalHours > 20 || highPriorityCount > 2 {
                return .medium
            } else {
                return .low
            }
        }()
        
        return WorkloadForecast(
            period: "Next 2 weeks",
            estimatedHours: totalHours,
            assignmentCount: upcomingAssignments.count,
            highPriorityCount: highPriorityCount,
            intensity: intensity,
            recommendations: generateWorkloadRecommendations(intensity, totalHours: totalHours)
        )
    }
    
    private func generateWorkloadRecommendations(_ intensity: WorkloadIntensity, totalHours: Double) -> [String] {
        switch intensity {
        case .high:
            return [
                "Consider rescheduling non-critical assignments",
                "Break large tasks into smaller, manageable chunks",
                "Schedule buffer time for unexpected delays",
                "Prioritize assignments with highest grade weight"
            ]
        case .medium:
            return [
                "Maintain steady progress on all assignments",
                "Review priority levels to optimize your focus",
                "Plan specific time blocks for deep work"
            ]
        case .low:
            return [
                "Great opportunity to get ahead on future assignments",
                "Consider working on long-term projects",
                "This is a good time to review and improve past work"
            ]
        }
    }
    
    @MainActor
    private func generateInsights(from assignments: [Assignment]) {
        // Generate study session recommendations based on assignment patterns
        let coursesWithUpcomingWork = Dictionary(grouping: assignments.filter { $0.status == .pending }, by: \.courseId)
        
        studySessionRecommendations = coursesWithUpcomingWork.compactMap { courseId, courseAssignments in
            guard let firstAssignment = courseAssignments.first else { return nil }
            
            // Recommend study time based on workload and priority
            let totalHours = courseAssignments.compactMap { $0.estimatedHours }.reduce(0, +)
            let highPriorityCount = courseAssignments.filter { $0.priority == .high || $0.priority == .critical }.count
            
            let recommendedTime = highPriorityCount > 0 ? TimeOfDay(hour: 9, minute: 0) : TimeOfDay(hour: 14, minute: 0)
            let duration = min(max(totalHours / Double(courseAssignments.count), 1.0), 3.0)
            
            return StudySessionRecommendation(
                subject: firstAssignment.courseName,
                recommendedTime: recommendedTime,
                duration: duration,
                reasoning: highPriorityCount > 0 ? "High priority assignments need early morning focus" : "Afternoon sessions work well for regular assignments",
                priority: highPriorityCount > 0 ? .high : .medium
            )
        }
        
        // Find most productive time slot based on historical data
        // For now, using a default based on common productivity patterns
        mostProductiveTimeSlot = TimeOfDay(hour: 10, minute: 0)
    }
    
    @MainActor
    private func generateMockCollaborationData() {
        // Keep existing collaboration functionality with mock data
        generateMockInsights()
    }
    
    func analyzeGroupProductivity(for group: CalendarGroup) -> GroupProductivityAnalysis {
        let meetings = calculateMeetingFrequency(for: group)
        let availability = calculateGroupAvailability(for: group)
        let conflictRate = calculateConflictRate(for: group)
        
        return GroupProductivityAnalysis(
            meetingFrequency: meetings,
            averageAvailability: availability,
            conflictRate: conflictRate,
            optimalMeetingTimes: findOptimalMeetingTimes(for: group),
            suggestions: generateProductivitySuggestions(for: group)
        )
    }
    
    func generateWeeklyReport(for group: CalendarGroup) -> WeeklyReport {
        return WeeklyReport(
            groupId: group.id,
            weekStarting: Date(),
            totalMeetings: Int.random(in: 3...8),
            averageMeetingDuration: Int.random(in: 45...90),
            mostActiveDay: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"].randomElement() ?? "Wednesday",
            collaborationScore: Double.random(in: 0.7...0.95),
            insights: generateWeeklyInsights(),
            recommendations: generateWeeklyRecommendations()
        )
    }
    
    // MARK: - Private Helper Methods
    private func calculateMeetingFrequency(for group: CalendarGroup) -> Double {
        // Mock calculation - in real app would analyze actual meeting data
        return Double.random(in: 2.5...4.5)
    }
    
    private func calculateGroupAvailability(for group: CalendarGroup) -> Double {
        // Calculate average availability percentage across all members
        let totalSlots = group.members.reduce(0) { total, member in
            total + member.availability.filter { $0.type == .free }.count
        }
        let maxPossibleSlots = group.members.count * 30 // Assuming 30 time slots per day
        return Double(totalSlots) / Double(maxPossibleSlots)
    }
    
    private func calculateConflictRate(for group: CalendarGroup) -> Double {
        // Mock calculation for conflict rate
        return Double.random(in: 0.1...0.3)
    }
    
    private func findOptimalMeetingTimes(for group: CalendarGroup) -> [TimeOfDay] {
        return [
            TimeOfDay(hour: 14, minute: 0),
            TimeOfDay(hour: 15, minute: 30),
            TimeOfDay(hour: 10, minute: 0)
        ]
    }
    
    private func generateProductivitySuggestions(for group: CalendarGroup) -> [ProductivitySuggestion] {
        return [
            ProductivitySuggestion(
                type: .scheduleOptimization,
                title: "Optimize Meeting Schedule",
                description: "Consider scheduling regular meetings on Tuesdays and Thursdays when all members are most available",
                impact: .high,
                effort: .low
            ),
            ProductivitySuggestion(
                type: .conflictReduction,
                title: "Reduce Schedule Conflicts",
                description: "Some members have overlapping commitments. Consider using async communication for quick updates",
                impact: .medium,
                effort: .medium
            )
        ]
    }
    
    private func generateWeeklyInsights() -> [String] {
        return [
            "Group meetings increased by 20% this week",
            "Best collaboration happened on Wednesday afternoons",
            "Average response time to meeting invites: 2.3 hours"
        ]
    }
    
    private func generateWeeklyRecommendations() -> [String] {
        return [
            "Schedule important decisions for mid-week when engagement is highest",
            "Consider shorter meetings - current average is 25% longer than optimal",
            "Use Tuesday mornings for deep work - highest individual productivity"
        ]
    }
    
    @MainActor
    private func generateMockInsights() {
        weeklyInsights = [
            WeeklyInsight(
                week: Date(),
                meetingCount: 5,
                averageAttendance: 0.85,
                topCollaborationDay: "Wednesday",
                productivityScore: 0.78
            ),
            WeeklyInsight(
                week: Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date(),
                meetingCount: 3,
                averageAttendance: 0.92,
                topCollaborationDay: "Tuesday",
                productivityScore: 0.82
            )
        ]
        
        studyPatterns = [
            StudyPattern(
                timeSlot: TimeOfDay(hour: 14, minute: 0),
                frequency: 0.75,
                effectiveness: 0.88,
                subjectAreas: ["Mobile Development", "Software Architecture"]
            ),
            StudyPattern(
                timeSlot: TimeOfDay(hour: 10, minute: 0),
                frequency: 0.60,
                effectiveness: 0.92,
                subjectAreas: ["Algorithms", "Data Structures"]
            )
        ]
        
        collaborationMetrics = CollaborationMetrics(
            totalGroups: 3,
            activeCollaborations: 7,
            averageResponseTime: 45, // minutes
            meetingSuccessRate: 0.86,
            mostProductiveHour: 14
        )
        
        productivityTrends = [
            ProductivityTrend(
                date: Date(),
                score: 0.78,
                meetingsAttended: 3,
                tasksCompleted: 7,
                focusHours: 4.5
            ),
            ProductivityTrend(
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                score: 0.82,
                meetingsAttended: 2,
                tasksCompleted: 9,
                focusHours: 5.2
            )
        ]
        
        // Generate some mock analytics when no real data is available
        if upcomingDeadlines.isEmpty {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            
            upcomingDeadlines = [
                Assignment(
                    title: "Mobile App Final Project",
                    courseId: "mobile-dev",
                    courseName: "Mobile Development",
                    courseColor: "#FF6B6B",
                    dueDate: tomorrow,
                    weight: 0.4,
                    priority: .high
                ),
                Assignment(
                    title: "Database Design Assignment",
                    courseId: "database",
                    courseName: "Database Systems",
                    courseColor: "#4ECDC4",
                    dueDate: nextWeek,
                    weight: 0.25,
                    priority: .medium
                )
            ]
        }
        
        if subjectPerformance.isEmpty {
            subjectPerformance = [
                SubjectPerformance(
                    courseId: "mobile-dev",
                    courseName: "Mobile Development",
                    completionRate: 0.85,
                    averageGrade: 92.0,
                    totalAssignments: 8,
                    upcomingAssignments: 2,
                    trend: .improving
                ),
                SubjectPerformance(
                    courseId: "database",
                    courseName: "Database Systems",
                    completionRate: 0.78,
                    averageGrade: 88.0,
                    totalAssignments: 6,
                    upcomingAssignments: 1,
                    trend: .stable
                ),
                SubjectPerformance(
                    courseId: "algorithms",
                    courseName: "Algorithms & Data Structures",
                    completionRate: 0.65,
                    averageGrade: 85.0,
                    totalAssignments: 10,
                    upcomingAssignments: 3,
                    trend: .declining
                )
            ]
        }
        
        if workloadForecast == nil {
            workloadForecast = WorkloadForecast(
                period: "Next 2 weeks",
                estimatedHours: 28.0,
                assignmentCount: 5,
                highPriorityCount: 2,
                intensity: .medium,
                recommendations: [
                    "Maintain steady progress on all assignments",
                    "Review priority levels to optimize your focus",
                    "Plan specific time blocks for deep work"
                ]
            )
        }
        
        // Set some default values for real-time metrics
        if todaysProductivityScore == 0.0 {
            todaysProductivityScore = 0.75
        }
        if weeklyGoalProgress == 0.0 {
            weeklyGoalProgress = 0.68
        }
        if assignmentCompletionRate == 0.0 {
            assignmentCompletionRate = 0.72
        }
        if averageTimeEstimationAccuracy == 0.0 {
            averageTimeEstimationAccuracy = 0.65
        }
        if daysSinceLastProgress == 0 {
            daysSinceLastProgress = 2
        }
    }
}

// MARK: - Data Models for Analytics

struct WeeklyInsight {
    let week: Date
    let meetingCount: Int
    let averageAttendance: Double
    let topCollaborationDay: String
    let productivityScore: Double
}

struct StudyPattern {
    let timeSlot: TimeOfDay
    let frequency: Double // How often this time is used for studying (0-1)
    let effectiveness: Double // How productive this time slot is (0-1)
    let subjectAreas: [String]
}

struct CollaborationMetrics {
    let totalGroups: Int
    let activeCollaborations: Int
    let averageResponseTime: Int // in minutes
    let meetingSuccessRate: Double
    let mostProductiveHour: Int
}

// MARK: - Insight Action Types

enum InsightActionType {
    case viewAllDeadlines
    case viewSubjectDetails(String)
    case optimizeSchedule
    case reviewProgress
}

struct ProductivityTrend {
    let date: Date
    let score: Double
    let meetingsAttended: Int
    let tasksCompleted: Int
    let focusHours: Double
}

// MARK: - New Analytics Data Models

struct SubjectPerformance {
    let courseId: String
    let courseName: String
    let completionRate: Double
    let averageGrade: Double
    let totalAssignments: Int
    let upcomingAssignments: Int
    let trend: PerformanceTrend
}

enum PerformanceTrend: String, CaseIterable {
    case improving = "improving"
    case stable = "stable"
    case declining = "declining"
    
    var color: Color {
        switch self {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .improving: return "arrow.up.circle.fill"
        case .stable: return "minus.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        }
    }
}

struct StudySessionRecommendation {
    let subject: String
    let recommendedTime: TimeOfDay
    let duration: Double // hours
    let reasoning: String
    let priority: Priority
}

struct WorkloadForecast {
    let period: String
    let estimatedHours: Double
    let assignmentCount: Int
    let highPriorityCount: Int
    let intensity: WorkloadIntensity
    let recommendations: [String]
}

enum WorkloadIntensity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "Light"
        case .medium: return "Moderate"
        case .high: return "Heavy"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "leaf.fill"
        case .medium: return "flame.fill"
        case .high: return "exclamationmark.triangle.fill"
        }
    }
}

struct GroupProductivityAnalysis {
    let meetingFrequency: Double
    let averageAvailability: Double
    let conflictRate: Double
    let optimalMeetingTimes: [TimeOfDay]
    let suggestions: [ProductivitySuggestion]
}

struct WeeklyReport {
    let groupId: String
    let weekStarting: Date
    let totalMeetings: Int
    let averageMeetingDuration: Int
    let mostActiveDay: String
    let collaborationScore: Double
    let insights: [String]
    let recommendations: [String]
}

struct ProductivitySuggestion {
    let type: SuggestionType
    let title: String
    let description: String
    let impact: Impact
    let effort: Effort
}

enum Impact: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var color: Color {
        switch self {
        case .high: return Color(hex: "#E74C3C")
        case .medium: return Color(hex: "#F39C12")
        case .low: return Color(hex: "#27AE60")
        }
    }
}

enum Effort: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var color: Color {
        switch self {
        case .high: return Color(hex: "#8E44AD")
        case .medium: return Color(hex: "#3498DB")
        case .low: return Color(hex: "#2ECC71")
        }
    }
}

// MARK: - Smart Features UI Components

struct SmartInsightsCard: View {
    let insight: WeeklyInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(UI.primary)
                
                Text("Weekly Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Text(weekText)
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
            
            HStack(spacing: 20) {
                InsightMetric(
                    icon: "calendar",
                    value: "\(insight.meetingCount)",
                    label: "Meetings",
                    color: UI.primary
                )
                
                InsightMetric(
                    icon: "person.3.fill",
                    value: "\(Int(insight.averageAttendance * 100))%",
                    label: "Attendance",
                    color: UI.success
                )
                
                InsightMetric(
                    icon: "star.fill",
                    value: "\(Int(insight.productivityScore * 100))%",
                    label: "Productivity",
                    color: UI.warning
                )
            }
            
            Text("Best collaboration day: **\(insight.topCollaborationDay)**")
                .font(.caption)
                .foregroundColor(UI.muted)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    private var weekText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Week of \(formatter.string(from: insight.week))"
    }
}

struct InsightMetric: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProductivityChart: View {
    let trends: [ProductivityTrend]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(UI.primary)
                
                Text("Productivity Trends")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(trends.indices, id: \.self) { index in
                    let trend = trends[index]
                    
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(UI.primary)
                            .frame(width: 20, height: CGFloat(trend.score * 60))
                        
                        Text(dayAbbreviation(for: trend.date))
                            .font(.caption2)
                            .foregroundColor(UI.muted)
                    }
                }
            }
            .frame(height: 80)
            
            HStack {
                Text("Average score: **\(Int(averageScore * 100))%**")
                    .font(.caption)
                    .foregroundColor(UI.muted)
                
                Spacer()
                
                if let trend = bestPerformanceDay {
                    Text("Best: \(dayName(for: trend.date))")
                        .font(.caption)
                        .foregroundColor(UI.success)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    private var averageScore: Double {
        guard !trends.isEmpty else { return 0 }
        return trends.reduce(0) { $0 + $1.score } / Double(trends.count)
    }
    
    private var bestPerformanceDay: ProductivityTrend? {
        trends.max { $0.score < $1.score }
    }
    
    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(2))
    }
    
    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

struct StudyPatternsView: View {
    let patterns: [StudyPattern]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(UI.primary)
                
                Text("Study Patterns")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            
            ForEach(patterns.indices, id: \.self) { index in
                let pattern = patterns[index]
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pattern.timeSlot.timeString)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(UI.navy)
                        
                        Text(pattern.subjectAreas.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(UI.muted)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("\(Int(pattern.effectiveness * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(UI.success)
                            
                            Text("effective")
                                .font(.caption)
                                .foregroundColor(UI.muted)
                        }
                        
                        ProgressView(value: pattern.frequency, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: UI.primary))
                            .scaleEffect(x: 1, y: 0.5)
                            .frame(width: 60)
                    }
                }
                .padding(.vertical, 8)
                
                if index < patterns.count - 1 {
                    Divider()
                }
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

// MARK: - Enhanced Smart Suggestions View
struct EnhancedSmartSuggestionsView: View {
    let suggestions: [ProductivitySuggestion]
    let onAccept: (ProductivitySuggestion) -> Void
    let onDismiss: (ProductivitySuggestion) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(UI.warning)
                
                Text("Smart Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            
            ForEach(suggestions.indices, id: \.self) { index in
                ProductivitySuggestionCard(
                    suggestion: suggestions[index],
                    onAccept: { onAccept(suggestions[index]) },
                    onDismiss: { onDismiss(suggestions[index]) }
                )
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

struct ProductivitySuggestionCard: View {
    let suggestion: ProductivitySuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Text(suggestion.description)
                        .font(.caption)
                        .foregroundColor(UI.muted)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    ImpactEffortBadge(impact: suggestion.impact, effort: suggestion.effort)
                }
            }
            
            HStack(spacing: 10) {
                Button(action: onDismiss) {
                    Text("Not Now")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(UI.muted.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Button(action: onAccept) {
                    Text("Apply")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(UI.primary)
                        )
                }
                
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(UI.neutralLight)
        )
    }
}

struct ImpactEffortBadge: View {
    let impact: Impact
    let effort: Effort
    
    var body: some View {
        HStack(spacing: 4) {
            VStack(spacing: 2) {
                Circle()
                    .fill(impact.color)
                    .frame(width: 6, height: 6)
                
                Text(impact.rawValue)
                    .font(.caption2)
                    .foregroundColor(UI.muted)
            }
            
            VStack(spacing: 2) {
                Circle()
                    .fill(effort.color)
                    .frame(width: 6, height: 6)
                
                Text(effort.rawValue)
                    .font(.caption2)
                    .foregroundColor(UI.muted)
            }
        }
    }
}

// MARK: - Enhanced Insights UI Components

struct SubjectPerformanceView: View {
    let performances: [SubjectPerformance]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(UI.primary)
                
                Text("Subject Performance")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            
            ForEach(Array(performances.prefix(3).enumerated()), id: \.offset) { index, performance in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(performance.courseName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(UI.navy)
                        
                        HStack(spacing: 8) {
                            Text("\(Int(performance.completionRate * 100))% complete")
                                .font(.caption)
                                .foregroundColor(UI.muted)
                            
                            if performance.averageGrade > 0 {
                                Text("Avg: \(Int(performance.averageGrade))%")
                                    .font(.caption)
                                    .foregroundColor(UI.success)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: performance.trend.icon)
                            .foregroundColor(performance.trend.color)
                            .font(.caption)
                        
                        Text("\(performance.upcomingAssignments)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("upcoming")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                if index < min(performances.count, 3) - 1 {
                    Divider()
                }
            }
            
            if performances.count > 3 {
                Button("View All Subjects") {
                    // Navigate to detailed view
                }
                .font(.caption)
                .foregroundColor(UI.primary)
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

struct WorkloadForecastView: View {
    let forecast: WorkloadForecast
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: forecast.intensity.icon)
                    .foregroundColor(forecast.intensity.color)
                
                Text("Workload Forecast")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Text(forecast.period)
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(forecast.estimatedHours))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(UI.navy)
                    
                    Text("Hours")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(forecast.assignmentCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(UI.navy)
                    
                    Text("Assignments")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(forecast.intensity.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(forecast.intensity.color)
                    
                    Text("Intensity")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                }
            }
            
            if !forecast.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommendations:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(UI.navy)
                    
                    Text(forecast.recommendations.first ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
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

struct ProductivityMetricsView: View {
    let todaysScore: Double
    let weeklyProgress: Double
    let completionRate: Double
    let estimationAccuracy: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(UI.primary)
                
                Text("Productivity Metrics")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ProductivityMetricCard(
                    title: "Today's Score",
                    value: "\(Int(todaysScore * 100))%",
                    color: todaysScore > 0.7 ? UI.success : todaysScore > 0.4 ? UI.warning : UI.error,
                    icon: "target"
                )
                
                ProductivityMetricCard(
                    title: "Weekly Progress",
                    value: "\(Int(weeklyProgress * 100))%",
                    color: weeklyProgress > 0.7 ? UI.success : weeklyProgress > 0.4 ? UI.warning : UI.error,
                    icon: "calendar.badge.checkmark"
                )
                
                ProductivityMetricCard(
                    title: "Completion Rate",
                    value: "\(Int(completionRate * 100))%",
                    color: completionRate > 0.8 ? UI.success : completionRate > 0.6 ? UI.warning : UI.error,
                    icon: "checkmark.circle"
                )
                
                ProductivityMetricCard(
                    title: "Time Accuracy",
                    value: estimationAccuracy > 0 ? "\(Int(estimationAccuracy * 100))%" : "N/A",
                    color: estimationAccuracy > 0.7 ? UI.success : estimationAccuracy > 0.5 ? UI.warning : UI.error,
                    icon: "clock.badge.checkmark"
                )
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

struct ProductivityMetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            Text(title)
                .font(.caption)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

struct UpcomingDeadlinesView: View {
    let assignments: [Assignment]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundColor(UI.warning)
                
                Text("Upcoming Deadlines")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                if !assignments.isEmpty {
                    Text("Next 7 days")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                }
            }
            
            if assignments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(UI.success)
                    
                    Text("No deadlines this week!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(UI.navy)
                    
                    Text("Great time to get ahead on future work.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(UI.success.opacity(0.1))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(assignments.prefix(4)) { assignment in
                        UpcomingDeadlineRow(assignment: assignment)
                    }
                    
                    if assignments.count > 4 {
                        Text("+ \(assignments.count - 4) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
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

struct UpcomingDeadlineRow: View {
    let assignment: Assignment
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: assignment.priority.color))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                    .lineLimit(1)
                
                HStack {
                    Text(assignment.courseName)
                        .font(.caption)
                        .foregroundColor(Color(hex: assignment.courseColor))
                    
                    Spacer()
                    
                    Text("\(Int(assignment.weight * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(relativeDateString(for: assignment.dueDate))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(daysToDueDate(assignment.dueDate) <= 2 ? UI.error : UI.muted)
                
                Text(timeString(for: assignment.dueDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func daysToDueDate(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
    }
    
    private func relativeDateString(for date: Date) -> String {
        let days = daysToDueDate(date)
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Tomorrow"
        } else {
            return "\(days) days"
        }
    }
    
    private func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}