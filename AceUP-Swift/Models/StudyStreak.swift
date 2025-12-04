//
//  StudyStreak.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 3/12/25.
//

import Foundation

/// Resumen de la racha de estudio del usuario basado en assignments completados
struct StudyStreak: Codable, Equatable {
    let currentStreakDays: Int
    let longestStreakDays: Int
    let lastActivityDate: Date?
    let assignmentsCompletedThisWeek: Int
    let assignmentsCompletedToday: Int
    let generatedAt: Date

    static let empty = StudyStreak(
        currentStreakDays: 0,
        longestStreakDays: 0,
        lastActivityDate: nil,
        assignmentsCompletedThisWeek: 0,
        assignmentsCompletedToday: 0,
        generatedAt: Date()
    )
}
