//
//  UniandesEventsViewModel.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 2/12/25.
//

import Foundation
import SwiftUI

@MainActor
class UniandesEventsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var events: [UniandesEvent] = []
    @Published var filteredEvents: [UniandesEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Filters
    @Published var filters = EventFilters()
    @Published var searchText = ""
    @Published var selectedCategory: EventCategory?
    @Published var selectedDateRange: DateRange = .upcoming
    
    // UI State
    @Published var showFilters = false
    @Published var showCategoryPicker = false
    @Published var selectedEvent: UniandesEvent?
    @Published var showEventDetail = false
    
    // Statistics
    @Published var statistics: EventStatistics = .empty
    
    // MARK: - Private Properties
    private let service: UniandesEventsServiceProtocol
    private let offlineManager = OfflineManager.shared
    
    // MARK: - Computed Properties
    var upcomingEvents: [UniandesEvent] {
        filteredEvents.filter { $0.isUpcoming || $0.isToday }
            .sorted { $0.startDate < $1.startDate }
    }
    
    var todayEvents: [UniandesEvent] {
        filteredEvents.filter { $0.isToday }
    }
    
    var pastEvents: [UniandesEvent] {
        filteredEvents.filter { $0.isPast }
            .sorted { $0.startDate > $1.startDate }
    }
    
    var favoriteEvents: [UniandesEvent] {
        events.filter { $0.isFavorite }
            .sorted { $0.startDate < $1.startDate }
    }
    
    var savedEvents: [UniandesEvent] {
        events.filter { $0.savedForLater }
            .sorted { $0.startDate < $1.startDate }
    }
    
    var categoriesWithCount: [(category: EventCategory, count: Int)] {
        var counts: [EventCategory: Int] = [:]
        for event in filteredEvents {
            counts[event.category, default: 0] += 1
        }
        return EventCategory.allCases.compactMap { category in
            if let count = counts[category], count > 0 {
                return (category, count)
            }
            return nil
        }.sorted { $0.count > $1.count }
    }
    
    var isOffline: Bool {
        !offlineManager.isOnline
    }
    
    // MARK: - Initialization
    init(service: UniandesEventsServiceProtocol? = nil) {
        self.service = service ?? UniandesEventsService()
    }
    
    // MARK: - Public Methods
    
    func loadEvents(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            events = try await service.fetchEvents(forceRefresh: forceRefresh)
            applyFilters()
            updateStatistics()
            print("✅ Loaded \(events.count) events")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            print("❌ Error loading events: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshEvents() async {
        await loadEvents(forceRefresh: true)
    }
    
    func applyFilters() {
        filters.searchQuery = searchText
        filters.dateRange = selectedDateRange
        
        if let category = selectedCategory {
            filters.categories = [category]
        } else {
            filters.categories = []
        }
        
        filteredEvents = events.filter { filters.matches(event: $0) }
        updateStatistics()
    }
    
    func clearFilters() {
        searchText = ""
        selectedCategory = nil
        selectedDateRange = .upcoming
        filters = EventFilters()
        applyFilters()
    }
    
    func selectEvent(_ event: UniandesEvent) {
        selectedEvent = event
        showEventDetail = true
    }
    
    func toggleFavorite(_ event: UniandesEvent) async {
        await service.toggleFavorite(eventId: event.id)
        
        // Update local state
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index].isFavorite.toggle()
            applyFilters()
        }
    }
    
    func toggleSaved(_ event: UniandesEvent) async {
        await service.toggleSaved(eventId: event.id)
        
        // Update local state
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index].savedForLater.toggle()
            applyFilters()
        }
    }
    
    func registerForEvent(_ event: UniandesEvent) async {
        do {
            try await service.registerForEvent(eventId: event.id)
            
            // Update local state
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].isRegistered = true
                applyFilters()
            }
            
            // Show success message
            errorMessage = "✅ Registrado exitosamente para: \(event.title)"
            showError = true
        } catch {
            errorMessage = "Error al registrarse: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func addToCalendar(_ event: UniandesEvent) {
        service.addToCalendar(event: event)
        errorMessage = "✅ Agregando evento al calendario..."
        showError = true
    }
    
    func shareEvent(_ event: UniandesEvent) -> URL? {
        return URL(string: event.detailURL)
    }
    
    // MARK: - Filter Helpers
    
    func filterByCategory(_ category: EventCategory?) {
        selectedCategory = category
        applyFilters()
    }
    
    func filterByDateRange(_ range: DateRange) {
        selectedDateRange = range
        applyFilters()
    }
    
    func showFavoritesOnly(_ show: Bool) {
        filters.showFavoritesOnly = show
        applyFilters()
    }
    
    func showSavedOnly(_ show: Bool) {
        filters.showSavedOnly = show
        applyFilters()
    }
    
    // MARK: - Statistics
    
    private func updateStatistics() {
        var eventsByCategory: [EventCategory: Int] = [:]
        
        for event in events {
            eventsByCategory[event.category, default: 0] += 1
        }
        
        statistics = EventStatistics(
            totalEvents: events.count,
            upcomingEvents: events.filter { $0.isUpcoming || $0.isToday }.count,
            pastEvents: events.filter { $0.isPast }.count,
            favoriteCount: events.filter { $0.isFavorite }.count,
            savedCount: events.filter { $0.savedForLater }.count,
            registeredCount: events.filter { $0.isRegistered }.count,
            eventsByCategory: eventsByCategory
        )
    }
    
    // MARK: - Grouping Helpers
    
    func eventsGroupedByDate() -> [(date: Date, events: [UniandesEvent])] {
        let grouped = Dictionary(grouping: filteredEvents) { event in
            Calendar.current.startOfDay(for: event.startDate)
        }
        
        return grouped
            .sorted { $0.key < $1.key }
            .map { (date: $0.key, events: $0.value.sorted { $0.startDate < $1.startDate }) }
    }
    
    func eventsGroupedByCategory() -> [(category: EventCategory, events: [UniandesEvent])] {
        let grouped = Dictionary(grouping: filteredEvents) { $0.category }
        
        return EventCategory.allCases.compactMap { category in
            if let events = grouped[category], !events.isEmpty {
                return (category, events.sorted { $0.startDate < $1.startDate })
            }
            return nil
        }
    }
    
    // MARK: - Search
    
    func performSearch(_ query: String) {
        searchText = query
        applyFilters()
    }
}
