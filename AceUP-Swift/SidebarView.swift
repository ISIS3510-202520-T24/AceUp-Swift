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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            VStack(alignment: .leading, spacing: 0) {
                Text("AceUp")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(UI.navy)
            
            
            VStack(alignment: .leading, spacing: 0) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Schedules")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    MenuItemView(
                        icon: nil,
                        title: "Today",
                        isSelected: selectedView == .today,
                        action: {
                            selectedView = .today
                            isPresented = false
                        }
                    )
                    
                    MenuItemView(
                        icon: nil,
                        title: "Week View",
                        isSelected: selectedView == .weekView,
                        action: {
                            selectedView = .weekView
                            isPresented = false
                        }
                    )
                    
                    MenuItemView(
                        icon: nil,
                        title: "Calendar",
                        isSelected: selectedView == .calendar,
                        action: {
                            selectedView = .calendar
                            isPresented = false
                        }
                    )
                    
                    MenuItemView(
                        icon: nil,
                        title: "Shared",
                        isSelected: selectedView == .sharedCalendars,
                        action: {
                            selectedView = .sharedCalendars
                            isPresented = false
                        }
                    )
                }
                
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Data")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    MenuItemView(
                        icon: nil,
                        title: "Planner",
                        isSelected: selectedView == .planner,
                        action: {
                            selectedView = .planner
                            isPresented = false
                        }
                    )
                    
                    MenuItemView(
                        icon: nil,
                        title: "Assignments",
                        isSelected: selectedView == .assignments,
                        action: {
                            selectedView = .assignments
                            isPresented = false
                        }
                    )
                    
                    MenuItemView(
                        icon: nil,
                        title: "Teachers",
                        isSelected: selectedView == .teachers,
                        action: {
                            selectedView = .teachers
                            isPresented = false
                        }
                    )
                    
                    MenuItemView(
                        icon: nil,
                        title: "Holidays",
                        isSelected: selectedView == .holidays,
                        action: {
                            selectedView = .holidays
                            isPresented = false
                        }
                    )
                }
                
                Spacer()
                
                
                MenuItemView(
                    icon: "gear",
                    title: "Settings",
                    isSelected: selectedView == .settings,
                    action: {
                        selectedView = .settings
                        isPresented = false
                    }
                )
                .padding(.bottom, 20)
            }
            .background(UI.neutralLight)
        }
        .frame(width: 280)
        .background(UI.neutralLight)
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