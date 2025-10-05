//
//  GroupCalendarView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 19/09/25.
//

import SwiftUI
import Combine

struct GroupCalendarView: View {
    let onMenuTapped: () -> Void
    let onBackTapped: () -> Void
    let group: CalendarGroup?
    
    @StateObject private var viewModel = GroupCalendarViewModel()
    @State private var showingDatePicker = false
    @State private var showingMemberList = false
    
    init(onMenuTapped: @escaping () -> Void = {}, 
         onBackTapped: @escaping () -> Void = {},
         group: CalendarGroup? = nil) {
        self.onMenuTapped = onMenuTapped
        self.onBackTapped = onBackTapped
        self.group = group
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Date Navigation
            dateNavigationView
            
            // Weekly Calendar
            weeklyCalendarView
            
            // Schedule Content
            scheduleContentView
        }
        .navigationBarHidden(true)
        .onAppear {
            if let group = group {
                viewModel.setGroup(group)
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerView(selectedDate: $viewModel.selectedDate)
        }
        .sheet(isPresented: $showingMemberList) {
            if let group = viewModel.selectedGroup {
                GroupMembersView(group: group)
            }
        }
        .sheet(isPresented: $viewModel.showingEventCreation) {
            if let timeSlot = viewModel.selectedTimeSlot {
                CreateEventView(
                    timeSlot: timeSlot,
                    group: viewModel.selectedGroup,
                    onEventCreated: {
                        viewModel.refreshSelectedGroup()
                    }
                )
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack {
            HStack {
                Button(action: onBackTapped) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(UI.navy)
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Button(action: {
                    showingMemberList = true
                }) {
                    VStack(spacing: 2) {
                        Text(viewModel.selectedGroup?.name ?? "Group Calendar")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(UI.navy)
                        
                        if let group = viewModel.selectedGroup {
                            Text("\(group.memberCount) members")
                                .font(.caption)
                                .foregroundColor(UI.muted)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onMenuTapped) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(UI.navy)
                        .font(.body)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 60)
        .background(Color(hex: "#B8C8DB"))
    }
    
    // MARK: - Date Navigation
    private var dateNavigationView: some View {
        HStack {
            Button(action: {
                viewModel.previousWeek()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(UI.navy)
                    .font(.body)
            }
            
            Spacer()
            
            Button(action: {
                showingDatePicker = true
            }) {
                Text(viewModel.formattedSelectedDate)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.nextWeek()
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(UI.navy)
                    .font(.body)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(UI.neutralLight)
    }
    
    // MARK: - Weekly Calendar
    private var weeklyCalendarView: some View {
        WeeklyCalendarView(
            currentWeek: viewModel.currentWeek,
            selectedDate: $viewModel.selectedDate,
            onDateSelected: { date in
                viewModel.selectDate(date)
            }
        )
        .background(UI.neutralLight)
    }
    
    // MARK: - Schedule Content
    private var scheduleContentView: some View {
        ZStack {
            if viewModel.isLoading {
                loadingView
            } else {
                mainScheduleView
            }
        }
        .background(UI.neutralLight)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: UI.primary))
            
            Text("Generating smart schedule...")
                .font(.subheadline)
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Main Schedule View
    private var mainScheduleView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Smart insights section
                if !viewModel.commonFreeSlots.isEmpty || !viewModel.conflictingSlots.isEmpty {
                    smartInsightsSection
                }
                
                // Time grid
                timeGridSection
            }
        }
    }
    
    // MARK: - Smart Insights Section
    private var smartInsightsSection: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(UI.primary)
                
                Text("Smart Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            if !viewModel.commonFreeSlots.isEmpty {
                freeTimeSlotsSection
            }
            
            if !viewModel.conflictingSlots.isEmpty {
                conflictingSlotsSection
            }
        }
        .background(UI.neutralLight)
    }
    
    // MARK: - Free Time Slots Section
    private var freeTimeSlotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Available Time Slots")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Text("\(viewModel.commonFreeSlots.count) found")
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.commonFreeSlots.prefix(5), id: \.id) { slot in
                        FreeSlotCard(
                            slot: slot,
                            group: viewModel.selectedGroup,
                            onTap: {
                                viewModel.selectTimeSlot(slot)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Conflicting Slots Section
    private var conflictingSlotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Schedule Conflicts")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Text("\(viewModel.conflictingSlots.count) conflicts")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#E74C3C"))
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.conflictingSlots.prefix(5), id: \.id) { conflict in
                        ConflictSlotCard(conflict: conflict)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Time Grid Section
    private var timeGridSection: some View {
        VStack(spacing: 0) {
            ForEach(6..<24, id: \.self) { hour in
                TimeSlotRow(
                    hour: hour,
                    freeSlots: viewModel.commonFreeSlots.filter { slot in
                        slot.startTime.hour == hour
                    },
                    conflicts: viewModel.conflictingSlots.filter { conflict in
                        conflict.startTime.hour == hour
                    },
                    onSlotTapped: { slot in
                        viewModel.selectTimeSlot(slot)
                    }
                )
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Supporting Views

struct WeeklyCalendarView: View {
    let currentWeek: [Date]
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    
    private let weekDays = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                if index < currentWeek.count {
                    let date = currentWeek[index]
                    let dayNumber = Calendar.current.component(.day, from: date)
                    let isSelected = Calendar.current.isDate(selectedDate, inSameDayAs: date)
                    let isToday = Calendar.current.isDateInToday(date)
                    
                    VStack(spacing: 8) {
                        Text(weekDays[index])
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(UI.muted)
                        
                        Text("\(dayNumber)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .white : (isToday ? UI.primary : UI.navy))
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? UI.primary : (isToday ? UI.primary.opacity(0.1) : Color.clear))
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDate = date
                        onDateSelected(date)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 20)
    }
}

struct FreeSlotCard: View {
    let slot: CommonFreeSlot
    let group: CalendarGroup?
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(confidenceColor)
                    .frame(width: 8, height: 8)
                
                Text("\(slot.startTime.timeString) - \(slot.endTime.timeString)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
            }
            
            Text("\(slot.duration) min")
                .font(.caption2)
                .foregroundColor(UI.muted)
            
            Text("\(slot.availableMembers.count)/\(group?.memberCount ?? 0) available")
                .font(.caption2)
                .foregroundColor(UI.muted)
        }
        .padding(12)
        .frame(width: 120, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
        .onTapGesture {
            onTap()
        }
    }
    
    private var confidenceColor: Color {
        if slot.confidence >= 0.8 {
            return Color(hex: "#27AE60")
        } else if slot.confidence >= 0.5 {
            return Color(hex: "#F39C12")
        } else {
            return Color(hex: "#E74C3C")
        }
    }
}

struct ConflictSlotCard: View {
    let conflict: ConflictingSlot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(hex: "#E74C3C"))
                    .frame(width: 8, height: 8)
                
                Text("\(conflict.startTime.timeString) - \(conflict.endTime.timeString)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
            }
            
            Text("\(conflict.conflicts.count) conflicts")
                .font(.caption2)
                .foregroundColor(Color(hex: "#E74C3C"))
            
            let conflictTypes = Set(conflict.conflicts.map { $0.conflictType.displayName })
            Text(conflictTypes.joined(separator: ", "))
                .font(.caption2)
                .foregroundColor(UI.muted)
                .lineLimit(2)
        }
        .padding(12)
        .frame(width: 120, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
    }
}

struct TimeSlotRow: View {
    let hour: Int
    let freeSlots: [CommonFreeSlot]
    let conflicts: [ConflictingSlot]
    let onSlotTapped: (CommonFreeSlot) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Time label
            Text("\(hour):00")
                .font(.caption)
                .foregroundColor(UI.muted)
                .frame(width: 50, alignment: .trailing)
                .padding(.trailing, 10)
            
            // Time slot content
            ZStack(alignment: .leading) {
                // Background line
                Rectangle()
                    .fill(UI.muted.opacity(0.2))
                    .frame(height: 1)
                
                // Free slots
                HStack(spacing: 2) {
                    ForEach(freeSlots, id: \.id) { slot in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "#50E3C2").opacity(0.7))
                            .frame(height: 30)
                            .overlay(
                                Text("\(slot.availableMembers.count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                            .onTapGesture {
                                onSlotTapped(slot)
                            }
                    }
                    
                    // Conflicts
                    ForEach(conflicts, id: \.id) { conflict in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "#FF6B6B").opacity(0.7))
                            .frame(height: 30)
                            .overlay(
                                Image(systemName: "exclamationmark")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }
}

// MARK: - Modal Views

struct DatePickerView: View {
    @Binding var selectedDate: Date
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                
                Spacer()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct GroupMembersView: View {
    let group: CalendarGroup
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(group.members) { member in
                    HStack {
                        Circle()
                            .fill(Color(hex: group.color))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(member.name.prefix(1)))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text(member.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if member.isAdmin {
                            Text("Admin")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Group Members")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct CreateEventView: View {
    let timeSlot: CommonFreeSlot
    let group: CalendarGroup?
    let onEventCreated: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var eventTitle = ""
    @State private var eventDescription = ""
    @State private var eventType: AvailabilityType = .meeting
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Create Event")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(UI.navy)
                    
                    Text("Time: \(timeSlot.startTime.timeString) - \(timeSlot.endTime.timeString)")
                        .font(.subheadline)
                        .foregroundColor(UI.muted)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Event Title")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(UI.navy)
                        
                        TextField("Enter event title", text: $eventTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(UI.navy)
                        
                        TextField("Event description (optional)", text: $eventDescription)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Event Type")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(UI.navy)
                        
                        Picker("Event Type", selection: $eventType) {
                            ForEach([AvailabilityType.meeting, .personal, .assignment], id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // Create event logic here
                    onEventCreated()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Create Event")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                }
                .background(UI.primary)
                .cornerRadius(10)
                .disabled(eventTitle.isEmpty)
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// Remove the studySession extension since it's not needed

#Preview {
    GroupCalendarView(
        onMenuTapped: {
            print("Menu tapped")
        },
        onBackTapped: {
            print("Back tapped")
        },
        group: CalendarGroup(
            id: "1",
            name: "Mobile Dev Team",
            description: "iOS Development Project Group",
            members: [],
            createdAt: Date(),
            createdBy: "user1",
            color: "#4ECDC4",
            isPublic: false,
            inviteCode: "ABC123"
        )
    )
}