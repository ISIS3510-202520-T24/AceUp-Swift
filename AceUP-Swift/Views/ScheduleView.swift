import SwiftUI
import UIKit

struct ScheduleView: View {
    let onMenuTapped: () -> Void

    @StateObject private var viewModel: ScheduleViewModel
    @State private var showCamera = false
    @State private var showLibrary = false

    init(onMenuTapped: @escaping () -> Void) {
        self.onMenuTapped = onMenuTapped

        _viewModel = StateObject(
            wrappedValue: ScheduleViewModel(
                service: ScheduleOCRService()
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {

            // Header estilo app
            topBar

            // Contenido scrollable
            ScrollView {
                VStack(spacing: 24) {
                    previewHeader
                    mainContent
                    actionRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
            .background(UI.neutralLight)
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { img in
                viewModel.didCapture(image: img)
            }
        }
        .sheet(isPresented: $showLibrary) {
            ImagePicker(sourceType: .photoLibrary) { img in
                viewModel.didCapture(image: img)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header
    private var topBar: some View {
        HStack {
            Button(action: onMenuTapped) {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(UI.navy)
                    .font(.title2)
            }

            Spacer()

            Text("Schedule")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)

            Spacer()

            // Para balancear el HStack visualmente
            Color.clear
                .frame(width: 24)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(hex: "#B8C8DB"))
    }

    // MARK: - Imagen capturada o placeholder
    private var previewHeader: some View {
        Group {
            if let image = viewModel.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.secondary)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 180)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 42))
                                .foregroundColor(UI.primary)
                            Text("Capture a photo of your schedule")
                                .font(.subheadline)
                                .foregroundColor(UI.muted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    )
            }
        }
    }

    // MARK: - Estado dinámico
    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.state {
        case .idle, .capturing:
            Text("Ready to capture. Use the camera or pick from Photos.")
                .font(.body)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

        case .sending:
            VStack(spacing: 12) {
                ProgressView("Parsing schedule with AI…")
                Text("We're extracting your classes, times and days.")
                    .font(.footnote)
                    .foregroundColor(UI.muted)
            }

        case .parsed:
            if viewModel.schedule.days.isEmpty {
                Text("No classes detected.")
                    .font(.body)
                    .foregroundColor(UI.muted)
            } else {
                scheduleListView()
            }

        case .error(let msg):
            VStack(spacing: 8) {
                Text("Couldn't parse schedule")
                    .font(.headline)
                    .foregroundColor(UI.navy)

                Text(msg)
                    .font(.footnote)
                    .foregroundColor(UI.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Button("Try Again") {
                    viewModel.reset()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Botones cámara / galería / reset
    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                showCamera = true
            } label: {
                Label("Use Camera", systemImage: "camera")
            }
            .buttonStyle(.borderedProminent)

            Button {
                showLibrary = true
            } label: {
                Label("From Photos", systemImage: "photo")
            }
            .buttonStyle(.bordered)

            if case .parsed = viewModel.state {
                Button("Reset") {
                    viewModel.reset()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func orderIndex(for weekday: Weekday) -> Int {
    switch weekday {
    case .monday: return 0
    case .tuesday: return 1
    case .wednesday: return 2
    case .thursday: return 3
    case .friday: return 4
    case .saturday: return 5
    case .sunday: return 6
    }
}

    @ViewBuilder
private func scheduleListView() -> some View {
    VStack(alignment: .leading, spacing: 24) {

        // Ordenar por el orden que tú quieras.
        // El JSON de la IA actualmente viene en este orden:
        // sunday, monday, tuesday, wednesday, thursday, friday, saturday
        // Podemos mantenerlo así, o reordenar a Lunes..Sábado..Domingo.
        //
        // Te lo voy a dejar ya ordenado Lunes->Domingo, que es más normal pa' la U.

        let orderedDays: [ScheduleDay] = viewModel.schedule.days.sorted {
            orderIndex(for: $0.weekday) < orderIndex(for: $1.weekday)
        }

        ForEach(orderedDays, id: \.weekday) { day in
            VStack(alignment: .leading, spacing: 12) {

                Text(day.weekday.display)
                    .font(.headline)
                    .foregroundColor(UI.navy)

                if day.sessions.isEmpty {
                    Text("No classes")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                } else {

                    ForEach(day.sessions, id: \.self) { session in
                        HStack(alignment: .firstTextBaseline) {

                            // horario
                            Text("\(session.start ?? "—")–\(session.end ?? "—")")
                                .font(.caption)
                                .monospacedDigit()
                                .frame(width: 96, alignment: .leading)
                                .foregroundColor(UI.navy)

                            VStack(alignment: .leading, spacing: 2) {
                                // nombre materia
                                Text(session.course)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(UI.navy)

                                if let loc = session.location, !loc.isEmpty {
                                    Text(loc)
                                        .font(.caption)
                                        .foregroundColor(UI.muted)
                                }

                                if let n = session.notes, !n.isEmpty {
                                    Text(n)
                                        .font(.caption2)
                                        .foregroundColor(UI.muted)
                                }
                            }

                            Spacer()
                        }
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}
}
