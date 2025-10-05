//
//  SharedCalendarsView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 19/09/25.
//

import SwiftUI

struct SharedCalendarsView: View {
    let onMenuTapped: () -> Void
    let onGroupSelected: (CalendarGroup) -> Void
    
    @StateObject private var viewModel = SharedCalendarViewModel()
    @State private var showingActionSheet = false
    @State private var showingJoinGroup = false
    @State private var showingGroupQR: CalendarGroup?
    
    init(onMenuTapped: @escaping () -> Void = {}, onGroupSelected: @escaping (CalendarGroup) -> Void = { _ in }) {
        self.onMenuTapped = onMenuTapped
        self.onGroupSelected = onGroupSelected
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Main Content
                    mainContent
                }
                
                // Smart Suggestions Overlay
                if !viewModel.recentSuggestions.isEmpty {
                    smartSuggestionsOverlay
                }
                
                // Loading Overlay
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $viewModel.showingCreateGroup) {
                CreateGroupView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingJoinGroup) {
                JoinGroupView {
                    // Reload groups when a new group is joined
                    viewModel.loadGroups()
                    viewModel.showingJoinGroup = false
                }
            }
            .actionSheet(isPresented: $showingActionSheet) {
                ActionSheet(
                    title: Text("Add Group"),
                    buttons: [
                        .default(Text("Create New Group")) {
                            viewModel.showingCreateGroup = true
                        },
                        .default(Text("Join Existing Group")) {
                            showingJoinGroup = true
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showingJoinGroup) {
                JoinGroupView {
                    viewModel.loadGroups()
                }
            }
            .sheet(item: $showingGroupQR) { group in
                GroupQRCodeView(group: group)
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack {
            HStack {
                Button(action: onMenuTapped) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(UI.navy)
                        .font(.body)
                }
                
                Spacer()
                
                Text("Shared Calendars")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Button(action: {
                    // Edit functionality can be implemented later
                }) {
                    Text("Edit")
                        .foregroundColor(UI.navy)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 60)
        .background(Color(hex: "#B8C8DB"))
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Stats Section
            statsSection
            
            // Groups List Section
            groupsListSection
            
            Spacer()
        }
        .background(UI.neutralLight)
        .overlay(
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingActionSheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(UI.primary)
                            .clipShape(Circle())
                            .shadow(color: UI.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 30)
                }
            }
        )
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Total Groups:")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Text("\(viewModel.totalGroups)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
            }
            
            // Additional stats
            if viewModel.totalGroups > 0 {
                HStack {
                    StatCard(
                        title: "Active",
                        value: "\(viewModel.activeGroups.count)",
                        color: UI.success
                    )
                    
                    StatCard(
                        title: "Members",
                        value: "\(viewModel.groups.reduce(0) { $0 + $1.memberCount })",
                        color: UI.primary
                    )
                    
                    StatCard(
                        title: "Suggestions",
                        value: "\(viewModel.smartSuggestions.count)",
                        color: UI.warning
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(UI.neutralLight)
    }
    
    // MARK: - Groups List Section
    private var groupsListSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your Groups")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            .background(UI.neutralLight)
            
            if viewModel.groups.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.groups) { group in
                            GroupRow(
                                group: group,
                                onTapped: {
                                    viewModel.selectGroup(group)
                                    onGroupSelected(group)
                                },
                                onQRTapped: { group in
                                    showingGroupQR = group
                                }
                            )
                            
                            if group.id != viewModel.groups.last?.id {
                                Divider()
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .background(UI.neutralLight)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(UI.muted)
            
            Text("No Groups Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)
            
            Text("Create or join a group to start sharing calendars with friends and classmates")
                .font(.body)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                showingActionSheet = true
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(UI.primary)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
        .background(UI.neutralLight)
    }
    
    // MARK: - Smart Suggestions Overlay
    private var smartSuggestionsOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(UI.muted.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)
                
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(UI.warning)
                    
                    Text("Smart Suggestions")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.smartSuggestions.removeAll()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(UI.muted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 15)
                
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.recentSuggestions, id: \.id) { suggestion in
                        SmartSuggestionCard(
                            suggestion: suggestion,
                            onAccept: {
                                viewModel.acceptSuggestion(suggestion)
                            },
                            onDismiss: {
                                viewModel.dismissSuggestion(suggestion)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
            )
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: UI.primary))
                
                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}


// MARK: - Supporting Views

struct GroupRow: View {
    let group: CalendarGroup
    let onTapped: () -> Void
    let onQRTapped: ((CalendarGroup) -> Void)?
    
    init(group: CalendarGroup, onTapped: @escaping () -> Void = {}, onQRTapped: ((CalendarGroup) -> Void)? = nil) {
        self.group = group
        self.onTapped = onTapped
        self.onQRTapped = onQRTapped
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // Group Color Indicator
            Circle()
                .fill(Color(hex: group.color))
                .frame(width: 40, height: 40)
                .overlay(
                    Text("\(group.memberCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
                
                Text(membersSummary)
                    .font(.caption)
                    .foregroundColor(UI.muted)
                    .lineLimit(1)
                
                if !group.description.isEmpty {
                    Text(group.description)
                        .font(.caption2)
                        .foregroundColor(UI.muted)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                if group.inviteCode != nil {
                    Button(action: {
                        onQRTapped?(group)
                    }) {
                        Image(systemName: "qrcode")
                            .foregroundColor(UI.primary)
                            .font(.body)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(UI.muted)
                        .font(.caption)
                    
                    if group.isPublic {
                        Image(systemName: "globe")
                            .foregroundColor(UI.primary)
                            .font(.caption2)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
        .onTapGesture {
            onTapped()
        }
    }
    
    private var membersSummary: String {
        let memberNames = group.members.prefix(3).map { $0.name }
        let remainingCount = max(0, group.memberCount - 3)
        
        var summary = memberNames.joined(separator: ", ")
        if remainingCount > 0 {
            summary += " +\(remainingCount) more"
        }
        
        return summary
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(UI.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

struct SmartSuggestionCard: View {
    let suggestion: SmartSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: suggestion.type.icon)
                    .foregroundColor(Color(hex: suggestion.type == .deadlineReminder ? "#E74C3C" : "#3498DB"))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Text(suggestion.description)
                        .font(.caption)
                        .foregroundColor(UI.muted)
                }
                
                Spacer()
                
                // Confidence indicator
                ConfidenceIndicator(confidence: suggestion.confidence)
            }
            
            if suggestion.actionRequired {
                HStack(spacing: 10) {
                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .font(.caption)
                            .foregroundColor(UI.muted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(UI.muted.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Button(action: onAccept) {
                        Text("Accept")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(UI.primary)
                            )
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

struct ConfidenceIndicator: View {
    let confidence: Double
    
    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            
            Text("\(Int(confidence * 100))%")
                .font(.caption2)
                .foregroundColor(UI.muted)
        }
    }
    
    private var confidenceColor: Color {
        if confidence >= 0.8 {
            return Color(hex: "#27AE60")
        } else if confidence >= 0.6 {
            return Color(hex: "#F39C12")
        } else {
            return Color(hex: "#E74C3C")
        }
    }
}

// MARK: - Create Group View
struct CreateGroupView: View {
    @ObservedObject var viewModel: SharedCalendarViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Create New Group")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(UI.navy)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(UI.navy)
                        
                        StyledTextField("Enter group name", text: $viewModel.newGroupName)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(UI.navy)
                        
                        StyledTextField("Describe your group's purpose", text: $viewModel.newGroupDescription)
                    }
                    
                    HStack {
                        Toggle("Public Group", isOn: $viewModel.newGroupIsPublic)
                            .toggleStyle(CheckToggleStyle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Public Group")
                                .font(.subheadline)
                                .foregroundColor(UI.navy)
                            
                            Text("Anyone can find and join this group")
                                .font(.caption)
                                .foregroundColor(UI.muted)
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.createGroup()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Create Group")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.newGroupName.isEmpty)
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

#Preview {
    SharedCalendarsView(
        onMenuTapped: {
            print("Menu tapped")
        },
        onGroupSelected: { group in
            print("Group selected: \(group.name)")
        }
    )
}