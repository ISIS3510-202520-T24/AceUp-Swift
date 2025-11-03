//
//  PrivacyPolicyView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/11/25.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy Policy")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(UI.navy)
                        
                        Text("Last updated: November 2, 2025")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Your privacy is important to us. This Privacy Policy explains how AceUp collects, uses, and protects your information.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Information We Collect
                    privacySection(
                        title: "Information We Collect",
                        content: """
                        We collect information you provide directly to us, such as:
                        
                        • Account information (name, email address)
                        • Academic data (courses, assignments, grades)
                        • Calendar information and shared calendars
                        • App preferences and settings
                        • Communication with our support team
                        
                        We also automatically collect certain information when you use our service:
                        
                        • Device information (model, operating system)
                        • Usage analytics and app performance data
                        • Log data (IP address, access times)
                        """
                    )
                    
                    // How We Use Your Information
                    privacySection(
                        title: "How We Use Your Information",
                        content: """
                        We use the information we collect to:
                        
                        • Provide and maintain our services
                        • Process your academic data and calculations
                        • Send you notifications and reminders
                        • Sync your data across devices
                        • Analyze usage patterns to improve our app
                        • Provide customer support
                        • Ensure security and prevent fraud
                        """
                    )
                    
                    // Information Sharing
                    privacySection(
                        title: "Information Sharing",
                        content: """
                        We do not sell, trade, or rent your personal information. We may share your information only in these limited circumstances:
                        
                        • With your consent (e.g., shared calendars with classmates)
                        • With service providers who help us operate our service
                        • To comply with legal obligations
                        • To protect our rights and safety
                        
                        Academic data you choose to share through group calendars is only visible to group members you invite.
                        """
                    )
                    
                    // Data Security
                    privacySection(
                        title: "Data Security",
                        content: """
                        We implement appropriate security measures to protect your information:
                        
                        • Data encryption in transit and at rest
                        • Secure authentication and authorization
                        • Regular security audits and updates
                        • Limited access to personal data by our team
                        
                        While we strive to protect your data, no security system is completely secure. Please notify us immediately if you suspect any unauthorized access.
                        """
                    )
                    
                    // Your Rights
                    privacySection(
                        title: "Your Rights and Choices",
                        content: """
                        You have the following rights regarding your personal information:
                        
                        • Access and review your data
                        • Update or correct your information
                        • Delete your account and data
                        • Export your data
                        • Control notification preferences
                        • Opt out of analytics collection
                        
                        You can exercise these rights through the app settings or by contacting us.
                        """
                    )
                    
                    // Data Retention
                    privacySection(
                        title: "Data Retention",
                        content: """
                        We retain your information for as long as necessary to provide our services:
                        
                        • Account data: Until you delete your account
                        • Academic data: Until you remove it or delete your account
                        • Analytics data: Up to 24 months
                        • Support communications: Up to 3 years
                        
                        When you delete your account, we will delete your personal data within 30 days, except where required by law.
                        """
                    )
                    
                    // Children's Privacy
                    privacySection(
                        title: "Children's Privacy",
                        content: """
                        Our service is intended for users 13 years of age and older. We do not knowingly collect personal information from children under 13.
                        
                        If you believe we have inadvertently collected information from a child under 13, please contact us immediately.
                        """
                    )
                    
                    // Contact Information
                    privacySection(
                        title: "Contact Us",
                        content: """
                        If you have questions about this Privacy Policy or our privacy practices, please contact us:
                        
                        Email: privacy@aceup.app
                        Address: AceUp Privacy Team
                        [Address would go here]
                        
                        We will respond to your inquiry within 30 days.
                        """
                    )
                    
                    // Footer
                    VStack(spacing: 16) {
                        Divider()
                        
                        Button("View Full Privacy Policy Online") {
                            if let url = URL(string: "https://aceup.app/privacy") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(UI.primary)
                        
                        Text("This is a summary of our privacy practices. For the complete policy, please visit our website.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
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
    
    private func privacySection(title: String, content: String) -> some View {
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
    PrivacyPolicyView()
}