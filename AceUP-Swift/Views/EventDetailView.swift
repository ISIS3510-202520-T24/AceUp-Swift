//
//  EventDetailView.swift
//  AceUP-Swift
//

import SwiftUI

struct EventDetailView: View {
    let eventId: String
    @ObservedObject var viewModel: UniandesEventsViewModel
    @Environment(\.dismiss) private var dismiss
    
    // obtener evento actualizado del viewModel
    private var event: UniandesEvent? {
        viewModel.events.first(where: { $0.id == eventId })
    }
    
    var body: some View {
        Group {
            if let event = event {
                eventDetailContent(event: event)
            } else {
                Text("Evento no encontrado")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func eventDetailContent(event: UniandesEvent) -> some View {
        ZStack(alignment: .top) {
            UI.neutralLight
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    headerSection(event: event)
                    infoSection(event: event)
                    descriptionSection(event: event)
                    actionsSection(event: event)
                }
                .padding()
            }
            
            // top bar
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(UI.navy)
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
    
    private func headerSection(event: UniandesEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // categoria badge
            HStack(spacing: 4) {
                Image(systemName: event.category.icon)
                    .font(.caption)
                Text(event.category.rawValue)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: event.category.color))
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Text(event.title)
                .font(.title.bold())
                .foregroundColor(UI.navy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
    
    private func infoSection(event: UniandesEvent) -> some View {
        VStack(spacing: 16) {
            EventInfoRow(icon: "calendar", title: "Fecha", value: event.dateRange)
            EventInfoRow(icon: "clock", title: "Horario", value: event.timeRange)
            
            if let location = event.location {
                EventInfoRow(icon: "mappin.circle", title: "Lugar", value: location)
            }
            
            if let organizer = event.organizer {
                EventInfoRow(icon: "person.2", title: "Organiza", value: organizer)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
    
    private func descriptionSection(event: UniandesEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Descripción")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            Text(event.description ?? "No hay descripción disponible")
                .font(.body)
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
    
    private func actionsSection(event: UniandesEvent) -> some View {
        VStack(spacing: 12) {
            Button(action: {
                viewModel.toggleSaved(event)
            }) {
                HStack {
                    Image(systemName: event.savedForLater ? "bookmark.fill" : "bookmark")
                    Text(event.savedForLater ? "Guardado" : "Guardar para después")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(event.savedForLater ? Color.gray : UI.primary)
                .cornerRadius(12)
            }
            
            // boton de ver más info - solo si hay internet
            if !viewModel.isOffline {
                if let url = URL(string: event.detailURL) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "safari")
                            Text("Ver más información")
                        }
                        .font(.headline)
                        .foregroundColor(UI.navy)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(UI.navy, lineWidth: 2)
                        )
                    }
                }
            } else {
                // boton deshabilitado cuando no hay internet
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("Sin conexión")
                }
                .font(.headline)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray, lineWidth: 2)
                )
            }
        }
    }
}

// fila de informacion del evento
struct EventInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(UI.primary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(UI.muted)
                
                Text(value)
                    .font(.body)
                    .foregroundColor(UI.navy)
            }
            
            Spacer()
        }
    }
}
