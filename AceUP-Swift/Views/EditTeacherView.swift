//
//  EditTeacherView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/12/25.
//

import SwiftUI

struct EditTeacherView: View {
    @ObservedObject var viewModel: TeacherViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAdvancedOptions = false
    
    var body: some View {
        NavigationView {
            Form {
                basicInfoSection
                
                contactInfoSection
                
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
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Teacher")
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
                            await viewModel.updateTeacher()
                            if !viewModel.showingEditTeacher {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isLoading)
                    .fontWeight(.semibold)
                }
            }
            .disabled(viewModel.isLoading)
        }
    }
    
    // MARK: - Form Sections
    
    private var basicInfoSection: some View {
        Section(header: Text("Basic Information")) {
            TextField("Name *", text: $viewModel.teacherName)
                .textContentType(.name)
                .autocapitalization(.words)
            
            TextField("Department", text: $viewModel.teacherDepartment)
                .autocapitalization(.words)
        }
    }
    
    private var contactInfoSection: some View {
        Section(header: Text("Contact Information")) {
            TextField("Email", text: $viewModel.teacherEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            
            TextField("Phone", text: $viewModel.teacherPhone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
        }
    }
    
    private var advancedOptionsSection: some View {
        Group {
            Section(header: Text("Office Information")) {
                TextField("Office Location", text: $viewModel.teacherOfficeLocation)
                    .autocapitalization(.words)
                
                TextField("Office Hours", text: $viewModel.teacherOfficeHours)
                    .placeholder("e.g., Mon/Wed 2-4 PM")
            }
            
            Section(header: Text("Notes")) {
                TextEditor(text: $viewModel.teacherNotes)
                    .frame(minHeight: 100)
                    .overlay(
                        Group {
                            if viewModel.teacherNotes.isEmpty {
                                Text("Add personal notes about this teacher...")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
            }
            
            if let teacher = viewModel.selectedTeacher {
                Section(header: Text("Metadata")) {
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(teacher.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(teacher.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    EditTeacherView(viewModel: TeacherViewModel())
}
