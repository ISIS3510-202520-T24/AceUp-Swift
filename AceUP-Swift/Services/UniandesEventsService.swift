//
//  UniandesEventsService.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 2/12/25.
//

import Foundation
import SwiftUI
import EventKit

protocol UniandesEventsServiceProtocol {
    func fetchEvents(forceRefresh: Bool) async throws -> [UniandesEvent]
    func getEventDetail(url: String) async throws -> UniandesEvent
    func toggleFavorite(eventId: String) async
    func toggleSaved(eventId: String) async
    func registerForEvent(eventId: String) async throws
    func addToCalendar(event: UniandesEvent)
}

@MainActor
class UniandesEventsService: ObservableObject, UniandesEventsServiceProtocol {
    
    @Published var isLoading = false
    @Published var error: Error?
    
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    private let userDefaults = UserDefaults.standard
    private let offlineManager = OfflineManager.shared
    
    // MARK: - Cache Keys
    private let cacheKey = "uniandes_events_cache"
    private let preferencesKey = "uniandes_events_preferences"
    
    // MARK: - Public Methods
    
    func fetchEvents(forceRefresh: Bool = false) async throws -> [UniandesEvent] {
        isLoading = true
        defer { isLoading = false }
        
        // Try to load from cache first
        if !forceRefresh, let cachedEvents = loadFromCache(), !cachedEvents.isExpired {
            print("Loading events from cache (age: \(Int(cachedEvents.age))s)")
            return applyUserPreferences(to: cachedEvents.events)
        }
        
        // Check if offline
        if !offlineManager.isOnline {
            if let cachedEvents = loadFromCache() {
                print("Offline mode: using cached events (expired: \(cachedEvents.isExpired))")
                return applyUserPreferences(to: cachedEvents.events)
            }
            throw UniandesEventsError.offline
        }
        
        // Fetch from web
        do {
            let events = try await scrapeEvents()
            saveToCache(events)
            return applyUserPreferences(to: events)
        } catch {
            // If fetch fails, try to use expired cache
            if let cachedEvents = loadFromCache() {
                print("Fetch failed, using expired cache")
                self.error = error
                return applyUserPreferences(to: cachedEvents.events)
            }
            throw error
        }
    }
    
    func getEventDetail(url: String) async throws -> UniandesEvent {
        // For now, we'll return the event from cache if it exists
        // In a real implementation, we would scrape the detail page
        guard let cachedEvents = loadFromCache() else {
            throw UniandesEventsError.eventNotFound
        }
        
        guard let event = cachedEvents.events.first(where: { $0.detailURL == url }) else {
            throw UniandesEventsError.eventNotFound
        }
        
        return event
    }
    
    func toggleFavorite(eventId: String) async {
        var prefs = loadPreferences()
        
        if prefs.favoriteEventIds.contains(eventId) {
            prefs.favoriteEventIds.remove(eventId)
        } else {
            prefs.favoriteEventIds.insert(eventId)
        }
        
        savePreferences(prefs)
        
        // Update cache
        if let cache = loadFromCache() {
            let updatedEvents = cache.events.map { event in
                var updatedEvent = event
                if event.id == eventId {
                    updatedEvent.isFavorite = prefs.favoriteEventIds.contains(eventId)
                }
                return updatedEvent
            }
            saveToCache(updatedEvents)
        }
    }
    
    func toggleSaved(eventId: String) async {
        var prefs = loadPreferences()
        
        if prefs.savedEventIds.contains(eventId) {
            prefs.savedEventIds.remove(eventId)
        } else {
            prefs.savedEventIds.insert(eventId)
        }
        
        savePreferences(prefs)
        
        // Update cache
        if let cache = loadFromCache() {
            let updatedEvents = cache.events.map { event in
                var updatedEvent = event
                if event.id == eventId {
                    updatedEvent.savedForLater = prefs.savedEventIds.contains(eventId)
                }
                return updatedEvent
            }
            saveToCache(updatedEvents)
        }
    }
    
    func registerForEvent(eventId: String) async throws {
        var prefs = loadPreferences()
        prefs.registeredEventIds.insert(eventId)
        savePreferences(prefs)
        
        // Update cache
        if let cache = loadFromCache() {
            let updatedEvents = cache.events.map { event in
                var updatedEvent = event
                if event.id == eventId {
                    updatedEvent.isRegistered = true
                }
                return updatedEvent
            }
            saveToCache(updatedEvents)
        }
        
        // In a real implementation, this would make an API call to register
        // For now, we'll just mark it locally
    }
    
    func addToCalendar(event: UniandesEvent) {
        let eventStore = EKEventStore()
        
        eventStore.requestAccess(to: .event) { [weak self] granted, error in
            guard granted else {
                print("Calendar access not granted: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let calendarEvent = EKEvent(eventStore: eventStore)
            calendarEvent.title = event.title
            calendarEvent.startDate = event.startDate
            calendarEvent.endDate = event.endDate
            calendarEvent.notes = event.description
            calendarEvent.location = event.location
            calendarEvent.calendar = eventStore.defaultCalendarForNewEvents
            
            // Add alarms
            let oneDayBeforeAlarm = EKAlarm(relativeOffset: -86400) // 1 day before
            let oneHourBeforeAlarm = EKAlarm(relativeOffset: -3600) // 1 hour before
            calendarEvent.alarms = [oneDayBeforeAlarm, oneHourBeforeAlarm]
            
            do {
                try eventStore.save(calendarEvent, span: .thisEvent)
                print("Event added to calendar: \(event.title)")
            } catch {
                print("Failed to save event to calendar: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods - Web Scraping
    
    private func scrapeEvents() async throws -> [UniandesEvent] {
        let urlString = "https://eventos.uniandes.edu.co/"
        
        guard let url = URL(string: urlString) else {
            throw UniandesEventsError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UniandesEventsError.networkError
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw UniandesEventsError.parsingError
        }
        
        return parseEvents(from: html)
    }
    
    private func parseEvents(from html: String) -> [UniandesEvent] {
        var events: [UniandesEvent] = []
        
        // This is a simplified parser - in production, you'd want to use a proper HTML parser
        // For now, we'll extract events using pattern matching
        
        // Split by event cards (looking for the pattern in the HTML)
        let eventPattern = #"<a[^>]*href="([^"]*evento\.uniandes\.edu\.co[^"]*)"[^>]*>.*?</a>"#
        
        do {
            let regex = try NSRegularExpression(pattern: eventPattern, options: [.dotMatchesLineSeparators])
            let nsString = html as NSString
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                if let event = parseEventFromMatch(match, in: nsString) {
                    events.append(event)
                }
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        // If regex parsing fails, use mock data for development
        if events.isEmpty {
            events = generateMockEvents()
        }
        
        return events
    }
    
    private func parseEventFromMatch(_ match: NSTextCheckingResult, in nsString: NSString) -> UniandesEvent? {
        // Extract URL
        guard match.numberOfRanges > 1 else { return nil }
        let urlRange = match.range(at: 1)
        let eventURL = nsString.substring(with: urlRange)
        
        // For now, return nil - we'll need more sophisticated parsing
        // or use the mock data below
        return nil
    }
    
    // MARK: - Mock Data (for development)
    
    private func generateMockEvents() -> [UniandesEvent] {
        let now = Date()
        
        return [
            UniandesEvent(
                id: UUID().uuidString,
                title: "I-MAT International Conference",
                description: "Conferencia internacional sobre matemáticas aplicadas y tecnología",
                category: .institutional,
                startDate: Calendar.current.date(byAdding: .day, value: 3, to: now)!,  // Jueves
                endDate: Calendar.current.date(byAdding: .day, value: 4, to: now)!,    // Viernes
                startTime: "7:50 am",
                endTime: "2:00 pm",
                location: "Edificio ML, Auditorio Principal",
                imageURL: "https://files.eventtia.com/uploads/event_banner/file/2025/01/99fc5ebcd62147449a4c89f0a8ca5a10_img_202501071404489f8bb.webp",
                detailURL: "https://evento.uniandes.edu.co/en/i-matinternationalconference2025",
                isRegistrationRequired: true,
                registrationURL: "https://connect.eventtia.com/users/sso/uniandes",
                organizer: "Departamento de Matemáticas",
                capacity: 200,
                tags: ["matemáticas", "internacional", "investigación"]
            ),
            UniandesEvent(
                id: UUID().uuidString,
                title: "Ponte al día con la IA - Usos educativos de la IAGen",
                description: "Taller práctico sobre inteligencia artificial generativa aplicada a la educación",
                category: .academic,
                startDate: Calendar.current.date(byAdding: .day, value: 3, to: now)!,  // Jueves
                endDate: Calendar.current.date(byAdding: .day, value: 3, to: now)!,    // Jueves
                startTime: "8:00 am",
                endTime: "2:00 pm",
                location: "Edificio W, Sala 301",
                imageURL: "https://files.eventtia.com/uploads/event_banner/file/2024/12/3efc1a52e4d244edab4d25a8d3e5e34e_img_202412021512247dc5e.png",
                detailURL: "https://evento.uniandes.edu.co/es/pontealdia_iagen",
                isRegistrationRequired: true,
                registrationURL: "https://connect.eventtia.com/users/sso/uniandes",
                organizer: "Centro de Innovación Educativa",
                capacity: 50,
                tags: ["IA", "educación", "tecnología"]
            ),
            UniandesEvent(
                id: UUID().uuidString,
                title: "Taller Historia del Suroccidente",
                description: "Análisis histórico y cultural del suroccidente colombiano",
                category: .academic,
                startDate: Calendar.current.date(byAdding: .day, value: 4, to: now)!,  // Viernes
                endDate: Calendar.current.date(byAdding: .day, value: 4, to: now)!,    // Viernes
                startTime: "8:00 am",
                endTime: "6:30 pm",
                location: "Edificio RGA, Salón 215",
                imageURL: nil,
                detailURL: "https://evento.uniandes.edu.co/es/historia_suroccidente",
                isRegistrationRequired: false,
                registrationURL: nil,
                organizer: "Departamento de Historia",
                capacity: nil,
                tags: ["historia", "cultura", "colombia"]
            ),
            UniandesEvent(
                id: UUID().uuidString,
                title: "Otro Cuento en la U \"El festín de la navidad\"",
                description: "Presentación cultural de cuentos navideños",
                category: .cultural,
                startDate: Calendar.current.date(byAdding: .day, value: 5, to: now)!,  // Sábado
                endDate: Calendar.current.date(byAdding: .day, value: 5, to: now)!,    // Sábado
                startTime: "5:00 pm",
                endTime: "6:30 pm",
                location: "Teatro Mario Laserna",
                imageURL: "https://files.eventtia.com/uploads/event_banner/file/2024/11/9d3d1dcc56c64cbdb8e23ee2cd13edef_img_202411261644145cdb7.png",
                detailURL: "https://evento.uniandes.edu.co/es/otro-cuento-en-la-u-el-festin-de-la-navidad",
                isRegistrationRequired: false,
                registrationURL: nil,
                organizer: "Bienestar Universitario",
                capacity: 100,
                tags: ["cultura", "navidad", "teatro"]
            ),
            UniandesEvent(
                id: UUID().uuidString,
                title: "Statistics and Data Science Workshop",
                description: "Workshop intensivo sobre estadística y ciencia de datos",
                category: .academic,
                startDate: Calendar.current.date(byAdding: .day, value: 7, to: now)!,  // Lunes
                endDate: Calendar.current.date(byAdding: .day, value: 10, to: now)!,   // Jueves,
                startTime: "8:00 am",
                endTime: "5:00 pm",
                location: "Edificio SD, Laboratorio de Datos",
                imageURL: nil,
                detailURL: "https://evento.uniandes.edu.co/en/stats-workshop25",
                isRegistrationRequired: true,
                registrationURL: "https://connect.eventtia.com/users/sso/uniandes",
                organizer: "Departamento de Estadística",
                capacity: 30,
                tags: ["estadística", "data science", "workshop"]
            ),
            UniandesEvent(
                id: UUID().uuidString,
                title: "3rd Colombian Economics Conference",
                description: "Conferencia anual de economía con expositores nacionales e internacionales",
                category: .academic,
                startDate: Calendar.current.date(byAdding: .day, value: 11, to: now)!,  // Viernes (semana siguiente)
                endDate: Calendar.current.date(byAdding: .day, value: 12, to: now)!,    // Sábado
                startTime: "8:00 am",
                endTime: "6:00 pm",
                location: "Edificio RGA, Auditorio Alberto Lleras",
                imageURL: nil,
                detailURL: "https://evento.uniandes.edu.co/es/3rd-colombian-economics-conference",
                isRegistrationRequired: true,
                registrationURL: "https://connect.eventtia.com/users/sso/uniandes",
                organizer: "Facultad de Economía",
                capacity: 250,
                tags: ["economía", "conferencia", "investigación"]
            )
        ]
    }
    
    // MARK: - Cache Management
    
    private func loadFromCache() -> EventsCache? {
        guard let data = userDefaults.data(forKey: cacheKey) else { return nil }
        
        do {
            let cache = try JSONDecoder().decode(EventsCache.self, from: data)
            return cache
        } catch {
            print("Failed to decode cache: \(error)")
            return nil
        }
    }
    
    private func saveToCache(_ events: [UniandesEvent]) {
        let expiresAt = Date().addingTimeInterval(cacheExpirationInterval)
        let cache = EventsCache(events: events, lastUpdated: Date(), expiresAt: expiresAt)
        
        do {
            let data = try JSONEncoder().encode(cache)
            userDefaults.set(data, forKey: cacheKey)
            print("Saved \(events.count) events to cache (expires: \(expiresAt))")
        } catch {
            print("Failed to save cache: \(error)")
        }
    }
    
    // MARK: - User Preferences
    
    private func loadPreferences() -> EventUserPreferences {
        guard let data = userDefaults.data(forKey: preferencesKey) else {
            return .default
        }
        
        do {
            return try JSONDecoder().decode(EventUserPreferences.self, from: data)
        } catch {
            print("Failed to decode preferences: \(error)")
            return .default
        }
    }
    
    private func savePreferences(_ prefs: EventUserPreferences) {
        do {
            let data = try JSONEncoder().encode(prefs)
            userDefaults.set(data, forKey: preferencesKey)
        } catch {
            print("Failed to save preferences: \(error)")
        }
    }
    
    private func applyUserPreferences(to events: [UniandesEvent]) -> [UniandesEvent] {
        let prefs = loadPreferences()
        
        return events.map { event in
            var updatedEvent = event
            updatedEvent.isFavorite = prefs.favoriteEventIds.contains(event.id)
            updatedEvent.savedForLater = prefs.savedEventIds.contains(event.id)
            updatedEvent.isRegistered = prefs.registeredEventIds.contains(event.id)
            return updatedEvent
        }
    }
}

// MARK: - Errors

enum UniandesEventsError: LocalizedError {
    case invalidURL
    case networkError
    case parsingError
    case offline
    case eventNotFound
    case calendarError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .networkError:
            return "Error de red. Por favor verifica tu conexión."
        case .parsingError:
            return "Error al procesar los datos"
        case .offline:
            return "Sin conexión a internet. Mostrando eventos guardados."
        case .eventNotFound:
            return "Evento no encontrado"
        case .calendarError(let error):
            return "Error al agregar al calendario: \(error.localizedDescription)"
        }
    }
}
