import Foundation

/// Wrapper para guardar las notas de un curso con fecha de actualización
struct StoredGrades: Codable, Sendable {
    var updatedAt: Date
    var courseId: String
    var items: [GradeItem]
}

/// DataStore local para grades - Thread-safe usando actor
actor GradesLocalStore {
    static let shared = GradesLocalStore()

    private let baseDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.baseDirectory = docs.appendingPathComponent("grades")
        
        // Crear directorio si no existe
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    /// Genera la URL del archivo para un curso específico
    private func fileURL(for courseId: String) -> URL {
        // Sanitizar el courseId para nombre de archivo seguro
        let safeName = courseId.replacingOccurrences(of: "/", with: "_")
        return baseDirectory.appendingPathComponent("\(safeName)_grades.json")
    }

    /// Guarda las notas de un curso
    func save(_ items: [GradeItem], for courseId: String) async throws {
        let wrapper = StoredGrades(updatedAt: Date(), courseId: courseId, items: items)
        let data = try encoder.encode(wrapper)
        let url = fileURL(for: courseId)
        try data.write(to: url, options: [.atomic])
    }

    /// Carga las notas de un curso
    func load(for courseId: String) async throws -> [GradeItem]? {
        let url = fileURL(for: courseId)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: url)
        let wrapper = try decoder.decode(StoredGrades.self, from: data)
        return wrapper.items
    }

    /// Elimina las notas de un curso
    func delete(for courseId: String) async throws {
        let url = fileURL(for: courseId)
        
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    /// Lista todos los cursos que tienen notas guardadas
    func listAllCourses() async throws -> [String] {
        let files = try FileManager.default.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil)
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> String? in
                let filename = url.deletingPathExtension().lastPathComponent
                return filename.replacingOccurrences(of: "_grades", with: "")
            }
    }
}
