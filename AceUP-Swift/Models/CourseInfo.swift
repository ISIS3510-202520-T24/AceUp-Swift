import Foundation

// Info basica de una materia sacada del schedule
struct CourseInfo: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let color: String
    
    // horarios de esta materia en la semana
    var sessions: [ClassSession]
    
    init(name: String, color: String = "#122C4A") {
        // ID único y estable: combinación de nombre normalizado + UUID corto
        // Esto evita colisiones entre cursos con nombres similares
        let normalizedName = Self.normalizeCourseName(name)
        let uniqueSuffix = UUID().uuidString.prefix(8)
        self.id = "\(normalizedName)_\(uniqueSuffix)"
        self.name = name
        self.color = color
        self.sessions = []
    }
    
    // Normaliza el nombre del curso para generar un ID estable
    private static func normalizeCourseName(_ name: String) -> String {
        name
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression)
    }
}

// representa una sesion de clase con dia y hora
struct ClassSession: Identifiable, Hashable, Sendable {
    // ID estable basado en weekday+start+end para ForEach
    var id: String {
        "\(weekday.rawValue)_\(start)_\(end)"
    }
    
    let weekday: Weekday
    let start: String
    let end: String
    let location: String?
}
