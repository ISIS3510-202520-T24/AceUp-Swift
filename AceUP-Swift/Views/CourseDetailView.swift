import SwiftUI

@MainActor
struct CourseDetailView: View {
    let course: CourseInfo
    @Environment(\.dismiss) private var dismiss
    
    // aqui traeremos las tareas de esta materia
    @State private var assignments: [Assignment] = []
    @State private var isLoadingAssignments = false
    
    // repository inicializado de forma lazy
    @State private var assignmentRepo: AssignmentRepositoryProtocol?
    
    // grades local store para persistencia
    private let gradesStore = GradesLocalStore.shared
    
    // tab seleccionado
    @State private var selectedTab: CourseTab = .schedule
    
    // para navegar a detalle de assignment
    @State private var selectedAssignment: Assignment?
    
    // para el calculador de notas (ahora se persiste en JSON)
    @State private var gradeItems: [GradeItem] = []
    @State private var showAddGrade = false
    
    init(course: CourseInfo) {
        self.course = course
        // Inicialización lazy del repository - se obtiene en task
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            UI.neutralLight
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                tabButtons
                
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .schedule:
                            timetableSection
                        case .assignments:
                            assignmentsSection
                        case .grades:
                            gradesSection
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadAssignments()
            await loadGrades()
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(UI.navy)
            }
            
            Text(course.name)
                .font(.title2.bold())
                .foregroundColor(UI.navy)
            
            Spacer()
        }
        .padding()
        .background(Color.white)
    }
    
    private var tabButtons: some View {
        HStack(spacing: 0) {
            CourseTabButton(title: "Schedule", isSelected: selectedTab == .schedule) {
                selectedTab = .schedule
            }
            
            CourseTabButton(title: "Assignments", isSelected: selectedTab == .assignments) {
                selectedTab = .assignments
            }
            
            CourseTabButton(title: "Grades", isSelected: selectedTab == .grades) {
                selectedTab = .grades
            }
        }
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
    
    private func loadAssignments() async {
        // Inicializar repository si no existe
        if assignmentRepo == nil {
            let provider = await Task.detached {
                await DataSynchronizationManager.shared.getAssignmentProvider()
            }.value
            assignmentRepo = AssignmentRepository(dataProvider: provider)
        }
        
        guard let repo = assignmentRepo else {
            print("Assignment repository not available")
            return
        }
        
        isLoadingAssignments = true
        defer { isLoadingAssignments = false }
        
        do {
            let allAssignments = try await repo.getAllAssignments()
            assignments = allAssignments.filter { $0.courseName == course.name }
        } catch {
            print("Error loading assignments: \(error)")
        }
    }
    
    /// Carga las notas guardadas del curso
    private func loadGrades() async {
        do {
            if let savedGrades = try await gradesStore.load(for: course.id) {
                gradeItems = savedGrades
            }
        } catch {
            print("Error loading grades: \(error)")
        }
    }
    
    /// Guarda las notas actuales del curso
    private func saveGrades() async {
        do {
            try await gradesStore.save(gradeItems, for: course.id)
        } catch {
            print("Error saving grades: \(error)")
        }
    }
    
    private var timetableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 8) {
                ForEach(course.sessions.sorted(by: { a, b in
                    // ordenamos por dia de la semana
                    let weekdays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
                    guard let indexA = weekdays.firstIndex(of: a.weekday),
                          let indexB = weekdays.firstIndex(of: b.weekday) else {
                        return false
                    }
                    return indexA < indexB
                })) { session in
                    HStack {
                        // dia
                        Text(session.weekday.display)
                            .font(.body.bold())
                            .foregroundColor(UI.navy)
                            .frame(width: 100, alignment: .leading)
                        
                        // hora
                        Text("\(session.start) - \(session.end)")
                            .font(.body)
                            .foregroundColor(UI.navy)
                        
                        Spacer()
                        
                        // salon
                        if let location = session.location, !location.isEmpty {
                            Text(location)
                                .font(.body)
                                .foregroundColor(UI.muted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.7))
                                .cornerRadius(6)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var assignmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoadingAssignments {
                ProgressView()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(8)
            } else if assignments.isEmpty {
                Text("No assignments for this class yet")
                    .font(.body)
                    .foregroundColor(UI.muted)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(assignments) { assignment in
                        AssignmentRow(assignment: assignment)
                            .onTapGesture {
                                selectedAssignment = assignment
                            }
                    }
                }
            }
        }
        .sheet(item: $selectedAssignment) { assignment in
            AssignmentsListView()
        }
    }
    
    private var gradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // mostrar nota calculada
            if !gradeItems.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("Current Grade")
                            .font(.headline)
                            .foregroundColor(UI.navy)
                        
                        Spacer()
                        
                        Text(String(format: "%.2f", calculateCurrentGrade()))
                            .font(.title.bold())
                            .foregroundColor(UI.primary)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    
                    HStack {
                        Text("Weighted")
                            .font(.caption)
                            .foregroundColor(UI.muted)
                        
                        Spacer()
                        
                        Text("\(Int(totalWeightUsed()))% of grade")
                            .font(.caption)
                            .foregroundColor(UI.muted)
                    }
                    .padding(.horizontal)
                }
            }
            
            // lista de items de nota
            ForEach(gradeItems.indices, id: \.self) { index in
                GradeItemRow(item: gradeItems[index]) {
                    gradeItems.remove(at: index)
                    Task {
                        await saveGrades()
                    }
                }
            }
            
            // boton para agregar item
            Button {
                showAddGrade = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add grade item")
                }
                .font(.subheadline.bold())
                .foregroundColor(UI.primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showAddGrade) {
            AddGradeItemView { newItem in
                gradeItems.append(newItem)
                Task {
                    await saveGrades()
                }
            }
        }
    }
    
    private func calculateCurrentGrade() -> Double {
        let totalWeight = gradeItems.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else { return 0.0 }
        
        let weightedSum = gradeItems.reduce(0.0) { sum, item in
            sum + (item.grade * item.weight / 100.0)
        }
        
        return (weightedSum / totalWeight) * 100.0
    }
    
    private func totalWeightUsed() -> Double {
        gradeItems.reduce(0.0) { $0 + $1.weight }
    }
}

// enum para los tabs
enum CourseTab {
    case schedule, assignments, grades
}

// boton de tab personalizado
struct CourseTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? UI.primary : UI.muted)
                
                Rectangle()
                    .fill(isSelected ? UI.primary : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

// modelo para calcular notas - ahora se persiste en JSON
struct GradeItem: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let weight: Double  // porcentaje del 100
    let grade: Double   // nota obtenida
    
    init(id: UUID = UUID(), name: String, weight: Double, grade: Double) {
        self.id = id
        self.name = name
        self.weight = weight
        self.grade = grade
    }
}

// fila de item de nota
struct GradeItemRow: View {
    let item: GradeItem
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body.bold())
                    .foregroundColor(UI.navy)
                
                Text("\(Int(item.weight))% of grade")
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
            
            Spacer()
            
            Text(String(format: "%.1f", item.grade))
                .font(.title3.bold())
                .foregroundColor(UI.primary)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .padding(.leading, 8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
}

// vista para agregar item de nota
struct AddGradeItemView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (GradeItem) -> Void
    
    @State private var name = ""
    @State private var weight = ""
    @State private var grade = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item details") {
                    TextField("Name (e.g., Midterm 1)", text: $name)
                    TextField("Weight % (e.g., 30)", text: $weight)
                        .keyboardType(.decimalPad)
                        .onChange(of: weight) { newValue in
                            // Reemplazar coma por punto para decimales
                            weight = newValue.replacingOccurrences(of: ",", with: ".")
                        }
                    TextField("Grade (e.g., 4.5)", text: $grade)
                        .keyboardType(.decimalPad)
                        .onChange(of: grade) { newValue in
                            // Reemplazar coma por punto para decimales
                            grade = newValue.replacingOccurrences(of: ",", with: ".")
                        }
                }
            }
            .navigationTitle("Add Grade Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let w = Double(weight), let g = Double(grade), !name.isEmpty else {
                            return
                        }
                        let item = GradeItem(name: name, weight: w, grade: g)
                        onAdd(item)
                        dismiss()
                    }
                    .disabled(name.isEmpty || weight.isEmpty || grade.isEmpty)
                }
            }
        }
    }
}

// fila simple de assignment
struct AssignmentRow: View {
    let assignment: Assignment
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.body.bold())
                    .foregroundColor(UI.navy)
                
                Text(assignment.formattedDueDate)
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
            
            Spacer()
            
            // estado
            Image(systemName: assignment.status.icon)
                .foregroundColor(Color(hex: assignment.status.color))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
}
