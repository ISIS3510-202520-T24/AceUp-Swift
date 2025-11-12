import SwiftUI

struct CalendarView: View {
    // igual patrón que las demás pantallas (TodayView, etc.)
    let onMenuTapped: () -> Void

    // controla sheet para la cámara / OCR
    @State private var showScheduleCapture = false

    var body: some View {
        VStack(spacing: 0) {

            // Barra superior estilo de tu app
            headerBar

            // Contenido principal (tu calendario + explicación)
            ScrollView {
                VStack(spacing: 30) {

                    Spacer().frame(height: 40)

                    // Aquí eventualmente va tu calendario real mensual / semanal.
                    // Por ahora dejamos el placeholder visual que ya usabas.
                    Image(systemName: "calendar")
                        .font(.system(size: 80))
                        .foregroundColor(UI.primary)

                    VStack(spacing: 12) {
                        Text("Calendar")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(UI.navy)

                        Text("Monthly calendar view will be implemented here.\nYou can also scan your class schedule with the camera.")
                            .font(.body)
                            .foregroundColor(UI.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    Spacer()
                }
                .background(UI.neutralLight)
            }
        }
        .sheet(isPresented: $showScheduleCapture) {
            // presentamos la vista de captura/IA en un modal
            // en el modal no necesitamos abrir el sidebar,
            // así que le pasamos onMenuTapped: {} vacío.
            ScheduleView(onMenuTapped: { })
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header con menú a la izquierda y cámara a la derecha
    private var headerBar: some View {
        HStack {
            // Botón menú lateral (abre/cierra sidebar exactamente como en las otras pantallas)
            Button(action: onMenuTapped) {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(UI.navy)
                    .font(.title2)
            }

            Spacer()

            // Título centrado igual que el resto de pantallas
            Text("Calendar")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)

            Spacer()

            // Botón cámara (quí es donde lanzamos la captura del horario)
            Button(action: {
                showScheduleCapture = true
            }) {
                Image(systemName: "camera.viewfinder")
                    .foregroundColor(UI.navy)
                    .font(.title2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(hex: "#B8C8DB"))
    }
}