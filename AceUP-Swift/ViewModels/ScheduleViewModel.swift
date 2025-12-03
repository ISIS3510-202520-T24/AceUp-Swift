import Foundation
import Combine
import UIKit

@MainActor
final class ScheduleViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case capturing
        case sending
        case parsed
        case error(String)
    }

    @Published var state: State = .idle
    @Published var capturedImage: UIImage?
    @Published var schedule: Schedule = .empty

    nonisolated private let service: ScheduleOCRServiceProtocol
    // Local store para calendario
    nonisolated private let localStore: ScheduleLocalStore

    nonisolated init(service: ScheduleOCRServiceProtocol,
                     localStore: ScheduleLocalStore = .shared) {

        self.service = service
        self.localStore = localStore
    }

    func loadSavedSchedule() {
        // Load previously saved schedule
        if let saved = try? localStore.load() {
            self.schedule = saved
            if !saved.days.isEmpty {
                self.state = .parsed
            }
            print("Loaded saved schedule with \(saved.days.count) days")
        } else {
            print("No saved schedule found")
        }
    }

    func didCapture(image: UIImage) {
        capturedImage = image
        print("📸 ScheduleViewModel.didCapture -> image captured, starting analyze()")
        Task { await analyze() }
    }

    func analyze() async {
        guard let img = capturedImage,
              let data = img.jpegData(compressionQuality: 0.8) else {
            print("ScheduleViewModel.analyze -> no image data")
            return
        }

        state = .sending
        print("ScheduleViewModel.analyze -> sending to OCR/AI")

        do {
            let parsed = try await service.parseSchedule(imageData: data)

            // Guardar en local
            do {
                try localStore.save(parsed)
                print("Analyze -> schedule saved locally")
            } catch {
                print("Failed to save schedule locally: \(error)")
            }

            self.schedule = parsed
            self.state = .parsed
            print("ScheduleViewModel.analyze -> parsed OK. days=\(parsed.days.count)")
        } catch {
            print("ScheduleViewModel.analyze -> error:", error.localizedDescription)
            self.state = .error(error.localizedDescription)
        }
    }

    // Aplica un horario manualmente y lo persiste
    func applyManualChanges(_ newSchedule: Schedule) {
        self.schedule = newSchedule

        do {
            try localStore.save(newSchedule)
            print("Apply manual changes -> saved")
        } catch {
            print("Failed to save manual schedule: \(error)")
        }

        if newSchedule.days.isEmpty {
            state = .idle
        } else {
            state = .parsed
        }
    }

    /// Guardar explícitamente lo que esté en `schedule` (para el botón Save)
    func saveCurrentSchedule() {
        do {
            try localStore.save(schedule)
            print("saveCurrentSchedule -> saved schedule with \(schedule.days.count) days")
        } catch {
            print("saveCurrentSchedule -> failed: \(error)")
        }

        if schedule.days.isEmpty {
            state = .idle
        } else {
            state = .parsed
        }
    }

    func reset() {
        print("🔄 ScheduleViewModel.reset")
        state = .idle
        capturedImage = nil
        schedule = .empty

        // Guardar horario vacío para que Calendar también quede limpio
        do {
            try localStore.save(.empty)
            print("Reset -> saved empty schedule")
        } catch {
            print("Reset -> failed to save empty schedule: \(error)")
        }
    }
}
