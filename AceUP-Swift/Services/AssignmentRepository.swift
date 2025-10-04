//
//  AssignmentRepository.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 3/10/25.
//

import Foundation
import SwiftData

class AssignmentRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchAll() throws -> [Assignment] {
        let descriptor = FetchDescriptor<Assignment>(
            sortBy: [SortDescriptor(\.dueDate)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchNext7Days() throws -> [Assignment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sevenDaysLater = calendar.date(byAdding: .day, value: 7, to: today)!
        
        let all = try fetchAll()
        return all.filter {
            guard let dueDate = $0.dueDate else { return false }
            return dueDate >= today && dueDate < sevenDaysLater
        }
    }
    
    func fetchToday() throws -> [Assignment] {
        let calendar = Calendar.current
        let today = Date()
        
        let all = try fetchAll()
        return all.filter {
            guard let dueDate = $0.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: today)
        }
    }
    
    func create(_ assignment: Assignment) throws {
        modelContext.insert(assignment)
        try modelContext.save()
    }
    
    func update() throws {
        try modelContext.save()
    }
    
    func delete(_ assignment: Assignment) throws {
        modelContext.delete(assignment)
        try modelContext.save()
    }
}
