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
                            //Binding directo a una sesión específica
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

// MARK: - Fila de edición de una clase

private struct SessionRowView: View {
    @Binding var session: ScheduleSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Nombre de la materia (totalmente editable)
            TextField("Course", text: $session.course)
                .font(.headline)

            HStack {
                // Hora inicio
                TextField("Start (e.g. 08:00)", text: Binding(
                    get: { session.start ?? "" },
                    set: { newValue in
                        session.start = newValue.isEmpty ? nil : newValue
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numbersAndPunctuation)

                // Hora fin
                TextField("End (e.g. 10:00)", text: Binding(
                    get: { session.end ?? "" },
                    set: { newValue in
                        session.end = newValue.isEmpty ? nil : newValue
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numbersAndPunctuation)
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
