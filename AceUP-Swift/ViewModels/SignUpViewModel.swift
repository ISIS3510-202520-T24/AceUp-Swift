//
//  SignUpViewModel.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 2/10/25.
//

import Foundation
import Firebase
import FirebaseAuth

@MainActor
final class SignUpViewModel: ObservableObject {
    
    // Campos necesarios para el formulario
    @Published var nick = ""
    @Published var email = ""
    @Published var emailConfirm = ""
    @Published var password = ""
    @Published var passwordConfirm = ""
    @Published var agree = false
    
    
    // UI states
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var didComplete = false
    
    private let authService: AuthService
    private let biometricService: BiometricService
    
    init(authService: AuthService = AuthService(),
         biometricService: BiometricService = BiometricService()) {
        self.authService = authService
        self.biometricService = biometricService
    }
    
    //validaciones para MVVM
     var emailIsValid: Bool {
         email.contains("@") && email.contains(".")
    }
    //AQUI ME FALTA PONER QUE NO SE PUEDA CREAR VACIOS
    var passwordsmatch: Bool { password == passwordConfirm}
    var emailsmatch: Bool {email == emailConfirm }
    var passwordStong: Bool { password.count >= 6 }
    var formIsValid: Bool {
        agree && !nick.isEmpty && emailIsValid && passwordsmatch && emailsmatch && passwordStong
    }
    
    var firstValidationError: String? {
        if !agree { return "you have to accept privacity policy" }
        if nick.isEmpty { return "nickname is required" }
        if !emailIsValid { return "email is invalid" }
        if !passwordsmatch { return "passwords do not match" }
        if !emailsmatch { return "emails do not match" }
        if !passwordStong { return "password must be at least 6 characters long" }
        return nil
    }
    
    //Accion principal
    
    func signUp() async {
        print("🔥 SignUpViewModel: Starting signup process")
        errorMessage = nil
        didComplete = false
        
        // Validation check first
        if let vErr = firstValidationError {
            print("🔥 SignUpViewModel: Validation error - \(vErr)")
            await MainActor.run {
                errorMessage = vErr
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            // Check if there's already a logged-in user and sign out
            if authService.isLoggedIn {
                print("🔥 SignUpViewModel: User already logged in, signing out first")
                try authService.signOut()
                // Add small delay to ensure clean state
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            print("🔥 SignUpViewModel: Creating user with email: \(email)")
            
            // Add timeout to prevent indefinite hanging
            let signupTask = Task {
                try await authService.signUp(email: email, password: password, nick: nick)
            }
            
            // Wait for signup with timeout
            let result = try await withTimeout(seconds: 30) {
                try await signupTask.value
            }
            
            print("🔥 SignUpViewModel: Signup completed successfully")
            await MainActor.run {
                didComplete = true
                errorMessage = nil
            }
            
        } catch let error as NSError {
            print("🔥 SignUpViewModel: Signup failed with NSError - \(error.localizedDescription)")
            print("🔥 SignUpViewModel: Error domain: \(error.domain), code: \(error.code)")
            
            await MainActor.run {
                // Handle specific Firebase auth errors
                switch error.code {
                case 17007: // FIRAuthErrorCodeEmailAlreadyInUse
                    errorMessage = "This email is already registered. Try signing in instead."
                case 17026: // FIRAuthErrorCodeWeakPassword
                    errorMessage = "Password is too weak. Please choose a stronger password."
                case 17008: // FIRAuthErrorCodeInvalidEmail
                    errorMessage = "Invalid email address format."
                case 17020: // FIRAuthErrorCodeNetworkError
                    errorMessage = "Network error. Please check your internet connection."
                case 17999: // FIRAuthErrorCodeInternalError
                    errorMessage = "Internal error occurred. Please try again."
                default:
                    errorMessage = error.localizedDescription
                }
            }
        } catch {
            print("🔥 SignUpViewModel: Signup failed with error - \(error.localizedDescription)")
            await MainActor.run {
                if error is TimeoutError {
                    errorMessage = "Registration is taking too long. Please check your internet connection and try again."
                } else {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // Timeout helper
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
        }
    }
}
