//
//  LoginView.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 19/09/25.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    @ObservedObject private var offline = OfflineManager.shared
    let onLoginSuccess: () -> Void

    init(onLoginSuccess: @escaping () -> Void = {}) {
        self.onLoginSuccess = onLoginSuccess
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UI.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 32)

                        Image("Blue")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 225, height: 225)

                        Text("AceUp")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(UI.navy)
                            .frame(maxWidth: .infinity, alignment: .center)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome Back!")
                                .font(.title3.bold())
                                .foregroundColor(UI.navy)

                            VStack(spacing: 14) {
                                StyledTextField("Email Address", text: $vm.email, keyboard: .emailAddress)
                                StyledSecureField("Password", text: $vm.password)

                                HStack {
                                    Spacer()
                                    Button("Forgot password?") {
                                        Task { await vm.forgotPassword() }
                                    }
                                    .font(.footnote)
                                    .foregroundColor(UI.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .frame(maxWidth: 480)
                        .padding(.top, 8)

                        // ---- LOGIN (funcional, MVVM) ----
                        Button(action: { Task { await vm.login() } }) {
                            Text(vm.isLoading ? "Signing in..." : "Login")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundColor(UI.navy)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 480)
                        .disabled(vm.isLoading || vm.email.isEmpty || vm.password.isEmpty)

                        // ---- BIOMÉTRICO (manual) ----
                        Button(action: { Task { await vm.biometricLogin() } }) {
                            Text(vm.isBioLoading ? "Authenticating..." : "Login with biometrics")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundColor(UI.navy)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 480)
                        .disabled(vm.isBioLoading)

                        // ---- BANNER OFFLINE (auto-unlock sin botón) ----
                        if !offline.isOnline {
                            Text(offline.getOfflineMessage())
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.orange)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 8)
                        }

                        HStack(spacing: 6) {
                            Text("New to AceUp?")
                                .foregroundColor(UI.muted)
                            NavigationLink("Register now") { SignUpView() }
                                .font(.subheadline.bold())
                                .foregroundColor(UI.navy)
                        }

                        Divider().padding(.top, 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)

            .alert((vm.errorMessage ?? vm.alertMessage) ?? "",
                   isPresented: Binding(
                    get: { (vm.errorMessage ?? vm.alertMessage) != nil },
                    set: { if !$0 { vm.errorMessage = nil; vm.alertMessage = nil } }
                   )
            ) {
                Button("OK", role: .cancel) {}
            }

            // Intento automático de desbloqueo offline con biometría (sin botones)
            .onAppear {
                vm.autoOfflineUnlockIfPossible()
            }
            .onChange(of: offline.isOnline) { _, isOnline in
                if !isOnline {
                    vm.autoOfflineUnlockIfPossible()
                }
            }

            // Navegación al éxito
            .onChange(of: vm.didLogin) { _, newValue in
                if newValue {
                    onLoginSuccess()
                    vm.didLogin = false // reset
                }
            }
        }
    }
}

#Preview {
    LoginView(onLoginSuccess: {
        print("Login exitoso - navegando a SharedCalendarsView")
    })
}
