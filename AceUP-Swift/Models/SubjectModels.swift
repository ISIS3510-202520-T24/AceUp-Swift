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
    let classDays: [DayOfWeek]?
    let startTime: String?  // "09:00"
    let endTime: String?    // "10:30"
    let location: String?
    let createdAt: Date
    var updatedAt: Date
    
    // Computed properties
    var isActive: Bool {
        true
    }
    
    var gradeStatus: GradeStatus {
        guard let grade = currentGrade else { return .none }
        if grade >= 4.0 { return .excellent }
        if grade >= 3.0 { return .passing }
        return .failing
    }
}

// MARK: - Day of Week
enum DayOfWeek: String, Codable, CaseIterable {
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    case sunday = "Sunday"
    
    var shortName: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
    
    var weekdayIndex: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
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
