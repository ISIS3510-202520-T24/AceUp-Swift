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
    
    init (AuthService: AuthService = AuthService(),
          biometricService: BiometricService = BiometricService()){
        self.authService = AuthService
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
        
        // Check if there's already a logged-in user
        if authService.isLoggedIn {
            print("🔥 SignUpViewModel: User already logged in, signing out first")
            do {
                try authService.signOut()
            } catch {
                print("🔥 SignUpViewModel: Failed to sign out existing user: \(error)")
            }
        }
        
        // Valdiación previa
        if let vErr = firstValidationError {
            print("🔥 SignUpViewModel: Validation error - \(vErr)")
            errorMessage = vErr
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            //primero se crea el usuario en firebase
            print("🔥 SignUpViewModel: Creating user with email: \(email)")
            _ = try await authService.signUp(email: email, password: password, nick: nick)
            
            //mostar si se pudo guardar e identificar
            print("🔥 SignUpViewModel: Signup completed successfully")
            didComplete = true
            
        } catch let error as NSError {
            print("🔥 SignUpViewModel: Signup failed with NSError - \(error.localizedDescription)")
            print("🔥 SignUpViewModel: Error domain: \(error.domain), code: \(error.code)")
            
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
        } catch {
            print("🔥 SignUpViewModel: Signup failed with error - \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
