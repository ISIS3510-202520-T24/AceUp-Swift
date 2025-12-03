//
//  UserProfileManager.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/11/25.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Manages user profile data including personal information and profile images
/// Now integrated with UnifiedHybridDataProviders for optimized caching
@MainActor
class UserProfileManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = UserProfileManager()
    
    // MARK: - Published Properties
    
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var university: String?
    @Published var studyProgram: String?
    @Published var academicYear: String?
    @Published var profileImageURL: URL?
    @Published var memberSince: String = ""
    @Published var isLoading = false
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private let unifiedProvider = UnifiedHybridDataProviders.shared
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load initial user data if available
        loadBasicUserInfo()
    }
    
    // MARK: - Public Methods
    
    /// Load user profile from Firestore with caching
    func loadUserProfile() async {
        guard let userId = currentUserId else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Try cache first
            if let cachedProfile = try await unifiedProvider.loadUserProfile(userId: userId) {
                await updateLocalProfile(from: cachedProfile)
                return
            }
            
            // Fallback to direct Firestore fetch
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists, let data = document.data() {
                await updateLocalProfile(from: data)
            }
        } catch {
            print("Error loading user profile: \(error)")
        }
    }
    
    /// Update user profile information with automatic cache sync
    func updateProfile(
        displayName: String? = nil,
        university: String? = nil,
        studyProgram: String? = nil,
        academicYear: String? = nil
    ) async {
        guard let userId = currentUserId else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        var updates: [String: Any] = [:]
        
        if let displayName = displayName {
            updates["displayName"] = displayName
            self.displayName = displayName
            
            // Also update Firebase Auth profile
            let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
            changeRequest?.displayName = displayName
            try? await changeRequest?.commitChanges()
        }
        
        if let university = university {
            updates["university"] = university
            self.university = university
        }
        
        if let studyProgram = studyProgram {
            updates["studyProgram"] = studyProgram
            self.studyProgram = studyProgram
        }
        
        if let academicYear = academicYear {
            updates["academicYear"] = academicYear
            self.academicYear = academicYear
        }
        
        if !updates.isEmpty {
            updates["updatedAt"] = FieldValue.serverTimestamp()
            
            do {
                try await db.collection("users").document(userId).updateData(updates)
                
                // Update unified cache
                let profileData = UserProfileData(
                    userId: userId,
                    displayName: self.displayName,
                    email: self.email,
                    university: self.university,
                    studyProgram: self.studyProgram,
                    academicYear: self.academicYear,
                    profileImageData: nil
                )
                try await unifiedProvider.updateUserProfile(profileData)
            } catch {
                print("Error updating profile: \(error)")
            }
        }
    }
    
    /// Upload and update profile image with unified caching
    func updateProfileImage(_ image: UIImage) async {
        guard let userId = currentUserId,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let base64String = imageData.base64EncodedString()
            
            // Update Firestore with image data
            try await db.collection("users").document(userId).updateData([
                "profileImageData": base64String,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // Update Firebase Auth profile
            let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
            changeRequest?.photoURL = URL(string: "data:image/jpeg;base64,\(base64String)")
            try? await changeRequest?.commitChanges()
            
            // Update local state
            self.profileImageURL = URL(string: "data:image/jpeg;base64,\(base64String)")
            
            // Update unified cache
            let profileData = UserProfileData(
                userId: userId,
                displayName: self.displayName,
                email: self.email,
                university: self.university,
                studyProgram: self.studyProgram,
                academicYear: self.academicYear,
                profileImageData: base64String
            )
            try await unifiedProvider.updateUserProfile(profileData)
            
        } catch {
            print("Error updating profile image: \(error)")
        }
    }
    
    /// Delete user account and all associated data
    func deleteAccount() async {
        guard let userId = currentUserId else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Delete user data from Firestore
            try await db.collection("users").document(userId).delete()
            
            // Delete Firebase Auth account
            try await Auth.auth().currentUser?.delete()
            
            // Clear local data and unified cache
            clearLocalProfile()
            unifiedProvider.invalidateProfileCache()
            
        } catch {
            print("Error deleting account: \(error)")
        }
    }
    
    /// Export user profile data
    func exportProfileData() -> [String: Any] {
        return [
            "displayName": displayName,
            "email": email,
            "university": university ?? "",
            "studyProgram": studyProgram ?? "",
            "academicYear": academicYear ?? "",
            "memberSince": memberSince,
            "exportDate": ISO8601DateFormatter().string(from: Date())
        ]
    }
    
    // MARK: - Private Methods
    
    private func loadBasicUserInfo() {
        if let user = Auth.auth().currentUser {
            self.email = user.email ?? ""
            self.displayName = user.displayName ?? extractNameFromEmail(user.email ?? "")
            self.profileImageURL = user.photoURL
            
            if let creationDate = user.metadata.creationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                self.memberSince = formatter.string(from: creationDate)
            }
        }
    }
    
    private func updateLocalProfile(from data: [String: Any]) async {
        if let displayName = data["displayName"] as? String {
            self.displayName = displayName
        }
        
        if let university = data["university"] as? String {
            self.university = university
        }
        
        if let studyProgram = data["studyProgram"] as? String {
            self.studyProgram = studyProgram
        }
        
        if let academicYear = data["academicYear"] as? String {
            self.academicYear = academicYear
        }
        
        // Handle profile image
        if let profileImageData = data["profileImageData"] as? String {
            self.profileImageURL = URL(string: "data:image/jpeg;base64,\(profileImageData)")
        } else if let profileImageURLString = data["profileImageURL"] as? String,
                  let url = URL(string: profileImageURLString) {
            self.profileImageURL = url
        }
        
        // Update member since date
        if let createdAt = data["createdAt"] as? Timestamp {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            self.memberSince = formatter.string(from: createdAt.dateValue())
        }
    }
    
    private func updateLocalProfile(from profile: UserProfileData) async {
        self.displayName = profile.displayName
        self.email = profile.email
        self.university = profile.university
        self.studyProgram = profile.studyProgram
        self.academicYear = profile.academicYear
        
        if let imageData = profile.profileImageData {
            self.profileImageURL = URL(string: "data:image/jpeg;base64,\(imageData)")
        }
    }
    
    private func clearLocalProfile() {
        displayName = ""
        email = ""
        university = nil
        studyProgram = nil
        academicYear = nil
        profileImageURL = nil
        memberSince = ""
    }
    
    private func extractNameFromEmail(_ email: String) -> String {
        let components = email.components(separatedBy: "@")
        return components.first?.capitalized ?? "User"
    }
}