import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Hybrid ASSIGNMENTS

/// Híbrido: si hay sesión -> Firebase; si no, Local (si existe).
final class HybridAssignmentDataProvider: AssignmentDataProviderProtocol {
    private let remote = FirebaseAssignmentDataProvider()
    private let local: AssignmentDataProviderProtocol?

    /// Inyecta un provider local si quieres soporte offline (por defecto usa uno en memoria).
    init(local: AssignmentDataProviderProtocol? = LocalAssignmentDataProvider()) {
        self.local = local
    }

    private var isLoggedIn: Bool { Auth.auth().currentUser != nil }

    // MARK: AssignmentDataProviderProtocol

    func fetchAll() async throws -> [Assignment] {
        if isLoggedIn { return try await remote.fetchAll() }
        if let local { return try await local.fetchAll() }
        return []
    }

    func fetchById(_ id: String) async throws -> Assignment? {
        if isLoggedIn { return try await remote.fetchById(id) }
        if let local { return try await local.fetchById(id) }
        return nil
    }

    func save(_ assignment: Assignment) async throws {
        if isLoggedIn { try await remote.save(assignment); return }
        if let local { try await local.save(assignment); return }
        throw FirebaseError.userNotAuthenticated
    }

    func update(_ assignment: Assignment) async throws {
        if isLoggedIn { try await remote.update(assignment); return }
        if let local { try await local.update(assignment); return }
        throw FirebaseError.userNotAuthenticated
    }

    func delete(_ id: String) async throws {
        if isLoggedIn { try await remote.delete(id); return }
        if let local { try await local.delete(id); return }
        throw FirebaseError.userNotAuthenticated
    }

    /// Utilidad para DataSynchronizationManager.
    func performFullSync() async throws {
        _ = try await fetchAll()
    }
}

// MARK: - Hybrid COURSES (sin depender de FirebaseCourseDataProvider)

/// Wrapper híbrido para cursos que lee directamente de Firestore.
/// Evita la dependencia a `FirebaseCourseDataProvider`.
final class HybridCourseDataProvider {
    private let db = Firestore.firestore()

    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? "anonymous"
    }

    /// Usado por OfflineManager
    func fetchCourses() async throws -> [Course] {
        let snapshot = try await db.collection("courses")
            .whereField("userId", isEqualTo: currentUserId)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()

            guard let name = data["name"] as? String,
                  let code = data["code"] as? String,
                  let credits = data["credits"] as? Int,
                  let instructor = data["instructor"] as? String,
                  let semester = data["semester"] as? String,
                  let year = data["year"] as? Int
            else { return nil }

            let color = data["color"] as? String ?? "#122C4A"
            let currentGrade = data["currentGrade"] as? Double
            let targetGrade = data["targetGrade"] as? Double
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

            let gw = data["gradeWeight"] as? [String: Any] ?? [:]
            let gradeWeight = GradeWeight(
                assignments: gw["assignments"] as? Double ?? 0.4,
                exams: gw["exams"] as? Double ?? 0.4,
                projects: gw["projects"] as? Double ?? 0.15,
                participation: gw["participation"] as? Double ?? 0.05,
                other: gw["other"] as? Double ?? 0.0
            )

            return Course(
                id: doc.documentID,
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
    }

    func performFullSync() async throws {
        _ = try await fetchCourses()
    }
}
// MARK: - Hybrid HOLIDAYS

/// Wrapper híbrido para festivos (delegando al provider de Firebase).
/// Expone ambas firmas (`for:` y `country:`) para ser compatible con distintos llamadores.
final class HybridHolidayDataProvider {
    private let remote = FirebaseHolidayDataProvider() // asegúrate que esta clase esté en tu target

    /// Usado cuando no se especifica país/año.
    func fetchAllHolidays() async throws -> [Holiday] {
        try await remote.fetchAllHolidays()
    }

    /// Firma que suele usar OfflineManager (for:year:)
    func fetchHolidays(for country: String, year: Int) async throws -> [Holiday] {
        try await remote.fetchHolidays(for: country, year: year)
    }

    /// Firma alternativa por si la llamas en otro lado (country:year:)
    func fetchHolidays(country: String, year: Int) async throws -> [Holiday] {
        try await remote.fetchHolidays(for: country, year: year)
    }

    func performFullSync() async throws {
        _ = try await fetchAllHolidays()
    }
}
