//
//  SmartCalendarFeatures.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

import SwiftUI
import Foundation

// MARK: - Smart Calendar Analytics Service
@MainActor
class SmartCalendarAnalytics: ObservableObject {
    
    @Published var weeklyInsights: [WeeklyInsight] = []
    @Published var studyPatterns: [StudyPattern] = []
    @Published var collaborationMetrics: CollaborationMetrics?
    @Published var productivityTrends: [ProductivityTrend] = []
    
    init() {
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

struct ProductivityTrend {
    let date: Date
    let score: Double
    let meetingsAttended: Int
    let tasksCompleted: Int
    let focusHours: Double
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