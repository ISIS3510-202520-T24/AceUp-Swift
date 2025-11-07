//
//  UserProfileView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/11/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UserProfileView: View {
    @StateObject private var authService = AuthService()
    @StateObject private var profileManager = UserProfileManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditProfile = false
    @State private var showingChangePassword = false
    @State private var showingImagePicker = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingDataExport = false
    @State private var showingPrivacySettings = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Header
                profileHeaderSection
                
                // Personal Information
                personalInfoSection
                
                // Account Settings
                accountSettingsSection
                
                // Danger Zone
                dangerZoneSection
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showingChangePassword) {
            ChangePasswordView()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                Task {
                    // Track profile image update
                    UserUpdateAnalytics.shared.startUpdateSession(type: .profileImage)
                    await profileManager.updateProfileImage(image)
                    UserUpdateAnalytics.shared.completeUpdateSession(
                        type: .profileImage,
                        fieldsUpdated: ["profileImage"]
                    )
                }
            }
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView()
        }
        .sheet(isPresented: $showingPrivacySettings) {
            PrivacySettingsView()
        }
        .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await profileManager.deleteAccount()
                }
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .task {
            await profileManager.loadUserProfile()
        }
    }
    
    // MARK: - Profile Header Section
    
    private var profileHeaderSection: some View {
        Section {
            HStack {
                Button(action: { showingImagePicker = true }) {
                    AsyncImage(url: profileManager.profileImageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(UI.primary.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(UI.primary)
                                    .font(.title)
                            )
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(UI.primary, lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: "camera.circle.fill")
                            .foregroundColor(UI.primary)
                            .background(Circle().fill(.white))
                            .offset(x: 25, y: 25)
                    )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(profileManager.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Text(profileManager.email)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("Member since \(profileManager.memberSince)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Personal Information Section
    
    private var personalInfoSection: some View {
        Section("Personal Information") {
            ProfileRow(title: "Display Name", value: profileManager.displayName, icon: "person")
            ProfileRow(title: "Email", value: profileManager.email, icon: "envelope")
            ProfileRow(title: "University", value: profileManager.university ?? "Not set", icon: "building.2")
            ProfileRow(title: "Study Program", value: profileManager.studyProgram ?? "Not set", icon: "graduationcap")
            ProfileRow(title: "Academic Year", value: profileManager.academicYear ?? "Not set", icon: "calendar.badge.plus")
            
            Button(action: { showingEditProfile = true }) {
                HStack {
                    Image(systemName: "pencil")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("Edit Profile")
                        .foregroundColor(UI.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Account Settings Section
    
    private var accountSettingsSection: some View {
        Section("Account") {
            Button(action: { showingChangePassword = true }) {
                HStack {
                    Image(systemName: "key")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("Change Password")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            Button(action: { showingDataExport = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("Export My Data")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            Button(action: { showingPrivacySettings = true }) {
                HStack {
                    Image(systemName: "hand.raised")
                        .foregroundColor(UI.primary)
                        .frame(width: 20)
                    
                    Text("Privacy Settings")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            HStack {
                Image(systemName: "checkmark.shield")
                    .foregroundColor(Auth.auth().currentUser?.isEmailVerified == true ? .green : .orange)
                    .frame(width: 20)
                
                Text("Email Verification")
                
                Spacer()
                
                Text(Auth.auth().currentUser?.isEmailVerified == true ? "Verified" : "Pending")
                    .foregroundColor(Auth.auth().currentUser?.isEmailVerified == true ? .green : .orange)
                    .font(.caption)
                
                if Auth.auth().currentUser?.isEmailVerified == false {
                    Button("Resend") {
                        Task {
                            try? await Auth.auth().currentUser?.sendEmailVerification()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(UI.primary)
                }
            }
        }
    }
    
    // MARK: - Danger Zone Section
    
    private var dangerZoneSection: some View {
        Section("Danger Zone") {
            Button(action: { showingDeleteAccountAlert = true }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .frame(width: 20)
                    
                    Text("Delete Account")
                        .foregroundColor(.red)
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Profile Row Component

struct ProfileRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(UI.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @StateObject private var profileManager = UserProfileManager.shared
    @StateObject private var analytics = UserUpdateAnalytics.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName: String = ""
    @State private var university: String = ""
    @State private var studyProgram: String = ""
    @State private var academicYear: String = ""
    @State private var isLoading = false
    @State private var hasStartedSession = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    HStack {
                        Text("Display Name")
                        Spacer()
                        TextField("Enter name", text: $displayName)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: displayName) {
                                trackInteractionOnce()
                            }
                    }
                    
                    HStack {
                        Text("University")
                        Spacer()
                        TextField("Enter university", text: $university)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: university) {
                                trackInteractionOnce()
                            }
                    }
                    
                    HStack {
                        Text("Study Program")
                        Spacer()
                        TextField("Enter program", text: $studyProgram)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: studyProgram) {
                                trackInteractionOnce()
                            }
                    }
                    
                    HStack {
                        Text("Academic Year")
                        Spacer()
                        Picker("Year", selection: $academicYear) {
                            Text("Not specified").tag("")
                            Text("1st Year").tag("1st Year")
                            Text("2nd Year").tag("2nd Year")
                            Text("3rd Year").tag("3rd Year")
                            Text("4th Year").tag("4th Year")
                            Text("5th Year").tag("5th Year")
                            Text("Graduate").tag("Graduate")
                            Text("PhD").tag("PhD")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: academicYear) {
                            trackInteractionOnce()
                        }
                    }
                }
                
                Section(footer: Text("Changes will be saved to your profile and synced across devices.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(isLoading)
                }
            }
            .disabled(isLoading)
        }
        .onAppear {
            loadCurrentValues()
            // Start analytics session when user opens edit screen
            analytics.startUpdateSession(type: .personalInfo)
        }
        .onDisappear {
            // If user closes without saving, abandon the session
            if hasStartedSession {
                analytics.abandonUpdateSession(type: .personalInfo)
            }
        }
    }
    
    private func trackInteractionOnce() {
        if !hasStartedSession {
            hasStartedSession = true
        }
        analytics.trackInteraction(type: .personalInfo)
    }
    
    private func loadCurrentValues() {
        displayName = profileManager.displayName
        university = profileManager.university ?? ""
        studyProgram = profileManager.studyProgram ?? ""
        academicYear = profileManager.academicYear ?? ""
    }
    
    private func saveProfile() {
        isLoading = true
        
        // Track which fields were updated
        var fieldsUpdated: [String] = []
        if displayName != profileManager.displayName { fieldsUpdated.append("displayName") }
        if university != (profileManager.university ?? "") { fieldsUpdated.append("university") }
        if studyProgram != (profileManager.studyProgram ?? "") { fieldsUpdated.append("studyProgram") }
        if academicYear != (profileManager.academicYear ?? "") { fieldsUpdated.append("academicYear") }
        
        Task {
            await profileManager.updateProfile(
                displayName: displayName.isEmpty ? nil : displayName,
                university: university.isEmpty ? nil : university,
                studyProgram: studyProgram.isEmpty ? nil : studyProgram,
                academicYear: academicYear.isEmpty ? nil : academicYear
            )
            
            // Complete analytics session with tracked fields
            analytics.completeUpdateSession(
                type: .personalInfo,
                fieldsUpdated: fieldsUpdated
            )
            
            // Mark session as completed so onDisappear doesn't abandon it
            hasStartedSession = false
            isLoading = false
            
            dismiss()
        }
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Current Password") {
                    SecureField("Enter current password", text: $currentPassword)
                }
                
                Section("New Password") {
                    SecureField("Enter new password", text: $newPassword)
                    SecureField("Confirm new password", text: $confirmPassword)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if let successMessage = successMessage {
                    Section {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Section(footer: Text("Password must be at least 8 characters long and contain uppercase, lowercase, numbers, and symbols.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Update") {
                        changePassword()
                    }
                    .disabled(isLoading || !isValidForm)
                }
            }
            .disabled(isLoading)
        }
    }
    
    private var isValidForm: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8
    }
    
    private func changePassword() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                // Re-authenticate with current password
                let user = Auth.auth().currentUser
                let credential = EmailAuthProvider.credential(withEmail: user?.email ?? "", password: currentPassword)
                try await user?.reauthenticate(with: credential)
                
                // Update password
                try await user?.updatePassword(to: newPassword)
                
                successMessage = "Password updated successfully"
                isLoading = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    UserProfileView()
}