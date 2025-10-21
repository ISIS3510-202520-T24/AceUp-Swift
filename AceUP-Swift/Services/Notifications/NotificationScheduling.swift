//
//  NotificationScheduling.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 18/10/25.
//

import Foundation


protocol NotificationScheduling {
    func scheduleDueSoonNotification(id: String, title: String, courseName: String?, dueDate: Date, status: AssignmentStatus )
    func cancelDueSoonNotification(id: String)
}
