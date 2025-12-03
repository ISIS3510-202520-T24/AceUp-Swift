//
//  WeekView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/12/25.
//

import SwiftUI

/// Main Week View with interactive calendar, filtering, and event management
struct WeekView: View {
    let onMenuTapped: () -> Void
    
    @StateObject private var viewModel = WeekViewModel()
    @State private var showFilter = false
    @State private var showEventCreation = false
    @State private var draggedEvent: WeekEvent?
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header with navigation
                weekHeader
                
                // Week overview bar
                weekOverviewBar
                
                // Filter chips
                if !viewModel.filter.eventTypes.isEmpty {
                    filterChipsBar
                }
                
                // Main content
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Week days grid
                        weekDaysGrid
                        
                        // Timeline view
                        timelineView
                    }
                }
                .background(UI.neutralLight)
            }
            
            // Loading overlay
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .sheet(isPresented: $showFilter) {
            WeekFilterView(filter: $viewModel.filter) {
                viewModel.updateFilter(viewModel.filter)
            }
        }
        .sheet(isPresented: $viewModel.showEventDetail) {
            if let event = viewModel.selectedEvent {
                WeekEventDetailView(event: event)
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadWeek()
        }
    }
    
    // MARK: - Header
    
    private var weekHeader: some View {
        HStack {
            Button(action: onMenuTapped) {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(UI.navy)
                    .font(.title2)
            }
            
            Spacer()
            
            Text("Week View")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: { showFilter.toggle() }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(UI.navy)
                        .font(.title2)
                }
                
                Button(action: { viewModel.goToToday() }) {
                    Image(systemName: "calendar.circle")
                        .foregroundColor(UI.navy)
                        .font(.title2)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(hex: "#B8C8DB"))
    }
    
    // MARK: - Week Overview Bar
    
    private var weekOverviewBar: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { viewModel.previousWeek() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(UI.navy)
                        .font(.body)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(viewModel.weekSummary?.weekRange ?? "")
                        .font(.headline)
                        .foregroundColor(UI.navy)
                    
                    if let summary = viewModel.weekSummary {
                        Text("\(summary.totalEvents) events")
                            .font(.caption)
                            .foregroundColor(UI.muted)
                    }
                }
                
                Spacer()
                
                Button(action: { viewModel.nextWeek() }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(UI.navy)
                        .font(.body)
                }
            }
            .padding(.horizontal, 20)
            
            // Week stats
            if let summary = viewModel.weekSummary {
                HStack(spacing: 20) {
                    WeekStatBadge(
                        icon: "clock.fill",
                        value: String(format: "%.1fh", summary.totalBusyHours),
                        label: "Busy"
                    )
                    
                    WeekStatBadge(
                        icon: "exclamationmark.triangle.fill",
                        value: "\(summary.conflictingSlots)",
                        label: "Conflicts"
                    )
                    
                    WeekStatBadge(
                        icon: "flag.fill",
                        value: "\(summary.upcomingDeadlines)",
                        label: "Due"
                    )
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 12)
        .background(UI.neutralLight)
    }
    
    // MARK: - Filter Chips Bar
    
    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(viewModel.filter.eventTypes), id: \.self) { type in
                    FilterChip(
                        icon: type.icon,
                        label: type.displayName,
                        color: Color(hex: type.defaultColor)
                    ) {
                        var newFilter = viewModel.filter
                        newFilter.eventTypes.remove(type)
                        viewModel.updateFilter(newFilter)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
        .background(UI.neutralLight)
    }
    
    // MARK: - Week Days Grid
    
    private var weekDaysGrid: some View {
        HStack(spacing: 0) {
            // Time column spacer
            Color.clear
                .frame(width: 50)
            
            // Day columns
            ForEach(viewModel.daySchedules) { daySchedule in
                WeekDayColumn(
                    daySchedule: daySchedule,
                    isSelected: Calendar.current.isDate(daySchedule.date, inSameDayAs: viewModel.selectedDate),
                    onTap: {
                        viewModel.selectDate(daySchedule.date)
                    }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .background(UI.neutralLight)
    }
    
    // MARK: - Timeline View
    
    private var timelineView: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        // Background grid
                        timelineGrid
                        
                        // Events overlay
                        eventsOverlay(in: geometry)
                    }
                    .frame(height: CGFloat(24 * 60)) // 24 hours at 1pt per minute
                }
                .onAppear {
                    // Scroll to current time
                    let currentHour = Calendar.current.component(.hour, from: Date())
                    withAnimation {
                        proxy.scrollTo("hour-\(max(0, currentHour - 2))", anchor: .top)
                    }
                }
            }
        }
        .frame(height: 600)
    }
    
    private var timelineGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(spacing: 0) {
                    // Hour label
                    Text(String(format: "%02d:00", hour))
                        .font(.caption)
                        .foregroundColor(UI.muted)
                        .frame(width: 50, alignment: .trailing)
                        .padding(.trailing, 8)
                        .id("hour-\(hour)")
                    
                    // Horizontal line
                    Rectangle()
                        .fill(UI.muted.opacity(0.2))
                        .frame(height: 1)
                }
                .frame(height: 60)
            }
        }
    }
    
    private func eventsOverlay(in geometry: GeometryProxy) -> some View {
        let filteredEvents = viewModel.events.filter { viewModel.filter.matches($0) }
        let eventsByDay = Dictionary(grouping: filteredEvents) { event in
            Calendar.current.startOfDay(for: event.startDate)
        }
        
        let dayWidth = (geometry.size.width - 50) / 7
        
        return ZStack(alignment: .topLeading) {
            ForEach(Array(eventsByDay.keys.sorted()), id: \.self) { date in
                if let dayIndex = viewModel.daySchedules.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                    let dayEvents = eventsByDay[date] ?? []
                    
                    ForEach(dayEvents) { event in
                        WeekEventBlock(
                            event: event,
                            onTap: {
                                viewModel.selectEvent(event)
                            }
                        )
                        .frame(width: dayWidth - 4)
                        .offset(
                            x: 50 + CGFloat(dayIndex) * dayWidth + 2,
                            y: eventYPosition(for: event)
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    draggedEvent = event
                                }
                                .onEnded { value in
                                    handleEventDrag(event: event, translation: value.translation)
                                }
                        )
                    }
                }
            }
            
            // Current time indicator
            if Calendar.current.isDate(Date(), equalTo: viewModel.currentWeekStart, toGranularity: .weekOfYear) {
                currentTimeIndicator(width: geometry.size.width)
            }
        }
    }
    
    private func eventYPosition(for event: WeekEvent) -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: event.startDate)
        let minute = calendar.component(.minute, from: event.startDate)
        return CGFloat(hour * 60 + minute)
    }
    
    private func eventHeight(for event: WeekEvent) -> CGFloat {
        return CGFloat(event.durationInMinutes)
    }
    
    private func currentTimeIndicator(width: CGFloat) -> some View {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let yPosition = CGFloat(hour * 60 + minute)
        
        return HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .offset(x: 46)
            
            Rectangle()
                .fill(Color.red)
                .frame(width: width - 50, height: 2)
        }
        .offset(y: yPosition)
    }
    
    private func handleEventDrag(event: WeekEvent, translation: CGSize) {
        // Calculate new time based on vertical drag
        let minutesDragged = Int(translation.height)
        let newStartDate = event.startDate.addingTimeInterval(TimeInterval(minutesDragged * 60))
        
        Task {
            await viewModel.rescheduleEvent(event, to: newStartDate)
        }
        
        draggedEvent = nil
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Loading week...")
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
            )
        }
    }
}

// MARK: - Supporting Views

struct WeekStatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(UI.navy)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(UI.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

struct FilterChip: View {
    let icon: String
    let label: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color)
        )
    }
}

struct WeekDayColumn: View {
    let daySchedule: DaySchedule
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(daySchedule.shortDayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(daySchedule.isToday ? UI.primary : UI.muted)
                
                Text("\(daySchedule.dayNumber)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : (daySchedule.isToday ? UI.primary : UI.navy))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isSelected ? UI.primary : (daySchedule.isToday ? UI.primary.opacity(0.1) : Color.clear))
                    )
                
                // Event count indicator
                if !daySchedule.events.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(0..<min(3, daySchedule.events.count), id: \.self) { _ in
                            Circle()
                                .fill(UI.primary)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct WeekEventBlock: View {
    let event: WeekEvent
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: event.type.icon)
                        .font(.caption2)
                    
                    Text(event.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if event.isOverlapping {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
                
                Text(event.startTimeString)
                    .font(.caption2)
                    .opacity(0.8)
                
                if let location = event.location {
                    Text(location)
                        .font(.caption2)
                        .lineLimit(1)
                        .opacity(0.7)
                }
            }
            .foregroundColor(.white)
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: CGFloat(event.durationInMinutes), alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(event.uiColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(event.isOverlapping ? Color.yellow : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

// MARK: - Preview

struct WeekView_Previews: PreviewProvider {
    static var previews: some View {
        WeekView(onMenuTapped: {})
    }
}
