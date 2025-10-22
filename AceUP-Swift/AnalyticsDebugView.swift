import SwiftUI

struct AnalyticsDebugView: View {

    // Usa el repositorio para disparar eventos y persistir
    @StateObject private var repo = AssignmentRepository()

    // Inputs
    @State private var assignmentId: String = ""
    @State private var gradeText: String = ""

    // UI
    @State private var status: String = "—"

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Datos del evento")) {
                    TextField("Assignment ID", text: $assignmentId)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    TextField("Grade (opcional, ej: 4.5)", text: $gradeText)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }

                Section(header: Text("Acciones")) {
                    Button("Actualizar nota (grade_recorded)") {
                        Task { await sendUpdateGrade() }
                    }

                    Button("Marcar como completada (assignment_completed)") {
                        Task { await sendMarkCompleted() }
                    }
                }

                Section(header: Text("Estado")) {
                    Text(status).font(.callout).foregroundColor(.secondary)
                }
                // -------- NUEVO: Due < 3 horas (resumen inmediato) --------
                Section(header: Text("BQ • Due < 3h (resumen)")) {
                    Button("Ver en consola (due < 3h, no done)") {
                        Task { await debugListDueWithin3h() }
                    }
                    Button("Avisar ahora (notificación resumen)") {
                        Task {
                            await NotificationService.notifyAssignmentsDueWithin3Hours(using: repo)
                            status = "Notificación resumen (due < 3h) disparada ✅"
                        }
                    }
                }

                Section(header: Text("Estado")) {
                    Text(status).font(.callout).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Analytics Debug")
        }
    }

    // MARK: - Helpers

    private func parsedGrade() -> Double? {
        let t = gradeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return Double(t.replacingOccurrences(of: ",", with: "."))
    }

    private func sendUpdateGrade() async {
        guard !assignmentId.isEmpty else { status = "Falta Assignment ID"; return }
        do {
            try await repo.updateGrade(assignmentId, grade: parsedGrade())
            status = "grade_recorded enviado ✅"
        } catch {
            status = "Error updateGrade: \(error.localizedDescription)"
        }
    }

    private func sendMarkCompleted() async {
        guard !assignmentId.isEmpty else { status = "Falta Assignment ID"; return }
        do {
            try await repo.markCompleted(assignmentId, finalGrade: parsedGrade())
            status = "assignment_completed enviado ✅"
        } catch {
            status = "Error markCompleted: \(error.localizedDescription)"
        }
    }
    
    private func debugListDueWithin3h() async {
        let now = Date()
        do {
            // Trae los de HOY que no están completados
            let allToday = try await repo.fetchDueTodayNotDone(now: now)
            // Filtra los que vencen dentro de las próximas 3 horas
            let threeHours = Calendar.current.date(byAdding: .hour, value: 3, to: now) ?? now
            let dueSoon = allToday
                .filter { $0.dueDate > now && $0.dueDate <= threeHours }
                .sorted { $0.dueDate < $1.dueDate }

            print("🔎 Due < 3h (no done): \(dueSoon.count)")
            let df = DateFormatter()
            df.dateStyle = .none
            df.timeStyle = .short

            for a in dueSoon {
                print("• \(a.title) — due \(df.string(from: a.dueDate))")
            }

            await MainActor.run {
                status = "Consola: due < 3h = \(dueSoon.count) ✅"
            }
        } catch {
            await MainActor.run {
                status = "Error listando <3h: \(error.localizedDescription)"
            }
        }
    }
}
