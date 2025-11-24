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
            
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.semesters.isEmpty {
                    loadingView
                } else if viewModel.semesters.isEmpty {
                    emptyStateView
                } else {
                    semestersList
                }
            }
        }
        .navigationTitle("Semesters")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { 
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleSidebar"), object: nil)
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(Color(hex: "#122C4A"))
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCreateSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: "#4ECDC4"))
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
            Text("Are you sure you want to delete \(semester.name)? This action cannot be undone.")
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
    
    // MARK: - Semesters List
    
    private var semestersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
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
            .padding()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#4ECDC4")))
                .scaleEffect(1.5)
            
            Text("Loading semesters...")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#8B8680"))
                .padding(.top)
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 80))
                .foregroundColor(Color(hex: "#B8C8DB"))
            
            Text("No Semesters Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#122C4A"))
            
            Text("Create your first semester to start organizing your academic journey")
                .font(.body)
                .foregroundColor(Color(hex: "#8B8680"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showCreateSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Semester")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color(hex: "#4ECDC4"))
                .cornerRadius(12)
            }
            .padding(.top)
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
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: semester.type.icon)
                        .font(.title)
                        .foregroundColor(Color(hex: "#4ECDC4"))
                        .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(semester.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "#122C4A"))
                        
                        Text("\(semester.credits) credits")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "#8B8680"))
                    }
                }
                
                Spacer()
                
                if isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("Active")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(Color(hex: "#4ECDC4"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#4ECDC4").opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Dates
            HStack(spacing: 20) {
                dateInfo(icon: "calendar", label: "Start", date: semester.startDate)
                dateInfo(icon: "calendar.badge.checkmark", label: "End", date: semester.endDate)
            }
            .font(.subheadline)
            .foregroundColor(Color(hex: "#8B8680"))
            
            // GPA info
            if let gpa = semester.actualGPA ?? semester.targetGPA {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(Color(hex: "#4ECDC4"))
                    
                    Text(semester.actualGPA != nil ? "GPA: \(String(format: "%.2f", gpa))" : "Target: \(String(format: "%.2f", gpa))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "#122C4A"))
                }
            }
            
            // Actions
            HStack(spacing: 12) {
                if !isActive {
                    actionButton(icon: "star.fill", title: "Set Active", color: Color(hex: "#FFE66D")) {
                        onSetActive()
                    }
                }
                
                actionButton(icon: "pencil", title: "Edit", color: Color(hex: "#4ECDC4")) {
                    onEdit()
                }
                
                actionButton(icon: "trash", title: "Delete", color: Color(hex: "#FF6B6B")) {
                    onDelete()
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
    
    private func dateInfo(icon: String, label: String, date: Date) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text("\(label): \(formatDate(date))")
        }
    }
    
    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Create Semester Sheet
struct CreateSemesterView: View {
    @ObservedObject var viewModel: SemesterViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Semester Name", text: $viewModel.formName)
                    
                    Picker("Type", selection: $viewModel.formType) {
                        ForEach(SemesterType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
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
                
                Section("Dates") {
                    DatePicker("Start Date", selection: $viewModel.formStartDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $viewModel.formEndDate, displayedComponents: .date)
                }
                
                Section("Academic Goals") {
                    TextField("Credits", text: $viewModel.formCredits)
                        .keyboardType(.numberPad)
                    
                    TextField("Target GPA (Optional)", text: $viewModel.formTargetGPA)
                        .keyboardType(.decimalPad)
                }
                
                Section("Notes") {
                    TextEditor(text: $viewModel.formNotes)
                        .frame(minHeight: 100)
                }
            }
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
                    .fontWeight(.bold)
                    .disabled(viewModel.formName.isEmpty)
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
            Form {
                Section("Basic Information") {
                    TextField("Semester Name", text: $viewModel.formName)
                    
                    HStack {
                        Text("Type")
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.formType.icon)
                            Text(viewModel.formType.displayName)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Year")
                        Spacer()
                        Text(String(viewModel.formYear))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Dates") {
                    DatePicker("Start Date", selection: $viewModel.formStartDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $viewModel.formEndDate, displayedComponents: .date)
                }
                
                Section("Academic Goals") {
                    TextField("Credits", text: $viewModel.formCredits)
                        .keyboardType(.numberPad)
                    
                    TextField("Target GPA", text: $viewModel.formTargetGPA)
                        .keyboardType(.decimalPad)
                }
                
                Section("Notes") {
                    TextEditor(text: $viewModel.formNotes)
                        .frame(minHeight: 100)
                }
            }
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
                    .fontWeight(.bold)
                    .disabled(viewModel.formName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SemesterListView()
    }
}
