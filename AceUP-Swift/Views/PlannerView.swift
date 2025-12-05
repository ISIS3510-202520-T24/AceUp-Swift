//
//  PlannerView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/12/25.
//

import SwiftUI

struct PlannerView: View {
    @StateObject private var viewModel = PlannerViewModel()
    @State private var showingTaskDetail: PlannerTask?
    @State private var showError = false
    let onMenuTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            PlannerHeaderView(onMenuTapped: onMenuTapped, viewModel: viewModel)
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Statistics Card
                    if let statistics = viewModel.statistics {
                        PlannerStatisticsCard(statistics: statistics)
                            .padding(.horizontal, 16)
                    }
                    
                    // Date Picker
                    DatePickerSection(selectedDate: $viewModel.selectedDate)
                        .padding(.horizontal, 16)
                    
                    // Quick Filters
                    FilterSection(
                        selectedCategory: $viewModel.selectedCategory,
                        selectedStatus: $viewModel.selectedStatus
                    )
                    .padding(.horizontal, 16)
                    
                    // Tasks for Selected Date
                    if viewModel.tasksForSelectedDate.isEmpty {
                        EmptyPlannerStateView()
                            .padding(.top, 40)
                    } else {
                        TasksListSection(
                            tasks: viewModel.tasksForSelectedDate,
                            onTaskTap: { task in
                                showingTaskDetail = task
                            },
                            onTaskComplete: { taskId in
                                Task {
                                    await viewModel.markTaskAsCompleted(taskId)
                                }
                            },
                            onTaskInProgress: { taskId in
                                Task {
                                    await viewModel.markTaskAsInProgress(taskId)
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(UI.neutralLight)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $viewModel.showCreateTaskSheet) {
            CreatePlannerTaskView(viewModel: viewModel)
        }
        .sheet(item: $showingTaskDetail) { task in
            PlannerTaskDetailView(task: task, viewModel: viewModel)
        }
        .overlay(alignment: .bottomTrailing) {
            // FAB Button
            Button(action: {
                viewModel.showCreateTaskSheet = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(UI.primary)
                    .clipShape(Circle())
                    .shadow(color: UI.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .task {
            await viewModel.loadTasks()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onChange(of: viewModel.errorMessage) {
            showError = viewModel.errorMessage != nil
        }
    }
}

// MARK: - Header View

struct PlannerHeaderView: View {
    let onMenuTapped: () -> Void
    @ObservedObject var viewModel: PlannerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onMenuTapped) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(UI.navy)
                        .frame(width: 32, height: 32)
                }
                
                Text("Planner")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await viewModel.loadTasks()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(UI.navy)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
        }
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
}

// MARK: - Statistics Card

struct PlannerStatisticsCard: View {
    let statistics: PlannerStatistics
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Progress")
                    .font(.headline)
                    .foregroundColor(UI.navy)
                Spacer()
            }
            
            HStack(spacing: 12) {
                StatisticItem(
                    title: "Today",
                    value: "\(statistics.tasksToday)",
                    icon: "calendar",
                    color: UI.primary
                )
                
                StatisticItem(
                    title: "Week",
                    value: "\(statistics.tasksThisWeek)",
                    icon: "calendar.badge.clock",
                    color: UI.secondary
                )
                
                StatisticItem(
                    title: "Completed",
                    value: "\(statistics.completionPercentage)%",
                    icon: "checkmark.circle.fill",
                    color: UI.success
                )
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct StatisticItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            Text(title)
                .font(.caption)
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Date Picker Section

struct DatePickerSection: View {
    @Binding var selectedDate: Date
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Select Date")
                    .font(.headline)
                    .foregroundColor(UI.navy)
                Spacer()
            }
            
            DatePicker(
                "Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(UI.primary)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Filter Section

struct FilterSection: View {
    @Binding var selectedCategory: PlannerTaskCategory?
    @Binding var selectedStatus: PlannerTaskStatus?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Filters")
                    .font(.headline)
                    .foregroundColor(UI.navy)
                Spacer()
                
                if selectedCategory != nil || selectedStatus != nil {
                    Button("Clear") {
                        selectedCategory = nil
                        selectedStatus = nil
                    }
                    .font(.caption)
                    .foregroundColor(UI.primary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PlannerTaskCategory.allCases, id: \.self) { category in
                        FilterChip(
                            title: category.displayName,
                            icon: category.icon,
                            isSelected: selectedCategory == category,
                            action: {
                                selectedCategory = selectedCategory == category ? nil : category
                            }
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

private struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? UI.primary : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .white : UI.navy)
            .cornerRadius(16)
        }
    }
}

// MARK: - Tasks List Section

struct TasksListSection: View {
    let tasks: [PlannerTask]
    let onTaskTap: (PlannerTask) -> Void
    let onTaskComplete: (String) -> Void
    let onTaskInProgress: (String) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Tasks")
                    .font(.headline)
                    .foregroundColor(UI.navy)
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
            
            ForEach(tasks) { task in
                PlannerTaskRowView(
                    task: task,
                    onTap: { onTaskTap(task) },
                    onComplete: { onTaskComplete(task.id) },
                    onInProgress: { onTaskInProgress(task.id) }
                )
            }
        }
    }
}

// MARK: - Empty State

struct EmptyPlannerStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(UI.muted)
            
            Text("No tasks scheduled")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)
            
            Text("Tap the + button to create your first task")
                .font(.body)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

#Preview {
    PlannerView(onMenuTapped: {})
}
