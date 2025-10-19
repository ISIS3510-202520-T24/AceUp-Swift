//
//  LoginView.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 19/09/25.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    let onLoginSuccess: () -> Void

    init(onLoginSuccess: @escaping () -> Void = {}) {
        self.onLoginSuccess = onLoginSuccess
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                
                ZStack {
                    UI.bg.ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: isLandscape ? 16 : 24) {
                            Spacer().frame(height: isLandscape ? 16 : 32)

                            Image("Blue")
                                .resizable()
                                .scaledToFit()
                                .frame(width: isLandscape ? 150 : 225, height: isLandscape ? 150 : 225)

                            Text("AceUp")
                                .font(.system(size: isLandscape ? 28 : 36, weight: .semibold))
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
                            .frame(maxWidth: isLandscape ? 400 : 480)
                            .padding(.top, 8)

                            // ---- BOTÓN LOGIN (funcional, MVVM) ----
                            Button(action: { Task { await vm.login() } }) {
                                Text(vm.isLoading ? "Signing in..." : "Login")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .foregroundColor(UI.navy)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(maxWidth: isLandscape ? 400 : 480)
                            .disabled(vm.isLoading || vm.email.isEmpty || vm.password.isEmpty)

                            // ---- BOTÓN BIOMÉTRICO (debajo, igual estilo) ----
                            Button(action: { Task { await vm.biometricLogin() } }) {
                                Text(vm.isBioLoading ? "Authenticating..." : "Login with biometrics")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .foregroundColor(UI.navy)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(maxWidth: isLandscape ? 400 : 480)
                            .disabled(vm.isBioLoading)

                            HStack(spacing: 6) {
                                Text("New to AceUp?")
                                    .foregroundColor(UI.muted)
                                NavigationLink("Register now") { SignUpView() }
                                    .font(.subheadline.bold())
                                    .foregroundColor(UI.navy)
                            }

                            Divider().padding(.top, isLandscape ? 16 : 24)
                        }
                        .padding(.horizontal, isLandscape ? 40 : 20)
                        .padding(.bottom, isLandscape ? 20 : 40)
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
                .onChange(of: vm.didLogin) { _, newValue in   // <- valor, NO binding
                    if newValue {
                        onLoginSuccess()
                        vm.didLogin = false   // reset
                    }
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
