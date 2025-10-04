//
//  Untitled.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 3/10/25.
//

import Foundation
import SwiftData

@Model
class Assignment {
    var id: UUID
    var title: String
    var subject: String
    var assignmentDescription: String?
    var type: String              // "Homework", "Task", "Exam"
    var dueDate: Date?

    // Numéricos:
    // Peso como porcentaje 0...100
    var weightPct: Double
    // Nota 0...5 (solo válida si isCompleted == true)
    var grade: Double?

    var priority: String
    var isCompleted: Bool
    var estimatedHours: Int
    var createdAt: Date
    var completedAt: Date?

    init(title: String,
         subject: String,
         type: String,
         dueDate: Date?,
         weightPct: Double = 20.0,
         priority: String = "Medium",
         estimatedHours: Int = 2,
         description: String? = nil) {

        self.id = UUID()
        self.title = title
        self.subject = subject
        self.assignmentDescription = description
        self.type = type
        self.dueDate = dueDate

        // aseguremos rangos válidos
        self.weightPct = Assignment.clampWeight(weightPct)

        self.priority = priority
        self.isCompleted = false
        self.estimatedHours = estimatedHours
        self.createdAt = Date()
        self.completedAt = nil
        self.grade = nil
    }

    /// Cambia el estado de completado. Si se desmarca, borra la nota.
    func setCompleted(_ completed: Bool) {
        isCompleted = completed
        completedAt = completed ? Date() : nil
        if !completed {
            grade = nil
        }
    }
    
    
    

    /// Setea el peso en % (0...100).
    func setWeightPct(_ value: Double) {
        weightPct = Assignment.clampWeight(value)
    }

    /// Setea la nota (0...5) solo si está completado.
    func setGrade(_ value: Double?) {
        guard isCompleted else { return }  // no permitir si no está hecho
        
        if let v = value {
            grade = Assignment.clampGrade(v)
        } else {
            grade = nil
        }
    }

    /// Devuelve el peso como fracción 0...1
    var weightFraction: Double { weightPct / 100.0 }

    private static func clampWeight(_ x: Double) -> Double {
        min(100.0, max(0.0, x))
    }
    private static func clampGrade(_ x: Double) -> Double {
        min(5.0, max(0.0, x))
    }

}
