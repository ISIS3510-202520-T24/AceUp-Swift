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

    // Servicio de OCR/IA para parsear el horario desde una foto
    private let service: ScheduleOCRServiceProtocol

    // Provider híbrido (NSCache en memoria + ScheduleLocalStore + Firebase)
    private let scheduleProvider = UnifiedHybridDataProviders.shared.scheduleProvider

    // Init simplificado (ya no inyectamos ScheduleLocalStore)
    init(service: ScheduleOCRServiceProtocol) {
        self.service = service
    }

    // MARK: - Carga inicial

    /// Carga el horario usando el HybridScheduleDataProvider (NSCache + local + Firebase)
    func loadSavedSchedule() {
        Task { @MainActor in
            let loaded = await self.scheduleProvider.loadSchedule()
            self.schedule = loaded

            if !loaded.days.isEmpty {
                self.state = .parsed
            } else {
                self.state = .idle
            }

            print("Loaded schedule (hybrid cache + Firebase) with \(loaded.days.count) days")
        }
    }

    // MARK: - Captura de imagen

    func didCapture(image: UIImage) {
        capturedImage = image
        print("📸 ScheduleViewModel.didCapture -> image captured, starting analyze()")
        Task { await analyze() }
    }

    // MARK: - Análisis con OCR/IA

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

            // Guarda el resultado a través del provider híbrido (NSCache + local + Firebase)
            await scheduleProvider.saveSchedule(parsed)

            self.schedule = parsed
            self.state = .parsed
            print("ScheduleViewModel.analyze -> parsed OK. days=\(parsed.days.count)")
        } catch {
            print("ScheduleViewModel.analyze -> error:", error.localizedDescription)
            self.state = .error(error.localizedDescription)
        }
    }

    // MARK: - Cambios manuales

    /// Aplica un horario manualmente y lo persiste
    func applyManualChanges(_ newSchedule: Schedule) {
        self.schedule = newSchedule

        Task {
            await self.scheduleProvider.saveSchedule(newSchedule)
            print("Apply manual changes -> saved via HybridScheduleDataProvider")
        }

        if newSchedule.days.isEmpty {
            state = .idle
        } else {
            state = .parsed
        }
    }

    /// Guardar explícitamente lo que esté en schedule (para el botón Save)
    func saveCurrentSchedule() {
        let current = schedule

        Task {
            await self.scheduleProvider.saveSchedule(current)
            print("saveCurrentSchedule -> saved via HybridScheduleDataProvider with \(current.days.count) days")
        }

        if schedule.days.isEmpty {
            state = .idle
        } else {
            state = .parsed
        }
    }

    // MARK: - Reset

    func reset() {
        print("🔄 ScheduleViewModel.reset")
        state = .idle
        capturedImage = nil
        schedule = .empty

        Task {
            await self.scheduleProvider.clearSchedule()
            print("Reset -> cleared schedule via HybridScheduleDataProvider")
        }
    }
}
