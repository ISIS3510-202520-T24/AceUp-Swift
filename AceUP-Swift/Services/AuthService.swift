//
//  AuthService.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 2/10/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// Estructura de como se va a guardar en firebase
struct AppUser {
    let uid: String
    let email: String
    let nick: String
}

final class AuthService {
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    // Aqui se crea el usuario en Auth y guarda el perfil básico en firestore
    func signUp(email: String, password: String, nick: String) async throws -> AppUser {
        let authResult = try await createUser(email: email, password: password)
        let uid = authResult.user.uid
        
        let changeReq = authResult.user.createProfileChangeRequest()
        changeReq.displayName = nick
        try await changeReq.commitChanges()
        
        let user = AppUser(uid: uid, email: email, nick: nick)
        try await saveUserProfile(user)
        return user
    }
    
    private func createUser(email: String, password:String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            auth.createUser(withEmail: email,password: password){ result, error in
                if let error = error { continuation.resume(throwing: error); return}
                continuation.resume(returning: result!)
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
        try await db.collection("users").document(user.uid).setData(data,merge: true)
    }
}


