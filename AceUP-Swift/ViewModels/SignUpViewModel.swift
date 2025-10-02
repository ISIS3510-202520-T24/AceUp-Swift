//
//  SignUpViewModel.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 2/10/25.
//

import Foundation
//Aqui no es necesario pero solo se hace para mapear errores comodamente
import Firebase

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
        if !agree { return "you ahve to accept privacity policy" }
        if nick.isEmpty { return "nickname is required" }
        if !emailIsValid { return "email is invalid" }
        if !passwordsmatch { return "passwords do not match" }
        if !emailsmatch { return "emails do not match" }
        if !passwordStong { return "password must be at least 6 characters long" }
        return nil
    }
    
    //Accion principal
    
    func signUp() async {
        errorMessage = nil
        didComplete = false
        
        // Valdiación previa
        if let vErr = firstValidationError {
            errorMessage = vErr
            return
        }
        
        isLoading = true
        defer {isLoading  = false}
        do {
            //primero se crea el usuario en firebase
            _ = try await authService.signUp(email: email, password: password, nick: nick)
            
            // solicitar el Face ID inmediatamente
            guard biometricService.canEvaluateBiometrics() else {
                errorMessage = "Face ID is not available on this device"
                return
            }
            try await biometricService.authenticateUser(reason: "Confirm your identity")
            
            //mostar si se pudo guardar e identificar
            
            didComplete = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
