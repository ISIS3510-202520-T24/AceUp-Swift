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
}
