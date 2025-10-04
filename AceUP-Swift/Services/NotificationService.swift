//
//  NotificationService.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 3/10/25.
//


import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting permission: \(error)")
            }
        }
    }
    
    // Notification 1: Daily summary (Type 2 BQ)
    func sendDailySummary(completed: Int, pending: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Today's Progress"
        content.body = "You have \(pending) task(s) pending and completed \(completed) today."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "daily-summary-\(UUID().uuidString)",
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending daily summary: \(error)")
            } else {
                print("Daily summary sent")
            }
        }
    }
    
    // Notification 2: Smart workload recommendation
    func sendWorkloadRecommendation(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Smart Recommendation"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "workload-rec-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending recommendation: \(error)")
            } else {
                print("Workload recommendation sent")
            }
        }
    }
    
    // Schedule daily summary for specific time (8 AM)
    func scheduleDailySummary() {
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let content = UNMutableNotificationContent()
        content.title = "Good morning!"
        content.body = "Check your tasks for today."
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "scheduled-daily-summary",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
