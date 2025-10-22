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

final class AuthService: ObservableObject {
    @Published var user: FirebaseAuth.User?
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    init() {
        // Initialize with current user if already logged in
        self.user = auth.currentUser
    }

    // MARK: - SIGNUP + send email verification
    @discardableResult
    func signUp(email: String, password: String, nick: String) async throws -> (FirebaseAuth.User, DocumentReference) {
        // Ensure we're in a clean state
        guard !email.isEmpty, !password.isEmpty, !nick.isEmpty else {
            throw AppAuthError.unknown("All fields are required")
        }
        
        // Check network connectivity first (basic check)
        guard await isNetworkAvailable() else {
            throw AppAuthError.network
        }
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Verify the user was actually created
            guard let currentUser = Auth.auth().currentUser else {
                throw AppAuthError.unknown("User creation succeeded but current user is nil")
            }
            
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
                    break
                } catch {
                    attempts += 1
                    
                    if attempts >= maxAttempts {
                        // If Firestore fails, we should clean up the Firebase Auth user
                        try? await currentUser.delete()
                        throw AppAuthError.unknown("Failed to create user profile after multiple attempts")
                    }
                    
                    // Wait before retry
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            }
            
            // Update current user state on main thread
            await MainActor.run {
                self.user = result.user
            }

            // Genera userkey para analytics BQ2.4
            AppAnalytics.shared.identify(userId: result.user.uid)

            return (result.user, userRef)
            
        } catch {
            // Ensure we're in a clean state after failure
            await MainActor.run {
                self.user = nil
            }
            throw mapFirebaseAuthError(error)
        }
    }
    
    // MARK: - Simple network availability check
    private func isNetworkAvailable() async -> Bool {
        do {
            let url = URL(string: "https://www.google.com")!
            let (_, response) = try await URLSession.shared.data(from: url)
            let isAvailable = (response as? HTTPURLResponse)?.statusCode == 200
            return isAvailable
        } catch {
            // Return true to allow signup attempt even if network check fails
            return true
        }
    }

    // MARK: - LOGIN
    @discardableResult
    func SignIn(email: String, password: String) async throws -> AppUser {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
            auth.signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    continuation.resume(throwing: self.mapFirebaseAuthError(error))
                    return
                }
                guard let user = result?.user else {
                    continuation.resume(throwing: AppAuthError.userNotFound)
                    return
                }

                // Update the user property on main thread
                Task { @MainActor in
                    self.user = user
                }

                // asegurar que el collector tenga un userkey estable
                AppAnalytics.shared.identify(userId: user.uid)

                let appUser = AppUser(
                    uid: user.uid,
                    email: user.email ?? email,
                    nick: user.displayName ?? ""
                )
                continuation.resume(returning: appUser)
            }
        }
    }

    // MARK: - FORGOT PASSWORD
    func sendPasswordReset(to email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch {
            throw mapFirebaseAuthError(error)
        }
    }
    
    // MARK: - SIGN OUT
    func signOut() throws {
        try auth.signOut()
        // Clear the user property on main thread
        Task { @MainActor in
            self.user = nil
        }
    }
    
    // MARK: - GET CURRENT USER
    var currentUser: AppUser? {
        guard let firebaseUser = auth.currentUser else { return nil }
        return AppUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            nick: firebaseUser.displayName ?? ""
        )
    }
    
    // MARK: - CHECK IF USER IS LOGGED IN
    var isLoggedIn: Bool {
        return auth.currentUser != nil
    }

    // MARK: - Resend verification (useful from a notice screen)
    func resendVerificationEmail() async throws {
        guard let user = auth.currentUser else {
            throw AppAuthError.userNotFound
        }
        do {
            try await user.sendEmailVerification()
        } catch {
            throw mapFirebaseAuthError(error)
        }
    }

    // MARK: - Legacy helpers (si decides usarlos internamente)
    private func createUser(email: String, password: String) async throws -> AuthDataResult {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            auth.createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    continuation.resume(throwing: self.mapFirebaseAuthError(error))
                    return
                }
                guard let result = result else {
                    continuation.resume(throwing: AppAuthError.unknown("Create user failed"))
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func saveUserProfile(_ user: AppUser) async throws {
        print("Saving user profile to Firestore for UID: \(user.uid)")
        let data: [String: Any] = [
            "uid": user.uid,
            "email": user.email,
            "nick": user.nick,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("users").document(user.uid).setData(data, merge: true)
            print("User profile saved successfully")
        } catch {
            print("Failed to save user profile: \(error)")
            throw mapFirebaseAuthError(error)
        }
    }
}

// MARK: - Firebase → AppAuthError mapper
private extension AuthService {
    func mapFirebaseAuthError(_ error: Error) -> AppAuthError {
        let ns = error as NSError

        // En tu SDK, AuthErrorCode ES el enum (no hay AuthErrorCode.Code)
        if ns.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: ns.code) {
            switch code {
            case .emailAlreadyInUse:     return .emailAlreadyInUse
            case .weakPassword:          return .weakPassword
            case .invalidEmail:          return .invalidEmail
            case .networkError:          return .network
            case .userNotFound:          return .userNotFound
            case .wrongPassword:         return .wrongPassword
            case .requiresRecentLogin:   return .requiresRecentLogin
            case .tooManyRequests:       return .tooManyRequests
            case .userDisabled:          return .userDisabled
            default:                     return .unknown(ns.localizedDescription)
            }
        }

        // Fallback si no coincide el dominio o no se pudo parsear
        return .unknown(error.localizedDescription)
    }
}
