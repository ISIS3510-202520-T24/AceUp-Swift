//
//  PersistenceController.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 7/10/25.
//

import CoreData
import Foundation

/// Core Data persistence controller for AceUp app
/// Manages the Core Data stack and provides access to managed object contexts
@MainActor
class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AceUpDataModel")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // In production, you should handle this error appropriately
                fatalError("Core Data failed to load: \(error), \(error.userInfo)")
            }
        }
        
        // Configure automatic merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // MARK: - Initialization
    
    nonisolated private init() {}
    
    // MARK: - Save Context
    
    func save() {
        guard viewContext.hasChanges else { return }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
    
    // MARK: - Background Context Operations
    
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) -> T) async -> T {
        return await withCheckedContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                let result = block(context)
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Batch Operations
    
    func batchDelete<T: NSManagedObject>(entityType: T.Type, predicate: NSPredicate? = nil) async throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entityType))
        request.predicate = predicate
        
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        let context = persistentContainer.viewContext
        
        do {
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            let objectIDArray = result?.result as? [NSManagedObjectID]
            let changes = [NSDeletedObjectsKey: objectIDArray ?? []]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
        } catch {
            throw error
        }
    }
    
    // MARK: - Preview Support
    
    static var preview: PersistenceController = {
        let controller = PersistenceController()
        let context = controller.persistentContainer.viewContext
        
        // Add sample data for previews
        // This will be populated with mock data for SwiftUI previews
        
        return controller
    }()
}

// MARK: - Persistence Errors

enum PersistenceError: LocalizedError {
    case failedToSave(Error)
    case failedToFetch(Error)
    case failedToDelete(Error)
    case objectNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .failedToSave(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .failedToFetch(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .failedToDelete(let error):
            return "Failed to delete data: \(error.localizedDescription)"
        case .objectNotFound:
            return "Requested object not found"
        case .invalidData:
            return "Invalid data provided"
        }
    }
}