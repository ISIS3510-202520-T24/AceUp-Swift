//
//  PlannerTaskDetailView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/12/25.
//

import SwiftUI

struct PlannerTaskDetailView: View {
    let task: PlannerTask
    @ObservedObject var viewModel: PlannerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showPostponeSheet = false
    @State private var newScheduledDate = Date()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Badge
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: task.status.icon)
                            Text(task.status.displayName)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: task.status.color).opacity(0.2))
                        .foregroundColor(Color(hex: task.status.color))
                        .cornerRadius(20)
                        Spacer()
                    }
                    
                    // Title and Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text(task.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(UI.navy)
                        
                        if let description = task.description {
                            Text(description)
                                .font(.body)
                                .foregroundColor(UI.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    
                    // Task Details
                    VStack(spacing: 16) {
                        DetailRow(
                            icon: task.category.icon,
                            title: "Category",
                            value: task.category.displayName,
                            color: Color(hex: task.category.defaultColor)
                        )
                        
                        Divider()
                        
                        DetailRow(
                            icon: "calendar",
                            title: "Scheduled",
                            value: formatDate(task.scheduledDate),
                            color: UI.primary
                        )
                        
                        if let scheduledTime = task.scheduledTime {
                            Divider()
                            DetailRow(
                                icon: "clock",
                                title: "Time",
                                value: formatTime(scheduledTime),
                                color: UI.secondary
                            )
                        }
                        
                        if task.estimatedDuration != nil {
                            Divider()
                            DetailRow(
                                icon: "hourglass",
                                title: "Duration",
                                value: task.formattedDuration,
                                color: UI.accent
                            )
                        }
                        
                        Divider()
                        
                        DetailRow(
                            icon: "exclamationmark.circle",
                            title: "Priority",
                            value: task.priority.displayName,
                            color: Color(hex: task.priority.color)
                        )
                        
                        if let courseName = task.courseName {
                            Divider()
                            DetailRow(
                                icon: "book.fill",
                                title: "Course",
                                value: courseName,
                                color: Color(hex: task.courseColor ?? "#122C4A")
                            )
                        }
                        
                        if task.isRecurring, let rule = task.recurrenceRule {
                            Divider()
                            DetailRow(
                                icon: "repeat",
                                title: "Recurrence",
                                value: rule.frequency.displayName,
                                color: UI.primary
                            )
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        if task.status == .planned {
                            Button(action: {
                                Task {
                                    await viewModel.markTaskAsInProgress(task.id)
                                    dismiss()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("Start Task")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(UI.primary)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        
                        if task.status != .completed {
                            Button(action: {
                                Task {
                                    await viewModel.markTaskAsCompleted(task.id)
                                    dismiss()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Mark as Completed")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(UI.success)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        
                        if task.status == .planned || task.status == .inProgress {
                            Button(action: {
                                showPostponeSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                    Text("Postpone")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        
                        Button(role: .destructive, action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Task")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 20)
            }
            .background(UI.neutralLight)
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Task", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteTask(task.id)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this task? This action cannot be undone.")
            }
            .sheet(isPresented: $showPostponeSheet) {
                PostponeTaskSheet(
                    currentDate: task.scheduledDate,
                    newDate: $newScheduledDate,
                    onPostpone: {
                        Task {
                            await viewModel.postponeTask(task.id, to: newScheduledDate)
                            dismiss()
                        }
                    }
                )
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(UI.muted)
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
            }
            
            Spacer()
        }
    }
}

struct PostponeTaskSheet: View {
    let currentDate: Date
    @Binding var newDate: Date
    let onPostpone: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select new date")
                    .font(.headline)
                    .foregroundColor(UI.navy)
                
                DatePicker(
                    "New Date",
                    selection: $newDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(UI.primary)
                
                Button(action: {
                    onPostpone()
                    dismiss()
                }) {
                    Text("Postpone Task")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(UI.primary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Postpone Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PlannerTaskDetailView(
        task: PlannerTask(
            title: "Study Algorithms",
            description: "Review sorting and searching algorithms for exam preparation",
            courseId: "cs101",
            courseName: "Computer Science",
            courseColor: "#42A5F5",
            scheduledDate: Date(),
            scheduledTime: Date(),
            estimatedDuration: 7200,
            priority: .high,
            status: .planned,
            category: .study
        ),
        viewModel: PlannerViewModel()
    )
}
