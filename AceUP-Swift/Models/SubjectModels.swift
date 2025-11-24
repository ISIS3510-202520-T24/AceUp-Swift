import Foundation

// MARK: - Subject Models (Para Semesters)
struct Subject: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let code: String
    let credits: Double
    let instructor: String?
    let color: String
    let currentGrade: Double?
    let targetGrade: Double?
    let createdAt: Date
    var updatedAt: Date  // var para poder modificarlo
    
    // Computed properties
    var isActive: Bool {
        true // Simple implementation
    }
    
    var gradeStatus: GradeStatus {
        guard let grade = currentGrade else { return .none }
        if grade >= 4.0 { return .excellent }
        if grade >= 3.0 { return .passing }
        return .failing
    }
}

// MARK: - Subject Grade Status
enum GradeStatus: String, Codable {
    case excellent = "Excellent"
    case passing = "Passing"
    case failing = "Failing"
    case none = "No Grade"
    
    var color: String {
        switch self {
        case .excellent: return "#34C759"
        case .passing: return "#FF9500"
        case .failing: return "#FF3B30"
        case .none: return "#8E8E93"
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "star.fill"
        case .passing: return "checkmark.circle.fill"
        case .failing: return "exclamationmark.triangle.fill"
        case .none: return "minus.circle.fill"
        }
    }
}

// MARK: - Subject Statistics
struct SubjectStatistics {
    let totalSubjects: Int
    let totalCredits: Double
    let averageGrade: Double
    let passingCount: Int
    
    static var empty: SubjectStatistics {
        SubjectStatistics(totalSubjects: 0, totalCredits: 0, averageGrade: 0, passingCount: 0)
    }
}
