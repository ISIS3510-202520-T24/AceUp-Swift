//
//  TermsAndConditionsSheet.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 4/10/25.
//

import SwiftUI

struct TermsAndConditionsSheet: View {
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .frame(width: 36, height: 5)
                    .opacity(0.15)
                    .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Terms & Conditions")
                            .font(.title2.bold())
                            .foregroundColor(UI.navy)
                            .padding(.top, 8)

                        Group {
                            section("1. Acceptance of Service",
                                    "By creating an account on AceUp you agree to follow our usage rules, privacy policy, and community guidelines.")

                            section("2. Acceptable Use",
                                    "You may not use the service for unlawful activities, spam, or attempts to compromise system security.")

                            section("3. Data & Privacy",
                                    "We process your data according to the Privacy Policy. You can request deletion of your account at any time.")

                            section("4. Intellectual Property",
                                    "AceUp trademarks and content belong to their respective owners. Do not use them without permission.")

                            section("5. Changes",
                                    "We may update these terms. We will notify you of material changes.")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("OK") { onClose() }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundColor(UI.navy)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundColor(UI.navy)
            Text(body).font(.subheadline).foregroundColor(UI.muted)
        }
    }
}
