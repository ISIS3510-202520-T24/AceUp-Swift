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
    
    // Form fields
    @Published var nick = ""
    @Published var email = ""
    @Published var emailConfirm = ""
    @Published var password = ""
    @Published var passwordConfirm = ""
    @Published var agree = false
    
    // Alert / UI feedback
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    // UI states
    @Published var isLoading = false
    @Published var errorMessage: String?   // ya no se muestra en la vista
    @Published var didComplete = false
    
    private let authService: AuthService
    private let biometricService: BiometricService
    
    init(authService: AuthService = AuthService(),
         biometricService: BiometricService = BiometricService()) {
        self.authService = authService
        self.biometricService = biometricService
    }
    
    // MARK: - Helpers (popup centralizado)
    private func showError(title: String = "Error",
                           message: String = "An unexpected error occurred") {
        alertTitle = title
        alertMessage = message
        showAlert = true
        errorMessage = message
    }
    
    private func showSuccess(_ message: String = "User created successfully") {
        alertTitle = "Success"
        alertMessage = message
        showAlert = true
    }
    
    // MARK: - Validations
    
    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    private func validatePassword(_ pwd: String) -> [String] {
        var errs: [String] = []
        if pwd.count < 8 { errs.append("Must have at least 8 characters.") }
        if pwd.range(of: "[A-Z]", options: .regularExpression) == nil { errs.append("Must include at least one uppercase letter (A-Z).") }
        if pwd.range(of: "[a-z]", options: .regularExpression) == nil { errs.append("Must include at least one lowercase letter (a-z).") }
        if pwd.range(of: "\\d", options: .regularExpression) == nil { errs.append("Must include at least one number (0-9).") }
        if pwd.range(of: "[^A-Za-z\\d]", options: .regularExpression) == nil { errs.append("Must include at least one symbol (e.g. !@#$%).") }
        return errs
    }
    
    private func validateForm() -> [String] {
        var errs: [String] = []
        if nick.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errs.append("Nickname is required.") }
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errs.append("Email is required.") }
        if emailConfirm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errs.append("Email confirmation is required.") }
        if password.isEmpty { errs.append("Password is required.") }
        if passwordConfirm.isEmpty { errs.append("Password confirmation is required.") }
        if !agree { errs.append("You must accept the privacy policy.") }
        
        if !isValidEmail(email) { errs.append("Email format is invalid.") }
        if email != emailConfirm { errs.append("Emails do not match.") }
        if password != passwordConfirm { errs.append("Passwords do not match.") }
        
        errs.append(contentsOf: validatePassword(password))
        return errs
    }
    
    // Habilitar/deshabilitar botón (solo guía visual)
    var formIsValid: Bool {
        return agree
        && !nick.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !email.isEmpty && !emailConfirm.isEmpty
        && !password.isEmpty && !passwordConfirm.isEmpty
        && isValidEmail(email)
        && email == emailConfirm
        && password == passwordConfirm
        && password.count >= 8
    }
    
    // MARK: - Main action
    
    func signUp() async {
        errorMessage = nil
        didComplete = false
        
        // 1) Validación local
        let errors = validateForm()
        if !errors.isEmpty {
            let msg = "Please fix:\n• " + errors.joined(separator: "\n• ")
            showError(title: "Error", message: msg)
            return
        }
        
        // 2) Loading
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 3) Limpiar sesión previa si aplica
            if authService.isLoggedIn {
                try authService.signOut()
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            }
            
            // 4) Signup con timeout
            let signupTask = Task {
                try await authService.signUp(email: email, password: password, nick: nick)
            }
            _ = try await withTimeout(seconds: 30) {
                try await signupTask.value
            }
            
            // 5) Éxito → popup verde
            didComplete = true
            errorMessage = nil
            showSuccess("User created successfully")
            
        } catch let error as NSError {
            // 6) Errores Firebase
            let code = error.code
            switch code {
            case AuthErrorCode.emailAlreadyInUse.rawValue:
                showError(message: "This email is already in use. Try signing in or use another email.")
            case AuthErrorCode.weakPassword.rawValue:
                showError(message: "Weak password. Use at least 8 characters with uppercase, lowercase, numbers, and a symbol.")
            case AuthErrorCode.invalidEmail.rawValue:
                showError(message: "Invalid email format. Example: name@domain.com")
            case AuthErrorCode.networkError.rawValue:
                showError(message: "Network error. Check your connection and try again.")
            default:
                showError(title: "Sign up error", message: error.localizedDescription)
            }
            
        } catch {
            // 7) Otros errores
            if error is TimeoutError {
                showError(message: "The sign up process is taking too long. Check your connection and try again.")
            } else {
                showError(message: error.localizedDescription)
            }
        }
    }
    
    // Timeout helper
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            guard let result = try await group.next() else { throw TimeoutError() }
            group.cancelAll()
            return result
        }
    }
}
