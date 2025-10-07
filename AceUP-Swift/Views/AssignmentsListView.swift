import SwiftUI

/// Main assignments list view with smart features and analytics
struct AssignmentsListView: View {
    let onMenuTapped: () -> Void
    @StateObject private var viewModel = AssignmentViewModel()
    @StateObject private var offlineRepository = OfflineAssignmentRepository()
    @State private var selectedFilter: AssignmentFilter = .all
    @State private var searchText = ""
    @State private var showingWorkloadAnalysis = false
    
    init(onMenuTapped: @escaping () -> Void = {}) {
        self.onMenuTapped = onMenuTapped
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Offline Status Indicator
            if offlineRepository.isOfflineMode || offlineRepository.syncStatus != .synced {
                OfflineStatusIndicator()
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            
            // Header
            headerView
            
            // Filter and Search
            filterAndSearchView
            
            // Smart Recommendations
            if !viewModel.smartRecommendations.isEmpty {
                smartRecommendationsView
            }
            
            // Assignment List with Offline Support
            offlineAwareAssignmentListView
        }
        .navigationBarHidden(true)
        .overlay(offlineFabButton, alignment: .bottomTrailing)
        .sheet(isPresented: $viewModel.showingCreateAssignment) {
            CreateAssignmentView(viewModel: viewModel, offlineRepository: offlineRepository)
        }
        .sheet(isPresented: $showingWorkloadAnalysis) {
            WorkloadAnalysisView()
        }
        .task {
            await loadAssignmentsWithOfflineSupport()
        }
        .onAppear {
            offlineRepository.refreshData()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
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
        .frame(height: 60)
        .background(Color(hex: "#B8C8DB"))
    }
    
    // MARK: - Filter and Search
    
    private var filterAndSearchView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search assignments...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
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
                HStack(spacing: 12) {
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
        .padding(.vertical, 12)
        .background(UI.neutralLight)
    }
    
    // MARK: - Smart Recommendations
    
    private var smartRecommendationsView: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                HStack(spacing: 12) {
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
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Offline-Aware Assignment List
    
    private var offlineAwareAssignmentListView: some View {
        OfflineAwareListView(
            items: filteredOfflineAssignments,
            isOfflineMode: offlineRepository.isOfflineMode,
            syncStatus: offlineRepository.syncStatus
        ) { assignment in
            AssignmentCard(
                assignment: assignment,
                isOfflineMode: offlineRepository.isOfflineMode,
                onToggleComplete: {
                    handleOfflineToggleComplete(assignment)
                },
                onEdit: {
                    viewModel.selectedAssignment = assignment
                }
            )
            .padding(.horizontal, 16)
        }
        .background(UI.neutralLight)
    }
    
    // MARK: - Assignment List
    
    private var assignmentListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredAssignments) { assignment in
                    AssignmentCard(
                        assignment: assignment,
                        onToggleComplete: {
                            Task {
                                await viewModel.markAsCompleted(assignment.id)
                            }
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
    
    // MARK: - Offline-Aware FAB
    
    private var offlineFabButton: some View {
        OfflineAwareButton(
            title: "+",
            isOfflineMode: offlineRepository.isOfflineMode
        ) {
            viewModel.showingCreateAssignment = true
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .shadow(color: UI.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.trailing, 20)
        .padding(.bottom, 30)
    }
    
    // MARK: - FAB
    
    private var fabButton: some View {
        Button(action: { viewModel.showingCreateAssignment = true }) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(UI.primary)
                .clipShape(Circle())
                .shadow(color: UI.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 30)
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
    let isOfflineMode: Bool
    let onToggleComplete: () -> Void
    let onEdit: () -> Void
    
    // Default initializer for backward compatibility
    init(assignment: Assignment, onToggleComplete: @escaping () -> Void, onEdit: @escaping () -> Void) {
        self.assignment = assignment
        self.isOfflineMode = false
        self.onToggleComplete = onToggleComplete
        self.onEdit = onEdit
    }
    
    // New initializer with offline support
    init(assignment: Assignment, isOfflineMode: Bool, onToggleComplete: @escaping () -> Void, onEdit: @escaping () -> Void) {
        self.assignment = assignment
        self.isOfflineMode = isOfflineMode
        self.onToggleComplete = onToggleComplete
        self.onEdit = onEdit
    }
    
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
                    HStack(spacing: 4) {
                        if isOfflineMode {
                            Image(systemName: "wifi.slash")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(2)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        PriorityBadge(priority: assignment.priority)
                    }
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
        case .completed: return "Keep working on your assignments to see completed ones here"
        case .overdue: return "Great! You're caught up with your assignments"
        case .dueToday: return "No assignments due today. Take a break or work ahead!"
        case .dueTomorrow: return "No assignments due tomorrow. You're in good shape!"
        case .highPriority: return "No urgent assignments. Keep up the good work!"
        default: return "Add some assignments to get started"
        }
    }
    
    // MARK: - Offline-Specific Properties and Methods
    
    private var filteredOfflineAssignments: [Assignment] {
        let assignments = offlineRepository.assignments
        let searchFiltered = searchText.isEmpty ? 
            assignments : 
            assignments.filter { assignment in
                assignment.title.localizedCaseInsensitiveContains(searchText) ||
                assignment.subject.localizedCaseInsensitiveContains(searchText) ||
                assignment.description.localizedCaseInsensitiveContains(searchText)
            }
        
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
    
    private func loadAssignmentsWithOfflineSupport() async {
        if offlineRepository.isOfflineMode {
            // Load from local storage
            offlineRepository.refreshData()
        } else {
            // Sync with Firebase
            try? await offlineRepository.syncWithFirebase()
            // Also load with existing view model for compatibility
            await viewModel.loadAssignments()
        }
    }
    
    private func handleOfflineToggleComplete(_ assignment: Assignment) {
        var updatedAssignment = assignment
        updatedAssignment.status = assignment.status == .completed ? .pending : .completed
        updatedAssignment.completedDate = assignment.status == .completed ? nil : Date()
        
        offlineRepository.updateAssignment(updatedAssignment)
        
        // Also update view model for compatibility
        Task {
            await viewModel.markAsCompleted(assignment.id)
        }
    }
}

// MARK: - Offline-Aware Assignment Card
struct OfflineAssignmentCard: View {
    let assignment: Assignment
    let isOfflineMode: Bool
    let onToggleComplete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with offline indicator
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Text(assignment.subject)
                        .font(.subheadline)
                        .foregroundColor(UI.primary)
                }
                
                Spacer()
                
                if isOfflineMode {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(4)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Button(action: onToggleComplete) {
                    Image(systemName: assignment.status == .completed ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(assignment.status == .completed ? .green : .gray)
                }
            }
            
            // Description
            if !assignment.description.isEmpty {
                Text(assignment.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Due date and priority
            HStack {
                Label(DateFormatter.shortDate.string(from: assignment.dueDate), systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(assignment.isOverdue ? .red : .secondary)
                
                Spacer()
                
                PriorityBadge(priority: assignment.priority)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .onTapGesture {
            onEdit()
        }
    }
}

// MARK: - Extensions for Assignment Properties
extension Assignment {
    var isOverdue: Bool {
        return dueDate < Date() && status != .completed
    }
    
    var isDueToday: Bool {
        return Calendar.current.isDateInToday(dueDate)
    }
    
    var isDueTomorrow: Bool {
        return Calendar.current.isDateInTomorrow(dueDate)
    }
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}
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