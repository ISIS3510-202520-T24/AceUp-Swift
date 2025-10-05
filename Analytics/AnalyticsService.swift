//
//  AnalyticsService.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

import Foundation

// MARK: - Analytics Service
class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()
    
    @Published var studentData: StudentAnalyticsData?
    @Published var isLoading = false
    @Published var lastResponse: HighestWeightEventResponse?
    
    private let baseURL = "http://localhost:8080"
    private let session = URLSession.shared
    
    private init() {
        loadMockData()
    }
    
    // MARK: - Business Question Implementation
    
    /// BQ 2.1: For a student, what is the next assignment or exam in their calendar 
    /// that carries the highest weight toward their final grade and is still marked as "Pending"?
    func getHighestWeightPendingEvent(for userId: String) async throws -> HighestWeightEventResponse {
        isLoading = true
        defer { isLoading = false }
        
        guard let data = studentData else {
            throw AnalyticsError.noDataAvailable
        }
        
        let response = await analyzeHighestWeightEvent(data: data, userId: userId)
        
        DispatchQueue.main.async {
            self.lastResponse = response
        }
        
        // Track analytics event
        Analytics.shared.track("highest_weight_event_queried", props: [
            "user_id": userId,
            "pending_events_count": data.pendingEvents.count,
            "has_result": response.data?.event != nil
        ])
        
        return response
    }
    
    private func analyzeHighestWeightEvent(data: StudentAnalyticsData, userId: String) async -> HighestWeightEventResponse {
        let pendingEvents = data.pendingEvents
        
        guard !pendingEvents.isEmpty else {
            return HighestWeightEventResponse(
                success: true,
                message: "No pending academic events found. Great job staying on top of your work!",
                data: HighestWeightEventData(
                    event: nil,
                    analysis: EventAnalysis(
                        totalPendingEvents: 0,
                        averageWeight: 0.0,
                        daysToDue: 0,
                        urgencyLevel: .low,
                        impactScore: 0.0,
                        courseLoad: "Light"
                    ),
                    recommendations: [
                        "Consider planning ahead for upcoming assignments",
                        "Review your course syllabi for future deadlines",
                        "Use this free time to get ahead on reading or projects"
                    ]
                ),
                timestamp: Date(),
                userId: userId
            )
        }
        
        // Find the highest priority event based on our scoring algorithm
        let highestPriorityEvent = pendingEvents.max { event1, event2 in
            event1.priorityScore < event2.priorityScore
        }
        
        guard let topEvent = highestPriorityEvent else {
            return HighestWeightEventResponse(
                success: false,
                message: "Error analyzing pending events",
                data: nil,
                timestamp: Date(),
                userId: userId
            )
        }
        
        // Calculate analysis metrics
        let totalWeight = pendingEvents.reduce(0) { $0 + $1.weight }
        let averageWeight = totalWeight / Double(pendingEvents.count)
        
        let urgencyLevel: UrgencyLevel
        if topEvent.daysUntilDue <= 1 {
            urgencyLevel = .critical
        } else if topEvent.daysUntilDue <= 3 {
            urgencyLevel = .high
        } else if topEvent.daysUntilDue <= 7 {
            urgencyLevel = .moderate
        } else {
            urgencyLevel = .low
        }
        
        let courseLoad: String
        if pendingEvents.count >= 8 {
            courseLoad = "Heavy"
        } else if pendingEvents.count >= 5 {
            courseLoad = "Moderate"
        } else {
            courseLoad = "Light"
        }
        
        // Generate recommendations
        let recommendations = generateRecommendations(for: topEvent, totalPending: pendingEvents.count)
        
        let analysis = EventAnalysis(
            totalPendingEvents: pendingEvents.count,
            averageWeight: averageWeight,
            daysToDue: topEvent.daysUntilDue,
            urgencyLevel: urgencyLevel,
            impactScore: topEvent.priorityScore,
            courseLoad: courseLoad
        )
        
        let responseData = HighestWeightEventData(
            event: topEvent,
            analysis: analysis,
            recommendations: recommendations
        )
        
        return HighestWeightEventResponse(
            success: true,
            message: "Successfully identified highest priority pending academic event",
            data: responseData,
            timestamp: Date(),
            userId: userId
        )
    }
    
    private func generateRecommendations(for event: AcademicEvent, totalPending: Int) -> [String] {
        var recommendations: [String] = []
        
        // Time-based recommendations
        if event.daysUntilDue <= 1 {
            recommendations.append("🚨 URGENT: This \(event.type.displayName.lowercased()) is due within 24 hours!")
            recommendations.append("Focus solely on this task and complete it as soon as possible")
        } else if event.daysUntilDue <= 3 {
            recommendations.append("⚠️ Priority: This \(event.type.displayName.lowercased()) is due very soon")
            recommendations.append("Allocate significant time today to work on this")
        } else if event.daysUntilDue <= 7 {
            recommendations.append("📅 Plan ahead: Start working on this \(event.type.displayName.lowercased()) soon")
        }
        
        // Weight-based recommendations
        if event.weight >= 0.3 {
            recommendations.append("💎 High Impact: This task represents \(event.weightPercentage)% of your grade")
            recommendations.append("Consider dedicating extra study time given its importance")
        } else if event.weight >= 0.15 {
            recommendations.append("📊 Moderate Impact: Worth \(event.weightPercentage)% of your final grade")
        }
        
        // Workload recommendations
        if totalPending >= 8 {
            recommendations.append("📚 Heavy workload detected - consider prioritizing by due date and weight")
            recommendations.append("Break down large tasks into smaller, manageable chunks")
        }
        
        // Type-specific recommendations
        switch event.type {
        case .exam:
            recommendations.append("📖 Create a study schedule leading up to the exam")
            recommendations.append("Review past materials and practice problems")
        case .project:
            recommendations.append("🛠️ Break this project into phases with mini-deadlines")
            recommendations.append("Start with research and planning phases")
        case .assignment:
            recommendations.append("✍️ Begin with an outline or initial draft")
        default:
            recommendations.append("📋 Set aside dedicated time to work on this task")
        }
        
        return recommendations
    }
    
    // MARK: - Mock Data for Demo
    private func loadMockData() {
        let mockCourses = [
            Course(
                id: "cs101",
                name: "Introduction to Computer Science",
                code: "CS 101",
                credits: 3,
                instructor: "Dr. Smith",
                color: "#122C4A",
                semester: "Fall",
                year: 2024,
                gradeWeight: GradeWeight(
                    assignments: 0.4,
                    exams: 0.4,
                    projects: 0.15,
                    participation: 0.05,
                    other: 0.0
                ),
                currentGrade: 0.85,
                targetGrade: 0.90,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Course(
                id: "math201",
                name: "Calculus II",
                code: "MATH 201",
                credits: 4,
                instructor: "Prof. Johnson",
                color: "#50E3C2",
                semester: "Fall",
                year: 2024,
                gradeWeight: GradeWeight(
                    assignments: 0.25,
                    exams: 0.60,
                    projects: 0.0,
                    participation: 0.15,
                    other: 0.0
                ),
                currentGrade: 0.78,
                targetGrade: 0.85,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        let calendar = Calendar.current
        
        let mockEvents = [
            AcademicEvent(
                id: "event1",
                title: "Final Programming Project",
                description: "Develop a complete web application using React and Node.js",
                courseId: "cs101",
                courseName: "Introduction to Computer Science",
                type: .project,
                dueDate: calendar.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                weight: 0.25,
                status: .pending,
                priority: .high,
                estimatedHours: 20,
                actualHours: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            AcademicEvent(
                id: "event2",
                title: "Midterm Exam",
                description: "Comprehensive exam covering chapters 8-12",
                courseId: "math201",
                courseName: "Calculus II",
                type: .exam,
                dueDate: calendar.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
                weight: 0.30,
                status: .pending,
                priority: .critical,
                estimatedHours: 8,
                actualHours: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            AcademicEvent(
                id: "event3",
                title: "Homework Assignment 7",
                description: "Integration problems and applications",
                courseId: "math201",
                courseName: "Calculus II",
                type: .homework,
                dueDate: calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                weight: 0.05,
                status: .pending,
                priority: .medium,
                estimatedHours: 3,
                actualHours: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            AcademicEvent(
                id: "event4",
                title: "Algorithm Analysis Quiz",
                description: "Quick quiz on Big O notation and complexity analysis",
                courseId: "cs101",
                courseName: "Introduction to Computer Science",
                type: .quiz,
                dueDate: calendar.date(byAdding: .day, value: 10, to: Date()) ?? Date(),
                weight: 0.08,
                status: .pending,
                priority: .medium,
                estimatedHours: 2,
                actualHours: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        studentData = StudentAnalyticsData(
            userId: "student123",
            courses: mockCourses,
            events: mockEvents,
            lastUpdated: Date()
        )
    }
}

// MARK: - Analytics Errors
enum AnalyticsError: LocalizedError {
    case noDataAvailable
    case networkError(String)
    case invalidResponse
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .noDataAvailable:
            return "No academic data available for analysis"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from analytics service"
        case .unauthorized:
            return "Unauthorized access to analytics data"
        }
    }
}