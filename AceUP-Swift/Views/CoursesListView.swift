//
//  CoursesListView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import SwiftUI

struct CoursesListView: View {
    @StateObject private var courseViewModel = CourseViewModel()
    @State private var searchText = ""
    @State private var selectedSemester = "All"
    
    private let semesters = ["All", "Fall", "Spring", "Summer", "Winter"]
    
    var filteredCourses: [Course] {
        var filtered = courseViewModel.courses
        
        if !searchText.isEmpty {
            filtered = filtered.filter { course in
                course.name.localizedCaseInsensitiveContains(searchText) ||
                course.code.localizedCaseInsensitiveContains(searchText) ||
                course.instructor.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if selectedSemester != "All" {
            filtered = filtered.filter { $0.semester == selectedSemester }
        }
        
        return filtered.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                filterSection
                
                if courseViewModel.isLoading {
                    loadingView
                } else if filteredCourses.isEmpty {
                    emptyStateView
                } else {
                    coursesList
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $courseViewModel.showingCreateCourse) {
            CreateCourseView(viewModel: courseViewModel)
        }
        .task {
            await courseViewModel.loadCourses()
        }
        .refreshable {
            await courseViewModel.refreshCourses()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Courses")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(UI.navy)
                    
                    Text("\(courseViewModel.courses.count) total courses")
                        .font(.subheadline)
                        .foregroundColor(UI.muted)
                }
                
                Spacer()
                
                Button(action: {
                    courseViewModel.showingCreateCourse = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(UI.primary)
                        .clipShape(Circle())
                }
            }
            
            if !courseViewModel.activeCourses.isEmpty {
                courseSummaryCards
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var courseSummaryCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(courseViewModel.activeCourses.prefix(3)) { course in
                    CourseSummaryCard(course: course)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var filterSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(UI.muted)
                
                TextField("Search courses...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Picker("Semester", selection: $selectedSemester) {
                ForEach(semesters, id: \.self) { semester in
                    Text(semester).tag(semester)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading courses...")
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(UI.muted)
            
            Text("No Courses Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)
            
            Text(searchText.isEmpty ? 
                 "Add your first course to get started" : 
                 "No courses match your search")
                .font(.body)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
            
            if searchText.isEmpty {
                Button(action: {
                    courseViewModel.showingCreateCourse = true
                }) {
                    Text("Add Course")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(UI.primary)
                        .cornerRadius(25)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var coursesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredCourses) { course in
                    CourseRow(
                        course: course,
                        onEdit: { editedCourse in
                            Task {
                                await courseViewModel.updateCourse(editedCourse)
                            }
                        },
                        onDelete: { courseToDelete in
                            Task {
                                await courseViewModel.deleteCourse(courseToDelete)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
    }
}

struct CourseSummaryCard: View {
    let course: Course
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(course.code)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                
                Spacer()
                
                Text("\(course.credits) cr")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Text(course.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(2)
            
            if let currentGrade = course.currentGrade {
                Text("\(Int(currentGrade))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .frame(width: 160, height: 120)
        .background(
            LinearGradient(
                colors: [Color(hex: course.color), Color(hex: course.color).opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}

struct CourseRow: View {
    let course: Course
    let onEdit: (Course) -> Void
    let onDelete: (Course) -> Void
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Course color indicator
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: course.color))
                .frame(width: 4, height: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(course.code)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(hex: course.color))
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    Text("\(course.credits) credits")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                }
                
                Text(course.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                    .lineLimit(1)
                
                Text(course.instructor)
                    .font(.subheadline)
                    .foregroundColor(UI.muted)
                    .lineLimit(1)
                
                HStack {
                    Text("\(course.semester) \(course.year)")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                    
                    Spacer()
                    
                    if let currentGrade = course.currentGrade {
                        Text("Current: \(Int(currentGrade))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(UI.primary)
                    }
                }
            }
            
            VStack(spacing: 8) {
                Button(action: {
                    showingEditSheet = true
                }) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(UI.primary)
                        .frame(width: 32, height: 32)
                        .background(UI.primary.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingEditSheet) {
            EditCourseView(course: course, onSave: onEdit)
        }
        .alert("Delete Course", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete(course)
            }
        } message: {
            Text("Are you sure you want to delete '\(course.name)'? This action cannot be undone.")
        }
    }
}

#if DEBUG
struct CoursesListView_Previews: PreviewProvider {
    static var previews: some View {
        CoursesListView()
    }
}
#endif