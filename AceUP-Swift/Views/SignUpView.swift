//
//  SignUpView.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 19/09/25.
//
import SwiftUI

struct SignUpView: View {
    @StateObject private var vm = SignUpViewModel()
    @State private var showTerms = false

    var body: some View {
        ZStack {
            UI.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Sign up")
                        .font(.title2.bold())
                        .foregroundColor(UI.navy)

                    Text("Create an account to access your new student lifestyle!")
                        .font(.footnote)
                        .foregroundColor(UI.muted)

                    Group {
                        sectionHeader("Choose Your Nick")
                        StyledTextField("Luc", text: $vm.nick)

                        sectionHeader("Email Address")
                        StyledTextField("name@email.com", text: $vm.email, keyboard: .emailAddress)
                        StyledTextField("Confirm email", text: $vm.emailConfirm, keyboard: .emailAddress)

                        sectionHeader("Password")
                        StyledSecureField("Create a password", text: $vm.password)
                        StyledSecureField("Confirm password", text: $vm.passwordConfirm)
                    }

                    HStack(alignment: .top, spacing: 10) {
                        Toggle("", isOn: $vm.agree)
                            .labelsHidden()
                            .toggleStyle(CheckToggleStyle())
                            .padding(.top, 2)

                        // Una sola oración + link a Terms (interceptado)
                        Text("I've read and agree with the [Terms and\u{00A0}Conditions](app://terms) and the Privacy Policy.")
                            .font(.footnote)
                            .foregroundColor(UI.muted)
                            .tint(UI.muted)
                            .environment(\.openURL, OpenURLAction { url in
                                if url.scheme == "app", url.host == "terms" {
                                    showTerms = true
                                    return .handled
                                }
                                return .discarded
                            })
                    }
                    .padding(.top, 4)

                    Button(action: {
                        Task { await vm.signUp() }
                    }) {
                        if vm.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Text("Create account")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundColor(UI.navy)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 8)
                    .disabled(!vm.formIsValid || vm.isLoading)

                    if let err = vm.errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                    if vm.didComplete {
                        Text("You're all set!.")
                            .foregroundColor(.green)
                            .font(.footnote)
                    }
                    Spacer(minLength: 12)
                }
                .frame(maxWidth: 520)
                .padding(20)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)

        // Sheet para términos y condiciones
        .sheet(isPresented: $showTerms) {
            TermsAndConditionsSheet { showTerms = false }
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(UI.muted)
            .padding(.top, 6)
    }
}
