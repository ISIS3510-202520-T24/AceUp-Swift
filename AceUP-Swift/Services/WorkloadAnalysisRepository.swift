//
//  WorkloadAnalysisRepository.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Firestore Model for Workload Analysis
struct WorkloadAnalysisFirestore: Codable {
    let id: String
    let userId: String
    let analysisDate: Timestamp
    let totalAssignments: Int
    let averageDaily: Double
    let workloadBalance: String
    let overloadDays: [Timestamp]
    let lightDays: [Timestamp]
    let recommendations: [String]
    let dailyWorkload: [String: Double] // Date string -> workload score
    let createdAt: Timestamp
}

// MARK: - Local Workload Analysis Models
struct WorkloadAnalysis: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let analysisDate: Date
    let totalAssignments: Int
    let averageDaily: Double
    let workloadBalance: WorkloadBalance
    let overloadDays: [Date]
    let lightDays: [Date]
    let recommendations: [String]
    let dailyWorkload: [Date: Double]
    let createdAt: Date
    
    static func == (lhs: WorkloadAnalysis, rhs: WorkloadAnalysis) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Workload Analysis Repository Protocol
protocol WorkloadAnalysisRepositoryProtocol {
    func loadAnalysis() async throws -> [WorkloadAnalysis]
    func loadLatestAnalysis() async throws -> WorkloadAnalysis?
    func saveAnalysis(_ analysis: WorkloadAnalysis) async throws
    func deleteAnalysis(id: String) async throws
    func generateAnalysis(assignments: [Assignment]) async throws -> WorkloadAnalysis
    func startRealtimeListener()
    func stopRealtimeListener()
}

// MARK: - Firebase Workload Analysis Repository
class FirebaseWorkloadAnalysisRepository: ObservableObject, WorkloadAnalysisRepositoryProtocol {
    
    // MARK: - Published Properties
    @Published var analyses: [WorkloadAnalysis] = []
    @Published var latestAnalysis: WorkloadAnalysis?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var analysisListener: ListenerRegistration?
    
    private var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? ""
    }
    
    deinit {
        analysisListener?.remove()
        analysisListener = nil
    }
    
    // MARK: - Public Methods
    
    func loadAnalysis() async throws -> [WorkloadAnalysis] {
        guard !currentUserId.isEmpty else {
            throw WorkloadAnalysisError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let querySnapshot = try await db.collection("workload_analysis")
                .whereField("userId", isEqualTo: currentUserId)
                .order(by: "analysisDate", descending: true)
                .limit(to: 30) // Load last 30 analyses
                .getDocuments()
            
            let analyses = try querySnapshot.documents.compactMap { document in
                try convertFirestoreToWorkloadAnalysis(document.data(), documentId: document.documentID)
            }
            
            await MainActor.run {
                self.analyses = analyses
                self.latestAnalysis = analyses.first
            }
            
            return analyses
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load workload analysis: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func loadLatestAnalysis() async throws -> WorkloadAnalysis? {
        guard !currentUserId.isEmpty else {
            throw WorkloadAnalysisError.notAuthenticated
        }
        
        do {
            let querySnapshot = try await db.collection("workload_analysis")
                .whereField("userId", isEqualTo: currentUserId)
                .order(by: "analysisDate", descending: true)
                .limit(to: 1)
                .getDocuments()
            
            guard let document = querySnapshot.documents.first else {
                return nil
            }
            
            let analysis = try convertFirestoreToWorkloadAnalysis(document.data(), documentId: document.documentID)
            
            await MainActor.run {
                self.latestAnalysis = analysis
            }
            
            return analysis
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load latest analysis: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func saveAnalysis(_ analysis: WorkloadAnalysis) async throws {
        guard !currentUserId.isEmpty else {
            throw WorkloadAnalysisError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let firestoreAnalysis = convertWorkloadAnalysisToFirestore(analysis)
            
            let data: [String: Any] = [
                "userId": firestoreAnalysis.userId,
                "analysisDate": firestoreAnalysis.analysisDate,
                "totalAssignments": firestoreAnalysis.totalAssignments,
                "averageDaily": firestoreAnalysis.averageDaily,
                "workloadBalance": firestoreAnalysis.workloadBalance,
                "overloadDays": firestoreAnalysis.overloadDays,
                "lightDays": firestoreAnalysis.lightDays,
                "recommendations": firestoreAnalysis.recommendations,
                "dailyWorkload": firestoreAnalysis.dailyWorkload,
                "createdAt": firestoreAnalysis.createdAt
            ]
            
            if analysis.id.isEmpty {
                // Create new analysis
                let docRef = try await db.collection("workload_analysis").addDocument(data: data)
                print("Analysis created with ID: \(docRef.documentID)")
            } else {
                // Update existing analysis
                try await db.collection("workload_analysis").document(analysis.id).setData(data)
                print("Analysis updated successfully")
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save analysis: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func deleteAnalysis(id: String) async throws {
        guard !currentUserId.isEmpty else {
            throw WorkloadAnalysisError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("workload_analysis").document(id).delete()
            
            await MainActor.run {
                self.analyses.removeAll { $0.id == id }
                if self.latestAnalysis?.id == id {
                    self.latestAnalysis = self.analyses.first
                }
            }
            
            print("Analysis deleted successfully")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete analysis: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func generateAnalysis(assignments: [Assignment]) async throws -> WorkloadAnalysis {
        let calendar = Calendar.current
        let now = Date()
        let twoWeeksFromNow = calendar.date(byAdding: .day, value: 14, to: now) ?? now
        
        // Filter relevant assignments (upcoming in next 2 weeks)
        let relevantAssignments = assignments.filter { assignment in
            assignment.dueDate >= now && assignment.dueDate <= twoWeeksFromNow
        }
        
        // Calculate daily workload distribution
        var dailyWorkload: [Date: Double] = [:]
        var totalWork = 0.0
        
        for assignment in relevantAssignments {
            let daysUntilDue = calendar.dateComponents([.day], from: now, to: assignment.dueDate).day ?? 0
            let workPerDay = calculateAssignmentWorkload(assignment) / max(Double(daysUntilDue), 1.0)
            
            for dayOffset in 0...max(daysUntilDue - 1, 0) {
                if let workDate = calendar.date(byAdding: .day, value: dayOffset, to: now) {
                    let dayStart = calendar.startOfDay(for: workDate)
                    dailyWorkload[dayStart, default: 0.0] += workPerDay
                    totalWork += workPerDay
                }
            }
        }
        
        // Calculate metrics
        let averageDaily = totalWork / 14.0 // Average over 2 weeks
        let workloadBalance = calculateWorkloadBalance(dailyWorkload: dailyWorkload)
        
        // Identify overload and light days
        let overloadThreshold = averageDaily * 1.5
        let lightThreshold = averageDaily * 0.3
        
        let overloadDays = dailyWorkload.compactMap { (date, workload) in
            workload > overloadThreshold ? date : nil
        }
        
        let lightDays = dailyWorkload.compactMap { (date, workload) in
            workload < lightThreshold ? date : nil
        }
        
        // Generate recommendations
        let recommendations = generateRecommendations(
            balance: workloadBalance,
            overloadDays: overloadDays,
            lightDays: lightDays,
            averageDaily: averageDaily
        )
        
        let analysis = WorkloadAnalysis(
            id: UUID().uuidString,
            userId: currentUserId,
            analysisDate: now,
            totalAssignments: relevantAssignments.count,
            averageDaily: averageDaily,
            workloadBalance: workloadBalance,
            overloadDays: overloadDays,
            lightDays: lightDays,
            recommendations: recommendations,
            dailyWorkload: dailyWorkload,
            createdAt: now
        )
        
        // Save the analysis
        try await saveAnalysis(analysis)
        
        return analysis
    }
    
    nonisolated func startRealtimeListener() {
        let userId = Auth.auth().currentUser?.uid ?? ""
        guard !userId.isEmpty else { return }
        
        Task { @MainActor in
            stopRealtimeListener() // Stop any existing listener
            
            analysisListener = db.collection("workload_analysis")
                .whereField("userId", isEqualTo: userId)
                .order(by: "analysisDate", descending: true)
                .limit(to: 30)
                .addSnapshotListener { [weak self] querySnapshot, error in
                    
                    Task { @MainActor in
                        guard let self = self else { return }
                        
                        if let error = error {
                            self.errorMessage = "Realtime listener error: \(error.localizedDescription)"
                            return
                        }
                        
                        guard let documents = querySnapshot?.documents else { return }
                        
                        do {
                            let analyses = try documents.compactMap { document in
                                try self.convertFirestoreToWorkloadAnalysis(document.data(), documentId: document.documentID)
                            }
                            
                            self.analyses = analyses
                            self.latestAnalysis = analyses.first
                            
                        } catch {
                            self.errorMessage = "Failed to process realtime updates: \(error.localizedDescription)"
                        }
                    }
                }
        }
    }
    
    nonisolated func stopRealtimeListener() {
        analysisListener?.remove()
        analysisListener = nil
    }
    
    // MARK: - Private Helper Methods
    
    private func calculateAssignmentWorkload(_ assignment: Assignment) -> Double {
        var baseWorkload = 1.0
        
        // Adjust based on priority
        switch assignment.priority {
        case .low:
            baseWorkload *= 0.7
        case .medium:
            baseWorkload *= 1.0
        case .high:
            baseWorkload *= 1.5
        case .critical:
            baseWorkload *= 2.0
        }
        
        // Adjust based on complexity (estimated hours)
        if let estimatedHours = assignment.estimatedHours, estimatedHours > 0 {
            baseWorkload = estimatedHours
        }
        
        // Adjust based on subtasks
        if !assignment.subtasks.isEmpty {
            let completedSubtasks = assignment.subtasks.filter { $0.isCompleted }.count
            let totalSubtasks = assignment.subtasks.count
            let remainingRatio = Double(totalSubtasks - completedSubtasks) / Double(totalSubtasks)
            baseWorkload *= remainingRatio
        }
        
        return max(baseWorkload, 0.1) // Minimum workload
    }
    
    private func calculateWorkloadBalance(dailyWorkload: [Date: Double]) -> WorkloadBalance {
        guard !dailyWorkload.isEmpty else { return .excellent }
        
        let workloads = Array(dailyWorkload.values)
        let average = workloads.reduce(0, +) / Double(workloads.count)
        let variance = workloads.map { pow($0 - average, 2) }.reduce(0, +) / Double(workloads.count)
        
        // Determine balance based on average workload and variance
        if average <= 2.0 && variance <= 1.0 {
            return .excellent
        } else if average <= 4.0 && variance <= 2.0 {
            return .good
        } else if average <= 6.0 && variance <= 4.0 {
            return .fair
        } else {
            return .poor
        }
    }
    
    private func generateRecommendations(
        balance: WorkloadBalance,
        overloadDays: [Date],
        lightDays: [Date],
        averageDaily: Double
    ) -> [String] {
        var recommendations: [String] = []
        
        switch balance {
        case .excellent:
            recommendations.append("Great job! Your workload is well balanced.")
        case .good:
            recommendations.append("Your workload is manageable. Keep up the good work!")
        case .fair:
            recommendations.append("Consider redistributing some tasks to balance your workload.")
        case .poor:
            recommendations.append("Your workload is overwhelming. Consider breaking down large tasks.")
        }
        
        if !overloadDays.isEmpty {
            recommendations.append("You have \(overloadDays.count) overloaded day(s). Try to move some tasks to lighter days.")
        }
        
        if !lightDays.isEmpty && !overloadDays.isEmpty {
            recommendations.append("Use your \(lightDays.count) lighter day(s) to prepare for busier periods.")
        }
        
        if averageDaily > 5.0 {
            recommendations.append("Consider starting assignments earlier to reduce daily pressure.")
        }
        
        if averageDaily < 1.0 {
            recommendations.append("You have light workload ahead. Great time to get ahead on future assignments!")
        }
        
        return recommendations
    }
    
    private func convertWorkloadAnalysisToFirestore(_ analysis: WorkloadAnalysis) -> WorkloadAnalysisFirestore {
        let dailyWorkloadStringDict: [String: Double] = Dictionary(
            uniqueKeysWithValues: analysis.dailyWorkload.map { (date, workload) in
                (ISO8601DateFormatter().string(from: date), workload)
            }
        )
        
        return WorkloadAnalysisFirestore(
            id: analysis.id,
            userId: analysis.userId,
            analysisDate: Timestamp(date: analysis.analysisDate),
            totalAssignments: analysis.totalAssignments,
            averageDaily: analysis.averageDaily,
            workloadBalance: analysis.workloadBalance.rawValue,
            overloadDays: analysis.overloadDays.map { Timestamp(date: $0) },
            lightDays: analysis.lightDays.map { Timestamp(date: $0) },
            recommendations: analysis.recommendations,
            dailyWorkload: dailyWorkloadStringDict,
            createdAt: Timestamp(date: analysis.createdAt)
        )
    }
    
    private func convertFirestoreToWorkloadAnalysis(_ data: [String: Any], documentId: String) throws -> WorkloadAnalysis {
        guard let userId = data["userId"] as? String,
              let analysisDateTimestamp = data["analysisDate"] as? Timestamp,
              let totalAssignments = data["totalAssignments"] as? Int,
              let averageDaily = data["averageDaily"] as? Double,
              let workloadBalanceString = data["workloadBalance"] as? String,
              let workloadBalance = WorkloadBalance(rawValue: workloadBalanceString),
              let overloadDaysTimestamps = data["overloadDays"] as? [Timestamp],
              let lightDaysTimestamps = data["lightDays"] as? [Timestamp],
              let recommendations = data["recommendations"] as? [String],
              let dailyWorkloadStringDict = data["dailyWorkload"] as? [String: Double],
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw WorkloadAnalysisError.invalidData
        }
        
        let formatter = ISO8601DateFormatter()
        let dailyWorkload: [Date: Double] = Dictionary(
            uniqueKeysWithValues: dailyWorkloadStringDict.compactMap { (dateString, workload) in
                guard let date = formatter.date(from: dateString) else { return nil }
                return (date, workload)
            }
        )
        
        return WorkloadAnalysis(
            id: documentId,
            userId: userId,
            analysisDate: analysisDateTimestamp.dateValue(),
            totalAssignments: totalAssignments,
            averageDaily: averageDaily,
            workloadBalance: workloadBalance,
            overloadDays: overloadDaysTimestamps.map { $0.dateValue() },
            lightDays: lightDaysTimestamps.map { $0.dateValue() },
            recommendations: recommendations,
            dailyWorkload: dailyWorkload,
            createdAt: createdAtTimestamp.dateValue()
        )
    }
}

// MARK: - Workload Analysis Errors
enum WorkloadAnalysisError: LocalizedError {
    case notAuthenticated
    case invalidData
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidData:
            return "Invalid analysis data"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}