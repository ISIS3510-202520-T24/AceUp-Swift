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
    // UI Fields
    @Published var email = ""
    @Published var password = ""

    // UI State
    @Published var isLoading = false
    @Published var isBioLoading = false
    @Published var errorMessage: String?
    @Published var alertMessage: String?
    @Published var didLogin = false

    private let auth = AuthService()
    private let keychain = BiometricKeychain()

    // MARK: - Normal login
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

            do {
                try keychain.saveCredentials(.init(email: email, password: password))
                keychain.debugCountItems()
                if let probe = try? keychain.loadCredentials(context: nil) {
                    print("KC probe after save:", probe.email)
                } else {
                    print("KC probe after save: nil")
                }
            } catch {
                print("Keychain save error:", error)
            }

            didLogin = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Biometric login
    func biometricLogin() async {
        errorMessage = nil
        isBioLoading = true
        defer { isBioLoading = false }

        keychain.debugCountItems()

        let ctx = LAContext()
        var evalError: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &evalError) else {
            errorMessage = evalError?.localizedDescription ?? "Biometrics not available on this device."
            return
        }

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                   localizedReason: "Authenticate to login") { ok, err in
                    ok ? cont.resume() : cont.resume(throwing: err ?? NSError(domain: "bio", code: -1))
                }
            }

            // 1) Intento seguro
            if let creds = try keychain.loadCredentials(context: ctx) {
                _ = try await auth.SignIn(email: creds.email, password: creds.password)
                didLogin = true
                return
            }

            // 2) Intento plain
            if let fallback = try keychain.loadCredentials(context: nil) {
                print("KC alt read (plain or secure without ctx):", fallback.email)
                _ = try await auth.SignIn(email: fallback.email, password: fallback.password)
                didLogin = true
                return
            }

            // 3) Seed automático si hay email/contraseña en pantalla
            guard !email.isEmpty, !password.isEmpty else {
                errorMessage = "No hay credenciales guardadas. Inicia una vez con email y contraseña para habilitar Face ID."
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

    // MARK: - (Optional) Resend verification
    func resendVerification() async {
        do {
            try await auth.resendVerificationEmail()
            alertMessage = "Verification email re-sent."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
