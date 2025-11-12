//
//  CoreDataExtensions.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 7/10/25.
//

import CoreData
import Foundation

// MARK: - Assignment Core Data Extensions

extension AssignmentEntity {
    
    /// Convert Core Data entity to Assignment model
    func toAssignment() -> Assignment {
        let tags = self.tags?.components(separatedBy: ",").filter { !$0.isEmpty } ?? []
        
        let attachments = (self.attachments?.allObjects as? [AttachmentEntity])?.compactMap { $0.toAttachment() } ?? []
        let subtasks = (self.subtasks?.allObjects as? [SubtaskEntity])?.compactMap { $0.toSubtask() } ?? []
        
        // Handle grade - check if entity has a grade attribute
        let grade: Double?
        if self.responds(to: Selector(("grade"))) {
            grade = self.value(forKey: "grade") as? Double
        } else {
            grade = nil
        }
        
        return Assignment(
            id: self.id ?? UUID().uuidString,
            title: self.title ?? "",
            description: self.descriptionText,
            courseId: self.courseId ?? "",
            courseName: self.courseName ?? "",
            courseColor: self.courseColor ?? "#122C4A",
            dueDate: self.dueDate ?? Date(),
            weight: self.weight,
            estimatedHours: self.estimatedHours == 0 ? nil : self.estimatedHours,
            actualHours: self.actualHours == 0 ? nil : self.actualHours,
            priority: Priority(rawValue: self.priority ?? "medium") ?? .medium,
            status: AssignmentStatus(rawValue: self.status ?? "pending") ?? .pending,
            tags: tags,
            attachments: attachments,
            subtasks: subtasks,
            createdAt: self.createdAt ?? Date(),
            updatedAt: self.updatedAt ?? Date(),
            grade: grade
        )
    }
    
    /// Update Core Data entity from Assignment model
    func updateFromAssignment(_ assignment: Assignment) {
        self.id = assignment.id
        self.title = assignment.title
        self.descriptionText = assignment.description
        self.courseId = assignment.courseId
        self.courseName = assignment.courseName
        self.courseColor = assignment.courseColor
        self.dueDate = assignment.dueDate
        self.weight = assignment.weight
        self.estimatedHours = assignment.estimatedHours ?? 0
        self.actualHours = assignment.actualHours ?? 0
        self.priority = assignment.priority.rawValue
        self.status = assignment.status.rawValue
        self.tags = assignment.tags.joined(separator: ",")
        self.createdAt = assignment.createdAt
        self.updatedAt = assignment.updatedAt
        self.userId = Auth.auth().currentUser?.uid
        
        // Handle grade if entity supports it
        if self.responds(to: Selector(("setGrade:"))) {
            self.setValue(assignment.grade, forKey: "grade")
        }
    }
    
    /// Create AssignmentEntity from Assignment model
    static func fromAssignment(_ assignment: Assignment, in context: NSManagedObjectContext) -> AssignmentEntity {
        let entity = AssignmentEntity(context: context)
        entity.updateFromAssignment(assignment)
        return entity
    }
}

// MARK: - Subtask Core Data Extensions

extension SubtaskEntity {
    
    /// Convert Core Data entity to Subtask model
    func toSubtask() -> Subtask {
        return Subtask(
            id: self.id ?? UUID().uuidString,
            title: self.title ?? "",
            description: self.descriptionText,
            isCompleted: self.isCompleted,
            estimatedHours: self.estimatedHours == 0 ? nil : self.estimatedHours,
            completedAt: self.completedAt,
            createdAt: self.createdAt ?? Date()
        )
    }
    
    /// Update Core Data entity from Subtask model
    func updateFromSubtask(_ subtask: Subtask) {
        self.id = subtask.id
        self.title = subtask.title
        self.descriptionText = subtask.description
        self.isCompleted = subtask.isCompleted
        self.estimatedHours = subtask.estimatedHours ?? 0
        self.completedAt = subtask.completedAt
        self.createdAt = subtask.createdAt
    }
    
    /// Create SubtaskEntity from Subtask model
    static func fromSubtask(_ subtask: Subtask, in context: NSManagedObjectContext) -> SubtaskEntity {
        let entity = SubtaskEntity(context: context)
        entity.updateFromSubtask(subtask)
        return entity
    }
}

// MARK: - Attachment Core Data Extensions

extension AttachmentEntity {
    
    /// Convert Core Data entity to AssignmentAttachment model
    func toAttachment() -> AssignmentAttachment {
        return AssignmentAttachment(
            id: self.id ?? UUID().uuidString,
            name: self.name ?? "",
            url: self.url ?? "",
            type: AttachmentType(rawValue: self.type ?? "other") ?? .other,
            size: self.size == 0 ? nil : self.size,
            uploadedAt: self.uploadedAt ?? Date()
        )
    }
    
    /// Update Core Data entity from AssignmentAttachment model
    func updateFromAttachment(_ attachment: AssignmentAttachment) {
        self.id = attachment.id
        self.name = attachment.name
        self.url = attachment.url
        self.type = attachment.type.rawValue
        self.size = attachment.size ?? 0
        self.uploadedAt = attachment.uploadedAt
    }
    
    /// Create AttachmentEntity from AssignmentAttachment model
    static func fromAttachment(_ attachment: AssignmentAttachment, in context: NSManagedObjectContext) -> AttachmentEntity {
        let entity = AttachmentEntity(context: context)
        entity.updateFromAttachment(attachment)
        return entity
    }
}

// MARK: - Course Core Data Extensions

extension CourseEntity {
    
    /// Convert Core Data entity to Course model
    func toCourse() -> Course {
        let gradeWeight = self.gradeWeights?.toGradeWeight() ?? GradeWeight(
            assignments: 0.4, exams: 0.4, projects: 0.15, participation: 0.05, other: 0.0
        )
        
        return Course(
            id: self.id ?? UUID().uuidString,
            name: self.name ?? "",
            code: self.code ?? "",
            credits: Int(self.credits),
            instructor: self.instructor ?? "",
            color: self.color ?? "#122C4A",
            semester: self.semester ?? "Fall",
            year: Int(self.year),
            gradeWeight: gradeWeight,
            currentGrade: self.currentGrade == 0 ? nil : self.currentGrade,
            targetGrade: self.targetGrade == 0 ? nil : self.targetGrade,
            createdAt: Date(), // Default since not stored in current model
            updatedAt: Date()  // Default since not stored in current model
        )
    }
    
    /// Update Core Data entity from Course model
    func updateFromCourse(_ course: Course) {
        self.id = course.id
        self.name = course.name
        self.code = course.code
        self.credits = Int32(course.credits)
        self.instructor = course.instructor
        self.color = course.color
        self.semester = course.semester
        self.year = Int32(course.year)
        self.currentGrade = course.currentGrade ?? 0
        self.targetGrade = course.targetGrade ?? 0
        self.userId = Auth.auth().currentUser?.uid
    }
    
    /// Create CourseEntity from Course model
    static func fromCourse(_ course: Course, in context: NSManagedObjectContext) -> CourseEntity {
        let entity = CourseEntity(context: context)
        entity.updateFromCourse(course)
        
        // Create grade weights
        let gradeWeightEntity = GradeWeightEntity(context: context)
        gradeWeightEntity.updateFromGradeWeight(course.gradeWeight)
        entity.gradeWeights = gradeWeightEntity
        
        return entity
    }
}

// MARK: - GradeWeight Core Data Extensions

extension GradeWeightEntity {
    
    /// Convert Core Data entity to GradeWeight model
    func toGradeWeight() -> GradeWeight {
        return GradeWeight(
            assignments: self.assignments,
            exams: self.exams,
            projects: self.projects,
            participation: self.participation,
            other: self.other
        )
    }
    
    /// Update Core Data entity from GradeWeight model
    func updateFromGradeWeight(_ gradeWeight: GradeWeight) {
        self.assignments = gradeWeight.assignments
        self.exams = gradeWeight.exams
        self.projects = gradeWeight.projects
        self.participation = gradeWeight.participation
        self.other = gradeWeight.other
    }
}

// MARK: - Holiday Core Data Extensions

extension HolidayEntity {
    
    /// Convert Core Data entity to Holiday model
    func toHoliday() -> Holiday {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        return Holiday(
            date: dateFormatter.string(from: self.date ?? Date()),
            localName: self.name ?? "",
            name: self.name ?? "",
            countryCode: self.country ?? "",
            fixed: true, // Default to true for holidays in Core Data
            global: self.isNational,
            counties: nil, // Not stored in current model
            launchYear: nil, // Not stored in current model
            types: self.type?.isEmpty == false ? [self.type!] : nil
        )
    }
    
    /// Update Core Data entity from Holiday model
    func updateFromHoliday(_ holiday: Holiday) {
        self.id = holiday.id
        self.name = holiday.name
        self.date = holiday.dateValue
        self.country = holiday.countryCode
        self.descriptionText = holiday.name // Use name as description fallback
        self.isNational = holiday.global ?? false
        self.type = holiday.types?.first ?? "national"
    }
    
    /// Create HolidayEntity from Holiday model
    static func fromHoliday(_ holiday: Holiday, in context: NSManagedObjectContext) -> HolidayEntity {
        let entity = HolidayEntity(context: context)
        entity.updateFromHoliday(holiday)
        return entity
    }
}

// MARK: - SharedCalendar Core Data Extensions

extension SharedCalendarEntity {
    
    /// Convert Core Data entity to CalendarGroup model
    func toCalendarGroup() -> CalendarGroup {
        let members = (self.members?.allObjects as? [GroupMemberEntity])?.compactMap { $0.toGroupMember() } ?? []
        
        return CalendarGroup(
            id: self.id ?? UUID().uuidString,
            name: self.name ?? "",
            description: self.descriptionText ?? "",
            members: members,
            createdAt: self.createdAt ?? Date(),
            createdBy: self.createdBy ?? "",
            color: self.color ?? "#122C4A",
            inviteCode: self.inviteCode
        )
    }
    
    /// Update Core Data entity from CalendarGroup model
    func updateFromCalendarGroup(_ group: CalendarGroup) {
        self.id = group.id
        self.name = group.name
        self.descriptionText = group.description
        self.createdAt = group.createdAt
        self.createdBy = group.createdBy
        self.color = group.color
        self.inviteCode = group.inviteCode
    }
    
    /// Create SharedCalendarEntity from CalendarGroup model
    static func fromCalendarGroup(_ group: CalendarGroup, in context: NSManagedObjectContext) -> SharedCalendarEntity {
        let entity = SharedCalendarEntity(context: context)
        entity.updateFromCalendarGroup(group)
        return entity
    }
}

// MARK: - GroupMember Core Data Extensions

extension GroupMemberEntity {
    
    /// Convert Core Data entity to GroupMember model
    func toGroupMember() -> GroupMember {
        return GroupMember(
            id: self.id ?? UUID().uuidString,
            name: self.name ?? "",
            email: self.email ?? "",
            avatar: self.avatar,
            isAdmin: self.isAdmin,
            joinedAt: self.joinedAt ?? Date(),
            availability: generateMockAvailabilitySlots() // This would need to be implemented properly
        )
    }
    
    /// Update Core Data entity from GroupMember model
    func updateFromGroupMember(_ member: GroupMember) {
        self.id = member.id
        self.name = member.name
        self.email = member.email
        self.avatar = member.avatar
        self.isAdmin = member.isAdmin
        self.joinedAt = member.joinedAt
    }
    
    /// Create GroupMemberEntity from GroupMember model
    static func fromGroupMember(_ member: GroupMember, in context: NSManagedObjectContext) -> GroupMemberEntity {
        let entity = GroupMemberEntity(context: context)
        entity.updateFromGroupMember(member)
        return entity
    }
}

// MARK: - Helper function for mock availability (temporary)

private func generateMockAvailabilitySlots() -> [AvailabilitySlot] {
    // This is a placeholder - in a real implementation, this would come from actual data
    return []
}

// MARK: - Import Firebase Auth for user ID

import FirebaseAuth