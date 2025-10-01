//
//  LoginView.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 19/09/25.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
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
                                StyledTextField("Email Address", text: $email, keyboard: .emailAddress)
                                StyledSecureField("Password", text: $password)

                                HStack {
                                    Spacer()
                                    Button("Forgot password?") {}
                                        .font(.footnote)
                                        .foregroundColor(UI.muted)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .frame(maxWidth: 480)
                        .padding(.top, 8)

                        Button(action: {
                           
                            onLoginSuccess()
                        }) {
                            Text("Login")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundColor(UI.navy)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 480)

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
        }
    }
}

#Preview {
    LoginView(onLoginSuccess: {
        print("Login exitoso - navegando a SharedCalendarsView")
    })
}
