//
//  SharedCalendarsView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 19/09/25.
//


import SwiftUI

struct SharedCalendarsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header con fondo azul claro
                VStack {
                    HStack {
                        // Botón hamburguesa
                        Button(action: {}) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(UI.navy)
                                .font(.title2)
                        }
                        
                        Spacer()
                        
                        // Título
                        Text("Shared")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(UI.navy)
                        
                        Spacer()
                        
                        // Botón Edit
                        Button(action: {}) {
                            Text("Edit")
                                .foregroundColor(UI.navy)
                                .font(.body)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 15)
                }
                .background(Color(hex: "#B8C8DB")) // Color azul claro del header
                
                // Contenido principal
                VStack(spacing: 0) {
                    // Contador de grupos
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
                    
                    // Título de sección
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
                    
                    // Lista de grupos
                    VStack(spacing: 0) {
                        GroupRow(groupName: "[Group Name]")
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        GroupRow(groupName: "[Group Name]")
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        GroupRow(groupName: "[Group Name]")
                    }
                    .background(UI.neutralLight)
                    
                    Spacer()
                }
                .background(UI.neutralLight)
            }
            .overlay(
                // Botón flotante para agregar
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

// Componente para cada fila de grupo
struct GroupRow: View {
    let groupName: String
    
    var body: some View {
        HStack(spacing: 15) {
            // Ícono circular azul
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
            
            // Flecha de navegación
            Image(systemName: "chevron.right")
                .foregroundColor(UI.muted)
                .font(.caption)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
        .onTapGesture {
            // Navegación al grupo específico
        }
    }
}

#Preview {
    SharedCalendarsView()
}