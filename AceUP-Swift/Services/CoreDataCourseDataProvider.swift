//
//  CoreDataCourseDataProvider.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 13/10/25.
//

import Foundation
import CoreData
import FirebaseAuth

@MainActor
final class CoreDataCourseDataProvider: ObservableObject {

    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext

    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? "anonymous"
    }

    init(persistenceController: PersistenceController? = nil) {
        let c = persistenceController ?? PersistenceController.shared
        self.persistenceController = c
        self.context = c.viewContext
    }

    func fetchCourses() async throws -> [Course] {
        let req: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
        req.predicate = NSPredicate(format: "userId == %@", currentUserId)
        req.sortDescriptors = [NSSortDescriptor(keyPath: \CourseEntity.name, ascending: true)]
        return try context.fetch(req).map { $0.toCourse() }
    }

    func saveCourse(_ course: Course) async throws {
        if let e = try await fetchEntity(by: course.id) {
            e.updateFromCourse(course)
            e.gradeWeights?.updateFromGradeWeight(course.gradeWeight)
        } else {
            _ = CourseEntity.fromCourse(course, in: context)
        }
        do { try context.save() } catch { context.rollback(); throw error }
    }

    func updateCourse(_ course: Course) async throws {
        guard let e = try await fetchEntity(by: course.id) else {
            throw PersistenceError.objectNotFound
        }
        e.updateFromCourse(course)
        e.gradeWeights?.updateFromGradeWeight(course.gradeWeight)
        do { try context.save() } catch { context.rollback(); throw error }
    }

    func deleteCourse(_ id: String) async throws {
        guard let e = try await fetchEntity(by: id) else {
            throw PersistenceError.objectNotFound
        }
        context.delete(e)
        do { try context.save() } catch { context.rollback(); throw error }
    }

    private func fetchEntity(by id: String) async throws -> CourseEntity? {
        let req: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@ AND userId == %@", id, currentUserId)
        req.fetchLimit = 1
        return try context.fetch(req).first
    }
}
