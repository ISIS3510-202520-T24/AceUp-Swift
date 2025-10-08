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
    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    // SIGNUP + send email verification
    @discardableResult
    func signUp(email: String, password: String, nick: String) async throws -> AppUser {
        print("🔥 Starting signup process for email: \(email)")
        
        // Sign out any existing user first to ensure clean registration
        if auth.currentUser != nil {
            try signOut()
            print("🔥 Signed out existing user before registration")
        }
        
        do {
            let authResult = try await createUser(email: email, password: password)
            print("🔥 User created successfully with UID: \(authResult.user.uid)")

            // Update displayName
            let changeReq = authResult.user.createProfileChangeRequest()
            changeReq.displayName = nick
            try await changeReq.commitChanges()
            print("🔥 Display name updated to: \(nick)")

            // Send verification email (log result)
            do {
                try await authResult.user.sendEmailVerification()
                print("🔥 Verification email dispatched to \(email)")
            } catch {
                print("🔥 SendEmailVerification failed: \(error)")
                // Don't throw here - verification email failure shouldn't crash signup
            }

            // Save profile to Firestore
            let user = AppUser(uid: authResult.user.uid, email: email, nick: nick)
            try await saveUserProfile(user)
            print("🔥 User profile saved to Firestore")
            
            return user
        } catch {
            print("🔥 Signup failed with error: \(error)")
            throw error
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
