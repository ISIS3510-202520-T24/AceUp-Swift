//
//  UniandesEvent.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 2/12/25.
//

import Foundation

// modelo simple de evento (no usa CoreData)
struct UniandesEvent: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let category: EventCategory
    let startDate: Date
    let endDate: Date
    let startTime: String
    let endTime: String
    let location: String?
    let imageURL: String?
    let detailURL: String
    let organizer: String?
    
    var isFavorite: Bool = false
    var savedForLater: Bool = false
    
    // mapear desde API response
    init(from apiEvent: EventtiaAPIEvent) {
        self.id = String(apiEvent.id)
        self.title = apiEvent.name
        self.description = apiEvent.description
        self.category = EventCategory.from(string: apiEvent.category_name ?? "")
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // parsear fechas del formato "2025-12-03 07:50:00"
        let simpleDateFormatter = DateFormatter()
        simpleDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        simpleDateFormatter.timeZone = TimeZone(identifier: "America/Bogota")
        
        self.startDate = simpleDateFormatter.date(from: apiEvent.start_date) ?? Date()
        self.endDate = simpleDateFormatter.date(from: apiEvent.end_date) ?? Date()
        
        // extraer horas
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        timeFormatter.timeZone = TimeZone(identifier: "America/Bogota")
        
        self.startTime = timeFormatter.string(from: self.startDate)
        self.endTime = timeFormatter.string(from: self.endDate)
        
        self.location = apiEvent.address_1
        self.imageURL = apiEvent.hero?.medium_url ?? apiEvent.logo?.medium_url
        self.detailURL = apiEvent.site_url ?? "https://eventos.uniandes.edu.co/"
        self.organizer = apiEvent.organizer_name
    }
    
    // init manual para cache/tests
    init(id: String, title: String, description: String?, category: EventCategory,
         startDate: Date, endDate: Date, startTime: String, endTime: String,
         location: String?, imageURL: String?, detailURL: String, organizer: String?) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.startDate = startDate
        self.endDate = endDate
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.imageURL = imageURL
        self.detailURL = detailURL
        self.organizer = organizer
    }
    
    var dateRange: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_CO")
        formatter.dateFormat = "d MMM yyyy"
        
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return formatter.string(from: startDate)
        } else {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }
    
    var timeRange: String {
        return "\(startTime) - \(endTime)"
    }
    
    var isPast: Bool {
        return endDate < Date()
    }
    
    var isToday: Bool {
        return Calendar.current.isDateInToday(startDate)
    }
    
    var isUpcoming: Bool {
        return startDate > Date() && !isToday
    }
    
    var daysUntil: Int {
        return Calendar.current.dateComponents([.day], from: Date(), to: startDate).day ?? 0
    }
}

enum EventCategory: String, Codable, CaseIterable {
    case academic = "ACADÉMICO"
    case cultural = "CULTURAL"
    case institutional = "INSTITUCIONAL"
    case wellness = "BIENESTAR"
    case other = "OTRO"
    
    var color: String {
        switch self {
        case .academic: return "#4ECDC4"
        case .cultural: return "#FF6B6B"
        case .institutional: return "#FFE66D"
        case .wellness: return "#98D8C8"
        case .other: return "#B8B8B8"
        }
    }
    
    var icon: String {
        switch self {
        case .academic: return "book.fill"
        case .cultural: return "theatermasks.fill"
        case .institutional: return "building.columns.fill"
        case .wellness: return "heart.fill"
        case .other: return "star.fill"
        }
    }
    
    static func from(string: String) -> EventCategory {
        let normalized = string.uppercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        
        if normalized.contains("ACADEM") { return .academic }
        if normalized.contains("CULTUR") { return .cultural }
        if normalized.contains("INSTITUCION") { return .institutional }
        if normalized.contains("BIENESTAR") || normalized.contains("WELLNESS") { return .wellness }
        
        return .other
    }
}

// MARK: - API Response Models

struct EventtiaAPIResponse: Codable {
    let total_events: Int
    let events: [EventtiaAPIEvent]
}

struct EventtiaAPIEvent: Codable {
    let id: Int
    let name: String
    let start_date: String
    let end_date: String
    let description: String?
    let address_1: String?
    let city: String?
    let country: String?
    let site_url: String?
    let organizer_name: String?
    let category_name: String?
    let logo: EventtiaImage?
    let hero: EventtiaImage?
}

struct EventtiaImage: Codable {
    let thumbnail_url: String?
    let small_url: String?
    let medium_url: String?
    let large_url: String?
}

// MARK: - Cache Models

// cache local simple (no CoreData)
struct EventsCache: Codable {
    let events: [UniandesEvent]
    let lastUpdated: Date
    let expiresAt: Date
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
}

// preferencias de usuario (guardadas en UserDefaults)
struct EventUserPreferences: Codable {
    var favoriteEventIds: Set<String> = []
    var savedEventIds: Set<String> = []
}
