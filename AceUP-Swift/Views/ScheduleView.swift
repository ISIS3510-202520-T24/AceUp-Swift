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
                service: ScheduleOCRService(),
                localStore: ScheduleLocalStore.shared
            )
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            topBar

            ScrollView {
                VStack(spacing: 24) {
                    previewHeader
                    stateMessage
                    manualScheduleSection
                    actionButtons
                    saveButton
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

            // Espaciador visual
            Color.clear
                .frame(width: 24)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(hex: "#B8C8DB"))
    }

    // MARK: - Preview imagen

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

    // MARK: - Mensaje según estado

    private var stateMessage: some View {
        Group {
            switch viewModel.state {
            case .idle, .capturing:
                Text("Use the camera, pick a photo or enter your schedule manually.")
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
                Text("Your schedule is ready. You can adjust it manually if needed, then save it to see it in the calendar.")
                    .font(.body)
                    .foregroundColor(UI.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

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
                }
            }
        }
    }

    // MARK: - Botón para horario manual (crear o COMPLETAR y editar)

    private var manualScheduleSection: some View {
        VStack(spacing: 8) {
            Text("If you prefer, you can enter your schedule manually. This works even when you're offline.")
                .font(.footnote)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button {
                handleManualButtonTapped()
            } label: {
                Label("Enter schedule manually", systemImage: "square.and.pencil")
            }
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
            // 2. Si solo vino miércoles/viernes (por ejemplo),
            //    añadimos los días faltantes vacíos
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Use Camera", systemImage: "camera")
                        .foregroundColor(offlineManager.isOnline ? UI.navy : UI.muted)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!offlineManager.isOnline)

                Button {
                    showLibrary = true
                } label: {
                    Label("From Photos", systemImage: "photo")
                        .foregroundColor(offlineManager.isOnline ? UI.navy : UI.muted)
                }
                .buttonStyle(.bordered)
                .disabled(!offlineManager.isOnline)

                Button("Reset") {
                    viewModel.reset()
                }
                .buttonStyle(.bordered)
            }

            if !offlineManager.isOnline {
                Text("You are offline. You can edit your schedule manually but capturing from camera is disabled.")
                    .font(.footnote)
                    .foregroundColor(UI.muted)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Botón Save

    private var saveButton: some View {
        Button {
            viewModel.saveCurrentSchedule()
            onDone()   // volver al calendario (AppNavigationView hace selectedView = .calendar)
        } label: {
            Text("Save and go to calendar")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 16)
    }
}
