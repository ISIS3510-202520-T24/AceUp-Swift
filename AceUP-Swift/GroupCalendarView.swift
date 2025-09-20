//
//  GroupCalendarView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 19/09/25.
//


import SwiftUI

struct GroupCalendarView: View {
    @State private var selectedDate = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            
            VStack {
                HStack {
                   
                    Button(action: {}) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(UI.navy)
                            .font(.title2)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    // Título del grupo
                    Text("[Group Name]")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Spacer()
                    
                    // Espacio para balancear el botón back
                    Color.clear
                        .frame(width: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 15)
            }
            .background(Color(hex: "#B8C8DB")) // Color azul claro del header
            
            // Selector de días de la semana
            WeeklyCalendarView(selectedDate: $selectedDate)
                .background(UI.neutralLight)
            
            // Contenido del calendario (líneas de horario)
            ScrollView {
                VStack(spacing: 0) {
                    // Crear líneas de horario desde las 6:00 AM hasta las 11:00 PM
                    ForEach(6..<24, id: \.self) { hour in
                        HStack {
                            // Línea divisora
                            Rectangle()
                                .fill(UI.muted.opacity(0.2))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 60) // Espacio para cada hora
                    }
                }
            }
            .background(UI.neutralLight)
        }
        .navigationBarHidden(true)
    }
}

// Componente del calendario semanal
struct WeeklyCalendarView: View {
    @Binding var selectedDate: Date
    
    private let weekDays = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private let dayNumbers = [19, 20, 21, 22, 23, 24, 25]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 8) {
                    // Día de la semana
                    Text(weekDays[index])
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(UI.muted)
                    
                    // Número del día
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
                    // Lógica para seleccionar día
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 20)
    }
}

#Preview {
    GroupCalendarView()
}