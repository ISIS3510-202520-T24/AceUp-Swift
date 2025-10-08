//
//  SharingService.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 8/10/25.
//

import UIKit
import SwiftUI

/// Service for handling sharing functionality across the app
class SharingService {
    
    static let shared = SharingService()
    
    private init() {}
    
    /// Share a group invitation code with customizable options
    /// - Parameters:
    ///   - group: The calendar group to share
    ///   - includeQRCode: Whether to include the QR code image (optional)
    ///   - sourceView: The source view for iPad popover presentation
    func shareGroupInvitation(
        group: CalendarGroup,
        includeQRCode: UIImage? = nil,
        sourceView: UIView? = nil
    ) {
        guard let inviteCode = group.inviteCode else {
            print("Cannot share: group has no invite code")
            return
        }
        
        let shareText = generateShareText(for: group)
        let deepLink = createDeepLink(for: inviteCode)
        
        var activityItems: [Any] = [shareText]
        
        // Add the deep link as a separate item for better compatibility
        if let url = URL(string: deepLink) {
            activityItems.append(url)
        }
        
        // Add QR code image if provided
        if let qrImage = includeQRCode {
            activityItems.append(qrImage)
        }
        
        presentActivityController(
            with: activityItems,
            sourceView: sourceView
        )
    }
    
    /// Share just the invitation code as text
    /// - Parameters:
    ///   - group: The calendar group to share
    ///   - sourceView: The source view for iPad popover presentation
    func shareInvitationCode(
        group: CalendarGroup,
        sourceView: UIView? = nil
    ) {
        guard let inviteCode = group.inviteCode else {
            print("Cannot share: group has no invite code")
            return
        }
        
        let deepLink = createDeepLink(for: inviteCode)
        let shareText = "Join my group \"\(group.name)\" on AceUP! 📚\n\n🔑 Invite Code: \(inviteCode)\n\n🔗 Tap to join: \(deepLink)"
        
        var activityItems: [Any] = [shareText]
        
        // Add the deep link as a URL object for better app compatibility
        if let url = URL(string: deepLink) {
            activityItems.append(url)
        }
        
        presentActivityController(
            with: activityItems,
            sourceView: sourceView
        )
    }
    
    /// Share detailed group information
    /// - Parameters:
    ///   - group: The calendar group to share
    ///   - sourceView: The source view for iPad popover presentation
    func shareGroupDetails(
        group: CalendarGroup,
        sourceView: UIView? = nil
    ) {
        guard let inviteCode = group.inviteCode else {
            print("Cannot share: group has no invite code")
            return
        }
        
        let memberCount = group.memberCount
        let memberText = memberCount == 1 ? "member" : "members"
        let deepLink = createDeepLink(for: inviteCode)
        
        let shareText = """
        📚 Join my study group on AceUP!
        
        📝 Group: \(group.name)
        📖 Description: \(group.description.isEmpty ? "Study group for collaborative learning" : group.description)
        👥 Members: \(memberCount) \(memberText)
        
        🔑 Invite Code: \(inviteCode)
        🔗 Tap to join: \(deepLink)
        
        AceUP - Your collaborative study companion
        """
        
        var activityItems: [Any] = [shareText]
        
        // Add the deep link as a URL object for better app compatibility
        if let url = URL(string: deepLink) {
            activityItems.append(url)
        }
        
        presentActivityController(
            with: activityItems,
            sourceView: sourceView
        )
    }
    
    /// Share group invitation with enhanced compatibility across different apps
    /// - Parameters:
    ///   - group: The calendar group to share
    ///   - sourceView: The source view for iPad popover presentation
    func shareGroupInvitationEnhanced(
        group: CalendarGroup,
        sourceView: UIView? = nil
    ) {
        guard group.inviteCode != nil else {
            print("Cannot share: group has no invite code")
            return
        }
        
        let activityItemProvider = GroupInvitationActivityItemProvider(group: group)
        let deepLink = createDeepLink(for: group.inviteCode!)
        
        let activityItems: [Any] = [
            activityItemProvider,
            URL(string: deepLink) as Any
        ].compactMap { $0 }
        
        presentActivityController(
            with: activityItems,
            sourceView: sourceView
        )
    }
    
    // MARK: - Private Methods
    
    private func createDeepLink(for inviteCode: String) -> String {
        return "aceup://join/\(inviteCode)"
    }
    
    private func generateShareText(for group: CalendarGroup) -> String {
        guard let inviteCode = group.inviteCode else { return "" }
        
        let baseText = "Join my group \"\(group.name)\" on AceUP! 📚"
        let codeText = "🔑 Invite Code: \(inviteCode)"
        let deepLink = createDeepLink(for: inviteCode)
        let linkText = "🔗 Tap to join: \(deepLink)"
        
        if !group.description.isEmpty {
            return "\(baseText)\n\n📖 \(group.description)\n\n\(codeText)\n\(linkText)"
        } else {
            return "\(baseText)\n\n\(codeText)\n\(linkText)"
        }
    }
    
    private func presentActivityController(
        with activityItems: [Any],
        sourceView: UIView? = nil
    ) {
        let activityController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityController.popoverPresentationController {
            if let sourceView = sourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            } else {
                // Fallback to center of screen
                let rootView = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows.first?.rootViewController?.view
                
                popover.sourceView = rootView
                popover.sourceRect = CGRect(
                    x: UIScreen.main.bounds.width / 2,
                    y: UIScreen.main.bounds.height / 2,
                    width: 0,
                    height: 0
                )
            }
        }
        
        // Present the activity controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // Find the topmost presented view controller
            var topViewController = rootViewController
            while let presentedViewController = topViewController.presentedViewController {
                topViewController = presentedViewController
            }
            
            topViewController.present(activityController, animated: true)
        }
    }
}

// MARK: - SwiftUI Extensions

extension SharingService {
    
    /// Custom activity item provider for group invitations
    class GroupInvitationActivityItemProvider: UIActivityItemProvider, @unchecked Sendable {
        private let group: CalendarGroup
        private let deepLink: String
        
        init(group: CalendarGroup) {
            self.group = group
            self.deepLink = "aceup://join/\(group.inviteCode ?? "")"
            super.init(placeholderItem: deepLink)
        }
        
        override func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
            
            guard let inviteCode = group.inviteCode else { return deepLink }
            
            // Customize content based on the sharing destination
            switch activityType {
            case .message:
                return "Join my group \"\(group.name)\" on AceUP! 📚\n\n🔑 Code: \(inviteCode)\n🔗 \(deepLink)"
            case .mail:
                return """
                Subject: Join my study group on AceUP!
                
                Hi there! 👋
                
                I'd like to invite you to join my study group "\(group.name)" on AceUP.
                
                📖 Description: \(group.description.isEmpty ? "Collaborative study group" : group.description)
                
                To join:
                🔑 Use invitation code: \(inviteCode)
                🔗 Or tap this link: \(deepLink)
                
                AceUP helps us stay organized and study together efficiently!
                
                Best regards! 📚
                """
            case .copyToPasteboard:
                return deepLink
            case .airDrop:
                return "\(group.name) - AceUP Group\nCode: \(inviteCode)\n\(deepLink)"
            default:
                return "Join \"\(group.name)\" on AceUP! Code: \(inviteCode) - \(deepLink)"
            }
        }
        
        override func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
            return "Join my study group on AceUP!"
        }
    }
    
    /// SwiftUI-friendly method to share group invitation with enhanced compatibility
    /// - Parameter group: The calendar group to share
    @MainActor
    func shareGroupInvitationEnhancedFromSwiftUI(group: CalendarGroup) {
        shareGroupInvitationEnhanced(group: group)
    }
    
    /// SwiftUI-friendly method to share group invitation
    /// - Parameters:
    ///   - group: The calendar group to share
    ///   - includeQRCode: Whether to include QR code image
    @MainActor
    func shareGroupFromSwiftUI(
        group: CalendarGroup,
        includeQRCode: UIImage? = nil
    ) {
        shareGroupInvitation(
            group: group,
            includeQRCode: includeQRCode
        )
    }
    
    /// SwiftUI-friendly method to share invitation code only
    /// - Parameter group: The calendar group to share
    @MainActor
    func shareInvitationCodeFromSwiftUI(group: CalendarGroup) {
        shareInvitationCode(group: group)
    }
    
    /// SwiftUI-friendly method to share detailed group information
    /// - Parameter group: The calendar group to share
    @MainActor
    func shareGroupDetailsFromSwiftUI(group: CalendarGroup) {
        shareGroupDetails(group: group)
    }
}