import SwiftUI
import UIKit

struct ScheduleView: View {
    let onMenuTapped: () -> Void
    let onDone: () -> Void       // Para volver al Calendar luego de guardar

    @StateObject private var viewModel: ScheduleViewModel
    @ObservedObject private var offlineManager = OfflineManager.shared

    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var showEditor = false

    // Lista fija de días para crear / completar el horario
    private let allWeekdays: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday,
        .friday, .saturday, .sunday
    ]

    init(onMenuTapped: @escaping () -> Void,
         onDone: @escaping () -> Void) {
        self.onMenuTapped = onMenuTapped
        self.onDone = onDone

        _viewModel = StateObject(
            wrappedValue: ScheduleViewModel(
                service: ScheduleOCRService()
            )
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Fondo general crema (o el que tengas en UI.neutralLight)
            UI.neutralLight
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(spacing: 20) {
                        stepHeader

                        card {
                            previewHeader
                        }

                        card {
                            stateMessage
                        }

                        card {
                            manualScheduleSection
                        }

                        card {
                            actionButtons
                        }

                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
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
        .sheet(isPresented: $showEditor) {
            ScheduleEditView(
                schedule: $viewModel.schedule,
                onSave: { edited in
                    viewModel.applyManualChanges(edited)
                }
            )
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadSavedSchedule()
        }
    }

    // MARK: - Reusable Card

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    // MARK: - Header barra superior

    private var topBar: some View {
        ZStack {
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

                // Espaciador visual para balancear el ícono del menú
                Color.clear
                    .frame(width: 24)
            }
            .padding(.horizontal, 20)
        }
        // Altura más pequeña + respeta el safe area superior
        .frame(height: 52)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            Color(hex: "#B8C8DB")
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Header de pasos

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Set up your weekly schedule")
                .font(.headline)
                .foregroundColor(UI.navy)

            Text("1) Capture or enter it • 2) Adjust details • 3) Save and see it in your calendar.")
                .font(.footnote)
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Preview imagen

    private var previewHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step 1 – Capture your schedule")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(UI.navy)

            Group {
                if let image = viewModel.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.secondary.opacity(0.3))
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
                                Text("Capture a photo of your timetable")
                                    .font(.subheadline)
                                    .foregroundColor(UI.muted)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                        )
                }
            }
        }
    }

    // MARK: - Mensaje según estado

    private var stateMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step 2 – Let the AI parse it")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(UI.navy)

            Group {
                switch viewModel.state {
                case .idle, .capturing:
                    Text("Use the camera, pick a photo or enter your schedule manually. We’ll extract your classes and times for you.")
                        .font(.body)
                        .foregroundColor(UI.muted)

                case .sending:
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView("Parsing schedule with AI…")
                        Text("We're extracting your classes, days and times.")
                            .font(.footnote)
                            .foregroundColor(UI.muted)
                    }

                case .parsed:
                    Text("Your schedule is ready. You can adjust it manually if needed before saving it to the calendar.")
                        .font(.body)
                        .foregroundColor(UI.muted)

                case .error(let msg):
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Couldn't parse schedule")
                            .font(.headline)
                            .foregroundColor(.red)

                        Text(msg)
                            .font(.footnote)
                            .foregroundColor(UI.muted)
                    }
                }
            }
        }
    }

    // MARK: - Botón para horario manual (crear o COMPLETAR y editar)

    private var manualScheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Step 3 – Edit it manually (optional)")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(UI.navy)

            Text("If you prefer, you can build or adjust your schedule by hand. This works even when you’re offline.")
                .font(.footnote)
                .foregroundColor(UI.muted)

            Button {
                handleManualButtonTapped()
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("Enter / edit schedule manually")
                }
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
        }
    }

    /// Si ya hay horario (de la IA o previo), se COMPLETA con los días faltantes (L–D) y se edita todo.
    /// Si no hay nada, se crea estructura vacía L–D y se edita.
    private func handleManualButtonTapped() {
        var current = viewModel.schedule

        // 1. Si no hay días aún, creamos todos
        if current.days.isEmpty {
            current.days = allWeekdays.map { weekday in
                ScheduleDay(weekday: weekday, sessions: [])
            }
        } else {
            // 2. Añadir días faltantes vacíos
            let existingWeekdays = Set(current.days.map { $0.weekday })
            for wd in allWeekdays where !existingWeekdays.contains(wd) {
                current.days.append(
                    ScheduleDay(weekday: wd, sessions: [])
                )
            }
        }

        // 3. Ordenar siempre Lunes -> Domingo
        current.days.sort { a, b in
            guard let ia = allWeekdays.firstIndex(of: a.weekday),
                  let ib = allWeekdays.firstIndex(of: b.weekday) else {
                return false
            }
            return ia < ib
        }

        // 4. Guardar en el viewModel y abrir el editor
        viewModel.applyManualChanges(current)
        showEditor = true
    }

    // MARK: - Botones de acción (camera / photos / reset)

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Capture options")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(UI.navy)

            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Use Camera", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(UI.navy)
                .disabled(!offlineManager.isOnline)
            }

            HStack(spacing: 12) {
                Button {
                    showLibrary = true
                } label: {
                    Label("From Photos", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!offlineManager.isOnline)

                Button("Reset") {
                    viewModel.reset()
                }
                .buttonStyle(.bordered)
            }

            if !offlineManager.isOnline {
                Text("You are offline. You can edit your schedule manually, but capturing from camera or photos is disabled.")
                    .font(.footnote)
                    .foregroundColor(UI.muted)
            }
        }
    }

    // MARK: - Botón Save

    private var saveButton: some View {
        Button {
            viewModel.saveCurrentSchedule()
            onDone()   // volver al calendario
        } label: {
            Text("Save and go to calendar")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(UI.primary)
        .padding(.top, 4)
    }
}
