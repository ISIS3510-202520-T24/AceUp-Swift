import SwiftUI

struct SubjectDetailView: View {
    
    let subject: Subject
    let semesterStartDate: Date
    let semesterEndDate: Date
    
    @State private var selectedTab = 0
    @State private var classSessions: [ClassSession] = []
    @State private var gradeEntries: [GradeEntry] = []
    @State private var assignments: [Assignment] = []
    @State private var gradeResult: GradeCalculationResult?
    @State private var showAddGradeSheet = false
    @State private var newGradeTitle = ""
    @State private var newGradeEarned = ""
    @State private var newGradeTotal = "5.0"
    @State private var newGradeWeight = ""
    
    @StateObject private var assignmentRepo = AssignmentRepository()
    
    private let db = SubjectDatabaseManager.shared
    private let calculator = GradeCalculator.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector
            Picker("", selection: $selectedTab) {
                Text("Timetable").tag(0)
                Text("Assignments").tag(1)
                Text("Grades").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Tab Content
            TabView(selection: $selectedTab) {
                timetableTab.tag(0)
                assignmentsTab.tag(1)
                gradesTab.tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        // Debug: Mostrar info del subject
                        print("\n📋 SUBJECT DEBUG INFO:")
                        print("   ID: \(subject.id)")
                        print("   Name: \(subject.name)")
                        print("   classDays: \(subject.classDays?.map { $0.rawValue } ?? [])")
                        print("   startTime: \(subject.startTime ?? "nil")")
                        print("   endTime: \(subject.endTime ?? "nil")")
                        print("   location: \(subject.location ?? "nil")")
                        print("   All fields present: \(subject.classDays != nil && subject.startTime != nil)")
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    
                    Button {
                        loadData()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            loadData()
        }
        .refreshable {
            loadData()
        }
        .sheet(isPresented: $showAddGradeSheet) {
            addGradeSheet
        }
    }
    
    // MARK: - Add Grade Sheet
    private var addGradeSheet: some View {
        NavigationView {
            Form {
                Section("Assignment Info") {
                    TextField("Assignment Name", text: $newGradeTitle)
                    TextField("Weight (0.0 - 1.0)", text: $newGradeWeight)
                        .keyboardType(.decimalPad)
                }
                
                Section("Grade") {
                    TextField("Points Earned", text: $newGradeEarned)
                        .keyboardType(.decimalPad)
                    TextField("Total Points", text: $newGradeTotal)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Grade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddGradeSheet = false
                        resetGradeForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addManualGrade()
                        showAddGradeSheet = false
                        resetGradeForm()
                    }
                    .disabled(newGradeTitle.isEmpty || newGradeEarned.isEmpty || newGradeWeight.isEmpty)
                }
            }
        }
    }
    
    private func addManualGrade() {
        guard let earned = Double(newGradeEarned),
              let total = Double(newGradeTotal),
              let weight = Double(newGradeWeight) else { return }
        
        let entry = GradeEntry(
            id: UUID().uuidString,
            subjectId: subject.id,
            assignmentName: newGradeTitle,
            earnedPoints: earned,
            totalPoints: total,
            weight: weight,
            category: "Manual",
            date: Date()
        )
        
        _ = db.insertGradeEntry(entry)
        loadGradeEntries()
    }
    
    private func resetGradeForm() {
        newGradeTitle = ""
        newGradeEarned = ""
        newGradeTotal = "5.0"
        newGradeWeight = ""
    }
    
    // MARK: - Tab 1: Timetable
    private var timetableTab: some View {
        VStack(spacing: 16) {
            // Stats Header
            HStack(spacing: 20) {
                StatBox(
                    title: "Classes Left",
                    value: "\(upcomingClasses)",
                    icon: "calendar.badge.clock",
                    color: "#007AFF"
                )
                
                StatBox(
                    title: "Completed",
                    value: "\(completedClasses)",
                    icon: "checkmark.circle.fill",
                    color: "#34C759"
                )
                
                StatBox(
                    title: "Total",
                    value: "\(totalClasses)",
                    icon: "calendar",
                    color: "#8E8E93"
                )
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Class List
            ScrollView {
                if classSessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "#C7C7CC"))
                        
                        Text("No class schedule")
                            .font(.headline)
                            .foregroundColor(Color(hex: "#8E8E93"))
                        
                        Text("Add class days and times when editing this subject")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#C7C7CC"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(classSessions) { session in
                            ClassSessionCard(session: session, subject: subject)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(hex: "#F5F7FA"))
    }
    
    // MARK: - Tab 2: Assignments
    private var assignmentsTab: some View {
        VStack(spacing: 16) {
            // Stats
            HStack(spacing: 20) {
                StatBox(
                    title: "Pending",
                    value: "\(pendingAssignments)",
                    icon: "clock.fill",
                    color: "#FF9500"
                )
                
                StatBox(
                    title: "Completed",
                    value: "\(completedAssignments)",
                    icon: "checkmark.circle.fill",
                    color: "#34C759"
                )
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Assignment List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(assignments) { assignment in
                        AssignmentRowCard(assignment: assignment)
                    }
                    
                    if assignments.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(Color(hex: "#C7C7CC"))
                            Text("No assignments found for \(subject.name)")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "#8E8E93"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                    }
                }
                .padding()
            }
        }
        .background(Color(hex: "#F5F7FA"))
    }
    
    // MARK: - Tab 3: Grades
    private var gradesTab: some View {
        VStack(spacing: 16) {
            // Current Grade Display
            if let result = gradeResult {
                VStack(spacing: 8) {
                    Text("Current Grade")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#8E8E93"))
                    
                    Text(String(format: "%.2f", result.currentGrade))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(gradeColor(result.currentGrade))
                    
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(Int(result.completedWeight * 100))%")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Completed")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#8E8E93"))
                        }
                        
                        VStack {
                            Text("\(Int(result.remainingWeight * 100))%")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Remaining")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#8E8E93"))
                        }
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .padding(.horizontal)
                .padding(.top)
                
                // Recommendations
                if let target = subject.targetGrade {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommendations")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(calculator.getRecommendations(currentResult: result, targetGrade: target), id: \.self) { rec in
                            HStack(alignment: .top, spacing: 12) {
                                Text(rec)
                                    .font(.subheadline)
                                    .foregroundColor(Color(hex: "#3A3A3C"))
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "#F5F7FA"))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
            }
            
            // Grade Entries List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(gradeEntries) { entry in
                        GradeEntryCard(entry: entry)
                    }
                    
                    if gradeEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 50))
                                .foregroundColor(Color(hex: "#C7C7CC"))
                            Text("No grades entered yet")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "#8E8E93"))
                            
                            Button {
                                showAddGradeSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Grade")
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color(hex: "#007AFF"))
                                .cornerRadius(8)
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                    } else {
                        Button {
                            showAddGradeSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Grade Manually")
                            }
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "#007AFF"))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(hex: "#F5F7FA"))
    }
    
    // MARK: - Computed Properties
    private var totalClasses: Int {
        classSessions.count
    }
    
    private var completedClasses: Int {
        classSessions.filter { $0.date < Date() }.count
    }
    
    private var upcomingClasses: Int {
        classSessions.filter { $0.date >= Date() }.count
    }
    
    private var pendingAssignments: Int {
        assignments.filter { $0.status != .completed }.count
    }
    
    private var completedAssignments: Int {
        assignments.filter { $0.status == .completed }.count
    }
    
    // MARK: - Helpers
    private func loadData() {
        Task {
            loadClassSessions()
            await loadAssignments()
            loadGradeEntries()
        }
    }
    
    private func loadClassSessions() {
        print("\n📅 Loading class sessions for: \(subject.name)")
        print("   Subject ID: \(subject.id)")
        print("   Subject has classDays: \(subject.classDays?.map { $0.rawValue }.joined(separator: ", ") ?? "none")")
        print("   Subject has startTime: \(subject.startTime ?? "none")")
        print("   Subject has endTime: \(subject.endTime ?? "none")")
        print("   Subject has location: \(subject.location ?? "none")")
        print("   Semester dates: \(semesterStartDate) to \(semesterEndDate)")
        
        classSessions = db.getClassSessions(forSubjectId: subject.id)
        print("   Loaded \(classSessions.count) sessions from DB")
        
        if classSessions.isEmpty {
            print("   Generating new sessions from \(semesterStartDate) to \(semesterEndDate)")
            db.generateClassSessions(subject: subject, semesterStartDate: semesterStartDate, semesterEndDate: semesterEndDate)
            classSessions = db.getClassSessions(forSubjectId: subject.id)
            print("   After generation: \(classSessions.count) sessions")
        }
    }
    
    private func loadAssignments() async {
        do {
            let allAssignments = try await assignmentRepo.getAllAssignments()
            print("📝 Loading assignments for: \(subject.name)")
            print("   Total assignments in repo: \(allAssignments.count)")
            
            // Filtrar por courseName que coincide con subject.name
            assignments = allAssignments.filter { $0.courseName == subject.name }
            print("   Filtered assignments for '\(subject.name)': \(assignments.count)")
            assignments.forEach { 
                print("      - \($0.title) | Status: \($0.status.rawValue) | Grade: \($0.grade?.description ?? "none") | Course: \($0.courseName)") 
            }
        } catch {
            print("❌ Error loading assignments: \(error)")
            assignments = []
        }
    }
    
    private func loadGradeEntries() {
        gradeEntries = db.getGradeEntries(forSubjectId: subject.id)
        
        print("\n📊 Loading grade entries for: \(subject.name)")
        print("   Subject ID: \(subject.id)")
        print("   Existing entries in DB: \(gradeEntries.count)")
        gradeEntries.forEach { print("      - \($0.assignmentName): \($0.earnedPoints ?? 0)/\($0.totalPoints)") }
        
        // Sincronizar assignments con grade_entries
        for assignment in assignments where assignment.status == .completed {
            // Verificar si ya existe una entrada para este assignment
            let exists = gradeEntries.contains { $0.assignmentName == assignment.title }
            if !exists, let grade = assignment.grade {
                print("   ✅ Creating entry for: \(assignment.title) with grade \(grade)")
                // Crear nueva entrada de calificación
                let entry = GradeEntry(
                    id: UUID().uuidString,
                    subjectId: subject.id,
                    assignmentName: assignment.title,
                    earnedPoints: grade,
                    totalPoints: 5.0,
                    weight: assignment.weight,
                    category: "Assignment",
                    date: assignment.updatedAt
                )
                _ = db.insertGradeEntry(entry)
            } else if exists {
                print("   ⏭️  Entry already exists for: \(assignment.title)")
            } else {
                print("   ⚠️  Assignment \(assignment.title) has no grade")
            }
        }
        
        // Recargar después de sincronizar
        gradeEntries = db.getGradeEntries(forSubjectId: subject.id)
        print("   Final entries count: \(gradeEntries.count)")
        gradeResult = calculator.calculateCurrentGrade(entries: gradeEntries)
        if let result = gradeResult {
            print("   Calculated grade: \(String(format: "%.2f", result.currentGrade))")
        }
    }
    
    private func gradeColor(_ grade: Double) -> Color {
        if grade >= 4.0 { return Color(hex: "#34C759") }
        if grade >= 3.0 { return Color(hex: "#FF9500") }
        return Color(hex: "#FF3B30")
    }
}

// MARK: - Stat Box Component
struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(hex: color))
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(Color(hex: "#8E8E93"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
    }
}

// MARK: - Class Session Card
struct ClassSessionCard: View {
    let session: ClassSession
    let subject: Subject
    
    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Text(dayName)
                    .font(.caption)
                    .foregroundColor(Color(hex: "#8E8E93"))
                Text(dayNumber)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(timeRange)
                    .font(.headline)
                
                if let location = session.location {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text(location)
                            .font(.subheadline)
                    }
                    .foregroundColor(Color(hex: "#8E8E93"))
                }
            }
            
            Spacer()
            
            Image(systemName: session.date < Date() ? "checkmark.circle.fill" : "circle")
                .foregroundColor(session.date < Date() ? Color(hex: "#34C759") : Color(hex: "#C7C7CC"))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: session.date)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: session.date)
    }
    
    private var timeRange: String {
        if let start = session.startTime, let end = session.endTime {
            return "\(start) - \(end)"
        }
        return "Time TBD"
    }
}

// MARK: - Assignment Row Card
struct AssignmentRowCard: View {
    let assignment: Assignment
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: assignment.status == .completed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(assignment.status == .completed ? Color(hex: "#34C759") : Color(hex: "#FF9500"))
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text("\(Int(assignment.weight * 100))%")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#007AFF").opacity(0.1))
                        .foregroundColor(Color(hex: "#007AFF"))
                        .cornerRadius(6)
                    
                    Text(dueDateText)
                        .font(.caption)
                        .foregroundColor(Color(hex: "#8E8E93"))
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
    
    private var dueDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Due: \(formatter.string(from: assignment.dueDate))"
    }
}

// MARK: - Grade Entry Card
struct GradeEntryCard: View {
    let entry: GradeEntry
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.assignmentName)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text("\(Int(entry.weight * 100))% weight")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#8E8E93"))
                    
                    if let category = entry.category {
                        Text("• \(category)")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#8E8E93"))
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let earned = entry.earnedPoints {
                    Text("\(String(format: "%.1f", earned))/\(String(format: "%.1f", entry.totalPoints))")
                        .font(.headline)
                        .foregroundColor(Color(hex: "#007AFF"))
                    
                    if let percentage = entry.percentageGrade {
                        Text("\(String(format: "%.1f", percentage))%")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#8E8E93"))
                    }
                } else {
                    Text("Not graded")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#8E8E93"))
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}
