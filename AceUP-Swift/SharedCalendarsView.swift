//
//  SharedCalendarsView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 19/09/25.
//


import SwiftUI

struct SharedCalendarsView: View {
    let onMenuTapped: () -> Void
    let onGroupSelected: (String) -> Void
    
    init(onMenuTapped: @escaping () -> Void = {}, onGroupSelected: @escaping (String) -> Void = { _ in }) {
        self.onMenuTapped = onMenuTapped
        self.onGroupSelected = onGroupSelected
    }
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                VStack {
                    HStack {
                       
                        Button(action: onMenuTapped) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(UI.navy)
                                .font(.body)
                        }
                        
                        Spacer()
                        
                        
                        Text("Shared")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(UI.navy)
                        
                        Spacer()
                        
                        
                        Button(action: {}) {
                            Text("Edit")
                                .foregroundColor(UI.navy)
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 60)
                .background(Color(hex: "#B8C8DB")) 
                
                VStack(spacing: 0) {
                   
                    HStack {
                        Text("Total Groups:")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(UI.navy)
                        
                        Spacer()
                        
                        Text("3")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(UI.navy)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(UI.neutralLight)
                    
                    
                    HStack {
                        Text("Shared Calendars")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(UI.navy)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .background(UI.neutralLight)
                    
                    
                    VStack(spacing: 0) {
                        GroupRow(groupName: "[Group Name]", onTapped: {
                            onGroupSelected("[Group Name]")
                        })
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        GroupRow(groupName: "[Group Name]", onTapped: {
                            onGroupSelected("[Group Name]")
                        })
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        GroupRow(groupName: "[Group Name]", onTapped: {
                            onGroupSelected("[Group Name]")
                        })
                    }
                    .background(UI.neutralLight)
                    
                    Spacer()
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
        }
        .navigationBarHidden(true)
    }
}


struct GroupRow: View {
    let groupName: String
    let onTapped: () -> Void
    
    init(groupName: String, onTapped: @escaping () -> Void = {}) {
        self.groupName = groupName
        self.onTapped = onTapped
    }
    
    var body: some View {
        HStack(spacing: 15) {
            
            Circle()
                .fill(UI.navy)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(groupName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                Text("Member member member")
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
            
            Spacer()
            
            
            Image(systemName: "chevron.right")
                .foregroundColor(UI.muted)
                .font(.caption)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
        .onTapGesture {
            onTapped()
        }
    }
}

#Preview {
    SharedCalendarsView(
        onMenuTapped: {
            print("Menu tapped")
        },
        onGroupSelected: { groupName in
            print("Group selected: \(groupName)")
        }
    )
}