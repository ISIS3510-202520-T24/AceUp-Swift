import SwiftUI

struct SubjectListView: View {
    
    @StateObject private var viewModel: SubjectViewModel
    @State private var showCreateSheet = false
    @State private var showEditSheet = false
    @State private var subjectToDelete: Subject?
    @State private var showDeleteAlert = false
    
    let semesterName: String
    
    init(semesterId: String, semesterName: String) {
        self.semesterName = semesterName
        _viewModel = StateObject(wrappedValue: SubjectViewModel(semesterId: semesterId))
    }
    
    var body: some View {
        ZStack {
            Color(hex: "#F5F7FA")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                statisticsHeader
                
                if viewModel.isLoading && viewModel.subjects.isEmpty {
                    ProgressView()
                        .padding(.top, 50)
                } else if viewModel.subjects.isEmpty {
                    emptyState
                } else {
                    subjectsList
                }
            }
        }
        .navigationTitle(semesterName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.resetForm()
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: "#007AFF"))
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateSubjectView(viewModel: viewModel, isPresented: $showCreateSheet)
        }
        .sheet(isPresented: $showEditSheet) {
            EditSubjectView(viewModel: viewModel, isPresented: $showEditSheet)
        }
        .alert("Delete Subject", isPresented: $showDeleteAlert, presenting: subjectToDelete) { subject in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteSubject(subject)
                }
            }
        } message: { subject in
            Text("Are you sure you want to delete \(subject.name)?")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .task {
            await viewModel.loadSubjects()
        }
    }
    
    private var statisticsHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                SubjectStatCard(
                    icon: "books.vertical.fill",
                    title: "Subjects",
                    value: "\(viewModel.statistics.totalSubjects)",
                    color: "#007AFF"
                )
                
                SubjectStatCard(
                    icon: "number.circle.fill",
                    title: "Credits",
                    value: String(format: "%.0f", viewModel.statistics.totalCredits),
                    color: "#34C759"
                )
                
                SubjectStatCard(
                    icon: "chart.bar.fill",
                    title: "Avg Grade",
                    value: String(format: "%.1f", viewModel.statistics.averageGrade),
                    color: "#FF9500"
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .background(Color.white)
    }
    
    private var subjectsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.subjects) { subject in
                    SubjectCard(
                        subject: subject,
                        onEdit: {
                            viewModel.prepareForEdit(subject)
                            showEditSheet = true
                        },
                        onDelete: {
                            subjectToDelete = subject
                            showDeleteAlert = true
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#C7C7CC"))
            
            Text("No Subjects Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "#1C1C1E"))
            
            Text("Add your first subject to get started")
                .font(.body)
                .foregroundColor(Color(hex: "#8E8E93"))
            
            Button {
                viewModel.resetForm()
                showCreateSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Subject")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(hex: "#007AFF"))
                .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Subject Stat Card
struct SubjectStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(hex: color))
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#1C1C1E"))
            
            Text(title)
                .font(.caption)
                .foregroundColor(Color(hex: "#8E8E93"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(hex: "#F5F7FA"))
        .cornerRadius(12)
    }
}

// MARK: - Subject Card
struct SubjectCard: View {
    let subject: Subject
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color(hex: subject.color))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.name)
                        .font(.headline)
                        .foregroundColor(Color(hex: "#1C1C1E"))
                    
                    Text(subject.code)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#8E8E93"))
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "number.circle.fill")
                        .font(.caption)
                    Text("\(Int(subject.credits))")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "#007AFF"))
                .cornerRadius(8)
            }
            
            if let instructor = subject.instructor {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#8E8E93"))
                    Text(instructor)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#3A3A3C"))
                }
            }
            
            if let currentGrade = subject.currentGrade {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                    Text("Grade: \(String(format: "%.1f", currentGrade))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color(hex: gradeColor(currentGrade)))
            }
            
            Divider()
            
            HStack(spacing: 12) {
                Button {
                    onEdit()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#007AFF"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#007AFF").opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button {
                    onDelete()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#FF3B30"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#FF3B30").opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func gradeColor(_ grade: Double) -> String {
        if grade >= 4.0 { return "#34C759" }
        if grade >= 3.0 { return "#FF9500" }
        return "#FF3B30"
    }
}

// MARK: - Create Subject View
struct CreateSubjectView: View {
    @ObservedObject var viewModel: SubjectViewModel
    @Binding var isPresented: Bool
    
    let availableColors = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#5856D6", "#AF52DE", "#FF2D55", "#5AC8FA"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Subject Information") {
                    TextField("Name", text: $viewModel.formName)
                    TextField("Code", text: $viewModel.formCode)
                    TextField("Credits", text: $viewModel.formCredits)
                        .keyboardType(.numberPad)
                }
                
                Section("Instructor") {
                    TextField("Instructor Name (Optional)", text: $viewModel.formInstructor)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(availableColors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: "#007AFF"), lineWidth: viewModel.formColor == color ? 3 : 0)
                                )
                                .onTapGesture {
                                    viewModel.formColor = color
                                }
                        }
                    }
                }
            }
            .navigationTitle("New Subject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await viewModel.createSubject()
                            if !viewModel.showError {
                                isPresented = false
                            }
                        }
                    }
                    .disabled(!viewModel.isFormValid)
                }
            }
        }
    }
}

// MARK: - Edit Subject View
struct EditSubjectView: View {
    @ObservedObject var viewModel: SubjectViewModel
    @Binding var isPresented: Bool
    
    let availableColors = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#5856D6", "#AF52DE", "#FF2D55", "#5AC8FA"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Subject Information") {
                    TextField("Name", text: $viewModel.formName)
                    TextField("Code", text: $viewModel.formCode)
                    TextField("Credits", text: $viewModel.formCredits)
                        .keyboardType(.numberPad)
                }
                
                Section("Instructor") {
                    TextField("Instructor Name (Optional)", text: $viewModel.formInstructor)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(availableColors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: "#007AFF"), lineWidth: viewModel.formColor == color ? 3 : 0)
                                )
                                .onTapGesture {
                                    viewModel.formColor = color
                                }
                        }
                    }
                }
            }
            .navigationTitle("Edit Subject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.updateSubject()
                            if !viewModel.showError {
                                isPresented = false
                            }
                        }
                    }
                    .disabled(!viewModel.isFormValid)
                }
            }
        }
    }
}
