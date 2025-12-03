//
//  UniandesEventsView.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 2/12/25.
//

import SwiftUI

struct UniandesEventsView: View {
    let onMenuTapped: () -> Void
    
    @StateObject private var viewModel = UniandesEventsViewModel()
    @State private var showFilters = false
    @State private var selectedTab: EventsTab = .upcoming
    
    enum EventsTab: String, CaseIterable {
        case upcoming = "Próximos"
        case today = "Hoy"
        case favorites = "Favoritos"
        case saved = "Guardados"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Search Bar
            searchBar
            
            // Category Filter
            if !viewModel.categoriesWithCount.isEmpty {
                categoryScrollView
            }
            
            // Tab Selector
            tabSelector
            
            // Content
            ZStack {
                if viewModel.isLoading && viewModel.events.isEmpty {
                    loadingView
                } else if viewModel.filteredEvents.isEmpty {
                    emptyStateView
                } else {
                    eventsList
                }
            }
        }
        .background(UI.neutralLight)
        .navigationBarHidden(true)
        .task {
            await viewModel.loadEvents()
        }
        .refreshable {
            await viewModel.refreshEvents()
        }
        .alert("Evento", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .sheet(isPresented: $viewModel.showEventDetail) {
            if let event = viewModel.selectedEvent {
                EventDetailView(
                    event: event,
                    onFavoriteToggle: {
                        Task {
                            await viewModel.toggleFavorite(event)
                        }
                    },
                    onSaveToggle: {
                        Task {
                            await viewModel.toggleSaved(event)
                        }
                    },
                    onAddToCalendar: {
                        viewModel.addToCalendar(event)
                    },
                    onRegister: {
                        Task {
                            await viewModel.registerForEvent(event)
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: onMenuTapped) {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(UI.navy)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Eventos Uniandes")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(UI.navy)
                
                if viewModel.isOffline {
                    HStack(spacing: 4) {
                        Image(systemName: "wifi.slash")
                        Text("Modo offline")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Statistics Badge
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(viewModel.statistics.upcomingEvents)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(UI.primary)
                
                Text("próximos")
                    .font(.caption2)
                    .foregroundColor(UI.muted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(UI.muted)
                
                TextField("Buscar eventos...", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: viewModel.searchText) { newValue in
                        viewModel.performSearch(newValue)
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                        viewModel.performSearch("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(UI.muted)
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(10)
            
            Button(action: {
                showFilters.toggle()
            }) {
                Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundColor(UI.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Category Filter
    
    private var categoryScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All categories button
                CategoryChip(
                    category: nil,
                    count: viewModel.filteredEvents.count,
                    isSelected: viewModel.selectedCategory == nil,
                    action: {
                        viewModel.filterByCategory(nil)
                    }
                )
                
                ForEach(viewModel.categoriesWithCount, id: \.category) { item in
                    CategoryChip(
                        category: item.category,
                        count: item.count,
                        isSelected: viewModel.selectedCategory == item.category,
                        action: {
                            viewModel.filterByCategory(item.category)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(EventsTab.allCases, id: \.self) { tab in
                    EventsTabButton(
                        title: tab.rawValue,
                        count: countForTab(tab),
                        isSelected: selectedTab == tab,
                        action: {
                            withAnimation {
                                selectedTab = tab
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    private func countForTab(_ tab: EventsTab) -> Int {
        switch tab {
        case .upcoming:
            return viewModel.upcomingEvents.count
        case .today:
            return viewModel.todayEvents.count
        case .favorites:
            return viewModel.favoriteEvents.count
        case .saved:
            return viewModel.savedEvents.count
        }
    }
    
    // MARK: - Events List
    
    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let events = eventsForSelectedTab()
                
                ForEach(events) { event in
                    EventCard(event: event) {
                        viewModel.selectEvent(event)
                    } onFavorite: {
                        Task {
                            await viewModel.toggleFavorite(event)
                        }
                    } onSave: {
                        Task {
                            await viewModel.toggleSaved(event)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    private func eventsForSelectedTab() -> [UniandesEvent] {
        switch selectedTab {
        case .upcoming:
            return viewModel.upcomingEvents
        case .today:
            return viewModel.todayEvents
        case .favorites:
            return viewModel.favoriteEvents
        case .saved:
            return viewModel.savedEvents
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Cargando eventos...")
                .font(.subheadline)
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: emptyStateIcon())
                .font(.system(size: 60))
                .foregroundColor(UI.muted)
            
            Text(emptyStateTitle())
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)
            
            Text(emptyStateMessage())
                .font(.subheadline)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if viewModel.searchText.isEmpty && !viewModel.filters.categories.isEmpty {
                Button(action: {
                    viewModel.clearFilters()
                }) {
                    Text("Limpiar filtros")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(UI.primary)
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }
    
    private func emptyStateIcon() -> String {
        switch selectedTab {
        case .upcoming: return "calendar"
        case .today: return "calendar.badge.clock"
        case .favorites: return "star"
        case .saved: return "bookmark"
        }
    }
    
    private func emptyStateTitle() -> String {
        switch selectedTab {
        case .upcoming: return "No hay eventos próximos"
        case .today: return "No hay eventos hoy"
        case .favorites: return "No tienes favoritos"
        case .saved: return "No has guardado eventos"
        }
    }
    
    private func emptyStateMessage() -> String {
        switch selectedTab {
        case .upcoming: return "Revisa más tarde para ver nuevos eventos"
        case .today: return "No hay eventos programados para hoy"
        case .favorites: return "Marca eventos como favoritos para verlos aquí"
        case .saved: return "Guarda eventos para revisarlos después"
        }
    }
}

// MARK: - Supporting Views

struct CategoryChip: View {
    let category: EventCategory?
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.caption)
                } else {
                    Image(systemName: "list.bullet")
                        .font(.caption)
                }
                
                Text(category?.displayName ?? "Todos")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("(\(count))")
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .white : UI.navy)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? (category != nil ? Color(hex: category!.color) : UI.primary) : Color.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke((category != nil ? Color(hex: category!.color) : UI.primary).opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct EventsTabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .bold : .medium)
                    
                    Text("(\(count))")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(isSelected ? UI.primary : UI.muted)
                
                if isSelected {
                    Rectangle()
                        .fill(UI.primary)
                        .frame(height: 3)
                        .cornerRadius(1.5)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 3)
                }
            }
        }
    }
}

struct EventCard: View {
    let event: UniandesEvent
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image header (if available)
                if event.imageURL != nil {
                    ZStack(alignment: .topTrailing) {
                        CachedAsyncImage(url: event.imageURL) {
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: event.category.color),
                                    Color(hex: event.category.color).opacity(0.7)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                        .frame(height: 140)
                        .clipped()
                        
                        // Category badge overlay
                        HStack(spacing: 6) {
                            Image(systemName: event.category.icon)
                                .font(.caption)
                            Text(event.category.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: event.category.color))
                        .cornerRadius(12)
                        .padding(12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    // Header with category and actions (only if no image)
                    HStack {
                        if event.imageURL == nil {
                            HStack(spacing: 6) {
                                Image(systemName: event.category.icon)
                                    .font(.caption)
                                Text(event.category.displayName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: event.category.color))
                            .cornerRadius(12)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button(action: onFavorite) {
                                Image(systemName: event.isFavorite ? "star.fill" : "star")
                                    .foregroundColor(event.isFavorite ? .yellow : UI.muted)
                            }
                            
                            Button(action: onSave) {
                                Image(systemName: event.savedForLater ? "bookmark.fill" : "bookmark")
                                    .foregroundColor(event.savedForLater ? UI.primary : UI.muted)
                            }
                        }
                        .font(.title3)
                    }
                
                // Title
                Text(event.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(UI.navy)
                    .multilineTextAlignment(.leading)
                
                // Date and Time
                HStack(spacing: 12) {
                    Label(event.dateRange, systemImage: "calendar")
                    Label(event.timeRange, systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(UI.muted)
                
                // Location (if available)
                if let location = event.location {
                    Label(location, systemImage: "mappin.circle")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                        .lineLimit(1)
                }
                
                // Tags
                if !event.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(event.tags.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .foregroundColor(UI.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(UI.primary.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                
                // Status indicators
                HStack(spacing: 12) {
                    if event.isRegistered {
                        Label("Inscrito", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    if event.isToday {
                        Label("Hoy", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if event.daysUntil > 0 && event.daysUntil <= 7 {
                        Label("En \(event.daysUntil) días", systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundColor(UI.primary)
                    }
                }
                }
                .padding(event.imageURL != nil ? 12 : 16)
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    UniandesEventsView(onMenuTapped: {})
}
