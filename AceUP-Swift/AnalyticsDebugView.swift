// AnalyticsDebugView.swift (solo para pruebas)
import SwiftUI

struct AnalyticsDebugView: View {
    @State private var assignmentId = ""
    @State private var gradeText = "4.5"
    @State private var status = "—"

    let provider = HybridAssignmentDataProvider()
    
    var body: some View {
        Form {
            Section(header: Text("Assignment")) {
                TextField("assignmentId", text: $assignmentId)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }

            Section(header: Text("Acciones")) {
                Button("Marcar como completada") {
                    Task {
                        do {
                            try await provider.markCompleted(id: assignmentId)
                            status = "Completed enviado"
                        } catch {
                            status = "\(error.localizedDescription)"
                        }
                    }
                }

                HStack {
                    TextField("Nueva nota (Double)", text: $gradeText)
                        .keyboardType(.decimalPad)
                    Button("Actualizar nota") {
                        Task {
                            do {
                                let g = Double(gradeText) ?? 0
                                try await provider.markCompleted(id: assignmentId)
                                status = "Grade \(g) enviado"
                            } catch {
                                status = "\(error.localizedDescription)"
                            }
                        }
                    }
                }
            }

            Section(header: Text("Estado")) {
                Text(status)
                    .font(.subheadline)
            }
        }
        .navigationTitle("Analytics Lab")
    }
}
