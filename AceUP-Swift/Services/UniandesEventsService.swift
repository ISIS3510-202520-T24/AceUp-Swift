//
//  UniandesEventsService.swift
//  AceUP-Swift
//
//  Servicio standalone para eventos de Uniandes con web scraping
//  NO usa CoreData, solo cache local en UserDefaults
//

import Foundation

@MainActor
class UniandesEventsService: ObservableObject {
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hora
    private let cacheKey = "uniandes_events_cache"
    private let preferencesKey = "uniandes_events_preferences"
    
    // API de Eventtia para eventos de Uniandes
    private let apiURL = "https://connect.eventtia.com/en/api/v2/14686ebc-5e09-481f-8/events/list"
    
    // MARK: - Fetch Events
    
    func fetchEvents(forceRefresh: Bool = false) async -> [UniandesEvent] {
        isLoading = true
        defer { isLoading = false }
        
        // intentar cargar del cache primero
        if !forceRefresh, let cache = loadFromCache(), !cache.isExpired {
            print("Cargando eventos del cache")
            return applyUserPreferences(to: cache.events)
        }
        
        // intentar hacer scraping
        do {
            let events = try await scrapeEvents()
            if !events.isEmpty {
                saveToCache(events)
                return applyUserPreferences(to: events)
            }
        } catch {
            print("Error scraping: \(error.localizedDescription)")
            errorMessage = "No se pudieron cargar los eventos"
        }
        
        // si falla, usar cache expirado o vacio
        if let cache = loadFromCache() {
            print("Usando cache expirado por error de scraping")
            return applyUserPreferences(to: cache.events)
        }
        
        return []
    }
    
    // MARK: - API Fetch
    
    private func scrapeEvents() async throws -> [UniandesEvent] {
        var components = URLComponents(string: apiURL)!
        components.queryItems = [
            URLQueryItem(name: "page_size", value: "50"),
            URLQueryItem(name: "show_in_widget", value: "true"),
            URLQueryItem(name: "execution_status", value: "upcoming"),
            URLQueryItem(name: "status", value: "active")
        ]
        
        guard let url = components.url else {
            throw NSError(domain: "Invalid URL", code: -1)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(EventtiaAPIResponse.self, from: data)
        
        let events = response.events.map { UniandesEvent(from: $0) }
        
        print("Fetched \(events.count) eventos from API")
        return events
    }
    
    // MARK: - Favoritos y Guardados
    
    func toggleFavorite(eventId: String) {
        var prefs = loadPreferences()
        
        if prefs.favoriteEventIds.contains(eventId) {
            prefs.favoriteEventIds.remove(eventId)
        } else {
            prefs.favoriteEventIds.insert(eventId)
        }
        
        savePreferences(prefs)
    }
    
    func toggleSaved(eventId: String) {
        var prefs = loadPreferences()
        
        if prefs.savedEventIds.contains(eventId) {
            prefs.savedEventIds.remove(eventId)
        } else {
            prefs.savedEventIds.insert(eventId)
        }
        
        savePreferences(prefs)
    }
    
    // MARK: - Cache Management (UserDefaults, NO CoreData)
    
    private func saveToCache(_ events: [UniandesEvent]) {
        let expiresAt = Date().addingTimeInterval(cacheExpirationInterval)
        let cache = EventsCache(
            events: events,
            lastUpdated: Date(),
            expiresAt: expiresAt
        )
        
        if let encoded = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            print("Eventos guardados en cache (expira en 1h)")
        }
    }
    
    private func loadFromCache() -> EventsCache? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(EventsCache.self, from: data) else {
            return nil
        }
        return cache
    }
    
    private func savePreferences(_ prefs: EventUserPreferences) {
        if let encoded = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(encoded, forKey: preferencesKey)
        }
    }
    
    private func loadPreferences() -> EventUserPreferences {
        guard let data = UserDefaults.standard.data(forKey: preferencesKey),
              let prefs = try? JSONDecoder().decode(EventUserPreferences.self, from: data) else {
            return EventUserPreferences()
        }
        return prefs
    }
    
    private func applyUserPreferences(to events: [UniandesEvent]) -> [UniandesEvent] {
        let prefs = loadPreferences()
        
        return events.map { event in
            var updatedEvent = event
            updatedEvent.isFavorite = prefs.favoriteEventIds.contains(event.id)
            updatedEvent.savedForLater = prefs.savedEventIds.contains(event.id)
            return updatedEvent
        }
    }
}

// extension para decodificar HTML
extension String {
    var htmlDecoded: String {
        guard let data = self.data(using: .utf8) else { return self }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return self
        }
        
        return attributedString.string
    }
}
