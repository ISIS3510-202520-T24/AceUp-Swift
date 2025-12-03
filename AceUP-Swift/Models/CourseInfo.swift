import Foundation

// Info basica de una materia sacada del schedule
struct CourseInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let color: String
    
    // horarios de esta materia en la semana
    var sessions: [ClassSession]
    
    init(name: String, color: String = "#122C4A") {
        self.id = UUID().uuidString
        self.name = name
        self.color = color
        self.sessions = []
    }
}

// representa una sesion de clase con dia y hora
struct ClassSession: Hashable {
    let weekday: Weekday
    let start: String
    let end: String
    let location: String?
}
