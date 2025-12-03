import SwiftUI

// MARK: - Course List by Semester View
// Temporary view to show courses for a specific semester
struct CourseListBySemesterView: View {
    let semester: Semester
    @State private var courses: [Course] = []
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Color(hex: "#F5F7FA")
                .ignoresSafeArea()
            
            VStack {
                if isLoading {
                    ProgressView()
                } else if courses.isEmpty {
                    emptyState
                } else {
                    coursesList
                }
            }
        }
        .navigationTitle(semester.name)
        .task {
            await loadCourses()
        }
    }
    
    private var coursesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(courses) { course in
                    CourseCard(course: course)
                }
            }
            .padding()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#8B8680"))
            
            Text("No Courses Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "#122C4A"))
            
            Text("Courses for this semester will appear here")
                .font(.body)
                .foregroundColor(Color(hex: "#8B8680"))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private func loadCourses() async {
        isLoading = true
        do {
            let repository = SemesterRepository()
            courses = try await repository.loadCoursesForSemester(
                startDate: semester.startDate,
                endDate: semester.endDate
            )
        } catch {
            print("Error loading courses: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Course Card Component
struct CourseCard: View {
    let course: Course
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#122C4A"))
                    
                    Text(course.code)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#8B8680"))
                }
                
                Spacer()
                
                Circle()
                    .fill(Color(hex: course.color))
                    .frame(width: 40, height: 40)
            }
            
            HStack(spacing: 20) {
                Label("\(course.credits) credits", systemImage: "graduationcap.fill")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#8B8680"))
                
                if let grade = course.currentGrade {
                    Label(String(format: "%.1f", grade), systemImage: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#4ECDC4"))
                }
            }
            
            if !course.instructor.isEmpty {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption)
                    Text(course.instructor)
                        .font(.caption)
                }
                .foregroundColor(Color(hex: "#8B8680"))
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Alias for compatibility
typealias SubjectListView = CourseListBySemesterView

#Preview {
    NavigationView {
        CourseListBySemesterView(semester: Semester(
            name: "Fall 2024",
            year: 2024,
            type: .fall,
            startDate: Date(),
            endDate: Date(),
            credits: 15,
            notes: "Test semester",
            colorHex: "#4ECDC4",
            userId: nil,
            createdAt: Date()
        ))
    }
}
