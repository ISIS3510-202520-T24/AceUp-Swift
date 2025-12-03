//
//  Teacher.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/12/25.
//

import Foundation

// MARK: - Teacher Model
/// Represents a teacher/professor in the system
struct Teacher: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let userId: String // Owner of this teacher record
    let name: String
    let email: String?
    let phoneNumber: String?
    let officeLocation: String?
    let officeHours: String?
    let department: String?
    let linkedCourseIds: [String] // Courses this teacher teaches
    let notes: String? // Student's personal notes about the teacher
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        userId: String = "default-user", // In real app, get from AuthService
        name: String,
        email: String? = nil,
        phoneNumber: String? = nil,
        officeLocation: String? = nil,
        officeHours: String? = nil,
        department: String? = nil,
        linkedCourseIds: [String] = [],
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.email = email
        self.phoneNumber = phoneNumber
        self.officeLocation = officeLocation
        self.officeHours = officeHours
        self.department = department
        self.linkedCourseIds = linkedCourseIds
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Codable Keys
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case name
        case email
        case phoneNumber
        case officeLocation
        case officeHours
        case department
        case linkedCourseIds
        case notes
        case createdAt
        case updatedAt
    }
    
    // MARK: - Copying
    /// Creates a copy of the teacher with optional property updates
    func copying(
        userId: String? = nil,
        name: String? = nil,
        email: String?? = nil,
        phoneNumber: String?? = nil,
        officeLocation: String?? = nil,
        officeHours: String?? = nil,
        department: String?? = nil,
        linkedCourseIds: [String]? = nil,
        notes: String?? = nil,
        updatedAt: Date? = nil
    ) -> Teacher {
        Teacher(
            id: self.id,
            userId: userId ?? self.userId,
            name: name ?? self.name,
            email: email ?? self.email,
            phoneNumber: phoneNumber ?? self.phoneNumber,
            officeLocation: officeLocation ?? self.officeLocation,
            officeHours: officeHours ?? self.officeHours,
            department: department ?? self.department,
            linkedCourseIds: linkedCourseIds ?? self.linkedCourseIds,
            notes: notes ?? self.notes,
            createdAt: self.createdAt,
            updatedAt: updatedAt ?? Date()
        )
    }
    
    // MARK: - Firestore Conversion
    /// Converts the teacher to a Firestore-compatible dictionary
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "userId": userId,
            "name": name,
            "linkedCourseIds": linkedCourseIds,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
        
        if let email = email { data["email"] = email }
        if let phoneNumber = phoneNumber { data["phoneNumber"] = phoneNumber }
        if let officeLocation = officeLocation { data["officeLocation"] = officeLocation }
        if let officeHours = officeHours { data["officeHours"] = officeHours }
        if let department = department { data["department"] = department }
        if let notes = notes { data["notes"] = notes }
        
        return data
    }
    
    /// Creates a teacher from Firestore data
    static func fromFirestoreData(_ data: [String: Any], id: String) -> Teacher? {
        guard let name = data["name"] as? String,
              let userId = data["userId"] as? String else { return nil }
        
        let linkedCourseIds = data["linkedCourseIds"] as? [String] ?? []
        
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Date {
            createdAt = timestamp
        } else {
            createdAt = Date()
        }
        
        let updatedAt: Date
        if let timestamp = data["updatedAt"] as? Date {
            updatedAt = timestamp
        } else {
            updatedAt = Date()
        }
        
        return Teacher(
            id: id,
            userId: userId,
            name: name,
            email: data["email"] as? String,
            phoneNumber: data["phoneNumber"] as? String,
            officeLocation: data["officeLocation"] as? String,
            officeHours: data["officeHours"] as? String,
            department: data["department"] as? String,
            linkedCourseIds: linkedCourseIds,
            notes: data["notes"] as? String,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Sample Data
extension Teacher {
    static let sampleTeachers: [Teacher] = [
        Teacher(
            userId: "sample-user",
            name: "Dr. María González",
            email: "maria.gonzalez@university.edu",
            phoneNumber: "+57 300 123 4567",
            officeLocation: "ML-604",
            officeHours: "Mon/Wed 2-4 PM",
            department: "Computer Science",
            linkedCourseIds: [],
            notes: "Very approachable, prefers email communication"
        ),
        Teacher(
            userId: "sample-user",
            name: "Prof. Carlos Ramírez",
            email: "carlos.ramirez@university.edu",
            officeLocation: "SD-302",
            officeHours: "Tue/Thu 10-12 AM",
            department: "Mathematics",
            linkedCourseIds: []
        )
    ]
}
