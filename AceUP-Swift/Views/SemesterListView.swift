import SwiftUI

// MARK: - Semester List View
struct SemesterListView: View {
    
    @StateObject private var viewModel = SemesterViewModel()
    @State private var showCreateSheet = false
    @State private var showEditSheet = false
    @State private var semesterToDelete: Semester?
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack {
            Color(hex: "#F5F7FA")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.semesters.isEmpty && !viewModel.isLoading {
                        emptyStateView
                    } else {
                        semesterCardsView
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Semesters")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCreateSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: "#4ECDC4") ?? Color.blue)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateSemesterView(viewModel: viewModel, isPresented: $showCreateSheet)
        }
        .sheet(isPresented: $showEditSheet) {
            EditSemesterView(viewModel: viewModel, isPresented: $showEditSheet)
        }
        .alert("Delete Semester", isPresented: $showDeleteAlert, presenting: semesterToDelete) { semester in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteSemester(semester)
                }
            }
        } message: { semester in
            Text("Are you sure you want to delete \(semester.name)?")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .task {
            await viewModel.loadSemesters()
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#8B8680") ?? Color.gray)
            
            Text("No Semesters Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "#122C4A") ?? Color.blue)
            
            Text("Create your first semester to start planning")
                .font(.body)
                .foregroundColor(Color(hex: "#8B8680") ?? Color.gray)
                .multilineTextAlignment(.center)
            
            Button(action: { showCreateSheet = true }) {
                Text("Create Semester")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#4ECDC4") ?? Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding(.top, 100)
    }
    
    // MARK: - Semester Cards
    private var semesterCardsView: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.semesters) { semester in
                SemesterCard(
                    semester: semester,
                    isActive: semester.id == viewModel.activeSemester?.id,
                    onEdit: {
                        viewModel.prepareForEdit(semester)
                        showEditSheet = true
                    },
                    onDelete: {
                        semesterToDelete = semester
                        showDeleteAlert = true
                    },
                    onSetActive: {
                        Task {
                            await viewModel.setActiveSemester(semester)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Semester Card Component
struct SemesterCard: View {
    let semester: Semester
    let isActive: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSetActive: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(semester.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#122C4A") ?? Color.blue)
                    
                    Text(semester.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#8B8680") ?? Color.gray)
                }
                
                Spacer()
                
                if isActive {
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#4ECDC4") ?? Color.blue)
                        .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Info Grid
            HStack(spacing: 20) {
                infoItem(title: "Year", value: String(semester.year))
                infoItem(title: "Credits", value: String(semester.credits))
                if let gpa = semester.actualGPA {
                    infoItem(title: "GPA", value: String(format: "%.2f", gpa))
                }
            }
            
            // Dates
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(Color(hex: "#8B8680") ?? Color.gray)
                    .font(.caption)
                Text(dateRangeString)
                    .font(.caption)
                    .foregroundColor(Color(hex: "#8B8680") ?? Color.gray)
            }
            
            // Actions
            HStack(spacing: 12) {
                if !isActive {
                    Button(action: onSetActive) {
                        Text("Set Active")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "#4ECDC4") ?? Color.blue)
                    }
                }
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(Color(hex: "#122C4A") ?? Color.blue)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func infoItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(Color(hex: "#8B8680") ?? Color.gray)
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "#122C4A") ?? Color.blue)
        }
    }
    
    private var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: semester.startDate)) - \(formatter.string(from: semester.endDate))"
    }
}

// MARK: - Create Semester Sheet
struct CreateSemesterView: View {
    @ObservedObject var viewModel: SemesterViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            SemesterFormView(viewModel: viewModel, isEditing: false)
                .navigationTitle("New Semester")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            viewModel.resetForm()
                            isPresented = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Create") {
                            Task {
                                await viewModel.createSemester()
                                isPresented = false
                            }
                        }
                        .disabled(viewModel.formName.isEmpty && viewModel.formType == .fall)
                    }
                }
        }
    }
}

// MARK: - Edit Semester Sheet
struct EditSemesterView: View {
    @ObservedObject var viewModel: SemesterViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            SemesterFormView(viewModel: viewModel, isEditing: true)
                .navigationTitle("Edit Semester")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            viewModel.resetForm()
                            isPresented = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            Task {
                                if let semester = viewModel.editingSemester {
                                    await viewModel.updateSemester(semester)
                                }
                                isPresented = false
                            }
                        }
                    }
                }
        }
    }
}

// MARK: - Semester Form
struct SemesterFormView: View {
    @ObservedObject var viewModel: SemesterViewModel
    let isEditing: Bool
    
    var body: some View {
        Form {
            Section(header: Text("Basic Information")) {
                TextField("Name (optional)", text: $viewModel.formName)
                
                Picker("Type", selection: $viewModel.formType) {
                    ForEach(SemesterType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .onChange(of: viewModel.formType) { newValue in
                    viewModel.updateDatesForType(newValue, year: viewModel.formYear)
                }
                
                Stepper("Year: \(viewModel.formYear)", value: $viewModel.formYear, in: 2020...2030)
                    .onChange(of: viewModel.formYear) { newValue in
                        viewModel.updateDatesForType(viewModel.formType, year: newValue)
                    }
            }
            
            Section(header: Text("Dates")) {
                DatePicker("Start Date", selection: $viewModel.formStartDate, displayedComponents: .date)
                DatePicker("End Date", selection: $viewModel.formEndDate, displayedComponents: .date)
            }
            
            Section(header: Text("Academic Goals")) {
                TextField("Target GPA (optional)", text: $viewModel.formTargetGPA)
                    .keyboardType(.decimalPad)
                
                TextField("Credits", text: $viewModel.formCredits)
                    .keyboardType(.numberPad)
            }
            
            Section(header: Text("Notes")) {
                TextEditor(text: $viewModel.formNotes)
                    .frame(minHeight: 100)
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    SemesterListView()
}
