//
//  AssignmentsListView.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 3/10/25.
//

import SwiftUI
import SwiftData

struct AssignmentsListView: View {
    let onMenuTapped: () -> Void
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: TaskViewModel?
    @State private var showingAddTask = false

    // Grade prompt
    @State private var gradeTarget: Assignment? = nil
    @State private var showGradeSheet = false
    @State private var tempGrade: Double = 4.0
    
    // Edit assignment
    @State private var editingAssignment: Assignment? = nil

    init(onMenuTapped: @escaping () -> Void = {}) {
        self.onMenuTapped = onMenuTapped
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                AssignmentsContentView(
                    onMenuTapped: onMenuTapped,
                    viewModel: vm,
                    showingAddTask: $showingAddTask,
                    editingAssignment: $editingAssignment,
                    onToggle: { assignment, newValue in
                        handleToggle(assignment, newValue: newValue)
                    }
                )
            } else {
                ProgressView()
                    .onAppear {
                        let vm = TaskViewModel(modelContext: modelContext)
                        self.viewModel = vm
                        vm.loadAssignments()
                    }
            }
        }
        .onChange(of: showingAddTask) { isShowing in
            if !isShowing { viewModel?.loadAssignments() }
        }
        // Grade sheet
        .sheet(isPresented: $showGradeSheet, onDismiss: { viewModel?.loadAssignments() }) {
            if let a = gradeTarget {
                GradePromptSheet(
                    title: a.title,
                    initial: tempGrade,
                    onSave: { g in
                        viewModel?.setGrade(a, grade: g)
                    },
                    onSkip: {
                        viewModel?.setGrade(a, grade: nil)
                    }
                )
                .presentationDetents([.height(260)])
            } else {
                Text("No assignment selected").padding()
            }
        }
        // Edit sheet
        .sheet(item: $editingAssignment) { assignment in
            if let vm = viewModel {
                EditTaskView(viewModel: vm, assignment: assignment)
            }
        }
    }

    // MARK: - Toggle handler (done/undone)
    private func handleToggle(_ a: Assignment, newValue: Bool) {
        viewModel?.toggleComplete(a, to: newValue)
        // si se marca como done y pesa > 0% y no tiene nota -> pedir grade
        if newValue, a.weightPct > 0, a.grade == nil {
            gradeTarget = a
            tempGrade = 4.0
            showGradeSheet = true
        }
    }
}

// MARK: - Inner content that OBSERVES the VM
private struct AssignmentsContentView: View {
    let onMenuTapped: () -> Void
    @ObservedObject var viewModel: TaskViewModel
    @Binding var showingAddTask: Bool
    @Binding var editingAssignment: Assignment?
    @Environment(\.modelContext) private var modelContext

    // desde el host
    let onToggle: (_ assignment: Assignment, _ newValue: Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
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
                    Color.clear.frame(width: 24)
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 60)
            .background(Color(hex: "#B8C8DB"))

            ScrollView {
                VStack(spacing: 16) {

                    // Smart Planning card
                    if !viewModel.workloadRecommendation.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text("Smart Planning")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(UI.navy)
                            }
                            Text(viewModel.workloadRecommendation)
                                .font(.body)
                                .foregroundColor(UI.navy)
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.15))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }

                    // Lists
                    VStack(alignment: .leading, spacing: 12) {
                        Text("All Assignments")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(UI.navy)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        let pending = viewModel.assignments.filter { !$0.isCompleted }
                        let finished = viewModel.assignments.filter { $0.isCompleted }

                        if pending.isEmpty && finished.isEmpty {
                            EmptyState()
                        } else {
                            if !pending.isEmpty {
                                SectionHeader(text: "Pending")
                                ForEach(pending) { a in
                                    AssignmentCardRow(
                                        assignment: a,
                                        onToggle: { newValue in
                                            onToggle(a, newValue)
                                        },
                                        onEdit: {
                                            editingAssignment = a
                                        },
                                        onDelete: {
                                            viewModel.deleteAssignment(a)
                                        }
                                    )
                                    .padding(.horizontal, 20)
                                }
                                Spacer(minLength: 8)
                            }

                            if !finished.isEmpty {
                                SectionHeader(text: "Finished")
                                ForEach(finished) { a in
                                    AssignmentCardRow(
                                        assignment: a,
                                        onToggle: { newValue in
                                            onToggle(a, newValue)
                                        },
                                        onEdit: {
                                            editingAssignment = a
                                        },
                                        onDelete: {
                                            viewModel.deleteAssignment(a)
                                        }
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                    }

                    Spacer().frame(height: 80)
                }
            }
            .background(UI.neutralLight)
        }
        // FAB
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingAddTask = true }) {
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
            }
        )
        .sheet(isPresented: $showingAddTask) {
            AssignmentView()
                .environment(\.modelContext, modelContext)
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Row (shows type, priority, due date, grade)
private struct AssignmentCardRow: View {
    let assignment: Assignment
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { onToggle(!assignment.isCompleted) } label: {
                Image(systemName: assignment.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(assignment.isCompleted ? .green : .gray)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(assignment.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    pill(assignment.subject, system: "book")
                    pill(assignment.type,    system: "list.bullet.rectangle")
                }

                HStack(spacing: 12) {
                    if let dueDate = assignment.dueDate {
                        Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                        
                    Label(assignment.priority, systemImage: "flag")
                        .font(.caption)
                        .foregroundStyle(priorityColor)
                }

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

    private var priorityColor: Color {
        switch assignment.priority.lowercased() {
        case "high":   return .red
        case "medium": return .orange
        default:       return .green
        }
    }
}

// MARK: - Grade sheet
private struct GradePromptSheet: View {
    let title: String
    @State var value: Double
    let onSave: (Double) -> Void
    let onSkip: () -> Void

    init(title: String, initial: Double, onSave: @escaping (Double) -> Void, onSkip: @escaping () -> Void) {
        self.title = title
        self._value = State(initialValue: initial)
        self.onSave = onSave
        self.onSkip = onSkip
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set grade for")
                .font(.footnote).foregroundStyle(.secondary)
            Text(title).font(.headline)

            HStack {
                Text("Grade").bold()
                Spacer()
                Text(String(format: "%.1f / 5.0", value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: 0...5, step: 0.1)

            HStack {
                Button("Skip") { onSkip() }
                Spacer()
                Button("Save") { onSave(value) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }
}

// MARK: - Little helpers
private struct SectionHeader: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundColor(UI.muted)
            Text("No assignments yet")
                .font(.body)
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
