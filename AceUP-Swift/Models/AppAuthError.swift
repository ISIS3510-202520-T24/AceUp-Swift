//
//  AppAuthError.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 22/10/25.
//

import Foundation

enum AppAuthError: LocalizedError {
    case emailAlreadyInUse
    case weakPassword
    case invalidEmail
    case network
    case userNotFound
    case wrongPassword
    case requiresRecentLogin
    case tooManyRequests
    case userDisabled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .emailAlreadyInUse:
            return "This email is already in use. Try signing in or use another email."
        case .weakPassword:
            // Este texto genérico se usa solo como fallback.
            return "Weak password. Use at least 8 characters with uppercase, lowercase, numbers, and a symbol."
        case .invalidEmail:
            return "Invalid email format. Example: name@domain.com"
        case .network:
            return "Network error. Check your connection and try again."
        case .userNotFound:
            return "User not found."
        case .wrongPassword:
            return "Incorrect password."
        case .requiresRecentLogin:
            return "Please re-authenticate to continue."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        case .userDisabled:
            return "This account has been disabled."
        case .unknown(let msg):
            return msg
        }
    }
}
