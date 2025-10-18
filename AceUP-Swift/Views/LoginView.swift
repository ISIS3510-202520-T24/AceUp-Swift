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

                        // ---- BOTÓN LOGIN (funcional, MVVM) ----
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

                        // ---- BOTÓN BIOMÉTRICO (debajo, igual estilo) ----
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

            
            .onChange(of: vm.didLogin) { _, newValue in   // <- valor, NO binding
                if newValue {
                    onLoginSuccess()
                    vm.didLogin = false   // reset
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
