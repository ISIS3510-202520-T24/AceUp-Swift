//
//  HelpSupportView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2/11/25.
//

import SwiftUI
import MessageUI

struct HelpSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingContactForm = false
    @State private var showingFeedbackForm = false
    @State private var expandedFAQ: Int? = nil
    
    var body: some View {
        NavigationView {
            List {
                // Quick Actions
                quickActionsSection
                
                // FAQ
                faqSection
                
                // Contact & Feedback
                contactFeedbackSection
                
                // Additional Resources
                resourcesSection
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingContactForm) {
            ContactSupportView()
        }
        .sheet(isPresented: $showingFeedbackForm) {
            FeedbackView()
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        Section("Quick Actions") {
            SupportActionRow(
                title: "Contact Support",
                description: "Get help with technical issues",
                icon: "envelope",
                action: { showingContactForm = true }
            )
            
            SupportActionRow(
                title: "Send Feedback",
                description: "Share your thoughts and suggestions",
                icon: "heart",
                action: { showingFeedbackForm = true }
            )
            
            SupportActionRow(
                title: "Report a Bug",
                description: "Help us improve the app",
                icon: "exclamationmark.triangle",
                action: { reportBug() }
            )
            
            SupportActionRow(
                title: "Feature Request",
                description: "Suggest new features",
                icon: "lightbulb",
                action: { requestFeature() }
            )
        }
    }
    
    // MARK: - FAQ Section
    
    private var faqSection: some View {
        Section("Frequently Asked Questions") {
            ForEach(Array(faqItems.enumerated()), id: \.offset) { index, faq in
                FAQRow(
                    question: faq.question,
                    answer: faq.answer,
                    isExpanded: expandedFAQ == index
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        expandedFAQ = expandedFAQ == index ? nil : index
                    }
                }
            }
        }
    }
    
    // MARK: - Contact & Feedback Section
    
    private var contactFeedbackSection: some View {
        Section("Get in Touch") {
            ContactRow(
                title: "Email Support",
                value: "support@aceup.app",
                icon: "envelope"
            ) {
                openEmail("support@aceup.app")
            }
            
            ContactRow(
                title: "Community Forum",
                value: "Join the discussion",
                icon: "bubble.left.and.bubble.right"
            ) {
                openURL("https://community.aceup.app")
            }
            
            ContactRow(
                title: "Social Media",
                value: "@AceUpApp",
                icon: "at"
            ) {
                openURL("https://twitter.com/aceupapp")
            }
        }
    }
    
    // MARK: - Additional Resources Section
    
    private var resourcesSection: some View {
        Section("Resources") {
            ResourceRow(
                title: "Getting Started Guide",
                description: "Learn the basics of AceUp",
                icon: "play.circle"
            ) {
                openURL("https://help.aceup.app/getting-started")
            }
            
            ResourceRow(
                title: "Video Tutorials",
                description: "Watch step-by-step guides",
                icon: "play.rectangle"
            ) {
                openURL("https://help.aceup.app/tutorials")
            }
            
            ResourceRow(
                title: "Keyboard Shortcuts",
                description: "Boost your productivity",
                icon: "keyboard"
            ) {
                showKeyboardShortcuts()
            }
            
            ResourceRow(
                title: "What's New",
                description: "Latest features and updates",
                icon: "sparkles"
            ) {
                openURL("https://help.aceup.app/whats-new")
            }
        }
    }
    
    // MARK: - FAQ Data
    
    private var faqItems: [FAQItem] {
        [
            FAQItem(
                question: "How do I sync my data across devices?",
                answer: "Your data automatically syncs when you're signed in to the same account. Make sure you have an internet connection and that sync is enabled in Settings > Data & Sync."
            ),
            FAQItem(
                question: "Can I share my calendar with classmates?",
                answer: "Yes! Go to Shared Calendars, create a group, and invite your classmates using their email addresses or share the group code."
            ),
            FAQItem(
                question: "How do I calculate my GPA?",
                answer: "Add your courses with their credit hours and weights in Academic Preferences. The app will automatically calculate your GPA as you enter grades."
            ),
            FAQItem(
                question: "Why am I not receiving notifications?",
                answer: "Check Settings > Notifications to ensure they're enabled. Also verify that notifications are allowed for AceUp in your device settings."
            ),
            FAQItem(
                question: "How do I backup my data?",
                answer: "Go to Settings > Import/Export Settings to create a backup file of all your preferences and data."
            ),
            FAQItem(
                question: "Can I use AceUp offline?",
                answer: "Yes, most features work offline. Your data will sync when you reconnect to the internet."
            ),
            FAQItem(
                question: "How do I reset my password?",
                answer: "On the login screen, tap 'Forgot Password' and follow the instructions sent to your email."
            ),
            FAQItem(
                question: "Is my data secure?",
                answer: "Yes, we use industry-standard encryption and security practices. Read our Privacy Policy for more details."
            )
        ]
    }
    
    // MARK: - Methods
    
    private func reportBug() {
        let subject = "Bug Report - AceUp iOS"
        let body = """
        Please describe the bug you encountered:
        
        Steps to reproduce:
        1. 
        2. 
        3. 
        
        Expected behavior:
        
        Actual behavior:
        
        Device Information:
        - Device: \(UIDevice.current.model)
        - iOS Version: \(UIDevice.current.systemVersion)
        - App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        """
        
        openEmail("support@aceup.app", subject: subject, body: body)
    }
    
    private func requestFeature() {
        let subject = "Feature Request - AceUp iOS"
        let body = """
        Feature Request:
        
        Description:
        
        How would this feature help you?
        
        Additional context:
        """
        
        openEmail("support@aceup.app", subject: subject, body: body)
    }
    
    private func openEmail(_ email: String, subject: String = "", body: String = "") {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func showKeyboardShortcuts() {
        // This could show a modal with keyboard shortcuts
        // For now, we'll just open a help page
        openURL("https://help.aceup.app/shortcuts")
    }
}

// MARK: - Component Views

struct SupportActionRow: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FAQRow: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack {
                    Text(question)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Text(answer)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
}

struct ContactRow: View {
    let title: String
    let value: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)
                    Text(value)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ResourceRow: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(UI.primary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Types

struct FAQItem {
    let question: String
    let answer: String
}

// MARK: - Additional Views

struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "envelope.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(UI.primary)
                
                Text("Contact Support")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(UI.navy)
                
                Text("We're here to help! Reach out to us and we'll get back to you as soon as possible.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    Button("Email Support") {
                        if let url = URL(string: "mailto:support@aceup.app") {
                            UIApplication.shared.open(url)
                        }
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Visit Help Center") {
                        if let url = URL(string: "https://help.aceup.app") {
                            UIApplication.shared.open(url)
                        }
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Contact Support")
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
}

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(UI.primary)
                
                Text("Send Feedback")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(UI.navy)
                
                Text("Your feedback helps us improve AceUp. Let us know what you think!")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    Button("Rate on App Store") {
                        if let url = URL(string: "https://apps.apple.com/app/aceup/id123456789") {
                            UIApplication.shared.open(url)
                        }
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Send Feedback Email") {
                        if let url = URL(string: "mailto:feedback@aceup.app") {
                            UIApplication.shared.open(url)
                        }
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Feedback")
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
}

#Preview {
    HelpSupportView()
}