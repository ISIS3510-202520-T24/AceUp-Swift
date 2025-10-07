//
//  CreateCourseView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import SwiftUI

struct CreateCourseView: View {
    @ObservedObject var viewModel: CourseViewModel
    @Environment(\.dismiss) private var dismiss
    
    private let semesters = ["Fall", "Spring", "Summer", "Winter"]
    private let courseColors = [
        "#122C4A", "#50E3C2", "#5352ED", "#FF6B6B",
        "#FFE66D", "#4ECDC4", "#FF4757", "#2F80ED",
        "#27AE60", "#8B8680", "#FF9800", "#9C27B0"
    ]
    
    var totalWeight: Double {
        viewModel.newCourseAssignmentsWeight +
        viewModel.newCourseExamsWeight +
        viewModel.newCourseProjectsWeight +
        viewModel.newCourseParticipationWeight +
        viewModel.newCourseOtherWeight
    }
    
    var isWeightValid: Bool {
        abs(totalWeight - 1.0) < 0.001
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    basicInfoSection
                    gradeWeightSection
                    additionalInfoSection
                }
                .padding()
            }
            .navigationTitle("New Course")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        Task {
                            await viewModel.clearForm()
                        }
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.createCourse()
                            dismiss()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !viewModel.newCourseName.isEmpty &&
        !viewModel.newCourseCode.isEmpty &&
        !viewModel.newCourseInstructor.isEmpty &&
        isWeightValid
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundColor(UI.primary)
            
            Text("Create New Course")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            Text("Add a new course to track assignments and grades")
                .font(.subheadline)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Basic Information", icon: "info.circle")
            
            VStack(spacing: 16) {
                CustomTextField(
                    title: "Course Name",
                    text: $viewModel.newCourseName,
                    placeholder: "e.g., Introduction to Computer Science"
                )
                
                CustomTextField(
                    title: "Course Code",
                    text: $viewModel.newCourseCode,
                    placeholder: "e.g., CS101"
                )
                
                CustomTextField(
                    title: "Instructor",
                    text: $viewModel.newCourseInstructor,
                    placeholder: "e.g., Dr. Smith"
                )
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Credits")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(UI.navy)
                        
                        Picker("Credits", selection: $viewModel.newCourseCredits) {
                            ForEach(1...6, id: \.self) { credit in
                                Text("\(credit)").tag(credit)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Semester")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(UI.navy)
                        
                        Picker("Semester", selection: $viewModel.newCourseSemester) {
                            ForEach(semesters, id: \.self) { semester in
                                Text(semester).tag(semester)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Year")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(UI.navy)
                    
                    TextField("Year", value: $viewModel.newCourseYear, format: .number)
                        .textFieldStyle(PlainTextFieldStyle())
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                colorPickerSection
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Course Color")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(UI.navy)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(courseColors, id: \.self) { color in
                    Button(action: {
                        viewModel.newCourseColor = color
                    }) {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .opacity(viewModel.newCourseColor == color ? 1 : 0)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                }
            }
        }
    }
    
    private var gradeWeightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Grade Weights", icon: "percent")
            
            VStack(spacing: 16) {
                WeightSlider(
                    title: "Assignments",
                    value: $viewModel.newCourseAssignmentsWeight,
                    color: .blue
                )
                
                WeightSlider(
                    title: "Exams",
                    value: $viewModel.newCourseExamsWeight,
                    color: .red
                )
                
                WeightSlider(
                    title: "Projects",
                    value: $viewModel.newCourseProjectsWeight,
                    color: .green
                )
                
                WeightSlider(
                    title: "Participation",
                    value: $viewModel.newCourseParticipationWeight,
                    color: .orange
                )
                
                WeightSlider(
                    title: "Other",
                    value: $viewModel.newCourseOtherWeight,
                    color: .purple
                )
                
                Divider()
                
                HStack {
                    Text("Total Weight:")
                        .font(.headline)
                        .foregroundColor(UI.navy)
                    
                    Spacer()
                    
                    Text("\(Int(totalWeight * 100))%")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isWeightValid ? .green : .red)
                }
                
                if !isWeightValid {
                    Text("Grade weights must total 100%")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Additional Information", icon: "target")
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Grade (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(UI.navy)
                    
                    TextField("e.g., 85", value: $viewModel.newCourseTargetGrade, format: .number)
                        .textFieldStyle(PlainTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(UI.primary)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)
        }
    }
}

struct WeightSlider: View {
    let title: String
    @Binding var value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Text("\(Int(value * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            Slider(value: $value, in: 0...1, step: 0.05)
                .accentColor(color)
        }
    }
}

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(UI.navy)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
        }
    }
}

struct EditCourseView: View {
    let course: Course
    let onSave: (Course) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var code: String
    @State private var instructor: String
    @State private var credits: Int
    @State private var semester: String
    @State private var year: Int
    @State private var color: String
    @State private var targetGrade: Double?
    @State private var currentGrade: Double?
    
    private let semesters = ["Fall", "Spring", "Summer", "Winter"]
    
    init(course: Course, onSave: @escaping (Course) -> Void) {
        self.course = course
        self.onSave = onSave
        
        _name = State(initialValue: course.name)
        _code = State(initialValue: course.code)
        _instructor = State(initialValue: course.instructor)
        _credits = State(initialValue: course.credits)
        _semester = State(initialValue: course.semester)
        _year = State(initialValue: course.year)
        _color = State(initialValue: course.color)
        _targetGrade = State(initialValue: course.targetGrade)
        _currentGrade = State(initialValue: course.currentGrade)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    CustomTextField(title: "Course Name", text: $name, placeholder: "Course Name")
                    CustomTextField(title: "Course Code", text: $code, placeholder: "Course Code")
                    CustomTextField(title: "Instructor", text: $instructor, placeholder: "Instructor")
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Credits")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("Credits", selection: $credits) {
                                ForEach(1...6, id: \.self) { credit in
                                    Text("\(credit)").tag(credit)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Semester")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("Semester", selection: $semester) {
                                ForEach(semesters, id: \.self) { sem in
                                    Text(sem).tag(sem)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Grade")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Current Grade", value: $currentGrade, format: .number)
                            .textFieldStyle(PlainTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCourse()
                    }
                }
            }
        }
    }
    
    private func saveCourse() {
        let updatedCourse = Course(
            id: course.id,
            name: name,
            code: code,
            credits: credits,
            instructor: instructor,
            color: color,
            semester: semester,
            year: year,
            gradeWeight: course.gradeWeight,
            currentGrade: currentGrade,
            targetGrade: targetGrade,
            createdAt: course.createdAt,
            updatedAt: Date()
        )
        
        onSave(updatedCourse)
        dismiss()
    }
}

#if DEBUG
struct CreateCourseView_Previews: PreviewProvider {
    static var previews: some View {
        CreateCourseView(viewModel: CourseViewModel())
    }
}
#endif