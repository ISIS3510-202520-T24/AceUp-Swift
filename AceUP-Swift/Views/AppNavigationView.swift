//
//  AppNavigationView.swift
//  AceUp-Swift
//
//  Created Ángel Farfán Arcila on 19/09/25.
//

import SwiftUI


struct AppNavigationView: View {
    @State private var selectedView: AppView = .today
    @State private var isSidebarPresented = false
    let onLogout: () -> Void
    
    init(onLogout: @escaping () -> Void = {}) {
        self.onLogout = onLogout
    }
    
    var body: some View {
        ZStack {
            
            Group {
                switch selectedView {
                case .login:
                    LoginView(onLoginSuccess: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            selectedView = .today
                        }
                    })
                case .today:
                    TodayView(onMenuTapped: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarPresented.toggle()
                        }
                    })
                case .weekView:
                    WeekViewPlaceholder(onMenuTapped: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarPresented.toggle()
                        }
                    })
                case .calendar:
                    CalendarPlaceholder(onMenuTapped: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarPresented.toggle()
                        }
                    })
                case .sharedCalendars:
                    SharedCalendarsView(
                        onMenuTapped: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSidebarPresented.toggle()
                            }
                        },
                        onGroupSelected: { groupName in
                            selectedView = .groupCalendar
                        }
                    )
                case .groupCalendar:
                    GroupCalendarView(
                        onMenuTapped: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSidebarPresented.toggle()
                            }
                        },
                        onBackTapped: {
                            selectedView = .sharedCalendars
                        }
                    )
                case .planner:
                    PlannerPlaceholder(onMenuTapped: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarPresented.toggle()
                        }
                    })
                case .assignments:
                    AssignmentsPlaceholder(onMenuTapped: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarPresented.toggle()
                        }
                    })
                case .teachers:
                    TeachersPlaceholder(onMenuTapped: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarPresented.toggle()
                        }
                    })
                case .holidays:
                    HolidaysView(onMenuTapped: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarPresented.toggle()
                        }
                    })
                case .profile:
                    ProfileView(onMenuTapped: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarPresented.toggle()
                        }
                    })
                case .settings:
                    SettingsView(onMenuTapped: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarPresented.toggle()
                        }
                    }, onLogout: onLogout)
                }
            }
            .disabled(isSidebarPresented) 
            
            if isSidebarPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarPresented = false
                        }
                    }
                
                HStack {
                    SidebarView(
                        selectedView: $selectedView,
                        isPresented: $isSidebarPresented
                    )
                    .transition(.move(edge: .leading))
                    
                    Spacer()
                }
            }
        }
    }
}

struct ProfileView: View {
    let onMenuTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                HStack {
                    Button(action: onMenuTapped) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(UI.navy)
                            .font(.title2)
                    }
                    
                    Spacer()
                    
                    Text("Profile")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .background(Color(hex: "#B8C8DB"))
            
            VStack(spacing: 30) {
                
                Spacer().frame(height: 40)
                
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(UI.primary)
                
                VStack(spacing: 12) {
                    Text("User Profile")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Text("Profile settings and information will go here")
                        .font(.body)
                        .foregroundColor(UI.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
            }
            .background(UI.neutralLight)
        }
        .navigationBarHidden(true)
    }
}

struct SettingsView: View {
    let onMenuTapped: () -> Void
    let onLogout: () -> Void
    
    init(onMenuTapped: @escaping () -> Void = {}, onLogout: @escaping () -> Void = {}) {
        self.onMenuTapped = onMenuTapped
        self.onLogout = onLogout
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                HStack {
                    Button(action: onMenuTapped) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(UI.navy)
                            .font(.title2)
                    }
                    
                    Spacer()
                    
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 24)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 60)
            .background(Color(hex: "#B8C8DB"))
            
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 32)
                        
                        ZStack {
                            Circle()
                                .fill(UI.neutralMedium)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 36))
                                .foregroundColor(UI.neutralLight)
                            
                            Circle()
                                .fill(UI.navy)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 28, y: 28)
                        }
                        
                        VStack(spacing: 4) {
                            Text("User Name")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(UI.navy)
                            
                            Text("@username")
                                .font(.subheadline)
                                .foregroundColor(UI.muted)
                        }
                        
                        Spacer().frame(height: 32)
                    }
                    
                    VStack(spacing: 0) {
                        SettingsOptionView(title: "Saved Messages", showDivider: true)
                        SettingsOptionView(title: "Recent Calls", showDivider: true)
                        SettingsOptionView(title: "Devices", showDivider: true)
                        SettingsOptionView(title: "Notifications", showDivider: true)
                        SettingsOptionView(title: "Appearance", showDivider: true)
                        SettingsOptionView(title: "Language", showDivider: true)
                        SettingsOptionView(title: "Privacy & Security", showDivider: true)
                        SettingsOptionView(title: "Storage", showDivider: false)
                    }
                    .background(UI.neutralLight)
                    
                    Spacer().frame(height: 40)
                    
                    Button(action: {
                        onLogout()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .font(.title3)
                                .foregroundColor(.white)
                            
                            Text("Logout")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer().frame(height: 40)
                }
            }
            .background(UI.neutralLight)
        }
        .navigationBarHidden(true)
    }
}

struct SettingsOptionView: View {
    let title: String
    let showDivider: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(UI.muted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(UI.neutralLight)
            
            if showDivider {
                Divider()
                    .padding(.leading, 20)
                    .background(UI.neutralLight)
            }
        }
    }
}

#Preview {
    AppNavigationView(onLogout: {
        print("Logout tapped")
    })
}

struct WeekViewPlaceholder: View {
    let onMenuTapped: () -> Void
    
    var body: some View {
        PlaceholderView(
            title: "Week View", 
            icon: "calendar.day.timeline.left", 
            message: "Weekly calendar view will be implemented here",
            onMenuTapped: onMenuTapped
        )
    }
}

struct CalendarPlaceholder: View {
    let onMenuTapped: () -> Void
    
    var body: some View {
        PlaceholderView(
            title: "Calendar", 
            icon: "calendar", 
            message: "Monthly calendar view will be implemented here",
            onMenuTapped: onMenuTapped
        )
    }
}

struct PlannerPlaceholder: View {
    let onMenuTapped: () -> Void
    
    var body: some View {
        PlaceholderView(
            title: "Planner", 
            icon: "book.fill", 
            message: "Academic planner and schedule management",
            onMenuTapped: onMenuTapped
        )
    }
}

struct AssignmentsPlaceholder: View {
    let onMenuTapped: () -> Void
    
    var body: some View {
        PlaceholderView(
            title: "Assignments", 
            icon: "doc.text.fill", 
            message: "Assignment tracking and management",
            onMenuTapped: onMenuTapped
        )
    }
}

struct TeachersPlaceholder: View {
    let onMenuTapped: () -> Void
    
    var body: some View {
        PlaceholderView(
            title: "Teachers", 
            icon: "person.2.fill", 
            message: "Teacher contacts and information",
            onMenuTapped: onMenuTapped
        )
    }
}

struct PlaceholderView: View {
    let title: String
    let icon: String
    let message: String
    let onMenuTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                HStack {
                    Button(action: onMenuTapped) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(UI.navy)
                            .font(.title2)
                    }
                    
                    Spacer()
                    
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .background(Color(hex: "#B8C8DB"))
            
            VStack(spacing: 30) {
                Spacer().frame(height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundColor(UI.primary)
                
                VStack(spacing: 12) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(UI.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
            }
            .background(UI.neutralLight)
        }
        .navigationBarHidden(true)
    }
}