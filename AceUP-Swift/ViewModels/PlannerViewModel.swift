import Foundation
import Combine

@MainActor
class PlannerViewModel: ObservableObject {
    @Published var courses: [CourseInfo] = []
    @Published var isLoading = false
    
    private let scheduleStore = ScheduleLocalStore.shared
    private var assignmentRepo: AssignmentRepositoryProtocol?
    
    init() {
        // Inicialización sincrónica - el provider se obtiene async en loadCourses
    }
    
    /// Carga los cursos de forma asíncrona en background thread
    func loadCourses() async {
        isLoading = true
        defer { isLoading = false }
        
        // 1. Obtener provider de forma async si no existe
        if assignmentRepo == nil {
            await initializeRepository()
        }
        
        // 2. Cargar schedule en background thread
        let schedule = await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return Schedule.empty }
            do {
                return try await self.scheduleStore.load() ?? Schedule.empty
            } catch {
                print("Error loading schedule: \(error)")
                return Schedule.empty
            }
        }.value
        
        // 3. Procesar en background thread
        let processedCourses = await Task.detached(priority: .userInitiated) {
            await Self.processCourses(from: schedule)
        }.value
        
        // 4. Actualizar UI en MainActor
        courses = processedCourses
    }
    
    /// Inicializa el repositorio de forma asíncrona
    private func initializeRepository() async {
        // Ejecutar en background para no bloquear el MainActor
        let provider = await Task.detached {
            await DataSynchronizationManager.shared.getAssignmentProvider()
        }.value
        
        assignmentRepo = AssignmentRepository(dataProvider: provider)
    }
    
    /// Procesa el schedule y agrupa por materias (ejecutado en background)
    private static func processCourses(from schedule: Schedule) -> [CourseInfo] {
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
        return courseDict.values.sorted { $0.name < $1.name }
    }
    
    func getAssignments(for courseName: String) async -> [Assignment] {
        // Asegurarse de que el repo esté inicializado
        if assignmentRepo == nil {
            await initializeRepository()
        }
        
        guard let repo = assignmentRepo else {
            print("Assignment repository not initialized")
            return []
        }
        
        // traemos todas las tareas y filtramos por nombre de materia
        do {
            let allAssignments = try await repo.getAllAssignments()
            return allAssignments.filter { $0.courseName == courseName }
        } catch {
            print("Error loading assignments: \(error)")
            return []
        }
    }
}
