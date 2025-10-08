//
//  DataMigrationService.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class DataMigrationService: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isMigrating = false
    @Published var migrationProgress = 0.0
    @Published var migrationMessage = ""
    @Published var migrationCompleted = false
    @Published var migrationError: String?
    
    private let db = Firestore.firestore()
    private let assignmentRepository = FirestoreAssignmentRepository()
    private let courseRepository = FirestoreCourseRepository()
    
    private var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? ""
    }
    
    // MARK: - Migration Methods
    
    func migrateAllData() async {
        guard !currentUserId.isEmpty else {
            migrationError = "No authenticated user found"
            return
        }
        
        isMigrating = true
        migrationProgress = 0.0
        migrationError = nil
        migrationCompleted = false
        
        // Step 1: Create sample courses
        migrationMessage = "Creating sample courses..."
        await createSampleCourses()
        migrationProgress = 0.3
        
        // Step 2: Create sample assignments
        migrationMessage = "Creating sample assignments..."
        await createSampleAssignments()
        migrationProgress = 0.6
        
        // Step 3: Verify data integrity
        migrationMessage = "Verifying data integrity..."
        await verifyDataIntegrity()
        migrationProgress = 1.0
        
        migrationMessage = "Migration completed successfully!"
        migrationCompleted = true
        
        isMigrating = false
    }
    
    private func createSampleCourses() async {
        let sampleCourses = generateSampleCourses()
        
        for course in sampleCourses {
            do {
                try await courseRepository.saveCourse(course)
            } catch {
                print("Failed to save course \(course.name): \(error)")
            }
        }
    }
    
    private func createSampleAssignments() async {
        // Get courses first to link assignments
        do {
            let courses = try await courseRepository.getAllCourses()
            let sampleAssignments = generateSampleAssignments(for: courses)
            
            for assignment in sampleAssignments {
                do {
                    try await assignmentRepository.saveAssignment(assignment)
                } catch {
                    print("Failed to save assignment \(assignment.title): \(error)")
                }
            }
        } catch {
            print("Failed to load courses for assignment creation: \(error)")
        }
    }
    
    private func verifyDataIntegrity() async {
        do {
            let courses = try await courseRepository.getAllCourses()
            let assignments = try await assignmentRepository.getAllAssignments()
            
            print("Migration verification:")
            print("- Created \(courses.count) courses")
            print("- Created \(assignments.count) assignments")
            
            // Verify that all assignments have valid course references
            let courseIds = Set(courses.map { $0.id })
            let invalidAssignments = assignments.filter { !courseIds.contains($0.courseId) }
            
            if !invalidAssignments.isEmpty {
                print("Warning: Found \(invalidAssignments.count) assignments with invalid course references")
            }
            
        } catch {
            print("Data verification failed: \(error)")
        }
    }
    
    // MARK: - Sample Data Generation
    
    private func generateSampleCourses() -> [Course] {
        let currentYear = Calendar.current.component(.year, from: Date())
        
        return [
            Course(
                id: "cs101",
                name: "Introduction to Computer Science",
                code: "CS101",
                credits: 4,
                instructor: "Dr. Sarah Johnson",
                color: "#122C4A",
                semester: "Fall",
                year: currentYear,
                gradeWeight: GradeWeight(
                    assignments: 0.4,
                    exams: 0.3,
                    projects: 0.2,
                    participation: 0.1,
                    other: 0.0
                ),
                currentGrade: 87.5,
                targetGrade: 90.0,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Course(
                id: "math201",
                name: "Calculus II",
                code: "MATH201",
                credits: 3,
                instructor: "Prof. Michael Chen",
                color: "#50E3C2",
                semester: "Fall",
                year: currentYear,
                gradeWeight: GradeWeight(
                    assignments: 0.3,
                    exams: 0.5,
                    projects: 0.0,
                    participation: 0.1,
                    other: 0.1
                ),
                currentGrade: 82.0,
                targetGrade: 85.0,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Course(
                id: "phys151",
                name: "Physics I",
                code: "PHYS151",
                credits: 4,
                instructor: "Dr. Emily Rodriguez",
                color: "#FF6B6B",
                semester: "Fall",
                year: currentYear,
                gradeWeight: GradeWeight(
                    assignments: 0.2,
                    exams: 0.4,
                    projects: 0.2,
                    participation: 0.1,
                    other: 0.1
                ),
                currentGrade: 79.3,
                targetGrade: 80.0,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Course(
                id: "cs401",
                name: "Advanced AI",
                code: "CS401",
                credits: 3,
                instructor: "Dr. Alex Thompson",
                color: "#9C27B0",
                semester: "Fall",
                year: currentYear,
                gradeWeight: GradeWeight(
                    assignments: 0.3,
                    exams: 0.2,
                    projects: 0.4,
                    participation: 0.1,
                    other: 0.0
                ),
                currentGrade: 91.2,
                targetGrade: 95.0,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
    }
    
    private func generateSampleAssignments(for courses: [Course]) -> [Assignment] {
        guard !courses.isEmpty else { return [] }
        
        let calendar = Calendar.current
        var assignments: [Assignment] = []
        
        // Computer Science assignments
        if let csCourse = courses.first(where: { $0.code == "CS101" }) {
            assignments.append(contentsOf: [
                Assignment(
                    title: "Final Programming Project",
                    description: "Develop a complete web application using React and Node.js",
                    subject: "Computer Science",
                    courseId: csCourse.id,
                    courseName: csCourse.name,
                    courseColor: csCourse.color,
                    dueDate: calendar.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                    weight: 0.25,
                    estimatedHours: 20,
                    priority: .high,
                    status: .pending,
                    tags: ["programming", "web development"],
                    subtasks: [
                        Subtask(title: "Setup project repository"),
                        Subtask(title: "Design database schema"),
                        Subtask(title: "Implement backend API"),
                        Subtask(title: "Create frontend components"),
                        Subtask(title: "Write tests"),
                        Subtask(title: "Deploy to production")
                    ]
                ),
                Assignment(
                    title: "Data Structures Quiz",
                    description: "Quiz covering arrays, linked lists, and trees",
                    subject: "Computer Science",
                    courseId: csCourse.id,
                    courseName: csCourse.name,
                    courseColor: csCourse.color,
                    dueDate: calendar.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
                    weight: 0.10,
                    estimatedHours: 2,
                    priority: .medium,
                    status: .pending,
                    tags: ["quiz", "data structures"]
                )
            ])
        }
        
        // Math assignments
        if let mathCourse = courses.first(where: { $0.code == "MATH201" }) {
            assignments.append(contentsOf: [
                Assignment(
                    title: "Calculus Midterm Preparation",
                    description: "Review chapters 8-12 for comprehensive midterm exam",
                    subject: "Mathematics",
                    courseId: mathCourse.id,
                    courseName: mathCourse.name,
                    courseColor: mathCourse.color,
                    dueDate: calendar.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
                    weight: 0.30,
                    estimatedHours: 8,
                    priority: .critical,
                    status: .inProgress,
                    tags: ["math", "calculus", "exam prep"]
                ),
                Assignment(
                    title: "Integration Homework",
                    description: "Complete problems 1-20 from chapter 9",
                    subject: "Mathematics",
                    courseId: mathCourse.id,
                    courseName: mathCourse.name,
                    courseColor: mathCourse.color,
                    dueDate: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
                    weight: 0.05,
                    estimatedHours: 3,
                    priority: .high,
                    status: .pending,
                    tags: ["homework", "integration"]
                )
            ])
        }
        
        // Physics assignments
        if let physicsCourse = courses.first(where: { $0.code == "PHYS151" }) {
            assignments.append(contentsOf: [
                Assignment(
                    title: "Physics Lab Report #3",
                    description: "Analysis of pendulum motion and harmonic oscillation",
                    subject: "Physics",
                    courseId: physicsCourse.id,
                    courseName: physicsCourse.name,
                    courseColor: physicsCourse.color,
                    dueDate: Date(),
                    weight: 0.08,
                    estimatedHours: 4,
                    priority: .medium,
                    status: .pending,
                    tags: ["physics", "lab", "mechanics"]
                )
            ])
        }
        
        // AI course assignments
        if let aiCourse = courses.first(where: { $0.code == "CS401" }) {
            assignments.append(contentsOf: [
                Assignment(
                    title: "Research Paper Draft",
                    description: "First draft of research paper on machine learning applications",
                    subject: "Computer Science",
                    courseId: aiCourse.id,
                    courseName: aiCourse.name,
                    courseColor: aiCourse.color,
                    dueDate: calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                    weight: 0.15,
                    estimatedHours: 12,
                    priority: .medium,
                    status: .pending,
                    tags: ["research", "AI", "paper"],
                    subtasks: [
                        Subtask(title: "Literature review", isCompleted: true),
                        Subtask(title: "Write introduction"),
                        Subtask(title: "Methodology section"),
                        Subtask(title: "Results analysis"),
                        Subtask(title: "Conclusions")
                    ]
                )
            ])
        }
        
        return assignments
    }
    
    // MARK: - Utility Methods
    
    func clearAllData() async {
        guard !currentUserId.isEmpty else {
            migrationError = "No authenticated user found"
            return
        }
        
        isMigrating = true
        migrationMessage = "Clearing all data..."
        
        do {
            // Clear assignments
            let assignments = try await assignmentRepository.getAllAssignments()
            for assignment in assignments {
                try await assignmentRepository.deleteAssignment(assignment.id)
            }
            
            // Clear courses
            let courses = try await courseRepository.getAllCourses()
            for course in courses {
                try await courseRepository.deleteCourse(course.id)
            }
            
            migrationMessage = "All data cleared successfully!"
            
        } catch {
            migrationError = "Failed to clear data: \(error.localizedDescription)"
        }
        
        isMigrating = false
    }
    
    func hasExistingData() async -> Bool {
        do {
            let courses = try await courseRepository.getAllCourses()
            let assignments = try await assignmentRepository.getAllAssignments()
            return !courses.isEmpty || !assignments.isEmpty
        } catch {
            return false
        }
    }
}