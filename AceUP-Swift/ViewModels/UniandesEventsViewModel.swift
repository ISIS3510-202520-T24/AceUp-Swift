//
//  UniandesEventsViewModel.swift
//  AceUP-Swift
//

import Foundation

@MainActor
class UniandesEventsViewModel: ObservableObject {
    @Published var events: [UniandesEvent] = []
    @Published var isLoading = false
    @Published var selectedCategory: EventCategory?
    @Published var searchText = ""
    @Published var showOnlySaved = false
    
    private let service = UniandesEventsService()
    private let offlineManager = OfflineManager.shared
    
    var isOffline: Bool {
        !offlineManager.isOnline
    }
    
    var filteredEvents: [UniandesEvent] {
        var result = events
        
        // filtro por categoria
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        // filtro por busqueda
        if !searchText.isEmpty {
            result = result.filter { event in
                event.title.lowercased().contains(searchText.lowercased()) ||
                event.description?.lowercased().contains(searchText.lowercased()) ?? false
            }
        }
        
        // ordenar por fecha
        return result.sorted { $0.startDate < $1.startDate }
    }
    
    var upcomingEvents: [UniandesEvent] {
        filteredEvents.filter { $0.isUpcoming || $0.isToday }
    }
    
    var favoriteEvents: [UniandesEvent] {
        events.filter { $0.isFavorite }
    }
    
    var savedEvents: [UniandesEvent] {
        events.filter { $0.savedForLater }
    }
    
    var displayEvents: [UniandesEvent] {
        if showOnlySaved {
            return savedEvents.sorted { $0.startDate < $1.startDate }
        }
        return filteredEvents
    }
    
    func loadEvents(forceRefresh: Bool = false) async {
        isLoading = true
        let fetchedEvents = await service.fetchEvents(forceRefresh: forceRefresh)
        
        if !fetchedEvents.isEmpty {
            events = fetchedEvents
        } else if events.isEmpty && isOffline {
            // no hay cache y estamos offline, mostrar guardados
            showOnlySaved = true
        }
        
        isLoading = false
    }
    
    func toggleFavorite(_ event: UniandesEvent) {
        service.toggleFavorite(eventId: event.id)
        
        // actualizar localmente
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index].isFavorite.toggle()
        }
    }
    
    func toggleSaved(_ event: UniandesEvent) {
        service.toggleSaved(eventId: event.id)
        
        // actualizar localmente
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index].savedForLater.toggle()
        }
    }
}
