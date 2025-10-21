//
//  AssignmentsNotifier.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 18/10/25.
//

import Foundation
import FirebaseFirestore

final class AssignmentsNotifier {
    static let shared = AssignmentsNotifier()
    private init() {}

    private var listener: ListenerRegistration?

    func startListeningForUser(_ uid: String,
                               scheduler: NotificationScheduling = NotificationCenterService.shared) {
        stop()
        let db = Firestore.firestore()
        let startDay = Calendar.current.startOfDay(for: Date())

        listener = db.collection("assignments")
            .whereField("userId", isEqualTo: uid)
            .whereField("dueDate", isGreaterThanOrEqualTo: Timestamp(date: startDay))
            .addSnapshotListener { snap, _ in
                guard let docs = snap?.documents else { return }
                for doc in docs {
                    let data = doc.data()
                    let id = doc.documentID
                    let title = data["title"] as? String ?? "Tarea"
                    let courseName = data["courseName"] as? String
                    let due = (data["dueDate"] as? Timestamp)?.dateValue() ?? Date()
                    let status = AssignmentStatus(rawValue: data["status"] as? String ?? "pending") ?? .pending

                    if due > Date(), status != .completed, status != .cancelled {
                        scheduler.scheduleDueSoonNotification(
                            id: id, title: title, courseName: courseName, dueDate: due, status: status
                        )
                    } else {
                        scheduler.cancelDueSoonNotification(id: id)
                    }
                }
            }
    }

    func stop() { listener?.remove(); listener = nil }
}
