import Foundation

extension Assignment {
    /// Crea una copia inmutable cambiando solo los campos provistos.
    /// Nota: updatedAt ANTES de grade; grade es Double?? para permitir nil explícito.
    func copying(
        title: String? = nil,
        description: String?? = nil,
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
        updatedAt: Date? = Date(),
        grade: Double?? = nil
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
