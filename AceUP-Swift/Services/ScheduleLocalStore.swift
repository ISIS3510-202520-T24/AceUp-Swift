import Foundation

/// Wrapper para guardar el horario con fecha de actualización
struct StoredSchedule: Codable {
    var updatedAt: Date
    var schedule: Schedule
}

/// DataStore local
@MainActor
final class ScheduleLocalStore {
    nonisolated(unsafe) static let shared = ScheduleLocalStore()

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = docs.appendingPathComponent("user_schedule.json")

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func save(_ schedule: Schedule) throws {
        let wrapper = StoredSchedule(updatedAt: Date(), schedule: schedule)
        let data = try encoder.encode(wrapper)
        try data.write(to: fileURL, options: [.atomic])
    }

    func load() throws -> Schedule? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        let wrapper = try decoder.decode(StoredSchedule.self, from: data)
        return wrapper.schedule
    }

    func delete() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}