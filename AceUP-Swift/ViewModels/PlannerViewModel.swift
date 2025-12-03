import Foundation
import Combine

@MainActor
class PlannerViewModel: ObservableObject {
    @Published var courses: [CourseInfo] = []
    
    private let scheduleStore = ScheduleLocalStore.shared
    private let assignmentRepo: AssignmentRepositoryProtocol
    
    init() {
        // ahora podemos usar el hybrid provider sin problemas
        let provider = DataSynchronizationManager.shared.getAssignmentProvider()
        self.assignmentRepo = AssignmentRepository(dataProvider: provider)
    }
    
    func loadCourses() {
        // cargamos el schedule guardado
        let schedule: Schedule
        do {
            schedule = try scheduleStore.load() ?? Schedule.empty
        } catch {
            print("Error loading schedule: \(error)")
            schedule = Schedule.empty
        }
        
        // agrupamos las sesiones por nombre de materia
        var courseDict: [String: CourseInfo] = [:]
        
        for day in schedule.days {
            for session in day.sessions {
                let courseName = session.course.trimmingCharacters(in: .whitespaces)
                
                // si la materia ya existe, agregamos la sesion
                if var existingCourse = courseDict[courseName] {
                    if let start = session.start, let end = session.end {
                        let classSession = ClassSession(
                            weekday: day.weekday,
                            start: start,
                            end: end,
                            location: session.location
                        )
                        existingCourse.sessions.append(classSession)
                        courseDict[courseName] = existingCourse
                    }
                } else {
                    // creamos nueva materia
                    var newCourse = CourseInfo(name: courseName)
                    if let start = session.start, let end = session.end {
                        let classSession = ClassSession(
                            weekday: day.weekday,
                            start: start,
                            end: end,
                            location: session.location
                        )
                        newCourse.sessions.append(classSession)
                    }
                    courseDict[courseName] = newCourse
                }
            }
        }
        
        // convertimos a array y ordenamos por nombre
        courses = courseDict.values.sorted { $0.name < $1.name }
    }
    
    func getAssignments(for courseName: String) async -> [Assignment] {
        // traemos todas las tareas y filtramos por nombre de materia
        do {
            let allAssignments = try await assignmentRepo.getAllAssignments()
            return allAssignments.filter { $0.courseName == courseName }
        } catch {
            print("Error loading assignments: \(error)")
            return []
        }
    }
}
