import Foundation

// Representa el día de la semana. Esto viene del JSON como "monday", "tuesday", etc.
public enum Weekday: String, Codable, CaseIterable {
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    // Texto bonito para mostrar en UI
    public var display: String {
        switch self {
        case .monday: return "Lunes"
        case .tuesday: return "Martes"
        case .wednesday: return "Miércoles"
        case .thursday: return "Jueves"
        case .friday: return "Viernes"
        case .saturday: return "Sábado"
        case .sunday: return "Domingo"
        }
    }
}

// Representa TODO el horario completo
public struct Schedule: Codable, Equatable {
    public var days: [ScheduleDay]
}

// Representa un día con sus materias/sesiones
public struct ScheduleDay: Codable, Equatable {
    public var weekday: Weekday
    public var sessions: [ScheduleSession]
}

// Representa una clase/sesión individual
// 🔥 Ahora también es Hashable para poder usar ForEach(..., id: \.self)
public struct ScheduleSession: Codable, Equatable, Hashable {
    public var course: String          // Nombre de la materia
    public var start: String?          // "08:00" o nil si no sabemos
    public var end: String?            // "10:00" o nil si no sabemos
    public var location: String?       // Salón / edificio / etc
    public var notes: String?          // Comentarios extra (opcional)
}

// Conveniencia para cuando no hay nada todavía
public extension Schedule {
    static var empty: Schedule {
        .init(days: [])
    }
}
