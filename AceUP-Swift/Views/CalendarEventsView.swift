//
//  CalendarEventsView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import SwiftUI

struct CalendarEventsView: View {
    @StateObject private var eventsRepository = FirebaseCalendarEventsRepository()
    @StateObject private var availabilityRepository = FirebaseUserAvailabilityRepository()
    @State private var selectedDate = Date()
    @State private var showingCreateEvent = false
    @State private var showingEventDetails: CalendarEvent?
    @State private var selectedEvent: CalendarEvent?
    @State private var searchText = ""
    
    let onMenuTapped: () -> Void
    
    init(onMenuTapped: @escaping () -> Void = {}) {
        self.onMenuTapped = onMenuTapped
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Search Bar
                searchSection
                
                // Calendar and Events
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Calendar Widget
                        calendarSection
                        
                        // Events List
                        eventsSection
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .onAppear {
                setupView()
            }
            .sheet(isPresented: $showingCreateEvent) {
                CreateCalendarEventView(
                    repository: eventsRepository,
                    initialDate: selectedDate
                ) {
                    // Refresh events after creation
                    Task {
                        _ = try? await eventsRepository.loadEvents()
                    }
                }
            }
            .sheet(item: $showingEventDetails) { event in
                EventDetailsView(
                    event: event,
                    repository: eventsRepository
                ) {
                    // Refresh after editing
                    Task {
                        _ = try? await eventsRepository.loadEvents()
                    }
                }
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onMenuTapped) {
                    Image(systemName: "line.horizontal.3")
                        .font(.title2)
                        .foregroundColor(UI.navy)
                }
                
                Spacer()
                
                Text("Calendar Events")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Button(action: { showingCreateEvent = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(UI.primary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Divider()
        }
        .background(.white)
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search events...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Calendar Section
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calendar")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            // Mini Calendar
            CalendarWidgetView(
                selectedDate: $selectedDate,
                events: eventsRepository.events
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Events Section
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Events")
                    .font(.headline)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Text(DateFormatter.mediumDate.string(from: selectedDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if eventsRepository.isLoading {
                loadingView
            } else if filteredEvents.isEmpty {
                emptyEventsView
            } else {
                eventsListView
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private var filteredEvents: [CalendarEvent] {
        let calendar = Calendar.current
        let selectedDayEvents = eventsRepository.events.filter { event in
            calendar.isDate(event.startTime, inSameDayAs: selectedDate)
        }
        
        if searchText.isEmpty {
            return selectedDayEvents
        } else {
            return selectedDayEvents.filter { event in
                event.title.localizedCaseInsensitiveContains(searchText) ||
                (event.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (event.location?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading events...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var emptyEventsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No events for this day")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Tap the + button to create your first event")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Create Event") {
                showingCreateEvent = true
            }
            .foregroundColor(UI.primary)
            .font(.headline)
        }
        .padding(.vertical, 20)
    }
    
    private var eventsListView: some View {
        LazyVStack(spacing: 8) {
            ForEach(filteredEvents.sorted(by: { $0.startTime < $1.startTime })) { event in
                eventCard(event)
            }
        }
    }
    
    private func eventCard(_ event: CalendarEvent) -> some View {
        Button(action: {
            showingEventDetails = event
        }) {
            HStack(spacing: 12) {
                // Time indicator
                VStack(alignment: .center, spacing: 2) {
                    Text(DateFormatter.shortTime.string(from: event.startTime))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(priorityColor(event.priority))
                    
                    Rectangle()
                        .fill(priorityColor(event.priority))
                        .frame(width: 3, height: 30)
                        .cornerRadius(1.5)
                }
                
                // Event details
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                        .lineLimit(1)
                    
                    if let description = event.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 8) {
                        if let location = event.location, !location.isEmpty {
                            Label(location, systemImage: "location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if event.isShared {
                            Label("Shared", systemImage: "person.2")
                                .font(.caption)
                                .foregroundColor(UI.primary)
                        }
                        
                        if event.isRecurring {
                            Label("Recurring", systemImage: "repeat")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                // Duration
                VStack(alignment: .trailing, spacing: 2) {
                    Text(durationText(from: event.startTime, to: event.endTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Helper Methods
    
    private func setupView() {
        Task {
            // Start real-time listeners
            eventsRepository.startRealtimeListener()
            availabilityRepository.startRealtimeListener()
            
            // Load initial data
            _ = try? await eventsRepository.loadEvents()
            _ = try? await availabilityRepository.loadUserAvailability()
        }
    }
    
    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }
    
    private func durationText(from startTime: Date, to endTime: Date) -> String {
        let duration = endTime.timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Calendar Widget View
struct CalendarWidgetView: View {
    @Binding var selectedDate: Date
    let events: [CalendarEvent]
    
    @State private var currentMonth = Date()
    
    var body: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(UI.primary)
                }
                
                Spacer()
                
                Text(DateFormatter.monthYear.string(from: currentMonth))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(UI.primary)
                }
            }
            
            // Days of week
            HStack {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(calendarDays, id: \.self) { date in
                    dayView(for: date)
                }
            }
        }
    }
    
    private var calendarDays: [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth
        
        var days: [Date] = []
        for i in 0..<42 { // 6 weeks
            if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                days.append(date)
            }
        }
        return days
    }
    
    private func dayView(for date: Date) -> some View {
        let calendar = Calendar.current
        let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasEvents = events.contains { calendar.isDate($0.startTime, inSameDayAs: date) }
        
        return Button(action: {
            selectedDate = date
        }) {
            VStack(spacing: 2) {
                Text("\\(calendar.component(.day, from: date))")
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(
                        isSelected ? .white :
                        isToday ? UI.primary :
                        isCurrentMonth ? UI.navy : .gray
                    )
                
                if hasEvents {
                    Circle()
                        .fill(isSelected ? .white : UI.primary)
                        .frame(width: 4, height: 4)
                } else {
                    Spacer()
                        .frame(height: 4)
                }
            }
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(isSelected ? UI.primary : .clear)
            )
            .overlay(
                Circle()
                    .stroke(isToday ? UI.primary : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
    
    private func previousMonth() {
        withAnimation {
            currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation {
            currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
}

// MARK: - Date Formatters
extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
}

#Preview {
    CalendarEventsView()
}