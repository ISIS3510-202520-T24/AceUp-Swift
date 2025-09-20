//
//  GroupCalendarView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 19/09/25.
//


import SwiftUI

struct GroupCalendarView: View {
    @State private var selectedDate = Date()
    let onMenuTapped: () -> Void
    let onBackTapped: () -> Void
    
    init(onMenuTapped: @escaping () -> Void = {}, onBackTapped: @escaping () -> Void = {}) {
        self.onMenuTapped = onMenuTapped
        self.onBackTapped = onBackTapped
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            VStack {
                HStack {
                    
                    Button(action: onBackTapped) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(UI.navy)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    
                    Text("[Group Name]")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Spacer()
                    
                   
                    Button(action: onMenuTapped) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(UI.navy)
                            .font(.body)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 60)
            .background(Color(hex: "#B8C8DB")) 
            
            
            WeeklyCalendarView(selectedDate: $selectedDate)
                .background(UI.neutralLight)
            
            
            ScrollView {
                VStack(spacing: 0) {
                    
                    ForEach(6..<24, id: \.self) { hour in
                        HStack {
                            
                            Rectangle()
                                .fill(UI.muted.opacity(0.2))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 60) 
                    }
                }
            }
            .background(UI.neutralLight)
        }
        .navigationBarHidden(true)
    }
}


struct WeeklyCalendarView: View {
    @Binding var selectedDate: Date
    
    private let weekDays = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private let dayNumbers = [19, 20, 21, 22, 23, 24, 25]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 8) {
                   
                    Text(weekDays[index])
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(UI.muted)
                    
                   
                    Text("\(dayNumbers[index])")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(index == 3 ? .white : UI.navy) // Día 22 (jueves) seleccionado
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(index == 3 ? UI.primary : Color.clear) // Día 22 destacado en verde aguamarina
                        )
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 20)
    }
}

#Preview {
    GroupCalendarView(
        onMenuTapped: {
            print("Menu tapped")
        },
        onBackTapped: {
            print("Back tapped")
        }
    )
}