//
//  LoginViewModel.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 2/10/25.
//

import Foundation
import LocalAuthentication
import Security

// --- Detecta errores típicos de conectividad para hacer fallback offline ---
private extension Error {
    var isConnectivityError: Bool {
        let ns = self as NSError
        if ns.domain == NSURLErrorDomain {
            return [
                NSURLErrorNotConnectedToInternet,
                NSURLErrorTimedOut,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorCannotFindHost
            ].contains(ns.code)
        }
        let msg = ns.localizedDescription.lowercased()
        return msg.contains("network error") || msg.contains("timeout") || msg.contains("unreachable")
    }
}

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

    // Offline / flags
    private var autoTriedOfflineUnlock = false                  // evita pedir biometría múltiples veces
    private var loginStore = LoginLocalStore.shared             // var para poder escribir flags

    // MARK: - Cache-then-Network al abrir login
    /// Lee hints locales y, si hay internet, valida sesión para entrar sin fricción.
    func loadHintsAndValidateIfPossible() {
        // 1) Pintar inmediatamente el hint local
        email = loginStore.lastEmail

        // 2) Si hay red, validar token en background (sin timeout)
        Task { [weak self] in
            guard let self = self else { return }
            if OfflineManager.shared.isOnline {
                do {
                    _ = try await auth.validateSession()
                    // 3) Warm-up de datos para que todo cargue rápido
                    Task { await DataSynchronizationManager.shared.performIncrementalSync() }
                    self.didLogin = true
                } catch {
                    // Silencioso: el usuario puede iniciar sesión manualmente
                    print("validateSession skipped:", error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Auto-unlock offline (sin botón)
    func autoOfflineUnlockIfPossible() {
        // Evita repetir en el mismo ciclo de vida de la vista
        guard !autoTriedOfflineUnlock else { return }
        autoTriedOfflineUnlock = true

        // Si el monitor cree que hay red pero está rota, igual permitimos el intento
        // Requiere que el usuario haya permitido biometría (guardado tras un login exitoso)
        guard loginStore.enableBiometric else { return }

        // NO exigimos hasOfflineData: si hay credenciales + biometría, se entra a sesión limitada
        Task { [weak self] in
            await self?.performBiometricOfflineUnlock()
        }
    }

    // MARK: - Biometría sin internet (NO hace SignIn de red)
    private func performBiometricOfflineUnlock() async {
        do {
            let ctx = LAContext()
            var authError: NSError?
            guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
                self.errorMessage = "Biometría no disponible en este dispositivo."
                return
            }

            // Dispara FaceID/TouchID y verifica que existan credenciales guardadas
            _ = try keychain.loadCredentials(context: ctx)

            // Entramos a la app en modo limitado (read-only + banner offline)
            self.didLogin = true
        } catch {
            self.errorMessage = "No se pudo desbloquear con biometría."
        }
    }

    // MARK: - Login normal (con red)
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

            // Guardar credenciales seguras (Keychain)
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

            // Habilita biometría para futuros desbloqueos offline
            loginStore.enableBiometric = true
            loginStore.lastEmail = email

            // Warm-up de datos tras éxito
            Task { await DataSynchronizationManager.shared.performIncrementalSync() }

            didLogin = true
        } catch {
            // ⚠ Si la falla es de conectividad, forzamos estado offline temporal y auto-desbloqueo
            if error.isConnectivityError {
                await OfflineManager.shared.markOfflineFor(seconds: 20)
                self.autoTriedOfflineUnlock = false
                self.errorMessage = nil
                self.autoOfflineUnlockIfPossible()
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Login con biometría (con red)
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

            // 1) Intento seguro (con contexto)
            if let creds = try keychain.loadCredentials(context: ctx) {
                _ = try await auth.SignIn(email: creds.email, password: creds.password)

                loginStore.enableBiometric = true
                loginStore.lastEmail = creds.email

                // Warm-up de datos tras éxito
                Task { await DataSynchronizationManager.shared.performIncrementalSync() }

                didLogin = true
                return
            }

            // 2) Fallback (sin contexto)
            if let fallback = try keychain.loadCredentials(context: nil) {
                print("KC alt read (plain or secure without ctx):", fallback.email)
                _ = try await auth.SignIn(email: fallback.email, password: fallback.password)

                loginStore.enableBiometric = true
                loginStore.lastEmail = fallback.email

                // Warm-up de datos tras éxito
                Task { await DataSynchronizationManager.shared.performIncrementalSync() }

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

            loginStore.enableBiometric = true
            loginStore.lastEmail = email

            // Warm-up de datos tras éxito
            Task { await DataSynchronizationManager.shared.performIncrementalSync() }

            didLogin = true

        } catch {
            if error.isConnectivityError {
                await OfflineManager.shared.markOfflineFor(seconds: 20)
                self.autoTriedOfflineUnlock = false
                self.errorMessage = nil
                self.autoOfflineUnlockIfPossible()
                return
            }
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
