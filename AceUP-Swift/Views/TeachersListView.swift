//
//  TeachersListView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/12/25.
//

import SwiftUI

/// Main teachers list view with search and management capabilities
struct TeachersListView: View {
    let onMenuTapped: () -> Void
    @StateObject private var viewModel = TeacherViewModel()
    @State private var showDeleteAlert = false
    @State private var teacherToDelete: Teacher?
    
    init(onMenuTapped: @escaping () -> Void = {}) {
        self.onMenuTapped = onMenuTapped
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                headerView(geometry: geometry)
                
                // Search Bar
                searchBarView(geometry: geometry)
                
                // Sync Status
                if viewModel.isSyncing {
                    syncStatusView(geometry: geometry)
                }
                
                // Teacher List
                teacherListView(geometry: geometry)
            }
            .navigationBarHidden(true)
            .overlay(fabButton(geometry: geometry), alignment: .bottomTrailing)
            .sheet(isPresented: $viewModel.showingCreateTeacher) {
                CreateTeacherView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingEditTeacher) {
                if viewModel.selectedTeacher != nil {
                    EditTeacherView(viewModel: viewModel)
                }
            }
            .alert("Delete Teacher", isPresented: $showDeleteAlert, presenting: teacherToDelete) { teacher in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteTeacher(teacher)
                    }
                }
            } message: { teacher in
                Text("Are you sure you want to delete \(teacher.name)? This action cannot be undone.")
            }
            .task {
                await viewModel.loadTeachers()
            }
        }
    }
    
    // MARK: - Header
    
    private func headerView(geometry: GeometryProxy) -> some View {
        HStack {
            Button(action: onMenuTapped) {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(UI.navy)
                    .font(.body)
            }
            
            Spacer()
            
            Text("Teachers")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)
            
            Spacer()
            
            Button(action: { Task { await viewModel.refreshCache() } }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(UI.navy)
                    .font(.body)
                    .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                    .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
            }
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 16)
        .frame(height: geometry.size.width > geometry.size.height ? 50 : 60)
        .background(Color(hex: "#B8C8DB"))
    }
    
    // MARK: - Search Bar
    
    private func searchBarView(geometry: GeometryProxy) -> some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search teachers...", text: $viewModel.searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Sync Status
    
    private func syncStatusView(geometry: GeometryProxy) -> some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Syncing...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if viewModel.pendingOperationsCount > 0 {
                Text("(\(viewModel.pendingOperationsCount) pending)")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Teacher List
    
    private func teacherListView(geometry: GeometryProxy) -> some View {
        Group {
            if viewModel.isLoading && viewModel.teachers.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading teachers...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredTeachers.isEmpty {
                emptyStateView(geometry: geometry)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredTeachers) { teacher in
                            TeacherRowView(
                                teacher: teacher,
                                onEdit: { viewModel.editTeacher(teacher) },
                                onDelete: {
                                    teacherToDelete = teacher
                                    showDeleteAlert = true
                                }
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Empty State
    
    private func emptyStateView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(viewModel.searchText.isEmpty ? "No Teachers Yet" : "No Results Found")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(viewModel.searchText.isEmpty ?
                 "Add your first teacher to get started" :
                 "Try adjusting your search")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - FAB Button
    
    private func fabButton(geometry: GeometryProxy) -> some View {
        Button(action: {
            viewModel.clearForm()
            viewModel.showingCreateTeacher = true
        }) {
            Image(systemName: "plus")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(UI.primary)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Teacher Row View
struct TeacherRowView: View {
    let teacher: Teacher
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(teacher.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let department = teacher.department {
                        Text(department)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(UI.primary)
                        .font(.title3)
                }
            }
            
            if let email = teacher.email {
                HStack {
                    Image(systemName: "envelope.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let phone = teacher.phoneNumber {
                HStack {
                    Image(systemName: "phone.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let officeLocation = teacher.officeLocation {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(officeLocation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let officeHours = teacher.officeHours {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(officeHours)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !teacher.linkedCourseIds.isEmpty {
                HStack {
                    Image(systemName: "book.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(teacher.linkedCourseIds.count) course(s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview
#Preview {
    TeachersListView(onMenuTapped: {})
}
