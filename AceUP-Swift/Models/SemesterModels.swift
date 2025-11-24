import Foundation

// MARK: - Semester Type Enumeration
enum SemesterType: String, Codable, CaseIterable {
    case fall = "Fall"
    case spring = "Spring"
    case summer = "Summer"
    case winter = "Winter"
    
    var defaultStartMonth: Int {
        switch self {
        case .fall: return 8      // August
        case .spring: return 1    // January
        case .summer: return 6    // June
        case .winter: return 12   // December
        }
    }
    
    var defaultEndMonth: Int {
        switch self {
        case .fall: return 12     // December
        case .spring: return 5    // May
        case .summer: return 8    // August
        case .winter: return 1    // January
        }
    }
}

// MARK: - Semester Status Enumeration
enum SemesterStatus: String, Codable, CaseIterable {
    case upcoming = "Upcoming"
    case active = "Active"
    case completed = "Completed"
    case archived = "Archived"
    
    var color: String {
        switch self {
        case .upcoming: return "#4ECDC4"
        case .active: return "#122C4A"
        case .completed: return "#8B8680"
        case .archived: return "#D3D3D3"
        }
    }
}

// MARK: - Main Semester Model
struct Semester: Identifiable, Codable {
    let id: UUID
    var name: String
    var year: Int
    var type: SemesterType
    var startDate: Date
    var endDate: Date
    var targetGPA: Double?
    var actualGPA: Double?
    var credits: Int
    var status: SemesterStatus
    var notes: String
    var colorHex: String
    var isActive: Bool
    var userId: String?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        year: Int,
        type: SemesterType,
        startDate: Date,
        endDate: Date,
        targetGPA: Double? = nil,
        actualGPA: Double? = nil,
        credits: Int = 0,
        status: SemesterStatus = .upcoming,
        notes: String = "",
        colorHex: String = "#4ECDC4",
        isActive: Bool = false,
        userId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.year = year
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.targetGPA = targetGPA
        self.actualGPA = actualGPA
        self.credits = credits
        self.status = status
        self.notes = notes
        self.colorHex = colorHex
        self.isActive = isActive
        self.userId = userId
        self.createdAt = createdAt
    }
    
    var displayName: String {
        "\(type.rawValue) \(year)"
    }
    
    var progress: Double {
        let total = endDate.timeIntervalSince(startDate)
        let elapsed = Date().timeIntervalSince(startDate)
        return min(max(elapsed / total, 0), 1)
    }
    
    var daysRemaining: Int {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        return max(days, 0)
    }
}

// MARK: - DTOs for Data Transfer
struct CreateSemesterDTO {
    let name: String
    let year: Int
    let type: SemesterType
    let startDate: Date
    let endDate: Date
    let targetGPA: Double?
    let credits: Int
    let notes: String
    let colorHex: String
    let userId: String?
}

struct UpdateSemesterDTO {
    let id: UUID
    let name: String?
    let year: Int?
    let type: SemesterType?
    let startDate: Date?
    let endDate: Date?
    let targetGPA: Double?
    let actualGPA: Double?
    let credits: Int?
    let status: SemesterStatus?
    let notes: String?
    let colorHex: String?
    let isActive: Bool?
}

// MARK: - Analytics Models
struct SemesterAnalytics {
    let semesterId: UUID
    let totalCourses: Int
    let completedCourses: Int
    let averageGrade: Double?
    let creditHours: Int
    let gpaProgress: Double?
    let attendanceRate: Double?
}

struct SemesterSummary {
    let total: Int
    let active: Int
    let upcoming: Int
    let completed: Int
    let averageGPA: Double?
    let totalCredits: Int
}
