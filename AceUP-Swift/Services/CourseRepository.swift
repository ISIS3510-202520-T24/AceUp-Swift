//
//  CourseRepository.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
protocol CourseRepositoryProtocol {
    func getAllCourses() async throws -> [Course]
    func getCourseById(_ id: String) async throws -> Course?
    func getCoursesByUserId(_ userId: String) async throws -> [Course]
    func saveCourse(_ course: Course) async throws
    func updateCourse(_ course: Course) async throws
    func deleteCourse(_ id: String) async throws
    func getActiveCourses() async throws -> [Course]
    func getCoursesByYear(_ year: Int) async throws -> [Course]
}

@MainActor
class FirestoreCourseRepository: CourseRepositoryProtocol, ObservableObject {
    
    // MARK: - Properties
    
    @Published private(set) var courses: [Course] = []
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    private var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? ""
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await startListening()
        }
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Private Methods
    
    private func startListening() async {
        guard !currentUserId.isEmpty else {
            print("No authenticated user found")
            return
        }
        
        listener = db.collection("courses")
            .whereField("userId", isEqualTo: currentUserId)
            .order(by: "name")
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching courses: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("No courses found")
                    return
                }
                
                Task { @MainActor in
                    self.courses = documents.compactMap { document in
                        try? document.data(as: CourseFirestore.self).toCourse()
                    }
                }
            }
    }
    
    private func courseDocument(id: String) -> DocumentReference {
        return db.collection("courses").document(id)
    }
    
    // MARK: - CourseRepositoryProtocol Implementation
    
    func getAllCourses() async throws -> [Course] {
        return courses
    }
    
    func getCourseById(_ id: String) async throws -> Course? {
        return courses.first { $0.id == id }
    }
    
    func getCoursesByUserId(_ userId: String) async throws -> [Course] {
        return courses.filter { _ in userId == currentUserId }
    }
    
    func saveCourse(_ course: Course) async throws {
        let firestoreCourse = CourseFirestore.from(course: course, userId: currentUserId)
        try await courseDocument(id: course.id).setData(from: firestoreCourse)
    }
    
    func updateCourse(_ course: Course) async throws {
        let updatedCourse = Course(
            id: course.id,
            name: course.name,
            code: course.code,
            credits: course.credits,
            instructor: course.instructor,
            color: course.color,
            semester: course.semester,
            year: course.year,
            gradeWeight: course.gradeWeight,
            currentGrade: course.currentGrade,
            targetGrade: course.targetGrade,
            createdAt: course.createdAt,
            updatedAt: Date()
        )
        
        let firestoreCourse = CourseFirestore.from(course: updatedCourse, userId: currentUserId)
        try await courseDocument(id: updatedCourse.id).setData(from: firestoreCourse)
    }
    
    func deleteCourse(_ id: String) async throws {
        try await courseDocument(id: id).delete()
    }
    
    func getActiveCourses() async throws -> [Course] {
        return courses.filter { $0.isActive }
    }
    
    func getCoursesByYear(_ year: Int) async throws -> [Course] {
        return courses.filter { $0.year == year }
    }
}

// MARK: - Firestore Models

struct CourseFirestore: Codable {
    let id: String
    let userId: String
    let name: String
    let code: String
    let credits: Int
    let instructor: String
    let color: String
    let semester: String
    let year: Int
    let gradeWeight: GradeWeightFirestore
    let currentGrade: Double?
    let targetGrade: Double?
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    static func from(course: Course, userId: String) -> CourseFirestore {
        return CourseFirestore(
            id: course.id,
            userId: userId,
            name: course.name,
            code: course.code,
            credits: course.credits,
            instructor: course.instructor,
            color: course.color,
            semester: course.semester,
            year: course.year,
            gradeWeight: GradeWeightFirestore.from(course.gradeWeight),
            currentGrade: course.currentGrade,
            targetGrade: course.targetGrade,
            createdAt: Timestamp(date: course.createdAt),
            updatedAt: Timestamp(date: course.updatedAt)
        )
    }
    
    func toCourse() -> Course {
        return Course(
            id: id,
            name: name,
            code: code,
            credits: credits,
            instructor: instructor,
            color: color,
            semester: semester,
            year: year,
            gradeWeight: gradeWeight.toGradeWeight(),
            currentGrade: currentGrade,
            targetGrade: targetGrade,
            createdAt: createdAt.dateValue(),
            updatedAt: updatedAt.dateValue()
        )
    }
}

struct GradeWeightFirestore: Codable {
    let assignments: Double
    let exams: Double
    let projects: Double
    let participation: Double
    let other: Double
    
    static func from(_ gradeWeight: GradeWeight) -> GradeWeightFirestore {
        return GradeWeightFirestore(
            assignments: gradeWeight.assignments,
            exams: gradeWeight.exams,
            projects: gradeWeight.projects,
            participation: gradeWeight.participation,
            other: gradeWeight.other
        )
    }
    
    func toGradeWeight() -> GradeWeight {
        return GradeWeight(
            assignments: assignments,
            exams: exams,
            projects: projects,
            participation: participation,
            other: other
        )
    }
}

// MARK: - Course View Model

@MainActor
class CourseViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var courses: [Course] = []
    @Published var activeCourses: [Course] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingCreateCourse = false
    @Published var selectedCourse: Course?
    
    // Form properties
    @Published var newCourseName = ""
    @Published var newCourseCode = ""
    @Published var newCourseCredits = 3
    @Published var newCourseInstructor = ""
    @Published var newCourseColor = "#122C4A"
    @Published var newCourseSemester = "Fall"
    @Published var newCourseYear = Calendar.current.component(.year, from: Date())
    @Published var newCourseAssignmentsWeight = 0.4
    @Published var newCourseExamsWeight = 0.3
    @Published var newCourseProjectsWeight = 0.2
    @Published var newCourseParticipationWeight = 0.1
    @Published var newCourseOtherWeight = 0.0
    @Published var newCourseTargetGrade: Double?
    
    // MARK: - Dependencies
    
    private let repository: CourseRepositoryProtocol
    
    // MARK: - Initialization
    
    init(repository: CourseRepositoryProtocol? = nil) {
        self.repository = repository ?? FirestoreCourseRepository()
        
        Task {
            await loadCourses()
        }
    }
    
    // MARK: - Public Methods
    
    func loadCourses() async {
        isLoading = true
        errorMessage = nil
        
        do {
            courses = try await repository.getAllCourses()
            activeCourses = try await repository.getActiveCourses()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func createCourse() async {
        guard !newCourseName.isEmpty && !newCourseCode.isEmpty else {
            errorMessage = "Course name and code are required"
            return
        }
        
        let gradeWeight = GradeWeight(
            assignments: newCourseAssignmentsWeight,
            exams: newCourseExamsWeight,
            projects: newCourseProjectsWeight,
            participation: newCourseParticipationWeight,
            other: newCourseOtherWeight
        )
        
        guard gradeWeight.isValid else {
            errorMessage = "Grade weights must total 100%"
            return
        }
        
        let course = Course(
            id: UUID().uuidString,
            name: newCourseName,
            code: newCourseCode,
            credits: newCourseCredits,
            instructor: newCourseInstructor,
            color: newCourseColor,
            semester: newCourseSemester,
            year: newCourseYear,
            gradeWeight: gradeWeight,
            currentGrade: nil,
            targetGrade: newCourseTargetGrade,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        do {
            try await repository.saveCourse(course)
            await clearForm()
            showingCreateCourse = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateCourse(_ course: Course) async {
        do {
            try await repository.updateCourse(course)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteCourse(_ course: Course) async {
        do {
            try await repository.deleteCourse(course.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func clearForm() async {
        newCourseName = ""
        newCourseCode = ""
        newCourseCredits = 3
        newCourseInstructor = ""
        newCourseColor = "#122C4A"
        newCourseSemester = "Fall"
        newCourseYear = Calendar.current.component(.year, from: Date())
        newCourseAssignmentsWeight = 0.4
        newCourseExamsWeight = 0.3
        newCourseProjectsWeight = 0.2
        newCourseParticipationWeight = 0.1
        newCourseOtherWeight = 0.0
        newCourseTargetGrade = nil
        errorMessage = nil
    }
    
    func refreshCourses() async {
        await loadCourses()
    }
}