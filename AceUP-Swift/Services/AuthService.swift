//
//  AuthService.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 2/10/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

struct AppUser {
    let uid: String
    let email: String
    let nick: String
}

final class AuthService {
    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    // SIGNUP + send email verification
    @discardableResult
    func signUp(email: String, password: String, nick: String) async throws -> AppUser {
        let authResult = try await createUser(email: email, password: password)

        // Update displayName
        let changeReq = authResult.user.createProfileChangeRequest()
        changeReq.displayName = nick
        try await changeReq.commitChanges()

        // Send verification email (log result)
        do {
            try await authResult.user.sendEmailVerification()
            print("Verification email dispatched to \(email)")
        } catch {
            print("SendEmailVerification failed: \(error)")
            throw error
        }

        // Save profile to Firestore
        let user = AppUser(uid: authResult.user.uid, email: email, nick: nick)
        try await saveUserProfile(user)
        return user
    }

    // LOGIN
    @discardableResult
    func SignIn(email: String, password: String) async throws -> AppUser {
        try await withCheckedThrowingContinuation { continuation in
            auth.signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let user = result?.user else {
                    continuation.resume(throwing: NSError(
                        domain: "Auth",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "User not found"]
                    ))
                    return
                }

                // Block if email not verified:
                // if !user.isEmailVerified {
                //     try? self.auth.signOut()
                //     continuation.resume(throwing: NSError(
                //         domain: "Auth",
                //         code: 401,
                //         userInfo: [NSLocalizedDescriptionKey: "Please verify your email to continue."]
                //     ))
                //     return
                // }

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

    // Resend verification (useful from a notice screen)
    func resendVerificationEmail() async throws {
        guard let user = auth.currentUser else {
            throw NSError(domain: "Auth", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "No active session"])
        }
        try await user.sendEmailVerification()
    }

    private func createUser(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
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
        let data: [String: Any] = [
            "uid": user.uid,
            "email": user.email,
            "nick": user.nick,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await db.collection("users").document(user.uid).setData(data, merge: true)
    }
}
