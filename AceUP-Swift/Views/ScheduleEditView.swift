import SwiftUI

struct ScheduleEditView: View {
    @Binding var schedule: Schedule
    var onSave: (Schedule) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(schedule.days.indices, id: \.self) { dayIndex in
                    let dayBinding = $schedule.days[dayIndex]

                    Section(dayBinding.wrappedValue.weekday.display) {
                        // Lista de clases de ese día
                        ForEach(dayBinding.sessions.indices, id: \.self) { sessionIndex in
                            // Binding directo a una sesión específica
                            SessionRowView(
                                session: dayBinding.sessions[sessionIndex]
                            )
                        }
                        .onDelete { indexSet in
                            dayBinding.sessions.wrappedValue.remove(atOffsets: indexSet)
                        }

                        // Botón para agregar una clase a ese día
                        Button {
                            dayBinding.sessions.wrappedValue.append(
                                ScheduleSession(
                                    course: "",
                                    start: nil,
                                    end: nil,
                                    location: nil,
                                    notes: nil
                                )
                            )
                        } label: {
                            Label("Add class", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("Edit schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(schedule)   // devuelve el horario editado
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Fila de edición de una clase con time pickers

private struct SessionRowView: View {
    @Binding var session: ScheduleSession

    // DatePickers usan Date; aquí guardamos la hora de inicio y fin
    @State private var startDate: Date
    @State private var endDate: Date

    // Formatter para convertir entre "HH:mm" y Date
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func defaultStart() -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 8
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    private static func defaultEnd() -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 10
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    init(session: Binding<ScheduleSession>) {
        self._session = session

        let formatter = Self.timeFormatter

        // Parsear las strings iniciales (si existen) a Date
        if let startString = session.wrappedValue.start,
           let parsed = formatter.date(from: startString) {
            _startDate = State(initialValue: parsed)
        } else {
            _startDate = State(initialValue: Self.defaultStart())
        }

        if let endString = session.wrappedValue.end,
           let parsed = formatter.date(from: endString) {
            _endDate = State(initialValue: parsed)
        } else {
            _endDate = State(initialValue: Self.defaultEnd())
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Nombre de la materia
            TextField("Course", text: $session.course)
                .font(.headline)

            // Picker de hora de inicio y fin
            HStack {
                DatePicker(
                    "Start",
                    selection: $startDate,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .onChange(of: startDate) { newValue in
                    session.start = Self.timeFormatter.string(from: newValue)
                }

                DatePicker(
                    "End",
                    selection: $endDate,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .onChange(of: endDate) { newValue in
                    session.end = Self.timeFormatter.string(from: newValue)
                }
            }

            // Salón / ubicación
            TextField("Location", text: Binding(
                get: { session.location ?? "" },
                set: { newValue in
                    session.location = newValue.isEmpty ? nil : newValue
                }
            ))
            .textFieldStyle(.roundedBorder)

            // Notas adicionales
            TextField("Notes", text: Binding(
                get: { session.notes ?? "" },
                set: { newValue in
                    session.notes = newValue.isEmpty ? nil : newValue
                }
            ))
            .textFieldStyle(.roundedBorder)
        }
        .padding(.vertical, 4)
    }
}
