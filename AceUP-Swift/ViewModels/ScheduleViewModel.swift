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

    private let service: ScheduleOCRServiceProtocol

    init(service: ScheduleOCRServiceProtocol) {
        self.service = service
    }

    func didCapture(image: UIImage) {
        capturedImage = image
        print("📸 ScheduleViewModel.didCapture -> image captured, starting analyze()")
        Task { await analyze() }
    }

    func analyze() async {
        guard let img = capturedImage,
              let data = img.jpegData(compressionQuality: 0.8) else {
            print("❌ ScheduleViewModel.analyze -> no image data")
            return
        }

        state = .sending
        print("🚀 ScheduleViewModel.analyze -> sending to OCR/AI")

        do {
            let parsed = try await service.parseSchedule(imageData: data)
            self.schedule = parsed
            self.state = .parsed
            print("✅ ScheduleViewModel.analyze -> parsed OK. days=\(parsed.days.count)")
        } catch {
            print("❌ ScheduleViewModel.analyze -> error:", error.localizedDescription)
            self.state = .error(error.localizedDescription)
        }
    }

    func reset() {
        print("🔄 ScheduleViewModel.reset")
        state = .idle
        capturedImage = nil
        schedule = .empty
    }
}
