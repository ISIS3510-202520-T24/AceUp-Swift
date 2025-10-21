import Foundation
import FirebaseFirestore
import FirebaseAuth

final class FirebaseAssignmentDataProvider: AssignmentDataProviderProtocol {

    private let db = Firestore.firestore()
    private var currentUserId: String { Auth.auth().currentUser?.uid ?? "anonymous" }

    private var assignmentsCollection: CollectionReference { db.collection("assignments") }

    // MARK: Protocol

    func fetchAll() async throws -> [Assignment] {
        let snapshot = try await assignmentsCollection
            .whereField("userId", isEqualTo: currentUserId)
            .order(by: "dueDate")
            .getDocuments()

        return snapshot.documents.compactMap { try? self.documentToAssignment($0) }
    }

    func fetchById(_ id: String) async throws -> Assignment? {
        let document = try await assignmentsCollection.document(id).getDocument()
        guard document.exists,
              let data = document.data(),
              data["userId"] as? String == currentUserId else { return nil }
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
    
    func updateStatus(_ id: String, status: AssignmentStatus, finalGrade: Double?) async throws {
        // (Opcional) Verificación rápida de usuario
        guard Auth.auth().currentUser != nil else { throw FirebaseError.userNotAuthenticated }

        var payload: [String: Any] = [
            "status": status.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let g = finalGrade {
            payload["grade"] = g
        }

        // Si quieres asegurarte de no tocar docs de otros usuarios, puedes chequear antes:
        // let doc = try await assignmentsCollection.document(id).getDocument()
        // guard let data = doc.data(), data["userId"] as? String == currentUserId else { throw FirebaseError.permissionDenied }

        try await assignmentsCollection.document(id).updateData(payload)
    }

    // MARK: Mapping

    private func documentToAssignment(_ document: QueryDocumentSnapshot) throws -> Assignment {
        try createAssignment(from: document.data(), documentID: document.documentID)
    }

    private func documentToAssignment(_ document: DocumentSnapshot) throws -> Assignment {
        guard let data = document.data() else { throw FirebaseError.invalidData }
        return try createAssignment(from: data, documentID: document.documentID)
    }

    private func createAssignment(from data: [String: Any], documentID: String) throws -> Assignment {
        guard
            let title = data["title"] as? String,
            let courseId = data["courseId"] as? String,
            let courseName = data["courseName"] as? String,
            let dueDate = (data["dueDate"] as? Timestamp)?.dateValue(),
            let weight = data["weight"] as? Double,
            let priorityRaw = data["priority"] as? String,
            let statusRaw = data["status"] as? String,
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        else { throw FirebaseError.invalidData }

        let description = data["description"] as? String
        let courseColor = data["courseColor"] as? String ?? "#122C4A"
        let estimatedHours = data["estimatedHours"] as? Double
        let actualHours = data["actualHours"] as? Double
        let tags = data["tags"] as? [String] ?? []
        let grade = data["grade"] as? Double // 👈 soporta grade

        let subtasksData = data["subtasks"] as? [[String: Any]] ?? []
        let subtasks: [Subtask] = subtasksData.compactMap { m in
            guard let id = m["id"] as? String,
                  let title = m["title"] as? String else { return nil }
            let description = m["description"] as? String
            let isCompleted = m["isCompleted"] as? Bool ?? false
            let estimatedHours = m["estimatedHours"] as? Double
            let completedAt = (m["completedAt"] as? Timestamp)?.dateValue()
            let createdAt = (m["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            return Subtask(id: id, title: title, description: description,
                           isCompleted: isCompleted, estimatedHours: estimatedHours,
                           completedAt: completedAt, createdAt: createdAt)
        }

        let attachmentsData = data["attachments"] as? [[String: Any]] ?? []
        let attachments: [AssignmentAttachment] = attachmentsData.compactMap { m in
            guard let id = m["id"] as? String,
                  let name = m["name"] as? String,
                  let url = m["url"] as? String,
                  let typeRaw = m["type"] as? String else { return nil }
            let size = m["size"] as? Int64
            let uploadedAt = (m["uploadedAt"] as? Timestamp)?.dateValue() ?? Date()
            return AssignmentAttachment(id: id, name: name, url: url,
                                        type: AttachmentType(rawValue: typeRaw) ?? .other,
                                        size: size, uploadedAt: uploadedAt)
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
            priority: Priority(rawValue: priorityRaw) ?? .medium,
            status: AssignmentStatus(rawValue: statusRaw) ?? .pending,
            tags: tags,
            attachments: attachments,
            subtasks: subtasks,
            createdAt: createdAt,
            updatedAt: updatedAt,
            grade: grade // 👈 mapea al modelo
        )
    }

    private func assignmentToFirestoreData(_ a: Assignment) throws -> [String: Any] {
        var data: [String: Any] = [
            "title": a.title,
            "courseId": a.courseId,
            "courseName": a.courseName,
            "courseColor": a.courseColor,
            "dueDate": Timestamp(date: a.dueDate),
            "weight": a.weight,
            "priority": a.priority.rawValue,
            "status": a.status.rawValue,
            "tags": a.tags,
            "createdAt": Timestamp(date: a.createdAt),
            "updatedAt": Timestamp(date: a.updatedAt),
            "userId": currentUserId
        ]
        if let d = a.description { data["description"] = d }
        if let eh = a.estimatedHours { data["estimatedHours"] = eh }
        if let ah = a.actualHours { data["actualHours"] = ah }
        if let g = a.grade { data["grade"] = g } // 👈 persiste grade

        data["subtasks"] = a.subtasks.map { s in
            var m: [String: Any] = [
                "id": s.id,
                "title": s.title,
                "isCompleted": s.isCompleted,
                "createdAt": Timestamp(date: s.createdAt)
            ]
            if let d = s.description { m["description"] = d }
            if let eh = s.estimatedHours { m["estimatedHours"] = eh }
            if let c = s.completedAt { m["completedAt"] = Timestamp(date: c) }
            return m
        }

        data["attachments"] = a.attachments.map { att in
            var m: [String: Any] = [
                "id": att.id,
                "name": att.name,
                "url": att.url,
                "type": att.type.rawValue,
                "uploadedAt": Timestamp(date: att.uploadedAt)
            ]
            if let size = att.size { m["size"] = size }
            return m
        }

        return data
    }
}

// Errores comunes
enum FirebaseError: LocalizedError {
    case invalidData
    case userNotAuthenticated
    case networkError(Error)
    case documentNotFound
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .invalidData: return "Invalid data format received from Firebase"
        case .userNotAuthenticated: return "User not authenticated"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .documentNotFound: return "Document not found in Firebase"
        case .permissionDenied: return "Permission denied to access this resource"
        }
    }
}
