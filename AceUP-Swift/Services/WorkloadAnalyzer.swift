//
//  WorkloadAnalyzer.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 4/10/25.
//

import Foundation

class WorkloadAnalyzer {
    
    // MARK: - Configuration
    
    private struct AnalysisConfig {
        static let overloadThreshold = 3 // 3+ assignments = overload
        static let analysisWindowDays = 7 // Analyze next 7 days
        static let lightWorkloadThreshold = 1 // 0-1 assignments = light day
        static let heavyWorkloadThreshold = 3 // 3+ assignments = heavy day
        static let recommendationCooldownHours = 6 // Don't spam recommendations
    }
    
    // MARK: - Public Methods
    
    /// Analyzes workload distribution across the next 7 days
    /// Returns workload analysis with recommendations
    func analyzeWorkload(assignments: [Assignment]) -> WorkloadAnalysisResult {
        let upcomingAssignments = getUpcomingAssignments(assignments)
        let dailyWorkload = calculateDailyWorkload(upcomingAssignments)
        let overloadDays = identifyOverloadDays(dailyWorkload)
        let lightDays = identifyLightDays(dailyWorkload)
        let recommendations = generateRecommendations(
            assignments: upcomingAssignments,
            dailyWorkload: dailyWorkload,
            overloadDays: overloadDays,
            lightDays: lightDays
        )
        
        return WorkloadAnalysisResult(
            totalAssignments: upcomingAssignments.count,
            dailyWorkload: dailyWorkload,
            averageDaily: calculateAverageDaily(dailyWorkload),
            overloadDays: overloadDays,
            lightDays: lightDays,
            recommendations: recommendations,
            analysisDate: Date()
        )
    }
    
    /// Identifies scheduling conflicts for a specific day
    func identifyConflicts(for date: Date, assignments: [Assignment]) -> [WorkloadConflict] {
        let dayAssignments = assignments.filter { assignment in
            Calendar.current.isDate(assignment.dueDate, inSameDayAs: date)
        }
        
        var conflicts: [WorkloadConflict] = []
        
        // Check for overload
        if dayAssignments.count >= AnalysisConfig.overloadThreshold {
            let totalWeight = dayAssignments.reduce(0) { $0 + $1.weight }
            let totalHours = dayAssignments.compactMap { $0.estimatedHours }.reduce(0, +)
            
            let hoursInfo = totalHours > 0 ? " (~\(Int(totalHours))h estimated)" : ""
            
            conflicts.append(WorkloadConflict(
                type: .overload,
                date: date,
                assignments: dayAssignments,
                severity: calculateOverloadSeverity(count: dayAssignments.count, weight: totalWeight),
                description: "Heavy workload: \(dayAssignments.count) assignments due\(hoursInfo)",
                suggestedAction: "Consider starting some assignments earlier or redistributing work"
            ))
        }
        
        // Check for high-weight concentration
        let highWeightAssignments = dayAssignments.filter { $0.weight >= 0.2 }
        if highWeightAssignments.count >= 2 {
            conflicts.append(WorkloadConflict(
                type: .highWeightConcentration,
                date: date,
                assignments: highWeightAssignments,
                severity: .high,
                description: "Multiple high-weight assignments due",
                suggestedAction: "Prioritize based on course importance and start early"
            ))
        }
        
        return conflicts
    }
    
    /// Generates smart recommendations for workload optimization
    func generateSmartRecommendations(assignments: [Assignment]) -> [SmartRecommendation] {
        let analysis = analyzeWorkload(assignments: assignments)
        var recommendations: [SmartRecommendation] = []
        
        // Workload redistribution recommendations
        for overloadDay in analysis.overloadDays {
            let overloadAssignments = analysis.dailyWorkload[overloadDay] ?? []
            let lightDay = findBestLightDay(from: analysis.lightDays, avoiding: overloadDay)
            
            if let targetDay = lightDay {
                let suggestedAssignment = selectBestAssignmentToMove(from: overloadAssignments)
                
                recommendations.append(SmartRecommendation(
                    id: UUID().uuidString,
                    type: .workloadDistribution,
                    title: "Redistribute Workload",
                    message: "\(DateFormatter.dayName.string(from: overloadDay)) has \(overloadAssignments.count) assignments due. \(DateFormatter.dayName.string(from: targetDay)) looks lighter - consider starting '\(suggestedAssignment?.title ?? "some assignments")' on \(DateFormatter.dayName.string(from: targetDay)).",
                    priority: .high,
                    actionable: true,
                    suggestedAction: "Move assignment",
                    relatedAssignments: [suggestedAssignment?.id].compactMap { $0 },
                    createdAt: Date()
                ))
            }
        }
        
        // Early start recommendations
        let criticalAssignments = assignments.filter { 
            $0.priority == .critical && $0.daysUntilDue <= 3 && $0.status == .pending 
        }
        
        for assignment in criticalAssignments {
            recommendations.append(SmartRecommendation(
                id: UUID().uuidString,
                type: .earlyStart,
                title: "Start Critical Assignment",
                message: "'\(assignment.title)' is due in \(assignment.daysUntilDue) day\(assignment.daysUntilDue == 1 ? "" : "s") and has high impact (\(assignment.weightPercentage)%). Consider starting today.",
                priority: .critical,
                actionable: true,
                suggestedAction: "Start now",
                relatedAssignments: [assignment.id],
                createdAt: Date()
            ))
        }
        
        // Time management recommendations
        let longAssignments = assignments.filter { 
            ($0.estimatedHours ?? 0) > 10 && $0.daysUntilDue <= 7 && $0.status == .pending 
        }
        
        for assignment in longAssignments {
            recommendations.append(SmartRecommendation(
                id: UUID().uuidString,
                type: .timeManagement,
                title: "Break Down Large Assignment",
                message: "'\(assignment.title)' requires ~\(Int(assignment.estimatedHours ?? 0)) hours. Break it into smaller tasks to make progress manageable.",
                priority: .medium,
                actionable: true,
                suggestedAction: "Create subtasks",
                relatedAssignments: [assignment.id],
                createdAt: Date()
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Private Methods
    
    private func getUpcomingAssignments(_ assignments: [Assignment]) -> [Assignment] {
        let endDate = Calendar.current.date(byAdding: .day, value: AnalysisConfig.analysisWindowDays, to: Date()) ?? Date()
        return assignments.filter { assignment in
            assignment.dueDate >= Date() && 
            assignment.dueDate <= endDate && 
            (assignment.status == .pending || assignment.status == .inProgress)
        }
    }
    
    private func calculateDailyWorkload(_ assignments: [Assignment]) -> [Date: [Assignment]] {
        let calendar = Calendar.current
        var dailyWorkload: [Date: [Assignment]] = [:]
        
        // Initialize all days in the analysis window
        for i in 0..<AnalysisConfig.analysisWindowDays {
            if let date = calendar.date(byAdding: .day, value: i, to: Date()) {
                let dayStart = calendar.startOfDay(for: date)
                dailyWorkload[dayStart] = []
            }
        }
        
        // Group assignments by due date
        for assignment in assignments {
            let dayStart = calendar.startOfDay(for: assignment.dueDate)
            dailyWorkload[dayStart, default: []].append(assignment)
        }
        
        return dailyWorkload
    }
    
    private func identifyOverloadDays(_ dailyWorkload: [Date: [Assignment]]) -> [Date] {
        return dailyWorkload.compactMap { date, assignments in
            assignments.count >= AnalysisConfig.overloadThreshold ? date : nil
        }.sorted()
    }
    
    private func identifyLightDays(_ dailyWorkload: [Date: [Assignment]]) -> [Date] {
        return dailyWorkload.compactMap { date, assignments in
            assignments.count <= AnalysisConfig.lightWorkloadThreshold ? date : nil
        }.sorted()
    }
    
    private func calculateAverageDaily(_ dailyWorkload: [Date: [Assignment]]) -> Double {
        let totalAssignments = dailyWorkload.values.reduce(0) { $0 + $1.count }
        return Double(totalAssignments) / Double(AnalysisConfig.analysisWindowDays)
    }
    
    private func generateRecommendations(
        assignments: [Assignment],
        dailyWorkload: [Date: [Assignment]],
        overloadDays: [Date],
        lightDays: [Date]
    ) -> [String] {
        var recommendations: [String] = []
        
        if overloadDays.isEmpty && lightDays.count <= 2 {
            recommendations.append("📊 Good workload distribution across the week")
        }
        
        for overloadDay in overloadDays {
            let assignmentCount = dailyWorkload[overloadDay]?.count ?? 0
            let dayName = DateFormatter.dayName.string(from: overloadDay)
            
            if let lightDay = lightDays.first {
                let lightDayName = DateFormatter.dayName.string(from: lightDay)
                recommendations.append("⚠️ \(dayName) has \(assignmentCount) assignments due. \(lightDayName) looks lighter - consider starting work early.")
            } else {
                recommendations.append("⚠️ \(dayName) has \(assignmentCount) assignments due. Plan ahead to manage the workload.")
            }
        }
        
        let criticalAssignments = assignments.filter { $0.priority == .critical && $0.daysUntilDue <= 3 }
        if !criticalAssignments.isEmpty {
            recommendations.append("🚨 \(criticalAssignments.count) critical assignment\(criticalAssignments.count == 1 ? "" : "s") due soon. Prioritize immediately.")
        }
        
        return recommendations
    }
    
    private func calculateOverloadSeverity(count: Int, weight: Double) -> ConflictSeverity {
        if count >= 5 || weight >= 0.8 { return .critical }
        if count >= 4 || weight >= 0.6 { return .high }
        if count >= 3 || weight >= 0.4 { return .medium }
        return .low
    }
    
    private func findBestLightDay(from lightDays: [Date], avoiding overloadDay: Date) -> Date? {
        // Prefer days closer to overload day but not the same day
        return lightDays
            .filter { !Calendar.current.isDate($0, inSameDayAs: overloadDay) }
            .min { abs($0.timeIntervalSince(overloadDay)) < abs($1.timeIntervalSince(overloadDay)) }
    }
    
    private func selectBestAssignmentToMove(from assignments: [Assignment]) -> Assignment? {
        // Prefer assignments with lower priority and weight for moving
        return assignments.min { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority.numericValue < rhs.priority.numericValue
            }
            return lhs.weight < rhs.weight
        }
    }
}

// MARK: - Supporting Models

struct WorkloadAnalysisResult {
    let totalAssignments: Int
    let dailyWorkload: [Date: [Assignment]]
    let averageDaily: Double
    let overloadDays: [Date]
    let lightDays: [Date]
    let recommendations: [String]
    let analysisDate: Date
    
    var hasOverload: Bool {
        !overloadDays.isEmpty
    }
    
    var workloadBalance: WorkloadBalance {
        if overloadDays.count >= 3 { return .poor }
        if overloadDays.count >= 2 { return .fair }
        if !overloadDays.isEmpty { return .good }
        return .excellent
    }
}

struct WorkloadConflict {
    let type: ConflictType
    let date: Date
    let assignments: [Assignment]
    let severity: ConflictSeverity
    let description: String
    let suggestedAction: String
}

struct SmartRecommendation {
    let id: String
    let type: RecommendationType
    let title: String
    let message: String
    let priority: Priority
    let actionable: Bool
    let suggestedAction: String?
    let relatedAssignments: [String]
    let createdAt: Date
}

enum WorkloadBalance: String, Codable, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "#4CAF50"
        case .good: return "#8BC34A"
        case .fair: return "#FF9800"
        case .poor: return "#F44336"
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.triangle"
        case .poor: return "xmark.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .excellent: return "Your workload is perfectly balanced"
        case .good: return "Your workload is well managed"
        case .fair: return "Your workload needs some attention"
        case .poor: return "Your workload is overwhelming"
        }
    }
}

enum ConflictType: String, CaseIterable {
    case overload = "overload"
    case highWeightConcentration = "high_weight_concentration"
    case timeConstraint = "time_constraint"
    case dependency = "dependency"
    
    var displayName: String {
        switch self {
        case .overload: return "Workload Overload"
        case .highWeightConcentration: return "High-Weight Concentration"
        case .timeConstraint: return "Time Constraint"
        case .dependency: return "Dependency Conflict"
        }
    }
}

enum ConflictSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var color: String {
        switch self {
        case .low: return "#4CAF50"
        case .medium: return "#FF9800"
        case .high: return "#FF5722"
        case .critical: return "#F44336"
        }
    }
}

enum RecommendationType: String, CaseIterable {
    case workloadDistribution = "workload_distribution"
    case earlyStart = "early_start"
    case timeManagement = "time_management"
    case priority = "priority"
    case dependency = "dependency"
    
    var displayName: String {
        switch self {
        case .workloadDistribution: return "Workload Distribution"
        case .earlyStart: return "Early Start"
        case .timeManagement: return "Time Management"
        case .priority: return "Priority"
        case .dependency: return "Dependency"
        }
    }
    
    var icon: String {
        switch self {
        case .workloadDistribution: return "chart.bar"
        case .earlyStart: return "clock.arrow.2.circlepath"
        case .timeManagement: return "timer"
        case .priority: return "exclamationmark.triangle"
        case .dependency: return "link"
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let dayName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    static let shortDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
    
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}