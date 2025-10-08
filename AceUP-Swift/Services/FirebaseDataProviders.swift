//
//  FirebaseDataProviders.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 7/10/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Firebase implementation of AssignmentDataProviderProtocol
/// Handles cloud storage and synchronization for assignments
class FirebaseAssignmentDataProvider: AssignmentDataProviderProtocol {
    
    private let db = Firestore.firestore()
    private var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? "anonymous"
    }
    
    // MARK: - Collection References
    
    private var assignmentsCollection: CollectionReference {
        return db.collection("assignments")
    }
    
    // MARK: - AssignmentDataProviderProtocol Implementation
    
    func fetchAll() async throws -> [Assignment] {
        let snapshot = try await assignmentsCollection
            .whereField("userId", isEqualTo: currentUserId)
            .order(by: "dueDate")
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? self.documentToAssignment(document)
        }
    }
    
    func fetchById(_ id: String) async throws -> Assignment? {
        let document = try await assignmentsCollection.document(id).getDocument()
        
        guard document.exists,
              let data = document.data(),
              data["userId"] as? String == currentUserId else {
            return nil
        }
        
        return try documentToAssignment(document)
    }
    
    func save(_ assignment: Assignment) async throws {
        let data = try assignmentToFirestoreData(assignment)
        try await assignmentsCollection.document(assignment.id).setData(data)
    }
    
    func update(_ assignment: Assignment) async throws {
        let data = try assignmentToFirestoreData(assignment)
        try await assignmentsCollection.document(assignment.id).setData(data, merge: true)
    }
    
    func delete(_ id: String) async throws {
        try await assignmentsCollection.document(id).delete()
    }
    
    // MARK: - Data Conversion Methods
    
    private func documentToAssignment(_ document: QueryDocumentSnapshot) throws -> Assignment {
        let data = document.data()
        return try createAssignment(from: data, documentID: document.documentID)
    }
    
    private func documentToAssignment(_ document: DocumentSnapshot) throws -> Assignment {
        guard let data = document.data() else {
            throw FirebaseError.invalidData
        }
        return try createAssignment(from: data, documentID: document.documentID)
    }
    
    private func createAssignment(from data: [String: Any], documentID: String) throws -> Assignment {
        
        guard let title = data["title"] as? String,
              let courseId = data["courseId"] as? String,
              let courseName = data["courseName"] as? String,
              let dueDate = (data["dueDate"] as? Timestamp)?.dateValue(),
              let weight = data["weight"] as? Double,
              let priority = data["priority"] as? String,
              let status = data["status"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
            throw FirebaseError.invalidData
        }
        
        // Parse optional fields
        let description = data["description"] as? String
        let courseColor = data["courseColor"] as? String ?? "#122C4A"
        let estimatedHours = data["estimatedHours"] as? Double
        let actualHours = data["actualHours"] as? Double
        let tags = data["tags"] as? [String] ?? []
        
        // Parse subtasks
        let subtasksData = data["subtasks"] as? [[String: Any]] ?? []
        let subtasks = subtasksData.compactMap { subtaskData -> Subtask? in
            guard let id = subtaskData["id"] as? String,
                  let title = subtaskData["title"] as? String else {
                return nil
            }
            
            let description = subtaskData["description"] as? String
            let isCompleted = subtaskData["isCompleted"] as? Bool ?? false
            let estimatedHours = subtaskData["estimatedHours"] as? Double
            let completedAt = (subtaskData["completedAt"] as? Timestamp)?.dateValue()
            let createdAt = (subtaskData["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            
            return Subtask(
                id: id,
                title: title,
                description: description,
                isCompleted: isCompleted,
                estimatedHours: estimatedHours,
                completedAt: completedAt,
                createdAt: createdAt
            )
        }
        
        // Parse attachments
        let attachmentsData = data["attachments"] as? [[String: Any]] ?? []
        let attachments = attachmentsData.compactMap { attachmentData -> AssignmentAttachment? in
            guard let id = attachmentData["id"] as? String,
                  let name = attachmentData["name"] as? String,
                  let url = attachmentData["url"] as? String,
                  let type = attachmentData["type"] as? String else {
                return nil
            }
            
            let size = attachmentData["size"] as? Int64
            let uploadedAt = (attachmentData["uploadedAt"] as? Timestamp)?.dateValue() ?? Date()
            
            return AssignmentAttachment(
                id: id,
                name: name,
                url: url,
                type: AttachmentType(rawValue: type) ?? .other,
                size: size,
                uploadedAt: uploadedAt
            )
        }
        
        return Assignment(
            id: documentID,
            title: title,
            description: description,
            courseId: courseId,
            courseName: courseName,
            courseColor: courseColor,
            dueDate: dueDate,
            weight: weight,
            estimatedHours: estimatedHours,
            actualHours: actualHours,
            priority: Priority(rawValue: priority) ?? .medium,
            status: AssignmentStatus(rawValue: status) ?? .pending,
            tags: tags,
            attachments: attachments,
            subtasks: subtasks,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func assignmentToFirestoreData(_ assignment: Assignment) throws -> [String: Any] {
        var data: [String: Any] = [
            "title": assignment.title,
            "courseId": assignment.courseId,
            "courseName": assignment.courseName,
            "courseColor": assignment.courseColor,
            "dueDate": Timestamp(date: assignment.dueDate),
            "weight": assignment.weight,
            "priority": assignment.priority.rawValue,
            "status": assignment.status.rawValue,
            "tags": assignment.tags,
            "createdAt": Timestamp(date: assignment.createdAt),
            "updatedAt": Timestamp(date: assignment.updatedAt),
            "userId": currentUserId
        ]
        
        // Add optional fields
        if let description = assignment.description {
            data["description"] = description
        }
        
        if let estimatedHours = assignment.estimatedHours {
            data["estimatedHours"] = estimatedHours
        }
        
        if let actualHours = assignment.actualHours {
            data["actualHours"] = actualHours
        }
        
        // Convert subtasks
        let subtasksData = assignment.subtasks.map { subtask -> [String: Any] in
            var subtaskData: [String: Any] = [
                "id": subtask.id,
                "title": subtask.title,
                "isCompleted": subtask.isCompleted,
                "createdAt": Timestamp(date: subtask.createdAt)
            ]
            
            if let description = subtask.description {
                subtaskData["description"] = description
            }
            
            if let estimatedHours = subtask.estimatedHours {
                subtaskData["estimatedHours"] = estimatedHours
            }
            
            if let completedAt = subtask.completedAt {
                subtaskData["completedAt"] = Timestamp(date: completedAt)
            }
            
            return subtaskData
        }
        data["subtasks"] = subtasksData
        
        // Convert attachments
        let attachmentsData = assignment.attachments.map { attachment -> [String: Any] in
            var attachmentData: [String: Any] = [
                "id": attachment.id,
                "name": attachment.name,
                "url": attachment.url,
                "type": attachment.type.rawValue,
                "uploadedAt": Timestamp(date: attachment.uploadedAt)
            ]
            
            if let size = attachment.size {
                attachmentData["size"] = size
            }
            
            return attachmentData
        }
        data["attachments"] = attachmentsData
        
        return data
    }
}

// MARK: - Firebase Errors

enum FirebaseError: LocalizedError {
    case invalidData
    case userNotAuthenticated
    case networkError(Error)
    case documentNotFound
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format received from Firebase"
        case .userNotAuthenticated:
            return "User not authenticated"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .documentNotFound:
            return "Document not found in Firebase"
        case .permissionDenied:
            return "Permission denied to access this resource"
        }
    }
}

// MARK: - Holiday Firebase Data Provider

class FirebaseHolidayDataProvider: ObservableObject {
    
    private let db = Firestore.firestore()
    
    func fetchHolidays(for country: String, year: Int) async throws -> [Holiday] {
        let snapshot = try await db.collection("holidays")
            .whereField("country", isEqualTo: country)
            .whereField("year", isEqualTo: year)
            .order(by: "date")
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? self.documentToHoliday(document)
        }
    }
    
    func fetchAllHolidays() async throws -> [Holiday] {
        let snapshot = try await db.collection("holidays")
            .order(by: "date")
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? self.documentToHoliday(document)
        }
    }
    
    private func documentToHoliday(_ document: QueryDocumentSnapshot) throws -> Holiday {
        let data = document.data()
        
        guard let name = data["name"] as? String,
              let date = data["date"] as? String,
              let countryCode = data["countryCode"] as? String else {
            throw FirebaseError.invalidData
        }
        
        let localName = data["localName"] as? String ?? name
        let fixed = data["fixed"] as? Bool
        let global = data["global"] as? Bool
        let counties = data["counties"] as? [String]
        let launchYear = data["launchYear"] as? Int
        let types = data["types"] as? [String]
        
        return Holiday(
            date: date,
            localName: localName,
            name: name,
            countryCode: countryCode,
            fixed: fixed,
            global: global,
            counties: counties,
            launchYear: launchYear,
            types: types
        )
    }
}

// MARK: - Course Firebase Data Provider

class FirebaseCourseDataProvider: ObservableObject {
    
    private let db = Firestore.firestore()
    private var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? "anonymous"
    }
    
    func fetchCourses() async throws -> [Course] {
        let snapshot = try await db.collection("courses")
            .whereField("userId", isEqualTo: currentUserId)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? self.documentToCourse(document)
        }
    }
    
    func saveCourse(_ course: Course) async throws {
        let data = try courseToFirestoreData(course)
        try await db.collection("courses").document(course.id).setData(data)
    }
    
    func updateCourse(_ course: Course) async throws {
        let data = try courseToFirestoreData(course)
        try await db.collection("courses").document(course.id).setData(data, merge: true)
    }
    
    func deleteCourse(_ courseId: String) async throws {
        try await db.collection("courses").document(courseId).delete()
    }
    
    private func documentToCourse(_ document: QueryDocumentSnapshot) throws -> Course {
        let data = document.data()
        
        guard let name = data["name"] as? String,
              let code = data["code"] as? String,
              let credits = data["credits"] as? Int,
              let instructor = data["instructor"] as? String,
              let semester = data["semester"] as? String,
              let year = data["year"] as? Int else {
            throw FirebaseError.invalidData
        }
        
        let color = data["color"] as? String ?? "#122C4A"
        let currentGrade = data["currentGrade"] as? Double
        let targetGrade = data["targetGrade"] as? Double
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        // Parse grade weights
        let gradeWeightData = data["gradeWeight"] as? [String: Any] ?? [:]
        let gradeWeight = GradeWeight(
            assignments: gradeWeightData["assignments"] as? Double ?? 0.4,
            exams: gradeWeightData["exams"] as? Double ?? 0.4,
            projects: gradeWeightData["projects"] as? Double ?? 0.15,
            participation: gradeWeightData["participation"] as? Double ?? 0.05,
            other: gradeWeightData["other"] as? Double ?? 0.0
        )
        
        return Course(
            id: document.documentID,
            name: name,
            code: code,
            credits: credits,
            instructor: instructor,
            color: color,
            semester: semester,
            year: year,
            gradeWeight: gradeWeight,
            currentGrade: currentGrade,
            targetGrade: targetGrade,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func courseToFirestoreData(_ course: Course) throws -> [String: Any] {
        var data: [String: Any] = [
            "name": course.name,
            "code": course.code,
            "credits": course.credits,
            "instructor": course.instructor,
            "color": course.color,
            "semester": course.semester,
            "year": course.year,
            "gradeWeight": [
                "assignments": course.gradeWeight.assignments,
                "exams": course.gradeWeight.exams,
                "projects": course.gradeWeight.projects,
                "participation": course.gradeWeight.participation,
                "other": course.gradeWeight.other
            ],
            "createdAt": Timestamp(date: course.createdAt),
            "updatedAt": Timestamp(date: course.updatedAt),
            "userId": currentUserId
        ]
        
        // Add optional fields only if they have values
        if let currentGrade = course.currentGrade {
            data["currentGrade"] = currentGrade
        }
        
        if let targetGrade = course.targetGrade {
            data["targetGrade"] = targetGrade
        }
        
        return data
    }
}