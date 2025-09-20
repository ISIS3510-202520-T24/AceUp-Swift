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
                    })
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
            // Header
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
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .background(Color(hex: "#B8C8DB"))
            
            
            VStack(spacing: 30) {
                
                Spacer().frame(height: 40)
                
                Image(systemName: "gear.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(UI.primary)
                
                VStack(spacing: 12) {
                    Text("App Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Text("Application settings and preferences will go here")
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

#Preview {
    AppNavigationView()
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