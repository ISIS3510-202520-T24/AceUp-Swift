//
//  TodayView.swift
//  AceUp-Swift
//
//  Created by Ana M. Sánchez on 19/09/25.
//

import SwiftUI


struct TodayView: View {
    let onMenuTapped: () -> Void
    @State private var selectedTab: TodayTab = .assignments
    
    init(onMenuTapped: @escaping () -> Void = {}) {
        self.onMenuTapped = onMenuTapped
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            VStack {
                HStack {
                    Button(action: onMenuTapped) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(UI.navy)
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    Text("Today")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 24)
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 60)
            .background(Color(hex: "#B8C8DB"))
            
            
            VStack(spacing: 0) {
                
                HStack(spacing: 8) {
                    TabButton(
                        title: "Exams",
                        isSelected: selectedTab == .exams,
                        action: { selectedTab = .exams }
                    )
                    
                    TabButton(
                        title: "Timetable",
                        isSelected: selectedTab == .timetable,
                        action: { selectedTab = .timetable }
                    )
                    
                    TabButton(
                        title: "Assignments",
                        isSelected: selectedTab == .assignments,
                        action: { selectedTab = .assignments }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                
                ScrollView {
                    switch selectedTab {
                    case .exams:
                        ExamsTabContent()
                    case .timetable:
                        TimetableTabContent()
                    case .assignments:
                        AssignmentsTabContent()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(UI.neutralLight)
        }
        
        .navigationBarHidden(true)
    }
}


enum TodayTab {
    case exams
    case timetable
    case assignments
}


struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : UI.navy)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? UI.primary : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}


struct ExamsTabContent: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 100)
            
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(UI.muted)
            
            VStack(spacing: 8) {
                Text("No exams scheduled")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Text("Your upcoming exams will appear here")
                    .font(.body)
                    .foregroundColor(UI.muted)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct TimetableTabContent: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 100)
            
            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundColor(UI.muted)
            
            VStack(spacing: 8) {
                Text("No classes today")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Text("Your class schedule will appear here")
                    .font(.body)
                    .foregroundColor(UI.muted)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct AssignmentsTabContent: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TaskViewModel?
    @State private var editingAssignment: Assignment?
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView()
                    .onAppear {
                        viewModel = TaskViewModel(modelContext: modelContext)
                    }
            }
        }
    }
    
    @ViewBuilder
    private func contentView(viewModel: TaskViewModel) -> some View {
        VStack(spacing: 20) {
            // Today's Summary Card
            VStack(spacing: 16) {
                Text("Today's Progress")
                    .font(.headline)
                    .foregroundColor(UI.navy)
                
                HStack(spacing: 30) {
                    VStack {
                        Text("\(viewModel.todaysCompleted)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.green)
                        Text("Done")
                            .font(.caption)
                            .foregroundColor(UI.muted)
                    }
                    
                    VStack {
                        Text("\(viewModel.todaysPending)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.orange)
                        Text("Pending")
                            .font(.caption)
                            .foregroundColor(UI.muted)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            
            // Today's Tasks List
            if viewModel.getTodaysAssignments().isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("No assignments due today!")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Text("Great job staying ahead!")
                        .font(.body)
                        .foregroundColor(UI.muted)
                }
                Spacer()
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.getTodaysAssignments()) { assignment in
                        TaskRow(
                            assignment: assignment,
                            onToggle: { _ in
                                viewModel.toggleComplete(assignment)
                            },
                            onEdit: {
                                editingAssignment = assignment
                            },
                            onDelete: {
                                viewModel.deleteAssignment(assignment)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .sheet(item: $editingAssignment) { assignment in
            EditTaskView(viewModel: viewModel, assignment: assignment)
        }
        .onAppear {
            viewModel.loadAssignments()
        }
    }
}

struct TaskRow: View {
    let assignment: Assignment
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            
            Button {
                onToggle(!assignment.isCompleted)
            } label: {
                Image(systemName: assignment.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(assignment.isCompleted ? .green : .gray)
            }

            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(assignment.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                // Tags: Subject + Type
                HStack(spacing: 8) {
                    pill(assignment.subject, system: "book")
                    pill(assignment.type, system: "list.bullet.rectangle")
                }

                // Meta: Due date + Priority
                HStack(spacing: 12) {
                    if let dueDate = assignment.dueDate {
                        Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                        
                    Label(priorityText, systemImage: "flag")
                        .font(.caption)
                        .foregroundStyle(priorityColor)
                }

                // Optional: grade if exists
                if let g = assignment.grade {
                    Label(String(format: "Grade %.1f / 5.0", g), systemImage: "checkmark.seal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func pill(_ text: String, system: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: system).font(.caption2)
            Text(text).font(.caption).bold()
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.15)))
        .foregroundStyle(.secondary)
    }

    private var priorityText: String {
        assignment.priority
    }

    private var priorityColor: Color {
        switch assignment.priority.lowercased() {
        case "high":   return .red
        case "medium": return .orange
        default:       return .green
        }
    }
}

#Preview {
    TodayView(onMenuTapped: {
        print("Menu tapped")
    })
}

