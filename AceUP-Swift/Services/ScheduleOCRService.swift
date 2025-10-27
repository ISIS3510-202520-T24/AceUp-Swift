import Foundation
import Vision
import UIKit

public protocol ScheduleOCRServiceProtocol {
    func parseSchedule(imageData: Data) async throws -> Schedule
}

public struct ScheduleOCRServiceConfig {
    public var useMock: Bool
    public var straico: StraicoConfig?

    public init(useMock: Bool, straico: StraicoConfig?) {
        self.useMock = useMock
        self.straico = straico
    }

    public static func load() -> ScheduleOCRServiceConfig {
        let mockFlag = AppConfigProvider.useMock()
        let straicoCfg = StraicoConfig.loadFromConfigPlist()
        print("🔧 ScheduleOCRServiceConfig.load -> useMock=\(mockFlag), straicoIsNil=\(straicoCfg == nil)")
        return .init(useMock: mockFlag, straico: straicoCfg)
    }
}

public final class ScheduleOCRService: ScheduleOCRServiceProtocol {
    private let cfg: ScheduleOCRServiceConfig
    private let straico: StraicoClient?

    public init(config: ScheduleOCRServiceConfig = .load()) {
        self.cfg = config
        if let sc = config.straico {
            print("✅ ScheduleOCRService.init -> StraicoClient creado")
            self.straico = StraicoClient(config: sc)
        } else {
            print("❌ ScheduleOCRService.init -> NO StraicoClient (probablemente falta Config.plist o STRAICO_* keys)")
            self.straico = nil
        }
    }

    public func parseSchedule(imageData: Data) async throws -> Schedule {
        if cfg.useMock {
            print("🟡 parseSchedule -> MODO MOCK activo, devolviendo horario falso")
            return try await mockResponse()
        }

        print("🟢 parseSchedule -> MODO REAL (OCR + Straico)")

        // 1. OCR local con Vision
        let recognized = try await recognizeText(from: imageData)
        print("🔎 OCR recognized text:\n\(recognized)")

        // 2. Llamar a Straico
        guard let straico = self.straico else {
            print("❌ parseSchedule -> straico == nil (no config?)")
            throw NSError(
                domain: "ScheduleOCRService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey:
                    "Missing Straico config. Check STRAICO_API_BASE / STRAICO_API_KEY / Target Membership."
                ]
            )
        }

        let completionText = try await straico.complete(prompt: buildPrompt(with: recognized))
        print("🤖 Straico completionText (RAW):\n\(completionText)")

        // 3. Extraer el bloque JSON puro "{ \"days\": [...] }"
        let jsonSchedule = try extractScheduleJSON(from: completionText)
        print("📄 FINAL JSON TO DECODE:\n\(jsonSchedule)\n")

        // 4. Decodificar al modelo Schedule
        let schedule = try JSONDecoder().decode(Schedule.self, from: Data(jsonSchedule.utf8))
        print("✅ parseSchedule -> decode OK, days=\(schedule.days.count)")
        return schedule
    }

    // MARK: - Vision OCR
    private func recognizeText(from imageData: Data) async throws -> String {
        guard let uiImg = UIImage(data: imageData),
              let cgImg = uiImg.cgImage else {
            throw NSError(
                domain: "OCR",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid image"])
        }

        return try await withCheckedThrowingContinuation { cont in
            let req = VNRecognizeTextRequest { req, err in
                if let err = err {
                    cont.resume(throwing: err)
                    return
                }
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let text = lines.joined(separator: "\n")
                cont.resume(returning: text)
            }

            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            req.recognitionLanguages = ["es-CO","es","en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImg, options: [:])
            do {
                try handler.perform([req])
            } catch {
                cont.resume(throwing: error)
            }
        }
    }

    // MARK: - Prompt a Straico
    private func buildPrompt(with rawText: String) -> String {
        """
        You are an assistant that converts noisy OCR text of a WEEKLY UNIVERSITY SCHEDULE into a clean JSON object.

        The OCR text (Spanish) is delimited by <TEXT>…</TEXT>.
        Group classes by weekday. Weekday keys MUST be: monday,tuesday,wednesday,thursday,friday,saturday,sunday.
        If you don't know start/end time, return null for them.
        If you don't know location or notes, return null.

        Output ONLY valid JSON. DO NOT include ``` or markdown fences or the word "json".
        Shape:

        {
          "days": [
            {
              "weekday": "monday",
              "sessions": [
                {
                  "course": "SISTEMAS EMPRESARIALES",
                  "start": "08:00" or null,
                  "end": "10:00" or null,
                  "location": null,
                  "notes": null
                }
              ]
            }
          ]
        }

        <TEXT>
        \(rawText)
        </TEXT>
        """
    }

    // MARK: - Limpia la respuesta de Straico y extrae el JSON puro
    private func extractScheduleJSON(from rawResponse: String) throws -> String {
        // La respuesta de Straico que vimos tiene esta forma:
        // {
        //   "data": {
        //     "completion": {
        //       "choices": [
        //         {
        //           "message": {
        //             "content": "json\n{ \"days\": [...] }"
        //           }
        //         }
        //       ]
        //     }
        //   },
        //   "success": true
        // }

        struct Root: Decodable {
            struct DataBlock: Decodable {
                struct Completion: Decodable {
                    struct Choice: Decodable {
                        struct Message: Decodable {
                            let content: String
                        }
                        let message: Message
                    }
                    let choices: [Choice]
                }
                let completion: Completion
            }
            let data: DataBlock
        }

        guard let data = rawResponse.data(using: .utf8) else {
            throw NSError(domain: "Parser", code: -10, userInfo: [NSLocalizedDescriptionKey: "Response not utf8"])
        }

        let decoded = try JSONDecoder().decode(Root.self, from: data)

        guard let firstChoice = decoded.data.completion.choices.first else {
            throw NSError(domain: "Parser", code: -11, userInfo: [NSLocalizedDescriptionKey: "No choices from AI"])
        }

        var content = firstChoice.message.content
        print("📝 AI message.content BEFORE CLEAN:\n\(content)\n")

        // content puede venir como:
        // "json\n{ \"days\": [...] }"
        // o
        // "{ \"days\": [...] }"
        // entonces buscamos el primer '{' y el último '}' y nos quedamos con eso

        if let firstBrace = content.firstIndex(of: "{"),
           let lastBrace = content.lastIndex(of: "}") {
            content = String(content[firstBrace...lastBrace])
        }

        content = content.trimmingCharacters(in: .whitespacesAndNewlines)

        print("📝 AI message.content AFTER CLEAN:\n\(content)\n")

        guard content.hasPrefix("{"), content.hasSuffix("}") else {
            throw NSError(
                domain: "Parser",
                code: -12,
                userInfo: [NSLocalizedDescriptionKey: "AI content is not pure JSON object"]
            )
        }

        return content
    }

    // MARK: - Mock (cuando AI_API_USE_MOCK = "true")
    private func mockResponse() async throws -> Schedule {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        return Schedule(days: [
            .init(weekday: .monday, sessions: [
                .init(course: "ARQUITECTURA Y DISEÑO DE SOFTWARE", start: "08:00", end: "10:00", location: "ML-101", notes: nil),
                .init(course: "INFRAESTRUCTURA COMPUTACIONAL", start: "10:00", end: "12:00", location: "SD-203", notes: nil)
            ]),
            .init(weekday: .friday, sessions: [
                .init(course: "DISEÑO DE PRODUCTOS E INNOVACIÓN EN TI", start: "12:00", end: "15:00", location: nil, notes: nil)
            ])
        ])
    }
}
