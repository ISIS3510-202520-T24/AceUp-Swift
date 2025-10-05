//
//  LoginViewModel.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 2/10/25.
//

import Foundation
import LocalAuthentication
import Security

@MainActor
final class LoginViewModel: ObservableObject {
    // Campos de la UI
    @Published var email = ""
    @Published var password = ""
    @Published var rememberWithBiometric = false

    // Estado de la UI
    @Published var isLoading = false           // login normal
    @Published var isBioLoading = false        // login biométrico
    @Published var errorMessage: String?
    @Published var alertMessage: String?       // para forgot password / info
    @Published var didLogin = false            // trigger para navegar desde la View

    private let auth = AuthService()
    private let keychain = BiometricKeychain()

    //Login normal
    func login() async {
        errorMessage = nil
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await auth.SignIn(email: email, password: password)

            if rememberWithBiometric {
                do { try keychain.saveCredentials(.init(email: email, password: password)) }
                catch { print("Keychain save error: \(error)") }
            }

            didLogin = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Login con biometría
    func biometricLogin() async {
        errorMessage = nil
        isBioLoading = true
        defer { isBioLoading = false }

        let ctx = LAContext()
        var evalError: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &evalError) else {
            errorMessage = evalError?.localizedDescription ?? "Biometrics not available on this device."
            return
        }

        do {
            // Autenticar con Face ID / Touch ID
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                   localizedReason: "Authenticate to login") { ok, err in
                    ok ? cont.resume() : cont.resume(throwing: err ?? NSError(domain: "bio", code: -1))
                }
            }

            // 1) Intentar leer credenciales guardadas
            do {
                if let creds = try keychain.loadCredentials(context: ctx) {
                    _ = try await auth.SignIn(email: creds.email, password: creds.password)
                    didLogin = true
                    return
                }
            } catch let nsErr as NSError
                where nsErr.domain == NSOSStatusErrorDomain && nsErr.code == Int(errSecItemNotFound) {
                // No había credenciales guardadas -> caer a 2)
            }

            // 2) Si no hay guardadas pero hay email/clave digitados: guardarlas y loguear
            guard !email.isEmpty, !password.isEmpty else {
                errorMessage = "No stored credentials. Type email & password once, then try again."
                return
            }
            try keychain.saveCredentials(.init(email: email, password: password))
            _ = try await auth.SignIn(email: email, password: password)
            didLogin = true

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func canUseBiometrics() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    // MARK: - Forgot Password
    func forgotPassword() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            alertMessage = "Please type your email above, then try again."
            return
        }
        do {
            try await auth.sendPasswordReset(to: trimmed)
            alertMessage = "We sent a password reset email to \(trimmed)."
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    // (Opcional) Reenviar verificación
    func resendVerification() async {
        do {
            try await auth.resendVerificationEmail()
            alertMessage = "Verification email re-sent."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
