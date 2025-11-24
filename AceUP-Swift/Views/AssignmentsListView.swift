//
//  AssignmentsListView.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 4/10/25.
//

import SwiftUI

/// Main assignments list view with smart features and analytics
struct AssignmentsListView: View {
    let onMenuTapped: () -> Void
    @StateObject private var viewModel = AssignmentViewModel()
    @State private var selectedFilter: AssignmentFilter = .all
    @State private var searchText = ""
    @State private var showingWorkloadAnalysis = false
    @State private var showGradeInput = false
    @State private var gradeInputText = ""
    @State private var assignmentToComplete: Assignment?
    
    init(onMenuTapped: @escaping () -> Void = {}) {
        self.onMenuTapped = onMenuTapped
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                headerView(geometry: geometry)
                
                // Filter and Search
                filterAndSearchView(geometry: geometry)
                
                // Smart Recommendations
                if !viewModel.smartRecommendations.isEmpty {
                    smartRecommendationsView(geometry: geometry)
                }
                
                // Assignment List
                assignmentListView(geometry: geometry)
            }
            .navigationBarHidden(true)
            .overlay(fabButton(geometry: geometry), alignment: .bottomTrailing)
            .sheet(isPresented: $viewModel.showingCreateAssignment) {
                CreateAssignmentView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingWorkloadAnalysis) {
                WorkloadAnalysisView(analysis: viewModel.workloadAnalysis)
            }
            .alert("Enter Grade", isPresented: $showGradeInput) {
                TextField("Grade (0.0 - 5.0)", text: $gradeInputText)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) {
                    assignmentToComplete = nil
                    gradeInputText = ""
                }
                Button("Complete") {
                    if let assignment = assignmentToComplete,
                       let grade = Double(gradeInputText),
                       grade >= 0 && grade <= 5.0 {
                        Task {
                            await viewModel.markAsCompleted(assignment.id, finalGrade: grade)
                        }
                    }
                    assignmentToComplete = nil
                    gradeInputText = ""
                }
            } message: {
                Text("Enter the final grade for this assignment (scale 0.0 to 5.0)")
            }
            .task {
                await viewModel.loadAssignments()
            }
        }
    }
    
    // MARK: - Header
    
    private func headerView(geometry: GeometryProxy) -> some View {
        VStack {
            HStack {
                Button(action: onMenuTapped) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(UI.navy)
                        .font(.body)
                }
                
                Spacer()
                
                Text("Assignments")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Button(action: { showingWorkloadAnalysis = true }) {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(UI.navy)
                        .font(.body)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: geometry.size.width > geometry.size.height ? 50 : 60) // Shorter in landscape
        .background(Color(hex: "#B8C8DB"))
    }
    
    // MARK: - Filter and Search
    
    private func filterAndSearchView(geometry: GeometryProxy) -> some View {
        VStack(spacing: geometry.size.width > geometry.size.height ? 8 : 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search assignments...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .searchQueryInput($searchText)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            
            // Filter buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: geometry.size.width > geometry.size.height ? 8 : 12) {
                    ForEach(AssignmentFilter.allCases, id: \.self) { filter in
                        FilterButton(
                            title: filter.displayName,
                            count: getFilterCount(filter),
                            isSelected: selectedFilter == filter,
                            action: { selectedFilter = filter }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, geometry.size.width > geometry.size.height ? 8 : 12) // Less padding in landscape
        .background(UI.neutralLight)
    }
    
    // MARK: - Smart Recommendations
    
    private func smartRecommendationsView(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: geometry.size.width > geometry.size.height ? 8 : 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(UI.primary)
                    .font(.caption)
                
                Text("Smart Recommendations")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: geometry.size.width > geometry.size.height ? 8 : 12) {
                    ForEach(viewModel.smartRecommendations.prefix(3), id: \.id) { recommendation in
                        SmartRecommendationCard(recommendation: recommendation) {
                            // Handle recommendation action
                            handleRecommendationAction(recommendation)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, geometry.size.width > geometry.size.height ? 8 : 12) // Less padding in landscape
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Assignment List
    
    private func assignmentListView(geometry: GeometryProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: geometry.size.width > geometry.size.height ? 8 : 12) {
                ForEach(filteredAssignments) { assignment in
                    AssignmentCard(
                        assignment: assignment,
                        onToggleComplete: {
                            assignmentToComplete = assignment
                            showGradeInput = true
                        },
                        onEdit: {
                            viewModel.selectedAssignment = assignment
                        }
                    )
                    .padding(.horizontal, 16)
                }
                
                if filteredAssignments.isEmpty {
                    EmptyAssignmentsView(filter: selectedFilter)
                        .padding(.top, 50)
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 100) // Space for FAB
        }
        .background(UI.neutralLight)
    }
    
    // MARK: - FAB
    
    private func fabButton(geometry: GeometryProxy) -> some View {
        Button(action: { viewModel.showingCreateAssignment = true }) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: geometry.size.width > geometry.size.height ? 48 : 56, 
                       height: geometry.size.width > geometry.size.height ? 48 : 56) // Smaller in landscape
                .background(UI.primary)
                .clipShape(Circle())
                .shadow(color: UI.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, geometry.size.width > geometry.size.height ? 15 : 20)
        .padding(.bottom, geometry.size.width > geometry.size.height ? 15 : 30)
    }
    
    // MARK: - Computed Properties
    
    private var filteredAssignments: [Assignment] {
        let searchFiltered = searchText.isEmpty ? 
            viewModel.assignments : 
            viewModel.searchAssignments(searchText)
        
        switch selectedFilter {
        case .all:
            return searchFiltered
        case .pending:
            return searchFiltered.filter { $0.status == .pending }
        case .inProgress:
            return searchFiltered.filter { $0.status == .inProgress }
        case .completed:
            return searchFiltered.filter { $0.status == .completed }
        case .overdue:
            return searchFiltered.filter { $0.isOverdue }
        case .dueToday:
            return searchFiltered.filter { $0.isDueToday }
        case .dueTomorrow:
            return searchFiltered.filter { $0.isDueTomorrow }
        case .highPriority:
            return searchFiltered.filter { $0.priority == .high || $0.priority == .critical }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getFilterCount(_ filter: AssignmentFilter) -> Int {
        switch filter {
        case .all:
            return viewModel.assignments.count
        case .pending:
            return viewModel.assignments.filter { $0.status == .pending }.count
        case .inProgress:
            return viewModel.assignments.filter { $0.status == .inProgress }.count
        case .completed:
            return viewModel.assignments.filter { $0.status == .completed }.count
        case .overdue:
            return viewModel.overdueAssignments.count
        case .dueToday:
            return viewModel.todaysAssignments.count
        case .dueTomorrow:
            return viewModel.assignments.filter { $0.isDueTomorrow }.count
        case .highPriority:
            return viewModel.assignments.filter { $0.priority == .high || $0.priority == .critical }.count
        }
    }
    
    private func handleRecommendationAction(_ recommendation: SmartRecommendation) {
        // Handle different recommendation actions
        switch recommendation.type {
        case .workloadDistribution:
            // Show workload analysis
            showingWorkloadAnalysis = true
        case .earlyStart:
            // Navigate to assignment
            if let assignmentId = recommendation.relatedAssignments.first,
               let assignment = viewModel.assignments.first(where: { $0.id == assignmentId }) {
                viewModel.selectedAssignment = assignment
            }
        case .timeManagement:
            // Show subtask creation
            break
        default:
            break
        }
    }
}

// MARK: - Supporting Views

struct AssignmentCard: View {
    let assignment: Assignment
    let onToggleComplete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(UI.navy)
                        .lineLimit(2)
                    
                    Text(assignment.courseName)
                        .font(.caption)
                        .foregroundColor(Color(hex: assignment.courseColor))
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    PriorityBadge(priority: assignment.priority)
                    StatusBadge(status: assignment.status)
                }
            }
            
            // Due date and weight
            HStack {
                Label(assignment.formattedDueDate, systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(assignment.urgencyLevel.color.isEmpty ? .secondary : Color(hex: assignment.urgencyLevel.color))
                
                Spacer()
                
                Label("\(assignment.weightPercentage)%", systemImage: "chart.pie")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar (if has subtasks)
            if !assignment.subtasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(assignment.completionPercentage * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: assignment.completionPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: UI.primary))
                }
            }
            
            // Action buttons
            HStack {
                if assignment.status == .pending || assignment.status == .inProgress {
                    Button(action: onToggleComplete) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                            Text("Complete")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(UI.success)
                        .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct PriorityBadge: View {
    let priority: Priority
    
    var body: some View {
        Text(priority.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(hex: priority.color))
            .cornerRadius(4)
    }
}

struct StatusBadge: View {
    let status: AssignmentStatus
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(Color(hex: status.color))
    }
}

struct FilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : UI.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(isSelected ? .white.opacity(0.3) : UI.primary.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .foregroundColor(isSelected ? .white : UI.navy)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? UI.primary : Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct SmartRecommendationCard: View {
    let recommendation: SmartRecommendation
    let onAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: recommendation.type.icon)
                    .foregroundColor(UI.primary)
                    .font(.caption)
                
                Text(recommendation.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            
            Text(recommendation.message)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            if recommendation.actionable {
                Button(action: onAction) {
                    Text(recommendation.suggestedAction ?? "Learn More")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(UI.primary)
                }
            }
        }
        .padding(12)
        .frame(width: 200)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

struct EmptyAssignmentsView: View {
    let filter: AssignmentFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text(emptyTitle)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                Text(emptyMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
    }
    
    private var emptyIcon: String {
        switch filter {
        case .completed: return "checkmark.circle"
        case .overdue: return "clock.badge.exclamationmark"
        case .dueToday: return "calendar"
        case .highPriority: return "exclamationmark.triangle"
        default: return "doc.text"
        }
    }
    
    private var emptyTitle: String {
        switch filter {
        case .completed: return "No completed assignments"
        case .overdue: return "No overdue assignments"
        case .dueToday: return "No assignments due today"
        case .dueTomorrow: return "No assignments due tomorrow"
        case .highPriority: return "No high priority assignments"
        default: return "No assignments found"
        }
    }
    
    private var emptyMessage: String {
        switch filter {
        case .completed: return "Complete some assignments to see them here"
        case .overdue: return "Great! You're staying on top of your work"
        case .dueToday: return "Enjoy your free day or work on upcoming assignments"
        case .dueTomorrow: return "Tomorrow looks clear so far"
        case .highPriority: return "All urgent assignments are under control"
        default: return "Create your first assignment to get started"
        }
    }
}

// MARK: - Supporting Enums

enum AssignmentFilter: String, CaseIterable {
    case all = "all"
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case overdue = "overdue"
    case dueToday = "due_today"
    case dueTomorrow = "due_tomorrow"
    case highPriority = "high_priority"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .overdue: return "Overdue"
        case .dueToday: return "Due Today"
        case .dueTomorrow: return "Due Tomorrow"
        case .highPriority: return "High Priority"
        }
    }
}

#Preview {
    AssignmentsListView(onMenuTapped: {})
}