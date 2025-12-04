//
//  UniandesEventsView.swift
//  AceUP-Swift
//

import SwiftUI

struct UniandesEventsView: View {
    let onMenuTapped: () -> Void
    
    @StateObject private var viewModel = UniandesEventsViewModel()
    @State private var selectedEvent: UniandesEvent?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                UI.neutralLight
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    topBar
                    searchBar
                    categoryFilter
                    savedToggle
                    
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.displayEvents.isEmpty {
                        emptyState
                    } else {
                        eventsList
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedEvent) { event in
                EventDetailView(eventId: event.id, viewModel: viewModel)
            }
            .task {
                await viewModel.loadEvents()
            }
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: onMenuTapped) {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundColor(UI.navy)
            }
            
            Text("Eventos Uniandes")
                .font(.title2.bold())
                .foregroundColor(UI.navy)
            
            Spacer()
        }
        .padding()
        .background(Color.white)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(UI.muted)
            
            TextField("Buscar eventos...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryButton(
                    title: "Todos",
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    viewModel.selectedCategory = nil
                }
                
                ForEach(EventCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        title: category.rawValue,
                        icon: category.icon,
                        color: Color(hex: category.color),
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var savedToggle: some View {
        HStack {
            Toggle(isOn: $viewModel.showOnlySaved) {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(viewModel.showOnlySaved ? UI.primary : UI.muted)
                    Text(viewModel.showOnlySaved ? "Mostrando guardados (\(viewModel.savedEvents.count))" : "Ver guardados")
                        .font(.subheadline.bold())
                        .foregroundColor(UI.navy)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: UI.primary))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    private var offlineBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.white)
            Text("Sin conexión - Mostrando solo eventos guardados")
                .font(.caption.bold())
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.orange)
    }
    
    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.displayEvents) { event in
                    EventCard(event: event, viewModel: viewModel)
                        .onTapGesture {
                            selectedEvent = event
                        }
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadEvents(forceRefresh: true)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
            Text("Cargando eventos...")
                .foregroundColor(UI.muted)
            Spacer()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: viewModel.showOnlySaved ? "bookmark.slash" : "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(UI.muted)
            
            Text(viewModel.showOnlySaved ? "No hay eventos guardados" : "No se encontraron eventos")
                .font(.title3.bold())
                .foregroundColor(UI.navy)
            
            Text(viewModel.showOnlySaved ? "Guarda eventos para verlos aquí sin conexión" : "Intenta con otros filtros de búsqueda")
                .font(.body)
                .foregroundColor(UI.muted)
            
            Spacer()
        }
    }
}

// boton de categoria
struct CategoryButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = UI.primary
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color.white)
            .foregroundColor(isSelected ? .white : UI.navy)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// tarjeta de evento
struct EventCard: View {
    let event: UniandesEvent
    @ObservedObject var viewModel: UniandesEventsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // categoria badge
            HStack(spacing: 4) {
                Image(systemName: event.category.icon)
                    .font(.caption2)
                Text(event.category.rawValue)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: event.category.color))
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Text(event.title)
                .font(.headline)
                .foregroundColor(UI.navy)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            if let description = event.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(UI.muted)
                    .lineLimit(2)
            } else {
                Text(" ")
                    .font(.caption)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 16) {
                    Label(event.dateRange, systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                    
                    Label(event.timeRange, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                }
                
                if let location = event.location {
                    Label(location, systemImage: "mappin.circle")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                        .lineLimit(1)
                } else {
                    Text(" ")
                        .font(.caption)
                }
            }
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
