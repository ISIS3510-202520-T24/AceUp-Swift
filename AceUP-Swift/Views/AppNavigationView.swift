//
//  AppNavigationView.swift
//  AceUp-Swift
//
//  Created by Ángel Farfán Arcila on 19/09/25.
//

import SwiftUI


struct AppNavigationView: View {
    @State private var selectedView: AppView = .today
    @State private var isSidebarPresented = false
    @State private var selectedGroup: CalendarGroup?
    @State private var showJoinGroupView = false
    @State private var pendingInviteCode: String?
    let onLogout: () -> Void
    
    init(onLogout: @escaping () -> Void = {}) {
        self.onLogout = onLogout
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content
                mainContent
                    .disabled(isSidebarPresented) // Disable interaction when sidebar is open 
                
                // Sidebar overlay with adaptive behavior
                if isSidebarPresented {
                    sidebarOverlay(geometry: geometry)
                }
            }
            .sheet(isPresented: $showJoinGroupView) {
                JoinGroupView(initialInviteCode: pendingInviteCode, onGroupJoined: {
                    showJoinGroupView = false
                    pendingInviteCode = nil
                    selectedView = .sharedCalendars
                })
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleGroupInviteCode"))) { notification in
                if let inviteCode = notification.object as? String {
                    print("🔗 AppNavigationView received deep link invite code: \(inviteCode)")
                    pendingInviteCode = inviteCode
                    selectedView = .sharedCalendars
                    showJoinGroupView = true
                }
            }
        }
    }
    
    /// Main content view with all the navigation cases
    private var mainContent: some View {
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
                    onGroupSelected: { group in
                        selectedGroup = group
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
                        selectedGroup = nil
                    },
                    group: selectedGroup
                )
            case .planner:
                PlannerPlaceholder(onMenuTapped: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSidebarPresented.toggle()
                    }
                })
            case .assignments:
                AssignmentsListView(onMenuTapped: {
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
    }
    
    /// Adaptive sidebar overlay that responds to screen size and orientation
    private func sidebarOverlay(geometry: GeometryProxy) -> some View {
        let isLandscape = geometry.size.width > geometry.size.height
        let shouldUseFullOverlay = !isLandscape || geometry.size.width < 1000
        
        return Group {
            if shouldUseFullOverlay {
                // Small screens or portrait: full overlay with backdrop
                ZStack {
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
            } else {
                // Large landscape screens: no backdrop, just sidebar
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
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
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
                    .padding(.horizontal, isLandscape ? 24 : 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
                .background(Color(hex: "#B8C8DB"))
                
                VStack(spacing: isLandscape ? 20 : 30) {
                    Spacer().frame(height: isLandscape ? 20 : 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: isLandscape ? 60 : 80))
                        .foregroundColor(UI.primary)
                    
                    VStack(spacing: 12) {
                        Text(title)
                            .font(isLandscape ? .title3 : .title2)
                            .fontWeight(.semibold)
                            .foregroundColor(UI.navy)
                        
                        Text(message)
                            .font(.body)
                            .foregroundColor(UI.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, isLandscape ? 60 : 40)
                    }
                    
                    Spacer()
                }
                .background(UI.neutralLight)
            }
            .navigationBarHidden(true)
        }
    }
}