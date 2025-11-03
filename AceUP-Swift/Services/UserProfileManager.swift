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
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load initial user data if available
        loadBasicUserInfo()
    }
    
    // MARK: - Public Methods
    
    /// Load user profile from Firestore
    func loadUserProfile() async {
        guard let userId = currentUserId else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists, let data = document.data() {
                await updateLocalProfile(from: data)
            }
        } catch {
            print("Error loading user profile: \(error)")
        }
    }
    
    /// Update user profile information
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
            } catch {
                print("Error updating profile: \(error)")
            }
        }
    }
    
    /// Upload and update profile image
    func updateProfileImage(_ image: UIImage) async {
        guard let userId = currentUserId,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // For now, we'll save the image data as base64 string in Firestore
            // In a production app, you'd want to use Firebase Storage or another image hosting service
            let base64String = imageData.base64EncodedString()
            
            // Update Firestore with image data
            try await db.collection("users").document(userId).updateData([
                "profileImageData": base64String,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // Update Firebase Auth profile with a placeholder URL
            // In production, this would be the actual storage URL
            let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
            changeRequest?.photoURL = URL(string: "data:image/jpeg;base64,\(base64String)")
            try? await changeRequest?.commitChanges()
            
            // Update local state - create a data URL for display
            self.profileImageURL = URL(string: "data:image/jpeg;base64,\(base64String)")
            
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
            
            // Note: Profile image data is stored in Firestore, so it's deleted with the document
            // If using Firebase Storage in the future, you would delete the image here
            
            // Delete Firebase Auth account
            try await Auth.auth().currentUser?.delete()
            
            // Clear local data
            clearLocalProfile()
            
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
        
        // Handle profile image - check for both base64 data and URL
        if let profileImageData = data["profileImageData"] as? String {
            // Convert base64 string to data URL
            self.profileImageURL = URL(string: "data:image/jpeg;base64,\(profileImageData)")
        } else if let profileImageURLString = data["profileImageURL"] as? String,
                  let url = URL(string: profileImageURLString) {
            self.profileImageURL = url
        }
        
        // Update member since date from Firestore creation timestamp
        if let createdAt = data["createdAt"] as? Timestamp {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            self.memberSince = formatter.string(from: createdAt.dateValue())
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