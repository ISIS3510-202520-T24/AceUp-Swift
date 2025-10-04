//
//  WorkloadAnalyzer.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 3/10/25.
//

import Foundation

struct WorkloadDay {
    let date: Date
    let assignments: [Assignment]
    var workloadScore: Int {
        assignments.filter { !$0.isCompleted }.count
    }
}

struct WorkloadRecommendation {
    let message: String
    let shouldNotify: Bool
}

class WorkloadAnalyzer {
    private let repository: AssignmentRepository
    
    init(repository: AssignmentRepository) {
        self.repository = repository
    }
    
    func analyzeNext7Days() throws -> WorkloadRecommendation {
        let assignments = try repository.fetchNext7Days()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Group assignments by day
        var workloadByDay: [Date: [Assignment]] = [:]
        
        for i in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: i, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            let dayAssignments = assignments.filter { assignment in
                guard let dueDate = assignment.dueDate else { return false }
                return dueDate >= dayStart && dueDate < dayEnd && !assignment.isCompleted
            }
            
            workloadByDay[dayStart] = dayAssignments
        }
        
        // Find overload days (3+ assignments)
        let overloadDays = workloadByDay.filter { $0.value.count >= 3 }
        
        // Find the lightest day in the next 7 days
        let lightestDay = workloadByDay.min { $0.value.count < $1.value.count }
        
        // Generate recommendation
        if !overloadDays.isEmpty, let lightDay = lightestDay {
            // Find the nearest overload day
            if let nearestOverload = overloadDays.keys.sorted().first,
               let overloadAssignments = workloadByDay[nearestOverload],
               let firstAssignment = overloadAssignments.first {
                
                let overloadDayName = formatDayName(nearestOverload)
                let lightDayName = formatDayName(lightDay.key)
                let assignmentCount = overloadAssignments.count
                
                return WorkloadRecommendation(
                    message: "\(overloadDayName) has \(assignmentCount) assignments due. \(lightDayName) looks lighter - consider starting '\(firstAssignment.title)' on \(lightDayName).",
                    shouldNotify: true
                )
            }
        }
        
        return WorkloadRecommendation(
            message: "Your workload looks balanced this week.",
            shouldNotify: false
        )
    }
    
    private func formatDayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Full day name
        return formatter.string(from: date)
    }
}
