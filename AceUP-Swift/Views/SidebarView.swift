//
//  SidebarView.swift
//  AceUp-Swift
//
//  Created by Ángel Farfán Arcila on 19/09/25.
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedView: AppView
    @Binding var isPresented: Bool
    @Environment(\.verticalSizeClass) private var vClass   // para ajustar en landscape

    // Perfil (nick + avatar) para el menú de encabezado
    @State private var currentEmail: String = LoginLocalStore.shared.lastEmail
    @State private var currentNick: String = ""
    @State private var showAvatarSheet: Bool = false

    // Fuerza reconstrucción del label del Menu (sin NotificationCenter)
    @State private var avatarVersion = UUID()
    
    // Offline manager for connectivity status
    @ObservedObject private var offlineManager = OfflineManager.shared

    var isLandscape: Bool { vClass == .compact } // en iPhone landscape suele ser .compact

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {

                // Header con título y menú de perfil (avatar + nick)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Text("AceUp")
                            .font(isLandscape ? .title3 : .title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        Spacer()

                        // Menú desplegable con avatar + nick (label)
                        Menu {
                            Button("Cambiar avatar") {
                                showAvatarSheet = true
                            }
                            // Puedes agregar más acciones (Perfil, Ajustes, Cerrar sesión) aquí.
                        } label: {
                            HStack(spacing: 8) {
                                AvatarImageView(email: currentEmail, size: 28)
                                Text(displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .contentShape(Rectangle())
                        }
                        // 👇 esto obliga a reconstruir el label cuando cambie avatarVersion
                        .id(avatarVersion)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(UI.navy)  // el azul del screenshot

                // HAZ EL MENÚ SCROLLABLE
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // -- Sección: My Schedules
                        VStack(alignment: .leading, spacing: 8) {
                            Text("My Schedules")
                                .font(.title3).fontWeight(.semibold)
                                .foregroundColor(UI.navy)
                                .padding(.horizontal, 24)
                                .padding(.top, isLandscape ? 12 : 20)
                                .padding(.bottom, 10)

                            MenuItemView(icon: nil, title: "Today",
                                         isSelected: selectedView == .today) {
                                selectedView = .today; isPresented = false
                            }

                            MenuItemView(icon: nil, title: "Week View",
                                         isSelected: selectedView == .weekView) {
                                selectedView = .weekView; isPresented = false
                            }

                            MenuItemView(icon: nil, title: "Calendar",
                                         isSelected: selectedView == .calendar) {
                                selectedView = .calendar; isPresented = false
                            }

                            // Shared calendars - disabled when offline
                            MenuItemView(
                                icon: offlineManager.isOnline ? nil : "wifi.slash",
                                title: "Shared",
                                isSelected: selectedView == .sharedCalendars,
                                isDisabled: !offlineManager.isOnline
                            ) {
                                if offlineManager.isOnline {
                                    selectedView = .sharedCalendars; isPresented = false
                                }
                            }
                            
                            // Show offline message for shared calendars
                            if !offlineManager.isOnline {
                                Text("Requires internet connection")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.leading, 48)
                                    .padding(.top, -6)
                            }
                        }

                        // -- Sección: My Data
                        VStack(alignment: .leading, spacing: 8) {
                            Text("My Data")
                                .font(.title3).fontWeight(.semibold)
                                .foregroundColor(UI.navy)
                                .padding(.horizontal, 24)
                                .padding(.top, isLandscape ? 12 : 20)
                                .padding(.bottom, 10)

                            MenuItemView(icon: nil, title: "Planner",
                                         isSelected: selectedView == .planner) {
                                selectedView = .planner; isPresented = false
                            }

                            MenuItemView(icon: nil, title: "Assignments",
                                         isSelected: selectedView == .assignments) {
                                selectedView = .assignments; isPresented = false
                            }

                            MenuItemView(icon: nil, title: "Teachers",
                                         isSelected: selectedView == .teachers) {
                                selectedView = .teachers; isPresented = false
                            }

                            MenuItemView(icon: nil, title: "Holidays",
                                         isSelected: selectedView == .holidays) {
                                selectedView = .holidays; isPresented = false
                            }
                        }

                        // Settings fijo al final del scroll
                        MenuItemView(icon: "gear", title: "Settings",
                                     isSelected: selectedView == .settings) {
                            selectedView = .settings; isPresented = false
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                    }
                    .background(UI.neutralLight)
                    .padding(.bottom, 8) // aire para que no quede pegado al borde
                }
            }
            .background(UI.neutralLight)
            // Gesto para cerrar deslizando hacia la izquierda (opcional pero útil)
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.width < -60 {
                        withAnimation(.easeInOut) { isPresented = false }
                    }
                }
            )
            .onAppear { loadSnapshot() }
            .onChange(of: showAvatarSheet) { _, presented in
                // Al cerrarse la hoja, recargamos snapshot y forzamos reconstrucción del label del Menu
                if !presented {
                    loadSnapshot()
                    avatarVersion = UUID() // 👈 clave para que AvatarImageView re-ejecute onAppear()
                }
            }
            .sheet(isPresented: $showAvatarSheet) {
                AvatarPickerSheet(email: currentEmail, currentNick: currentNick)
            }
        }
    }

    // MARK: - Helpers

    /// Muestra nick si existe; si no, email; si tampoco, un texto genérico.
    private var displayName: String {
        if !currentNick.isEmpty { return currentNick }
        if !currentEmail.isEmpty { return currentEmail }
        return "Profile"
    }

    /// Carga nick y email desde cache para pintar instantáneo
    private func loadSnapshot() {
        let email = LoginLocalStore.shared.lastEmail
        currentEmail = email
        if let snap = ProfileSnapshotCache.shared.get(email: email) {
            currentNick = snap.nick ?? ""
        } else {
            currentNick = ""
        }
    }
}


/// Ítem de menú estándar
struct MenuItemView: View {
    let icon: String?
    let title: String
    let isSelected: Bool
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                
                if let iconName = icon {
                    Image(systemName: iconName)
                        .font(.body)
                        .foregroundColor(isDisabled ? .gray : UI.muted)
                        .frame(width: 20, height: 20)
                } else {
                    Circle()
                        .fill(isDisabled ? Color.gray : UI.primary)
                        .frame(width: 12, height: 12)
                }
                
                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isDisabled ? .gray : UI.navy)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                isSelected ? UI.primary.opacity(0.1) : Color.clear
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

enum AppView {
    case login
    case today
    case weekView
    case calendar
    case sharedCalendars
    case groupCalendar
    case planner
    case assignments
    case teachers
    case holidays
    case profile
    case settings
    case scheduleOCR
}

#Preview {
    SidebarView(
        selectedView: .constant(.today),
        isPresented: .constant(true)
    )
}
