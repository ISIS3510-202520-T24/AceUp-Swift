import Foundation

extension Assignment {
    /// Devuelve una copia de ⁠ Assignment ⁠ cambiando solo los campos indicados.
    /// Los nombres de propiedades coinciden con los usados en FirebaseDataProviders.createAssignment(...)
    
    func copying(
        title: String? = nil,
        description: String?? = nil,            // doble optional: permite setear nil explícito
        courseId: String? = nil,
        courseName: String? = nil,
        courseColor: String? = nil,
        dueDate: Date? = nil,
        weight: Double? = nil,
        estimatedHours: Double?? = nil,
        actualHours: Double?? = nil,
        priority: Priority? = nil,
        status: AssignmentStatus? = nil,
        tags: [String]? = nil,
        attachments: [AssignmentAttachment]? = nil,
        subtasks: [Subtask]? = nil,
        createdAt: Date? = nil,
        grade: Double?? = nil,
        updatedAt: Date? = Date()
    ) -> Assignment {
        Assignment(
            id: self.id,
            title: title ?? self.title,
            description: description ?? self.description,
            courseId: courseId ?? self.courseId,
            courseName: courseName ?? self.courseName,
            courseColor: courseColor ?? self.courseColor,
            dueDate: dueDate ?? self.dueDate,
            weight: weight ?? self.weight,
            estimatedHours: estimatedHours ?? self.estimatedHours,
            actualHours: actualHours ?? self.actualHours,
            priority: priority ?? self.priority,
            status: status ?? self.status,
            tags: tags ?? self.tags,
            attachments: attachments ?? self.attachments,
            subtasks: subtasks ?? self.subtasks,
            createdAt: createdAt ?? self.createdAt,
            updatedAt: updatedAt ?? self.updatedAt,
            grade: grade ?? self.grade
        )
    }
}
