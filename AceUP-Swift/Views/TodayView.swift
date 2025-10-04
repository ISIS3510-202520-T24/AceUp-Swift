//
//  TodayView.swift
//  AceUp-Swift
//
//  Created by Ana M. Sánchez on 19/09/25.
//

import SwiftUI

struct TodayView: View {
    let onMenuTapped: () -> Void
    @State private var selectedTab: TodayTab = .assignments
    
    init(onMenuTapped: @escaping () -> Void = {}) {
        self.onMenuTapped = onMenuTapped
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            VStack {
                HStack {
                    Button(action: onMenuTapped) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(UI.navy)
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    Text("Today")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 24)
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 60)
            .background(Color(hex: "#B8C8DB"))
            
            
            VStack(spacing: 0) {
                
                HStack(spacing: 8) {
                    TabButton(
                        title: "Exams",
                        isSelected: selectedTab == .exams,
                        action: { selectedTab = .exams }
                    )
                    
                    TabButton(
                        title: "Timetable", 
                        isSelected: selectedTab == .timetable,
                        action: { selectedTab = .timetable }
                    )
                    
                    TabButton(
                        title: "Assignments",
                        isSelected: selectedTab == .assignments,
                        action: { selectedTab = .assignments }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                
                ScrollView {
                    switch selectedTab {
                    case .exams:
                        ExamsTabContent()
                    case .timetable:
                        TimetableTabContent()
                    case .assignments:
                        AssignmentsTabContent()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(UI.neutralLight)
        }
        .overlay(
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(UI.primary)
                            .clipShape(Circle())
                            .shadow(color: UI.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 30)
                }
            }
        )
        .navigationBarHidden(true)
    }
}


enum TodayTab {
    case exams
    case timetable
    case assignments
}


struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : UI.navy)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? UI.primary : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}


struct ExamsTabContent: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 100)
            
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(UI.muted)
            
            VStack(spacing: 8) {
                Text("No exams scheduled")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Text("Your upcoming exams will appear here")
                    .font(.body)
                    .foregroundColor(UI.muted)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct TimetableTabContent: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 100)
            
            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundColor(UI.muted)
            
            VStack(spacing: 8) {
                Text("No classes today")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Text("Your class schedule will appear here")
                    .font(.body)
                    .foregroundColor(UI.muted)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct AssignmentsTabContent: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 100)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#E8E8E8"))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(UI.muted)
                )
            
            VStack(spacing: 8) {
                Text("You have no assignments due for the next 7 days")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                    .multilineTextAlignment(.center)
                
                Text("Time to work on a hobby of yours!")
                    .font(.body)
                    .foregroundColor(UI.muted)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    TodayView(onMenuTapped: {
        print("Menu tapped")
    })
}