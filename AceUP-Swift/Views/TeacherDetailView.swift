//
//  TeacherDetailView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/12/25.
//

import SwiftUI

struct TeacherDetailView: View {
    let teacher: Teacher
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Card
                headerCard
                
                // Contact Information
                if hasContactInfo {
                    contactInfoCard
                }
                
                // Office Information
                if hasOfficeInfo {
                    officeInfoCard
                }
                
                // Linked Courses
                if !teacher.linkedCourseIds.isEmpty {
                    linkedCoursesCard
                }
                
                // Notes
                if let notes = teacher.notes, !notes.isEmpty {
                    notesCard(notes)
                }
                
                // Metadata
                metadataCard
            }
            .padding(16)
        }
        .navigationTitle(teacher.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: { showDeleteAlert = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Teacher", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \(teacher.name)? This action cannot be undone.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasContactInfo: Bool {
        teacher.email != nil || teacher.phoneNumber != nil
    }
    
    private var hasOfficeInfo: Bool {
        teacher.officeLocation != nil || teacher.officeHours != nil
    }
    
    // MARK: - Card Views
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(UI.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(teacher.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let department = teacher.department {
                        Text(department)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var contactInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contact Information")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let email = teacher.email {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(UI.primary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(email)
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    Link(destination: URL(string: "mailto:\(email)")!) {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(UI.primary)
                    }
                }
            }
            
            if let phone = teacher.phoneNumber {
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(UI.primary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Phone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(phone)
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    if let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                        Link(destination: url) {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(UI.primary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var officeInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Office Information")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let location = teacher.officeLocation {
                HStack(alignment: .top) {
                    Image(systemName: "location.fill")
                        .foregroundColor(UI.primary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.body)
                    }
                }
            }
            
            if let hours = teacher.officeHours {
                HStack(alignment: .top) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(UI.primary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Office Hours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(hours)
                            .font(.body)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var linkedCoursesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Linked Courses")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("\(teacher.linkedCourseIds.count) course(s) linked to this teacher")
                .font(.body)
                .foregroundColor(.secondary)
            
            // In a real app, you'd fetch and display actual course names
            ForEach(teacher.linkedCourseIds, id: \.self) { courseId in
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(UI.primary)
                    Text(courseId)
                        .font(.body)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(notes)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Text("Created")
                    .foregroundColor(.secondary)
                Spacer()
                Text(teacher.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            
            HStack {
                Text("Last Updated")
                    .foregroundColor(.secondary)
                Spacer()
                Text(teacher.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        TeacherDetailView(
            teacher: Teacher.sampleTeachers[0],
            onEdit: {},
            onDelete: {}
        )
    }
}
