//
//  CoreDataHolidayDataProvider.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 13/10/25.
//

import Foundation
import CoreData

@MainActor
final class CoreDataHolidayDataProvider: ObservableObject {

    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext

    init(persistenceController: PersistenceController? = nil) {
        let c = persistenceController ?? PersistenceController.shared
        self.persistenceController = c
        self.context = c.viewContext
    }

    func fetchHolidays(for country: String, year: Int) async throws -> [Holiday] {
        let req: NSFetchRequest<HolidayEntity> = HolidayEntity.fetchRequest()
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
        let end   = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        req.predicate = NSPredicate(format: "country == %@ AND date >= %@ AND date < %@",
                                    country, start as NSDate, end as NSDate)
        req.sortDescriptors = [NSSortDescriptor(keyPath: \HolidayEntity.date, ascending: true)]
        return try context.fetch(req).map { $0.toHoliday() }
    }

    func fetchAllHolidays() async throws -> [Holiday] {
        let req: NSFetchRequest<HolidayEntity> = HolidayEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(keyPath: \HolidayEntity.date, ascending: true)]
        return try context.fetch(req).map { $0.toHoliday() }
    }

    func saveHoliday(_ h: Holiday) async throws {
        if let e = try await fetchEntity(by: h.id) {
            e.updateFromHoliday(h)
        } else {
            _ = HolidayEntity.fromHoliday(h, in: context)
        }
        do { try context.save() } catch { context.rollback(); throw error }
    }

    func saveHolidays(_ hs: [Holiday]) async throws {
        for h in hs {
            if let e = try await fetchEntity(by: h.id) { e.updateFromHoliday(h) }
            else { _ = HolidayEntity.fromHoliday(h, in: context) }
        }
        do { try context.save() } catch { context.rollback(); throw error }
    }

    private func fetchEntity(by id: String) async throws -> HolidayEntity? {
        let req: NSFetchRequest<HolidayEntity> = HolidayEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id)
        req.fetchLimit = 1
        return try context.fetch(req).first
    }
}
