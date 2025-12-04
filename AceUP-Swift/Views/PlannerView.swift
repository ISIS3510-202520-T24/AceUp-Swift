import SwiftUI

struct PlannerView: View {
    let onMenuTapped: () -> Void
    
    @StateObject private var viewModel = PlannerViewModel()
    @State private var selectedCourse: CourseInfo?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                UI.neutralLight
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    topBar
                    
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.courses.isEmpty {
                        emptyState
                    } else {
                        courseList
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedCourse) { course in
                CourseDetailView(course: course)
            }
            .task {
                // Usar .task en lugar de .onAppear para async
                await viewModel.loadCourses()
            }
            .refreshable {
                // Pull-to-refresh para recargar
                await viewModel.loadCourses()
            }
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: onMenuTapped) {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundColor(UI.navy)
            }
            
            Text("My Classes")
                .font(.title2.bold())
                .foregroundColor(UI.navy)
            
            Spacer()
        }
        .padding()
        .background(Color.white)
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading classes...")
                .tint(UI.primary)
            Spacer()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(UI.primary.opacity(0.5))
            
            Text("No classes yet")
                .font(.title3.bold())
                .foregroundColor(UI.navy)
            
            Text("Create your schedule in the Calendar tab to see your classes here")
                .font(.body)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var courseList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.courses) { course in
                    CourseCard(course: course)
                        .onTapGesture {
                            selectedCourse = course
                        }
                }
            }
            .padding()
        }
    }
}

// tarjeta de cada materia
struct CourseCard: View {
    let course: CourseInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // nombre de la materia
            Text(course.name)
                .font(.headline)
                .foregroundColor(UI.navy)
            
            // info rapida de horarios
            if !course.sessions.isEmpty {
                Text("\(course.sessions.count) classes per week")
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
            
            // mostrar primeras sesiones
            ForEach(course.sessions.prefix(3), id: \.self) { session in
                HStack(spacing: 8) {
                    Text(session.weekday.display)
                        .font(.caption)
                        .foregroundColor(UI.muted)
                        .frame(width: 80, alignment: .leading)
                    
                    Text("\(session.start) - \(session.end)")
                        .font(.caption)
                        .foregroundColor(UI.navy)
                    
                    if let location = session.location {
                        Text(location)
                            .font(.caption)
                            .foregroundColor(UI.muted)
                    }
                }
            }
            
            if course.sessions.count > 3 {
                Text("+\(course.sessions.count - 3) more")
                    .font(.caption)
                    .foregroundColor(UI.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
