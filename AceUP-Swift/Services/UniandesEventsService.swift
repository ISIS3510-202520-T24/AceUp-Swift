//
//  UniandesEventsService.swift
//  AceUP-Swift
//
//  Servicio standalone para eventos de Uniandes con API
//  Triple persistencia: NSCache (memoria) + UserDefaults + FileManager
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
    
    // MARK: - NSCache Configuration (LRU Cache en memoria)
    
    private let memoryCache: NSCache<NSString, CacheWrapper> = {
        let cache = NSCache<NSString, CacheWrapper>()
        
        // Configuración de límites
        cache.countLimit = 100        // Máximo 100 objetos en cache
        cache.totalCostLimit = 50 * 1024 * 1024  // Máximo 50 MB
        
        // Nombre para debugging
        cache.name = "com.aceup.events.cache"
        
        return cache
    }()
    
    // Wrapper class para NSCache (NSCache requiere clases, no structs)
    private class CacheWrapper {
        let cache: EventsCache
        let cost: Int  // Tamaño en bytes
        
        init(cache: EventsCache, cost: Int) {
            self.cache = cache
            self.cost = cost
        }
    }
    
    // MARK: - Fetch Events
    func fetchEvents(forceRefresh: Bool = false) async -> [UniandesEvent] {
        isLoading = true
        defer { isLoading = false }
        
        // NIVEL 1: NSCache en memoria (más rápido - LRU)
        if !forceRefresh, let cache = loadFromMemoryCache(), !cache.isExpired {
            print("⚡ Cache HIT desde NSCache (memoria)")
            return applyUserPreferences(to: cache.events)
        }
        
        // NIVEL 2: UserDefaults (.plist en disco)
        if !forceRefresh, let cache = loadFromUserDefaults(), !cache.isExpired {
            print("📦 Cache HIT desde UserDefaults")
            // Guardar en NSCache para próxima vez
            saveToMemoryCache(cache)
            return applyUserPreferences(to: cache.events)
        }
        
        // NIVEL 3: Archivo JSON (fallback)
        if !forceRefresh, let cache = loadFromFile(), !cache.isExpired {
            print("📄 Cache HIT desde archivo JSON")
            // Guardar en niveles superiores
            saveToMemoryCache(cache)
            saveToUserDefaults(cache)
            return applyUserPreferences(to: cache.events)
        }
        
        // NIVEL 4: Network (API)
        do {
            let events = try await scrapeEvents()
            if !events.isEmpty {
                saveToCache(events)
                return applyUserPreferences(to: events)
            }
        } catch {
            print("⚠️ Error scraping: \(error.localizedDescription)")
            errorMessage = "No se pudieron cargar los eventos"
        }
        
        // NIVEL 5: Cache expirado (mejor que nada)
        if let cache = loadFromMemoryCache() ?? loadFromUserDefaults() ?? loadFromFile() {
            print("📦 Usando cache expirado por error de scraping")
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
    
    // MARK: - Triple Cache System (NSCache + UserDefaults + File)
    
    private func saveToCache(_ events: [UniandesEvent]) {
        let expiresAt = Date().addingTimeInterval(cacheExpirationInterval)
        let cache = EventsCache(
            events: events,
            lastUpdated: Date(),
            expiresAt: expiresAt
        )
        
        // NIVEL 1: NSCache (memoria - más rápido, LRU)
        saveToMemoryCache(cache)
        
        // NIVEL 2: UserDefaults (.plist)
        saveToUserDefaults(cache)
        
        // NIVEL 3: Archivo JSON (respaldo)
        saveToFile(cache)
    }
    
    // MARK: - NSCache Operations (LRU in-memory cache)
    
    private func saveToMemoryCache(_ cache: EventsCache) {
        // Calcular costo aproximado (tamaño en bytes)
        let cost = estimateCacheSize(cache)
        
        let wrapper = CacheWrapper(cache: cache, cost: cost)
        memoryCache.setObject(wrapper, forKey: cacheKey as NSString, cost: cost)
        
        print("⚡ NSCache: Guardado \(cache.events.count) eventos (~\(cost/1024) KB)")
    }
    
    private func loadFromMemoryCache() -> EventsCache? {
        guard let wrapper = memoryCache.object(forKey: cacheKey as NSString) else {
            return nil
        }
        return wrapper.cache
    }
    
    private func estimateCacheSize(_ cache: EventsCache) -> Int {
        guard let data = try? JSONEncoder().encode(cache) else {
            return 0
        }
        return data.count
    }
    
    // MARK: - UserDefaults Operations
    
    private func saveToUserDefaults(_ cache: EventsCache) {
        if let encoded = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            print("📦 UserDefaults: Guardado")
        }
    }
    
    private func loadFromUserDefaults() -> EventsCache? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(EventsCache.self, from: data) else {
            return nil
        }
        return cache
    }
    
    // MARK: - File Management (Archivos Locales con FileManager)
    
    private func saveToFile(_ cache: EventsCache) {
        let fileURL = getFileURL()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(cache)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            
            // Obtener tamaño del archivo
            let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int ?? 0
            let sizeKB = Double(fileSize) / 1024.0
            
            print("Cache guardado en archivo JSON")
            print("Ubicación: \(fileURL.path)")
            print("Tamaño: \(String(format: "%.2f", sizeKB)) KB")
            print("Eventos guardados: \(cache.events.count)")
        } catch {
            print("Error guardando archivo: \(error.localizedDescription)")
        }
    }
    
    private func loadFromFile() -> EventsCache? {
        let fileURL = getFileURL()
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Archivo de cache no existe")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cache = try decoder.decode(EventsCache.self, from: data)
            
            print("Cache leído desde archivo: \(cache.events.count) eventos")
            return cache
        } catch {
            print("Error leyendo archivo: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func getFileURL() -> URL {
        let documentsDirectory = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("uniandes_events_cache.json")
    }
    
    // Método para debugging - muestra info del archivo
    func getCacheFileInfo() -> String? {
        let fileURL = getFileURL()
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return "No existe archivo de cache"
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int ?? 0
            let modificationDate = attributes[.modificationDate] as? Date ?? Date()
            
            let sizeKB = Double(fileSize) / 1024.0
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            
            return """
            Archivo: uniandes_events_cache.json
            Ruta: \(fileURL.path)
            Tamaño: \(String(format: "%.2f", sizeKB)) KB
            Modificado: \(dateFormatter.string(from: modificationDate))
            """
        } catch {
            return "Error obteniendo info: \(error.localizedDescription)"
        }
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
