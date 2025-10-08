//
//  AuthService.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 2/10/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

// Estructura de usuario en tu app
struct AppUser {
    let uid: String
    let email: String
    let nick: String
}

final class AuthService: ObservableObject {
    @Published var user: FirebaseAuth.User?
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    init() {
        // Initialize with current user if already logged in
        self.user = auth.currentUser
    }

    // SIGNUP + send email verification
    @discardableResult
    func signUp(email: String, password: String, nick: String) async throws -> (FirebaseAuth.User, DocumentReference) {
        print("🔥 AuthService: Starting signUp for email: \(email)")
        
        // Ensure we're in a clean state
        guard !email.isEmpty, !password.isEmpty, !nick.isEmpty else {
            throw NSError(domain: "AuthServiceError", code: -1, userInfo: [NSLocalizedDescriptionKey: "All fields are required"])
        }
        
        // Check network connectivity first (basic check)
        guard await isNetworkAvailable() else {
            throw NSError(domain: "AuthServiceError", code: -2, userInfo: [NSLocalizedDescriptionKey: "No internet connection available"])
        }
        
        do {
            print("🔥 AuthService: Creating Firebase user...")
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            print("🔥 AuthService: Firebase user created successfully with UID: \(result.user.uid)")
            
            // Verify the user was actually created
            guard let currentUser = Auth.auth().currentUser else {
                throw NSError(domain: "AuthServiceError", code: -3, userInfo: [NSLocalizedDescriptionKey: "User creation succeeded but current user is nil"])
            }
            
            print("🔥 AuthService: Creating user document in Firestore...")
            
            // Create user document in Firestore with retry mechanism
            let userData: [String: Any] = [
                "email": email,
                "nick": nick,
                "createdAt": FieldValue.serverTimestamp(),
                "lastLogin": FieldValue.serverTimestamp()
            ]
            
            let userRef = Firestore.firestore().collection("users").document(result.user.uid)
            
            // Retry mechanism for Firestore operation
            var attempts = 0
            let maxAttempts = 3
            
            while attempts < maxAttempts {
                do {
                    try await userRef.setData(userData)
                    print("🔥 AuthService: User document created in Firestore successfully")
                    break
                } catch {
                    attempts += 1
                    print("🔥 AuthService: Firestore write attempt \(attempts) failed: \(error)")
                    
                    if attempts >= maxAttempts {
                        // If Firestore fails, we should clean up the Firebase Auth user
                        print("🔥 AuthService: Firestore failed after \(maxAttempts) attempts, deleting Firebase user")
                        try? await currentUser.delete()
                        throw NSError(domain: "AuthServiceError", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to create user profile after multiple attempts"])
                    }
                    
                    // Wait before retry
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            }
            
            // Update current user state on main thread
            await MainActor.run {
                self.user = result.user
            }
            
            print("🔥 AuthService: SignUp completed successfully")
            return (result.user, userRef)
            
        } catch let error as NSError {
            print("🔥 AuthService: SignUp failed with NSError: \(error.localizedDescription)")
            print("🔥 AuthService: Error domain: \(error.domain), code: \(error.code)")
            
            // Ensure we're in a clean state after failure
            await MainActor.run {
                self.user = nil
            }
            
            throw error
        } catch {
            print("🔥 AuthService: SignUp failed with error: \(error.localizedDescription)")
            
            // Ensure we're in a clean state after failure
            await MainActor.run {
                self.user = nil
            }
            
            throw error
        }
    }
    
    // Simple network availability check
    private func isNetworkAvailable() async -> Bool {
        do {
            let url = URL(string: "https://www.google.com")!
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("🔥 AuthService: Network check failed: \(error)")
            return false
        }
    }

    // LOGIN
    @discardableResult
    func SignIn(email: String, password: String) async throws -> AppUser {
        print("🔥 Starting sign-in process for email: \(email)")
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
            auth.signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    print("🔥 Sign-in failed with error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                guard let user = result?.user else {
                    print("🔥 Sign-in failed: User not found")
                    continuation.resume(throwing: NSError(
                        domain: "Auth",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "User not found"]
                    ))
                    return
                }

                print("🔥 User signed in successfully with UID: \(user.uid)")
                
                // Update the user property on main thread
                Task { @MainActor in
                    self.user = user
                }

                let appUser = AppUser(
                    uid: user.uid,
                    email: user.email ?? email,
                    nick: user.displayName ?? ""
                )
                continuation.resume(returning: appUser)
            }
        }
    }

    // FORGOT PASSWORD
    func sendPasswordReset(to email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    // SIGN OUT
    func signOut() throws {
        try auth.signOut()
        // Clear the user property on main thread
        Task { @MainActor in
            self.user = nil
        }
        print("🔥 User signed out successfully")
    }
    
    // GET CURRENT USER
    var currentUser: AppUser? {
        guard let firebaseUser = auth.currentUser else { return nil }
        return AppUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            nick: firebaseUser.displayName ?? ""
        )
    }
    
    // CHECK IF USER IS LOGGED IN
    var isLoggedIn: Bool {
        return auth.currentUser != nil
    }

    // Resend verification (useful from a notice screen)
    func resendVerificationEmail() async throws {
        guard let user = auth.currentUser else {
            throw NSError(domain: "Auth", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "No active session"])
        }
        try await user.sendEmailVerification()
    }

    private func createUser(email: String, password: String) async throws -> AuthDataResult {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            auth.createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result = result else {
                    continuation.resume(throwing: NSError(
                        domain: "Auth",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Create user failed"]
                    ))
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func saveUserProfile(_ user: AppUser) async throws {
        print("🔥 Saving user profile to Firestore for UID: \(user.uid)")
        let data: [String: Any] = [
            "uid": user.uid,
            "email": user.email,
            "nick": user.nick,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("users").document(user.uid).setData(data, merge: true)
            print("🔥 User profile saved successfully")
        } catch {
            print("🔥 Failed to save user profile: \(error)")
            throw error
        }
    }
}
