import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Hybrid ASSIGNMENTS

/// Enhanced Hybrid provider with automatic offline caching
/// - When ONLINE: Reads from Firebase + automatically caches to Core Data
/// - When OFFLINE: Reads from Core Data cache + queues changes for sync
/// - On RECONNECT: Syncs pending changes automatically
@MainActor
final class HybridAssignmentDataProvider: AssignmentDataProviderProtocol {
    private let remote = FirebaseAssignmentDataProvider()
    private let coreDataProvider: CoreDataAssignmentDataProvider
    private let offlineManager = OfflineManager.shared
    
    // Pending operations queue for offline mode
    private var pendingOperations: [PendingOperation] = []
    private let pendingOpsKey = "HybridAssignment.pendingOps"
    
    init(coreDataProvider: CoreDataAssignmentDataProvider? = nil) {
        self.coreDataProvider = coreDataProvider ?? CoreDataAssignmentDataProvider()
        loadPendingOperations()
    }

    private var isOnline: Bool { offlineManager.isOnline }
    private var isLoggedIn: Bool { Auth.auth().currentUser != nil }

    // MARK: AssignmentDataProviderProtocol

    func fetchAll() async throws -> [Assignment] {
        // Try online first, fallback to cache
        if isOnline && isLoggedIn {
            do {
                let remoteAssignments = try await remote.fetchAll()
                // Cache to Core Data for offline access
                try await cacheAssignments(remoteAssignments)
                print("✅ Fetched \(remoteAssignments.count) assignments from Firebase and cached")
                return remoteAssignments
            } catch {
                print("⚠️ Firebase fetch failed, using cached data: \(error.localizedDescription)")
                // Fallback to cache on network error
                return try await coreDataProvider.fetchAll()
            }
        }
        
        // Offline or not logged in - use cache
        print("📦 Using cached assignments (offline mode)")
        return try await coreDataProvider.fetchAll()
    }

    func fetchById(_ id: String) async throws -> Assignment? {
        // Try online first, fallback to cache
        if isOnline && isLoggedIn {
            do {
                if let remoteAssignment = try await remote.fetchById(id) {
                    // Cache individual assignment
                    try await coreDataProvider.save(remoteAssignment)
                    return remoteAssignment
                }
            } catch {
                print("⚠️ Firebase fetch failed for \(id), using cache")
            }
        }
        
        // Fallback to cache
        return try await coreDataProvider.fetchById(id)
    }

    func save(_ assignment: Assignment) async throws {
        if isOnline && isLoggedIn {
            // Save to Firebase and cache
            try await remote.save(assignment)
            try await coreDataProvider.save(assignment)
            print("✅ Saved assignment \(assignment.id) to Firebase and cache")
        } else {
            // Offline: save to cache and queue for sync
            try await coreDataProvider.save(assignment)
            queueOperation(.save(assignment))
            print("📦 Saved assignment \(assignment.id) to cache (offline), queued for sync")
        }
    }

    func update(_ assignment: Assignment) async throws {
        if isOnline && isLoggedIn {
            // Update Firebase and cache
            try await remote.update(assignment)
            try await coreDataProvider.update(assignment)
            print("✅ Updated assignment \(assignment.id) in Firebase and cache")
        } else {
            // Offline: update cache and queue for sync
            try await coreDataProvider.update(assignment)
            queueOperation(.update(assignment))
            print("📦 Updated assignment \(assignment.id) in cache (offline), queued for sync")
        }
    }

    func delete(_ id: String) async throws {
        if isOnline && isLoggedIn {
            // Delete from Firebase and cache
            try await remote.delete(id)
            try await coreDataProvider.delete(id)
            print("✅ Deleted assignment \(id) from Firebase and cache")
        } else {
            // Offline: delete from cache and queue for sync
            try await coreDataProvider.delete(id)
            queueOperation(.delete(id))
            print("📦 Deleted assignment \(id) from cache (offline), queued for sync")
        }
    }

    /// Full sync: fetch from Firebase and refresh cache
    func performFullSync() async throws {
        guard isOnline && isLoggedIn else {
            print("⚠️ Cannot sync: offline or not logged in")
            return
        }
        
        print("🔄 Starting full assignment sync...")
        
        // 1. Sync pending operations first
        await syncPendingOperations()
        
        // 2. Fetch fresh data from Firebase
        let remoteAssignments = try await remote.fetchAll()
        
        // 3. Update cache
        try await cacheAssignments(remoteAssignments)
        
        print("✅ Full sync completed: \(remoteAssignments.count) assignments synced")
    }
    
    // MARK: - Private Helpers
    
    /// Cache assignments to Core Data (replaces existing)
    private func cacheAssignments(_ assignments: [Assignment]) async throws {
        for assignment in assignments {
            try await coreDataProvider.save(assignment)
        }
    }
    
    /// Queue an operation for later sync
    private func queueOperation(_ operation: PendingOperation) {
        pendingOperations.append(operation)
        savePendingOperations()
        
        // Update OfflineManager pending count
        Task { @MainActor in
            offlineManager.pendingSyncOperations = pendingOperations.count
        }
    }
    
    /// Sync all pending operations when back online
    func syncPendingOperations() async {
        guard isOnline && isLoggedIn else { return }
        guard !pendingOperations.isEmpty else { return }
        
        print("🔄 Syncing \(pendingOperations.count) pending operations...")
        
        var successCount = 0
        var failedOps: [PendingOperation] = []
        
        for operation in pendingOperations {
            do {
                switch operation {
                case .save(let assignment):
                    try await remote.save(assignment)
                    print("✅ Synced save: \(assignment.id)")
                    
                case .update(let assignment):
                    try await remote.update(assignment)
                    print("✅ Synced update: \(assignment.id)")
                    
                case .delete(let id):
                    try await remote.delete(id)
                    print("✅ Synced delete: \(id)")
                }
                successCount += 1
                
                // Small delay to avoid overwhelming Firebase
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                
            } catch {
                print("❌ Failed to sync operation: \(error.localizedDescription)")
                failedOps.append(operation)
            }
        }
        
        // Update pending operations (keep only failed ones)
        pendingOperations = failedOps
        savePendingOperations()
        
        // Update OfflineManager
        Task { @MainActor in
            offlineManager.pendingSyncOperations = failedOps.count
        }
        
        print("✅ Sync completed: \(successCount) success, \(failedOps.count) failed")
    }
    
    // MARK: - Persistence of Pending Operations
    
    private func savePendingOperations() {
        do {
            let data = try JSONEncoder().encode(pendingOperations)
            UserDefaults.standard.set(data, forKey: pendingOpsKey)
        } catch {
            print("❌ Failed to save pending operations: \(error.localizedDescription)")
        }
    }
    
    private func loadPendingOperations() {
        guard let data = UserDefaults.standard.data(forKey: pendingOpsKey) else { return }
        do {
            pendingOperations = try JSONDecoder().decode([PendingOperation].self, from: data)
            print("📦 Loaded \(pendingOperations.count) pending operations")
            
            // Update OfflineManager count
            Task { @MainActor in
                offlineManager.pendingSyncOperations = pendingOperations.count
            }
        } catch {
            print("❌ Failed to load pending operations: \(error.localizedDescription)")
        }
    }
    
    /// Get count of pending operations
    func getPendingOperationsCount() -> Int {
        return pendingOperations.count
    }
}

// MARK: - Pending Operation Model

enum PendingOperation: Codable {
    case save(Assignment)
    case update(Assignment)
    case delete(String)
    
    private enum CodingKeys: String, CodingKey {
        case type, assignment, id
    }
    
    enum OperationType: String, Codable {
        case save, update, delete
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(OperationType.self, forKey: .type)
        
        switch type {
        case .save:
            let assignment = try container.decode(Assignment.self, forKey: .assignment)
            self = .save(assignment)
        case .update:
            let assignment = try container.decode(Assignment.self, forKey: .assignment)
            self = .update(assignment)
        case .delete:
            let id = try container.decode(String.self, forKey: .id)
            self = .delete(id)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .save(let assignment):
            try container.encode(OperationType.save, forKey: .type)
            try container.encode(assignment, forKey: .assignment)
        case .update(let assignment):
            try container.encode(OperationType.update, forKey: .type)
            try container.encode(assignment, forKey: .assignment)
        case .delete(let id):
            try container.encode(OperationType.delete, forKey: .type)
            try container.encode(id, forKey: .id)
        }
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
