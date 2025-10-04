//
//  AddTaskView.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 3/10/25.
//

import SwiftUI
import SwiftData


struct AssignmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var subject: Subject? = nil
    @State private var assignmentType: AssignmentType? = nil
    @State private var title: String = ""
    @State private var isDone: Bool = false
    @State private var descriptionText: String = ""
    @State private var dueDate: Date? = nil
    @State private var priority: Priority? = nil

    // Numéricos
    @State private var estimatedHours: Int = 2
    @State private var weightPct: Double = 20.0
    @State private var gradeValue: Double = 4.0

    
    init(defaultDueDate: Date? = nil,
         defaultType: AssignmentType? = nil,
         defaultSubject: Subject? = nil) {
        _dueDate = State(initialValue: defaultDueDate)
        _assignmentType = State(initialValue: defaultType)
        _subject = State(initialValue: defaultSubject)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Subject
                    MenuPickerField(
                        label: "Subject",
                        placeholder: "Subject",
                        selection: $subject,
                        allCases: Subject.allCases
                    ) { subject in
                        Label(subject.rawValue, systemImage: subject.icon)
                    }

                    // Type (Homework / Project / Exam)
                    MenuPickerField(
                        label: "Type",
                        placeholder: "Type",
                        selection: $assignmentType,
                        allCases: AssignmentType.allCases
                    ) { t in
                        Text(t.rawValue)
                    }

                    // Title + Done
                    HStack(alignment: .center, spacing: 12) {
                        TextField("Title", text: $title)
                            .textFieldStyle(.roundedBorder)
                        VStack(spacing: 6) {
                            Toggle("", isOn: Binding(
                                get: { isDone },
                                set: { newVal in
                                    isDone = newVal
                                }
                            ))
                            .labelsHidden()
                            Text("Done")
                                .font(.footnote)
                                .foregroundStyle(isDone ? .green : .secondary)
                        }
                    }

                    // Description
                    LabeledTextEditor(placeholder: "Description", text: $descriptionText)

                    // Due date
                    DueDateField(label: "Due date", date: $dueDate)

                    // Priority
                    MenuPickerField(
                        label: "Priority",
                        placeholder: "Priority",
                        selection: $priority,
                        allCases: Priority.allCases
                    ) { p in
                        Text(p.rawValue)
                    }

                    // Estimated hours
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Estimated Hours")
                            Spacer()
                            Text("\(estimatedHours)h")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Stepper("", value: $estimatedHours, in: 1...16)
                            .labelsHidden()
                    }

                    // Weight (%)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Weight")
                            Spacer()
                            Text("\(Int(weightPct))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $weightPct, in: 0...100, step: 5)
                    }

                    // Grade (0..5) – solo si done
                    if isDone {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Grade")
                                Spacer()
                                Text(String(format: "%.1f", gradeValue))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $gradeValue, in: 0...5, step: 0.1)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut, value: isDone)
                    }

                    Spacer(minLength: 12)
                }
                .padding(20)
            }
            .navigationTitle("Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveAssignment() }
                        .bold()
                        .disabled(!canSave)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private var canSave: Bool {
        !title.isEmpty && subject != nil && dueDate != nil
    }

    private func saveAssignment() {
        guard let subject = subject, let dueDate = dueDate else { return }

        let typeRaw = (assignmentType?.rawValue ?? "Homework")

        let assignment = Assignment(
            title: title,
            subject: subject.rawValue,
            type: typeRaw,
            dueDate: dueDate,
            weightPct: clamp(weightPct, 0, 100),
            priority: (priority?.rawValue ?? "Medium"),
            estimatedHours: estimatedHours,
            description: descriptionText.isEmpty ? nil : descriptionText
        )

        assignment.isCompleted = isDone
        assignment.completedAt = isDone ? Date() : nil
        assignment.grade = isDone ? clamp(gradeValue, 0, 5) : nil

        modelContext.insert(assignment)
        try? modelContext.save()
        dismiss()
    }

    private func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T {
        min(hi, max(lo, v))
    }
}

// MARK: - Reusables

struct LabeledTextEditor: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .padding(12)
                .frame(minHeight: 120)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.35), lineWidth: 1))
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
        }
    }
}

struct DueDateField: View {
    let label: String
    @Binding var date: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker(
                "Due date",
                selection: Binding(
                    get: { date ?? Date() },
                    set: { date = $0 }
                ),
                in: Date()...,
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.35), lineWidth: 1)
            )
        }
    }
}

struct MenuPickerField<T: Hashable & CaseIterable & RawRepresentable>: View where T.RawValue == String {
    let label: String
    let placeholder: String
    @Binding var selection: T?
    let allCases: [T]
    let row: (T) -> any View

    init(label: String, placeholder: String, selection: Binding<T?>, allCases: [T], row: @escaping (T) -> some View) {
        self.label = label
        self.placeholder = placeholder
        self._selection = selection
        self.allCases = allCases
        self.row = row
    }

    var body: some View {
        Menu {
            ForEach(allCases, id: \.self) { item in
                Button(action: { selection = item }) {
                    AnyView(row(item))
                }
            }
        } label: {
            HStack {
                Text(selectionText)
                    .foregroundStyle(selection == nil ? .gray : .primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.35), lineWidth: 1))
        }
        .accessibilityLabel(label)
    }

    private var selectionText: String {
        selection.map { $0.rawValue } ?? placeholder
    }
}

// MARK: - Enums

enum Subject: String, CaseIterable, Hashable {
    case math = "Mathematics"
    case physics = "Physics"
    case cs = "Computer Science"
    case literature = "Literature"

    var icon: String {
        switch self {
        case .math: return "function"
        case .physics: return "atom"
        case .cs: return "desktopcomputer"
        case .literature: return "book.closed"
        }
    }
}

enum Priority: String, CaseIterable, Hashable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum AssignmentType: String, CaseIterable, Hashable {
    case homework = "Homework"
    case project  = "Project"
    case exam     = "Exam"
}
