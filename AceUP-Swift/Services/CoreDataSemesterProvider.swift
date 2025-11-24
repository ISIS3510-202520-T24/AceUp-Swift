import CoreData
import Foundation
import FirebaseAuth

// MARK: - CoreData Semester Data Provider
class CoreDataSemesterProvider {
    
    private let persistentContainer: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    private let viewContext: NSManagedObjectContext
    
    @MainActor
    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.backgroundContext = persistentContainer.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.viewContext = persistentContainer.viewContext
    }
    
    // MARK: - Create Operation (I/O Optimized)
    func create(_ semester: Semester) async throws -> Semester {
        return try await withCheckedThrowingContinuation { continuation in
            //CAMBIA A BACKGROUND THREAD
            backgroundContext.perform {
                do {
                    // OUTPUT: Escribir a disco (BACKGROUND)
                    let entity = SemesterEntity.fromSemester(semester, in: self.backgroundContext)
                    try self.backgroundContext.save()
                    
                    // INPUT: Leer desde disco (BACKGROUND)
                    let createdSemester = entity.toSemester()

                    // Retorna al MAIN THREAD
                    continuation.resume(returning: createdSemester)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Read Operations (I/O Optimized)
    func fetchAll(userId: String? = nil) async throws -> [Semester] {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<SemesterEntity> = SemesterEntity.fetchRequest()
                    
                    if let userId = userId ?? Auth.auth().currentUser?.uid {
                        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
                    }
                    
                    fetchRequest.sortDescriptors = [
                        NSSortDescriptor(key: "year", ascending: false),
                        NSSortDescriptor(key: "startDate", ascending: false)
                    ]
                    
                    let entities = try self.backgroundContext.fetch(fetchRequest)
                    let semesters = entities.map { $0.toSemester() }
                    continuation.resume(returning: semesters)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchById(_ id: UUID) async throws -> Semester? {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<SemesterEntity> = SemesterEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id.uuidString)
                    fetchRequest.fetchLimit = 1
                    
                    let entities = try self.backgroundContext.fetch(fetchRequest)
                    let semester = entities.first?.toSemester()
                    continuation.resume(returning: semester)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchByYear(_ year: Int, userId: String? = nil) async throws -> [Semester] {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<SemesterEntity> = SemesterEntity.fetchRequest()
                    
                    var predicates: [NSPredicate] = [
                        NSPredicate(format: "year == %d", year)
                    ]
                    
                    if let userId = userId ?? Auth.auth().currentUser?.uid {
                        predicates.append(NSPredicate(format: "userId == %@", userId))
                    }
                    
                    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
                    
                    let entities = try self.backgroundContext.fetch(fetchRequest)
                    let semesters = entities.map { $0.toSemester() }
                    continuation.resume(returning: semesters)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchActive(userId: String? = nil) async throws -> Semester? {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<SemesterEntity> = SemesterEntity.fetchRequest()
                    
                    var predicates: [NSPredicate] = [
                        NSPredicate(format: "isActive == YES")
                    ]
                    
                    if let userId = userId ?? Auth.auth().currentUser?.uid {
                        predicates.append(NSPredicate(format: "userId == %@", userId))
                    }
                    
                    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                    fetchRequest.fetchLimit = 1
                    
                    let entities = try self.backgroundContext.fetch(fetchRequest)
                    let semester = entities.first?.toSemester()
                    continuation.resume(returning: semester)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Update Operation (I/O Optimized)
    func update(_ semester: Semester) async throws -> Semester {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<SemesterEntity> = SemesterEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", semester.id.uuidString)
                    fetchRequest.fetchLimit = 1
                    
                    guard let entity = try self.backgroundContext.fetch(fetchRequest).first else {
                        throw NSError(domain: "CoreDataSemesterProvider", code: 404, userInfo: [NSLocalizedDescriptionKey: "Semester not found"])
                    }
                    
                    entity.updateFromSemester(semester)
                    try self.backgroundContext.save()
                    
                    let updatedSemester = entity.toSemester()
                    continuation.resume(returning: updatedSemester)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Delete Operation (I/O Optimized)
    func delete(_ id: UUID) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<SemesterEntity> = SemesterEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id.uuidString)
                    fetchRequest.fetchLimit = 1
                    
                    guard let entity = try self.backgroundContext.fetch(fetchRequest).first else {
                        throw NSError(domain: "CoreDataSemesterProvider", code: 404, userInfo: [NSLocalizedDescriptionKey: "Semester not found"])
                    }
                    
                    self.backgroundContext.delete(entity)
                    try self.backgroundContext.save()
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Batch Operations
    func deleteAll(userId: String? = nil) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = SemesterEntity.fetchRequest()
                    
                    if let userId = userId ?? Auth.auth().currentUser?.uid {
                        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
                    }
                    
                    let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    try self.backgroundContext.execute(batchDeleteRequest)
                    try self.backgroundContext.save()
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Activation Management
    func setActiveSemester(_ id: UUID, userId: String? = nil) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    // First, deactivate all semesters
                    let fetchAllRequest: NSFetchRequest<SemesterEntity> = SemesterEntity.fetchRequest()
                    if let userId = userId ?? Auth.auth().currentUser?.uid {
                        fetchAllRequest.predicate = NSPredicate(format: "userId == %@", userId)
                    }
                    
                    let allEntities = try self.backgroundContext.fetch(fetchAllRequest)
                    allEntities.forEach { $0.isActive = false }
                    
                    // Then, activate the target semester
                    let fetchRequest: NSFetchRequest<SemesterEntity> = SemesterEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id.uuidString)
                    fetchRequest.fetchLimit = 1
                    
                    guard let entity = try self.backgroundContext.fetch(fetchRequest).first else {
                        throw NSError(domain: "CoreDataSemesterProvider", code: 404, userInfo: [NSLocalizedDescriptionKey: "Semester not found"])
                    }
                    
                    entity.isActive = true
                    try self.backgroundContext.save()
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
