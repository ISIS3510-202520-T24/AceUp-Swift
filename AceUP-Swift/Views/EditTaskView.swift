//
//  EditTaskView.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 4/10/25.
//


import SwiftUI

struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaskViewModel
    let assignment: Assignment
    
    @State private var title: String
    @State private var subject: String
    @State private var type: String
    @State private var dueDate: Date
    @State private var priority: String
    @State private var estimatedHours: Int
    
    let subjects = ["Mathematics", "Physics", "Computer Science", "Chemistry", "Biology", "History", "Literature"]
    let types = ["Homework", "Project", "Exam", "Quiz", "Lab", "Essay"]
    let priorities = ["Low", "Medium", "High"]
    
    init(viewModel: TaskViewModel, assignment: Assignment) {
        self.viewModel = viewModel
        self.assignment = assignment
        _title = State(initialValue: assignment.title)
        _subject = State(initialValue: assignment.subject)
        _type = State(initialValue: assignment.type)
        _dueDate = State(initialValue: assignment.dueDate ?? Date())
        _priority = State(initialValue: assignment.priority)
        _estimatedHours = State(initialValue: assignment.estimatedHours)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)
                    
                    Picker("Subject", selection: $subject) {
                        ForEach(subjects, id: \.self) { subject in
                            Text(subject).tag(subject)
                        }
                    }
                    
                    Picker("Type", selection: $type) {
                        ForEach(types, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(priorities, id: \.self) { priority in
                            Text(priority).tag(priority)
                        }
                    }
                    
                    Stepper("Estimated Hours: \(estimatedHours)", value: $estimatedHours, in: 1...20)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        viewModel.updateAssignment(
            assignment,
            title: title,
            subject: subject,
            type: type,
            dueDate: dueDate,
            priority: priority,
            estimatedHours: estimatedHours
        )
        dismiss()
    }
}
