import Foundation
import SQLite3

// MARK: - SQLite Database Manager (BD Local Relacional - 10 puntos)
class SubjectDatabaseManager {
    
    static let shared = SubjectDatabaseManager()
    
    private var db: OpaquePointer?
    private let dbPath: String
    
    private init() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("subjects.sqlite")
        
        dbPath = fileURL.path
        
        openDatabase()
        createTables()
    }
    
    // MARK: - Database Setup
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ Error opening database")
            return
        }
        print("✅ SQLite database opened at: \(dbPath)")
    }
    
    private func createTables() {
        // Tabla de sesiones de clase (Timetable)
        let classSessionsTable = """
        CREATE TABLE IF NOT EXISTS class_sessions (
            id TEXT PRIMARY KEY,
            subject_id TEXT NOT NULL,
            subject_name TEXT NOT NULL,
            session_date TEXT NOT NULL,
            day_of_week INTEGER NOT NULL,
            start_time TEXT,
            end_time TEXT,
            location TEXT,
            status TEXT DEFAULT 'upcoming',
            notes TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (subject_id) REFERENCES subjects(id)
        );
        """
        
        // Tabla de entradas de calificaciones
        let gradeEntriesTable = """
        CREATE TABLE IF NOT EXISTS grade_entries (
            id TEXT PRIMARY KEY,
            subject_id TEXT NOT NULL,
            subject_name TEXT NOT NULL,
            assignment_name TEXT NOT NULL,
            earned_points REAL,
            total_points REAL NOT NULL,
            weight REAL NOT NULL,
            category TEXT,
            date TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (subject_id) REFERENCES subjects(id)
        );
        """
        
        // Tabla de cálculos de notas (cache)
        let gradeCalculationsTable = """
        CREATE TABLE IF NOT EXISTS grade_calculations (
            subject_id TEXT PRIMARY KEY,
            subject_name TEXT NOT NULL,
            current_grade REAL,
            weighted_grade REAL,
            completed_weight REAL,
            remaining_weight REAL,
            last_calculated TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (subject_id) REFERENCES subjects(id)
        );
        """
        
        executeSQL(classSessionsTable)
        executeSQL(gradeEntriesTable)
        executeSQL(gradeCalculationsTable)
        
        // Crear índices para mejor performance
        executeSQL("CREATE INDEX IF NOT EXISTS idx_class_sessions_subject ON class_sessions(subject_id);")
        executeSQL("CREATE INDEX IF NOT EXISTS idx_class_sessions_date ON class_sessions(session_date);")
        executeSQL("CREATE INDEX IF NOT EXISTS idx_grade_entries_subject ON grade_entries(subject_id);")
    }
    
    private func executeSQL(_ sql: String) {
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ SQL executed: \(sql.prefix(50))...")
            } else {
                print("❌ SQL execution failed")
            }
        } else {
            print("❌ SQL preparation failed: \(sql.prefix(50))...")
        }
        
        sqlite3_finalize(statement)
    }
    
    // MARK: - Class Sessions CRUD
    
    func insertClassSession(subjectId: String, subjectName: String, date: Date, 
                          dayOfWeek: DayOfWeek, startTime: String?, endTime: String?, 
                          location: String?) -> Bool {
        let sql = """
        INSERT INTO class_sessions (id, subject_id, subject_name, session_date, day_of_week, start_time, end_time, location)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare insert statement")
            return false
        }
        
        let id = UUID().uuidString
        let dateFormatter = ISO8601DateFormatter()
        
        sqlite3_bind_text(statement, 1, id, -1, nil)
        sqlite3_bind_text(statement, 2, subjectId, -1, nil)
        sqlite3_bind_text(statement, 3, subjectName, -1, nil)
        sqlite3_bind_text(statement, 4, dateFormatter.string(from: date), -1, nil)
        sqlite3_bind_int(statement, 5, Int32(dayOfWeek.weekdayIndex))
        
        if let startTime = startTime {
            sqlite3_bind_text(statement, 6, startTime, -1, nil)
        }
        if let endTime = endTime {
            sqlite3_bind_text(statement, 7, endTime, -1, nil)
        }
        if let location = location {
            sqlite3_bind_text(statement, 8, location, -1, nil)
        }
        
        let success = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        return success
    }
    
    func getClassSessions(forSubjectId subjectId: String) -> [ClassSession] {
        let sql = "SELECT * FROM class_sessions WHERE subject_id = ? ORDER BY session_date ASC;"
        var statement: OpaquePointer?
        var sessions: [ClassSession] = []
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return sessions
        }
        
        sqlite3_bind_text(statement, 1, subjectId, -1, nil)
        
        let dateFormatter = ISO8601DateFormatter()
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let dateString = String(cString: sqlite3_column_text(statement, 3))
            let date = dateFormatter.date(from: dateString) ?? Date()
            
            let startTime = sqlite3_column_text(statement, 5) != nil ? 
                String(cString: sqlite3_column_text(statement, 5)) : nil
            let endTime = sqlite3_column_text(statement, 6) != nil ? 
                String(cString: sqlite3_column_text(statement, 6)) : nil
            let location = sqlite3_column_text(statement, 7) != nil ? 
                String(cString: sqlite3_column_text(statement, 7)) : nil
            let status = String(cString: sqlite3_column_text(statement, 8))
            
            let session = ClassSession(
                id: id,
                subjectId: subjectId,
                date: date,
                startTime: startTime,
                endTime: endTime,
                location: location,
                status: ClassSessionStatus(rawValue: status) ?? .upcoming
            )
            
            sessions.append(session)
        }
        
        sqlite3_finalize(statement)
        return sessions
    }
    
    func generateClassSessions(subject: Subject, semesterStartDate: Date, semesterEndDate: Date) {
        guard let classDays = subject.classDays, !classDays.isEmpty else { return }
        
        let calendar = Calendar.current
        var currentDate = semesterStartDate
        
        while currentDate <= semesterEndDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            for day in classDays {
                if day.weekdayIndex == weekday {
                    _ = insertClassSession(
                        subjectId: subject.id,
                        subjectName: subject.name,
                        date: currentDate,
                        dayOfWeek: day,
                        startTime: subject.startTime,
                        endTime: subject.endTime,
                        location: subject.location
                    )
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
    }
    
    // MARK: - Grade Entries CRUD
    
    // Convenience method accepting GradeEntry object
    func insertGradeEntry(_ entry: GradeEntry) -> Bool {
        return insertGradeEntry(
            subjectId: entry.subjectId,
            subjectName: "",
            assignmentName: entry.assignmentName,
            earnedPoints: entry.earnedPoints,
            totalPoints: entry.totalPoints,
            weight: entry.weight,
            category: entry.category,
            date: entry.date
        )
    }
    
    func insertGradeEntry(subjectId: String, subjectName: String, assignmentName: String,
                         earnedPoints: Double?, totalPoints: Double, weight: Double, 
                         category: String?, date: Date) -> Bool {
        let sql = """
        INSERT INTO grade_entries (id, subject_id, subject_name, assignment_name, earned_points, total_points, weight, category, date)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        let id = UUID().uuidString
        let dateFormatter = ISO8601DateFormatter()
        
        sqlite3_bind_text(statement, 1, id, -1, nil)
        sqlite3_bind_text(statement, 2, subjectId, -1, nil)
        sqlite3_bind_text(statement, 3, subjectName, -1, nil)
        sqlite3_bind_text(statement, 4, assignmentName, -1, nil)
        
        if let earnedPoints = earnedPoints {
            sqlite3_bind_double(statement, 5, earnedPoints)
        }
        
        sqlite3_bind_double(statement, 6, totalPoints)
        sqlite3_bind_double(statement, 7, weight)
        
        if let category = category {
            sqlite3_bind_text(statement, 8, category, -1, nil)
        }
        
        sqlite3_bind_text(statement, 9, dateFormatter.string(from: date), -1, nil)
        
        let success = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        return success
    }
    
    func getGradeEntries(forSubjectId subjectId: String) -> [GradeEntry] {
        let sql = "SELECT * FROM grade_entries WHERE subject_id = ? ORDER BY date DESC;"
        var statement: OpaquePointer?
        var entries: [GradeEntry] = []
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return entries
        }
        
        sqlite3_bind_text(statement, 1, subjectId, -1, nil)
        
        let dateFormatter = ISO8601DateFormatter()
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let assignmentName = String(cString: sqlite3_column_text(statement, 3))
            
            let earnedPoints = sqlite3_column_type(statement, 4) != SQLITE_NULL ? 
                sqlite3_column_double(statement, 4) : nil
            
            let totalPoints = sqlite3_column_double(statement, 5)
            let weight = sqlite3_column_double(statement, 6)
            
            let category = sqlite3_column_text(statement, 7) != nil ? 
                String(cString: sqlite3_column_text(statement, 7)) : nil
            
            let dateString = String(cString: sqlite3_column_text(statement, 8))
            let date = dateFormatter.date(from: dateString) ?? Date()
            
            let entry = GradeEntry(
                id: id,
                subjectId: subjectId,
                assignmentName: assignmentName,
                earnedPoints: earnedPoints,
                totalPoints: totalPoints,
                weight: weight,
                category: category,
                date: date
            )
            
            entries.append(entry)
        }
        
        sqlite3_finalize(statement)
        return entries
    }
    
    deinit {
        sqlite3_close(db)
    }
}

// MARK: - Models
struct ClassSession: Identifiable {
    let id: String
    let subjectId: String
    let date: Date
    let startTime: String?
    let endTime: String?
    let location: String?
    let status: ClassSessionStatus
}

enum ClassSessionStatus: String {
    case upcoming = "upcoming"
    case completed = "completed"
    case cancelled = "cancelled"
}

struct GradeEntry: Identifiable {
    let id: String
    let subjectId: String
    let assignmentName: String
    let earnedPoints: Double?
    let totalPoints: Double
    let weight: Double
    let category: String?
    let date: Date
    
    var percentageGrade: Double? {
        guard let earned = earnedPoints else { return nil }
        return (earned / totalPoints) * 100
    }
    
    var contributionToFinal: Double? {
        guard let earned = earnedPoints else { return nil }
        return (earned / totalPoints) * weight
    }
}
