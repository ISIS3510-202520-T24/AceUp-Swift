//
//  HolidaysView.swift
//  AceUp-Swift
//
//  Created by Ana M. Sánchez on 19/09/25.
//

import SwiftUI

struct HolidaysView: View {
    let onMenuTapped: () -> Void
    
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
                    
                    Text("Holidays")
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
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    HolidayRow(
                        name: "[Holiday Name]",
                        dateRange: "[Date]",
                        onEdit: { print("Edit holiday 1") }
                    )
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    HolidayRow(
                        name: "[Holiday Name]",
                        dateRange: "[Start Date] - [End Date]",
                        onEdit: { print("Edit holiday 2") }
                    )
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    HolidayRow(
                        name: "[Holiday Name]",
                        dateRange: "[Date]",
                        onEdit: { print("Edit holiday 3") }
                    )
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    HolidayRow(
                        name: "[Holiday Name]",
                        dateRange: "[Date]",
                        onEdit: { print("Edit holiday 4") }
                    )
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    HolidayRow(
                        name: "[Holiday Name]",
                        dateRange: "[Start Date] - [End Date]",
                        onEdit: { print("Edit holiday 5") }
                    )
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    HolidayRow(
                        name: "[Holiday Name]",
                        dateRange: "[Start Date] - [End Date]",
                        onEdit: { print("Edit holiday 6") }
                    )
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    HolidayRow(
                        name: "[Holiday Name]",
                        dateRange: "[Date]",
                        onEdit: { print("Edit holiday 7") }
                    )
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    HolidayRow(
                        name: "[Holiday Name]",
                        dateRange: "[Date]",
                        onEdit: { print("Edit holiday 8") }
                    )
                    
                    
                    Spacer().frame(height: 100)
                }
                .padding(.top, 10)
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

struct HolidayRow: View {
    let name: String
    let dateRange: String
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                Text(dateRange)
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.body)
                    .foregroundColor(UI.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

#Preview {
    HolidaysView(onMenuTapped: {
        print("Menu tapped")
    })
}