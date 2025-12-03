//
//  UniandesEvent.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 2/12/25.
//

import Foundation

// MARK: - Uniandes Event Models

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
    let isRegistrationRequired: Bool
    let registrationURL: String?
    let organizer: String?
    let capacity: Int?
    let tags: [String]
    
    var isFavorite: Bool = false
    var isRegistered: Bool = false
    var savedForLater: Bool = false
    
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
    case institutional = "INSTITUCIONAL"
    case cultural = "CULTURAL"
    case sports = "DEPORTIVO"
    case social = "SOCIAL"
    case other = "OTRO"
    
    var displayName: String {
        return rawValue
    }
    
    var color: String {
        switch self {
        case .academic: return "#4ECDC4"
        case .institutional: return "#FFE66D"
        case .cultural: return "#FF6B6B"
        case .sports: return "#95E1D3"
        case .social: return "#A8E6CF"
        case .other: return "#B8B8B8"
        }
    }
    
    var icon: String {
        switch self {
        case .academic: return "book.fill"
        case .institutional: return "building.columns.fill"
        case .cultural: return "theatermasks.fill"
        case .sports: return "sportscourt.fill"
        case .social: return "person.3.fill"
        case .other: return "star.fill"
        }
    }
    
    static func from(string: String) -> EventCategory {
        return EventCategory.allCases.first { $0.rawValue.lowercased() == string.lowercased() } ?? .other
    }
}

// MARK: - Event Filters

struct EventFilters: Codable {
    var categories: Set<EventCategory> = []
    var dateRange: DateRange = .upcoming
    var searchQuery: String = ""
    var showFavoritesOnly: Bool = false
    var showSavedOnly: Bool = false
    
    func matches(event: UniandesEvent) -> Bool {
        // Category filter
        if !categories.isEmpty && !categories.contains(event.category) {
            return false
        }
        
        // Date range filter
        switch dateRange {
        case .upcoming:
            if !event.isUpcoming && !event.isToday { return false }
        case .today:
            if !event.isToday { return false }
        case .past:
            if !event.isPast { return false }
        case .all:
            break
        }
        
        // Search query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            let matchesTitle = event.title.lowercased().contains(query)
            let matchesDescription = event.description?.lowercased().contains(query) ?? false
            let matchesOrganizer = event.organizer?.lowercased().contains(query) ?? false
            if !matchesTitle && !matchesDescription && !matchesOrganizer {
                return false
            }
        }
        
        // Favorites filter
        if showFavoritesOnly && !event.isFavorite {
            return false
        }
        
        // Saved filter
        if showSavedOnly && !event.savedForLater {
            return false
        }
        
        return true
    }
}

enum DateRange: String, Codable, CaseIterable {
    case upcoming = "Próximos"
    case today = "Hoy"
    case past = "Pasados"
    case all = "Todos"
}

// MARK: - Cache Models

struct EventsCache: Codable {
    let events: [UniandesEvent]
    let lastUpdated: Date
    let expiresAt: Date
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    var age: TimeInterval {
        return Date().timeIntervalSince(lastUpdated)
    }
}

// MARK: - User Preferences

struct EventUserPreferences: Codable {
    var favoriteEventIds: Set<String> = []
    var savedEventIds: Set<String> = []
    var registeredEventIds: Set<String> = []
    var notificationSettings: EventNotificationSettings = .default
    
    static let `default` = EventUserPreferences()
}

struct EventNotificationSettings: Codable {
    var enabled: Bool = true
    var notifyDayBefore: Bool = true
    var notifyOneDayBefore: Bool = true
    var notifyOneHourBefore: Bool = true
    var notifyNewEvents: Bool = false
    
    static let `default` = EventNotificationSettings()
}

// MARK: - Event Statistics

struct EventStatistics: Codable {
    let totalEvents: Int
    let upcomingEvents: Int
    let pastEvents: Int
    let favoriteCount: Int
    let savedCount: Int
    let registeredCount: Int
    let eventsByCategory: [EventCategory: Int]
    
    static var empty: EventStatistics {
        return EventStatistics(
            totalEvents: 0,
            upcomingEvents: 0,
            pastEvents: 0,
            favoriteCount: 0,
            savedCount: 0,
            registeredCount: 0,
            eventsByCategory: [:]
        )
    }
}
