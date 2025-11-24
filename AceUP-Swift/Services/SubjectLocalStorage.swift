import Foundation

// MARK: - UserDefaults Subject Storage (BD Llave/Valor - 5 puntos)
class SubjectLocalStorage {
    
    static let shared = SubjectLocalStorage()
    private let defaults = UserDefaults.standard
    private let cache = SubjectCache.shared
    
    private let subjectsKey = "com.aceup.subjects"
    
    private init() {}
    
    // MARK: - Create
    func create(_ subject: Subject, semesterId: String?) async throws -> Subject {
        var allSubjects = try await fetchAll()
        
        // Verificar duplicados
        if allSubjects.contains(where: { $0.id == subject.id }) {
            throw NSError(domain: "SubjectStorage", code: 409, 
                         userInfo: [NSLocalizedDescriptionKey: "Subject already exists"])
        }
        
        var newSubject = subject
        if let semesterId = semesterId {
            // Guardar semesterId en un UserDefaults separado para mantener la relación
            var semesterSubjects = getSemesterSubjects(semesterId: semesterId)
            semesterSubjects.append(subject.id)
            setSemesterSubjects(semesterId: semesterId, subjectIds: semesterSubjects)
        }
        
        allSubjects.append(newSubject)
        try save(allSubjects)
        
        cache.setSubject(newSubject)
        if let semesterId = semesterId {
            cache.invalidateSemester(id: semesterId)
        }
        
        return newSubject
    }
    
    // MARK: - Read
    func fetchAll(semesterId: String? = nil) async throws -> [Subject] {
        // 1. Intentar cache primero
        if let semesterId = semesterId,
           let cached = cache.getSubjects(forSemester: semesterId) {
            print("✅ Returning \(cached.count) subjects from CACHE")
            return cached
        }
        
        // 2. Leer de UserDefaults (Key-Value DB)
        guard let data = defaults.data(forKey: subjectsKey) else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let allSubjects = try decoder.decode([Subject].self, from: data)
        
        // 3. Filtrar por semester si es necesario
        var subjects = allSubjects
        if let semesterId = semesterId {
            let semesterSubjectIds = getSemesterSubjects(semesterId: semesterId)
            subjects = allSubjects.filter { semesterSubjectIds.contains($0.id) }
            
            // Cachear resultado
            cache.setSubjects(subjects, forSemester: semesterId)
        }
        
        print("✅ Fetched \(subjects.count) subjects from UserDefaults")
        return subjects
    }
    
    func fetchById(_ id: String) async throws -> Subject? {
        // 1. Intentar cache
        if let cached = cache.getSubject(id: id) {
            return cached
        }
        
        // 2. Buscar en UserDefaults
        let allSubjects = try await fetchAll()
        let subject = allSubjects.first { $0.id == id }
        
        // 3. Cachear si existe
        if let subject = subject {
            cache.setSubject(subject)
        }
        
        return subject
    }
    
    // MARK: - Update
    func update(_ subject: Subject) async throws -> Subject {
        var allSubjects = try await fetchAll()
        
        guard let index = allSubjects.firstIndex(where: { $0.id == subject.id }) else {
            throw NSError(domain: "SubjectStorage", code: 404,
                         userInfo: [NSLocalizedDescriptionKey: "Subject not found"])
        }
        
        var updated = subject
        updated.updatedAt = Date()
        allSubjects[index] = updated
        
        try save(allSubjects)
        
        // Actualizar cache
        cache.setSubject(updated)
        
        // Invalidar cache de semester (buscar en qué semester está)
        if let semesterId = findSemesterForSubject(subjectId: subject.id) {
            cache.invalidateSemester(id: semesterId)
        }
        
        return updated
    }
    
    // MARK: - Delete
    func delete(_ id: String) async throws {
        var allSubjects = try await fetchAll()
        
        guard let index = allSubjects.firstIndex(where: { $0.id == id }) else {
            throw NSError(domain: "SubjectStorage", code: 404,
                         userInfo: [NSLocalizedDescriptionKey: "Subject not found"])
        }
        
        allSubjects.remove(at: index)
        try save(allSubjects)
        
        // Invalidar caches
        cache.invalidateSubject(id: id)
        
        // Remover de relación semester
        if let semesterId = findSemesterForSubject(subjectId: id) {
            var semesterSubjects = getSemesterSubjects(semesterId: semesterId)
            semesterSubjects.removeAll { $0 == id }
            setSemesterSubjects(semesterId: semesterId, subjectIds: semesterSubjects)
            cache.invalidateSemester(id: semesterId)
        }
    }
    
    // MARK: - Private Helpers
    private func save(_ subjects: [Subject]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(subjects)
        defaults.set(data, forKey: subjectsKey)
    }
    
    // MARK: - Semester Relationships (usando UserDefaults como BD Llave/Valor)
    private func getSemesterSubjects(semesterId: String) -> [String] {
        let key = "semester_subjects_\(semesterId)"
        return defaults.stringArray(forKey: key) ?? []
    }
    
    private func setSemesterSubjects(semesterId: String, subjectIds: [String]) {
        let key = "semester_subjects_\(semesterId)"
        defaults.set(subjectIds, forKey: key)
    }
    
    private func findSemesterForSubject(subjectId: String) -> String? {
        // Buscar en todas las keys que empiezan con "semester_subjects_"
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix("semester_subjects_") {
            if let subjectIds = defaults.stringArray(forKey: key),
               subjectIds.contains(subjectId) {
                let semesterId = key.replacingOccurrences(of: "semester_subjects_", with: "")
                return semesterId
            }
        }
        return nil
    }
}
