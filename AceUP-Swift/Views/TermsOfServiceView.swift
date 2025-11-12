//
//  TermsOfServiceView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/11/25.
//

import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Terms of Service")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(UI.navy)
                        
                        Text("Last updated: November 2, 2025")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("By using AceUp, you agree to these terms. Please read them carefully.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Acceptance of Terms
                    termsSection(
                        title: "1. Acceptance of Terms",
                        content: """
                        By downloading, installing, or using the AceUp application ("Service"), you agree to be bound by these Terms of Service ("Terms").
                        
                        If you disagree with any part of these terms, you may not access the Service.
                        """
                    )
                    
                    // Description of Service
                    termsSection(
                        title: "2. Description of Service",
                        content: """
                        AceUp is an academic management application that helps students:
                        
                        • Track courses, assignments, and grades
                        • Manage academic calendars and deadlines
                        • Collaborate with classmates through shared calendars
                        • Analyze academic workload and performance
                        • Receive notifications and reminders
                        
                        The Service is provided "as is" and we reserve the right to modify or discontinue any aspect of the Service at any time.
                        """
                    )
                    
                    // User Accounts
                    termsSection(
                        title: "3. User Accounts",
                        content: """
                        To use certain features of the Service, you must register for an account. You agree to:
                        
                        • Provide accurate and complete information
                        • Maintain the security of your account credentials
                        • Notify us immediately of any unauthorized use
                        • Accept responsibility for all activities under your account
                        
                        You must be at least 13 years old to create an account.
                        """
                    )
                    
                    // Acceptable Use
                    termsSection(
                        title: "4. Acceptable Use",
                        content: """
                        You agree not to use the Service to:
                        
                        • Violate any applicable laws or regulations
                        • Infringe on intellectual property rights
                        • Share inappropriate or harmful content
                        • Attempt to gain unauthorized access to our systems
                        • Interfere with the proper functioning of the Service
                        • Use the Service for commercial purposes without permission
                        
                        Academic integrity is important. Use the Service responsibly and in accordance with your institution's policies.
                        """
                    )
                    
                    // User Content
                    termsSection(
                        title: "5. User Content",
                        content: """
                        You retain ownership of any content you submit to the Service ("User Content"). By submitting User Content, you grant us a license to use, store, and display it solely for providing the Service.
                        
                        You are responsible for:
                        
                        • The accuracy of your academic data
                        • Compliance with your institution's policies
                        • Respecting others' privacy in shared content
                        • Not sharing copyrighted materials without permission
                        """
                    )
                    
                    // Privacy
                    termsSection(
                        title: "6. Privacy",
                        content: """
                        Your privacy is important to us. Our Privacy Policy explains how we collect, use, and protect your information.
                        
                        By using the Service, you consent to our collection and use of your information as described in our Privacy Policy.
                        """
                    )
                    
                    // Intellectual Property
                    termsSection(
                        title: "7. Intellectual Property",
                        content: """
                        The Service and its original content, features, and functionality are owned by AceUp and are protected by international copyright, trademark, and other intellectual property laws.
                        
                        You may not copy, modify, distribute, or create derivative works of our intellectual property without explicit permission.
                        """
                    )
                    
                    // Termination
                    termsSection(
                        title: "8. Termination",
                        content: """
                        You may terminate your account at any time through the app settings.
                        
                        We may suspend or terminate your account if you violate these Terms or engage in conduct that we determine to be harmful to the Service or other users.
                        
                        Upon termination, your right to use the Service ceases immediately.
                        """
                    )
                    
                    // Disclaimers
                    termsSection(
                        title: "9. Disclaimers",
                        content: """
                        The Service is provided "as is" without warranties of any kind. We disclaim all warranties, express or implied, including but not limited to:
                        
                        • Merchantability and fitness for a particular purpose
                        • Accuracy or completeness of information
                        • Uninterrupted or error-free operation
                        • Security or absence of viruses
                        
                        You use the Service at your own risk.
                        """
                    )
                    
                    // Limitation of Liability
                    termsSection(
                        title: "10. Limitation of Liability",
                        content: """
                        To the maximum extent permitted by law, AceUp shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of the Service.
                        
                        Our total liability shall not exceed the amount you paid for the Service in the 12 months preceding the claim.
                        """
                    )
                    
                    // Changes to Terms
                    termsSection(
                        title: "11. Changes to Terms",
                        content: """
                        We reserve the right to modify these Terms at any time. We will notify you of any changes by posting the new Terms in the app and updating the "Last updated" date.
                        
                        Your continued use of the Service after any changes constitutes acceptance of the new Terms.
                        """
                    )
                    
                    // Contact Information
                    termsSection(
                        title: "12. Contact Us",
                        content: """
                        If you have any questions about these Terms, please contact us:
                        
                        Email: legal@aceup.app
                        Address: AceUp Legal Team
                        [Address would go here]
                        """
                    )
                    
                    // Footer
                    VStack(spacing: 16) {
                        Divider()
                        
                        Button("View Full Terms Online") {
                            if let url = URL(string: "https://aceup.app/terms") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(UI.primary)
                        
                        Text("This is a summary of our terms. For the complete terms, please visit our website.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func termsSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)
            
            Text(content)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)
        }
    }
}

#Preview {
    TermsOfServiceView()
}