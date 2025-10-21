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

    var isLandscape: Bool { vClass == .compact } // en iPhone landscape suele ser .compact

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {

                // Header
                VStack(alignment: .leading, spacing: 0) {
                    Text("AceUp")
                        .font(isLandscape ? .title3 : .title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(UI.navy)  // el azul del screenshot

                //HAZ EL MENÚ SCROLLABLE
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

                            MenuItemView(icon: nil, title: "Shared",
                                         isSelected: selectedView == .sharedCalendars) {
                                selectedView = .sharedCalendars; isPresented = false
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
        }
    }
}


struct MenuItemView: View {
    let icon: String?
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                
                if let iconName = icon {
                    Image(systemName: iconName)
                        .font(.body)
                        .foregroundColor(UI.muted)
                        .frame(width: 20, height: 20)
                } else {
                    Circle()
                        .fill(UI.primary)
                        .frame(width: 12, height: 12)
                }
                
                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                isSelected ? UI.primary.opacity(0.1) : Color.clear
            )
        }
        .buttonStyle(.plain)
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
}

#Preview {
    SidebarView(
        selectedView: .constant(.today),
        isPresented: .constant(true)
    )
}
