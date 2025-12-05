//
//  CreatePlannerTaskView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/12/25.
//

import SwiftUI

struct CreatePlannerTaskView: View {
    @ObservedObject var viewModel: PlannerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Title", text: $viewModel.newTaskTitle)
                    
                    TextField("Description (optional)", text: $viewModel.newTaskDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Category")) {
                    Picker("Category", selection: $viewModel.newTaskCategory) {
                        ForEach(PlannerTaskCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Schedule")) {
                    DatePicker("Date", selection: $viewModel.newTaskScheduledDate, displayedComponents: .date)
                    
                    Toggle("Set specific time", isOn: Binding(
                        get: { viewModel.newTaskScheduledTime != nil },
                        set: { if $0 { viewModel.newTaskScheduledTime = Date() } else { viewModel.newTaskScheduledTime = nil } }
                    ))
                    
                    if viewModel.newTaskScheduledTime != nil {
                        DatePicker("Time", selection: Binding(
                            get: { viewModel.newTaskScheduledTime ?? Date() },
                            set: { viewModel.newTaskScheduledTime = $0 }
                        ), displayedComponents: .hourAndMinute)
                    }
                }
                
                Section(header: Text("Duration")) {
                    Picker("Estimated Duration", selection: $viewModel.newTaskEstimatedDuration) {
                        Text("15 minutes").tag(TimeInterval(900))
                        Text("30 minutes").tag(TimeInterval(1800))
                        Text("1 hour").tag(TimeInterval(3600))
                        Text("1.5 hours").tag(TimeInterval(5400))
                        Text("2 hours").tag(TimeInterval(7200))
                        Text("3 hours").tag(TimeInterval(10800))
                        Text("4 hours").tag(TimeInterval(14400))
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Priority")) {
                    Picker("Priority", selection: $viewModel.newTaskPriority) {
                        ForEach([Priority.low, .medium, .high, .critical], id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(Color(hex: priority.color))
                                    .frame(width: 12, height: 12)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Recurrence")) {
                    Toggle("Recurring Task", isOn: $viewModel.newTaskIsRecurring)
                    
                    if viewModel.newTaskIsRecurring {
                        Picker("Frequency", selection: $viewModel.newTaskRecurrenceFrequency) {
                            ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createTask()
                        }
                    }
                    .disabled(viewModel.newTaskTitle.isEmpty)
                }
            }
        }
    }
}

#Preview {
    CreatePlannerTaskView(viewModel: PlannerViewModel())
}
