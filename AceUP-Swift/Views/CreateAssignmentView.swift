//
//  CreateAssignmentView.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 4/10/25.
//

import SwiftUI

struct CreateAssignmentView: View {
    @ObservedObject var viewModel: AssignmentViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAdvancedOptions = false
    
    var body: some View {
        NavigationView {
            Form {
                basicInfoSection
                
                if showingAdvancedOptions {
                    advancedOptionsSection
                }
                
                Section {
                    Button(action: { showingAdvancedOptions.toggle() }) {
                        HStack {
                            Text(showingAdvancedOptions ? "Hide Advanced Options" : "Show Advanced Options")
                            Spacer()
                            Image(systemName: showingAdvancedOptions ? "chevron.up" : "chevron.down")
                        }
                        .foregroundColor(UI.primary)
                    }
                }
            }
            .navigationTitle("New Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.clearForm()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.createAssignment()
                            if !viewModel.showingCreateAssignment {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Form Sections
    
    private var basicInfoSection: some View {
        Section("Assignment Details") {
            TextField("Assignment Title", text: $viewModel.newAssignmentTitle)
                .textInputAutocapitalization(.words)
            
            TextField("Course Name", text: $viewModel.newAssignmentCourse)
                .textInputAutocapitalization(.words)
            
            DatePicker(
                "Due Date",
                selection: $viewModel.newAssignmentDueDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            
            HStack {
                Text("Weight")
                Spacer()
                Text("\(Int(viewModel.newAssignmentWeight * 100))%")
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: $viewModel.newAssignmentWeight,
                in: 0.01...1.0,
                step: 0.01
            )
            
            Picker("Type", selection: $viewModel.newAssignmentType){
                ForEach(EventType.allCases, id: \.self) {
                    type in
                    HStack {
                        Circle()
                            .frame(width: 8, height: 8)
                        Text(type.displayName)
                    }
                    .tag(type)
                }
            }
            
            
            
            Picker("Priority", selection: $viewModel.newAssignmentPriority) {
                ForEach(Priority.allCases, id: \.self) { priority in
                    HStack {
                        Circle()
                            .fill(Color(hex: priority.color))
                            .frame(width: 8, height: 8)
                        Text(priority.displayName)
                    }
                    .tag(priority)
                }
            }
        }
    }
    
    private var advancedOptionsSection: some View {
        Group {
            Section("Additional Information") {
                TextField("Description (optional)", text: $viewModel.newAssignmentDescription, axis: .vertical)
                    .lineLimit(3...6)
                
                HStack {
                    Text("Estimated Hours")
                    Spacer()
                    if let hours = viewModel.newAssignmentEstimatedHours {
                        Text("\(hours, specifier: "%.1f")h")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Not set")
                            .foregroundColor(.secondary)
                    }
                }
                
                if viewModel.newAssignmentEstimatedHours != nil {
                    Slider(
                        value: Binding(
                            get: { viewModel.newAssignmentEstimatedHours ?? 1.0 },
                            set: { viewModel.newAssignmentEstimatedHours = $0 }
                        ),
                        in: 0.5...40.0,
                        step: 0.5
                    )
                } else {
                    Button("Set Estimated Hours") {
                        viewModel.newAssignmentEstimatedHours = 2.0
                    }
                    .foregroundColor(UI.primary)
                }
            }
            
            Section("Tags") {
                TagInputView(tags: $viewModel.newAssignmentTags)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !viewModel.newAssignmentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.newAssignmentCourse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct TagInputView: View {
    @Binding var tags: [String]
    @State private var newTag = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Existing tags
            if !tags.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 60, maximum: 120), spacing: 8)
                ], spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(
                            text: tag,
                            onRemove: {
                                tags.removeAll { $0 == tag }
                            }
                        )
                    }
                }
            }
            
            // Add new tag
            HStack {
                TextField("Add tag", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        addTag()
                    }
                
                Button("Add", action: addTag)
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
}

struct TagChip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .foregroundColor(UI.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(UI.primary.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    CreateAssignmentView(viewModel: AssignmentViewModel())
}
