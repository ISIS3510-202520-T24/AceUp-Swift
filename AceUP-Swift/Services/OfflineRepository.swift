//
//  OfflineRepository.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Type Aliases to resolve ambiguity
typealias AnalysisWorkloadBalance = WorkloadBalance

// MARK: - Offline Repository Base Protocol
protocol OfflineRepositoryProtocol: ObservableObject {
    associatedtype DataModel: Codable & Identifiable
    
    var dataType: DataType { get }
    var isOfflineMode: Bool { get set }
    var localData: [DataModel] { get set }
    var syncStatus: SyncStatus { get set }
    
    func enableOfflineMode()
    func syncWithFirebase() async throws
    func saveLocally(_ items: [DataModel])
    func loadFromLocal() -> [DataModel]
}

// MARK: - Base Offline Repository
class BaseOfflineRepository<T: Codable & Identifiable>: ObservableObject, OfflineCapable {
    @Published var isOfflineMode: Bool = false
    @Published var localData: [T] = []
    @Published var syncStatus: SyncStatus = .synced
    @Published var lastSyncDate: Date?
    
    private let offlineManager = OfflineManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    let dataType: DataType
    let userId: String
    
    init(dataType: DataType, userId: String = "currentUser") {
        self.dataType = dataType
        self.userId = userId
        
        setupOfflineMonitoring()
        loadFromLocal()
    }
    
    // MARK: - Offline Monitoring
    private func setupOfflineMonitoring() {
        offlineManager.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status
                
                if status == .offline {
                    self?.enableOfflineMode()
                } else if status == .synced {
                    self?.isOfflineMode = false
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Offline Mode Management
    func enableOfflineMode() {
        isOfflineMode = true
        loadFromLocal()
    }
    
    func syncWhenOnline() {
        if offlineManager.isOnline {
            Task {
                do {
                    try await syncWithFirebase()
                } catch {
                    print("Failed to sync with Firebase: \(error)")
                }
            }
        }
    }
    
    // MARK: - Local Storage
    func saveLocally(_ items: [T]) {
        localData = items
        offlineManager.storeOfflineData(items, for: dataType, userId: userId)
    }
    
    func loadFromLocal() {
        localData = offlineManager.loadOfflineData(T.self, for: dataType, userId: userId)
    }
    
    // MARK: - CRUD Operations with Offline Support
    func create(_ item: T) {
        // Add to local storage immediately
        localData.append(item)
        saveLocally(localData)
        
        // Queue for sync when online
        offlineManager.queueOperation(.create, data: item, dataType: dataType, userId: userId)
    }
    
    func update(_ item: T) {
        // Update local storage
        if let index = localData.firstIndex(where: { $0.id == item.id }) {
            localData[index] = item
            saveLocally(localData)
        }
        
        // Queue for sync when online
        offlineManager.queueOperation(.update, data: item, dataType: dataType, userId: userId)
    }
    
    func delete(_ item: T) {
        // Remove from local storage
        localData.removeAll { $0.id == item.id }
        saveLocally(localData)
        
        // Queue for sync when online
        offlineManager.queueOperation(.delete, data: item, dataType: dataType, userId: userId)
    }
    
    // MARK: - Firebase Sync (Override in subclasses)
    func syncWithFirebase() async throws {
        // Override in subclasses to implement Firebase-specific sync logic
        fatalError("Must override syncWithFirebase in subclass")
    }
    
    // MARK: - Conflict Resolution
    func resolveConflicts(_ localItems: [T], _ serverItems: [T]) -> [T] {
        // Simple merge strategy - prefer server data for conflicts
        var mergedItems: [T] = []
        
        // Add all server items
        mergedItems.append(contentsOf: serverItems)
        
        // Add local items that don't exist on server
        for localItem in localItems {
            if !serverItems.contains(where: { $0.id == localItem.id }) {
                mergedItems.append(localItem)
            }
        }
        
        return mergedItems
    }
    
    // MARK: - Utility Methods
    func refreshData() {
        if offlineManager.isOnline {
            Task {
                do {
                    try await syncWithFirebase()
                } catch {
                    print("Failed to refresh data: \(error)")
                }
            }
        } else {
            loadFromLocal()
        }
    }
    
    func clearLocalData() {
        localData.removeAll()
        saveLocally([])
    }
}

// MARK: - Offline Assignment Repository
class OfflineAssignmentRepository: BaseOfflineRepository<Assignment> {
    
    init() {
        super.init(dataType: .assignment)
    }
    
    override func syncWithFirebase() async throws {
        // Placeholder for Firebase sync implementation
        // This would integrate with Firebase when available
        lastSyncDate = Date()
    }
    
    // MARK: - Assignment-specific methods
    var assignments: [Assignment] {
        return localData
    }
    
    func addAssignment(_ assignment: Assignment) {
        create(assignment)
    }
    
    func updateAssignment(_ assignment: Assignment) {
        update(assignment)
    }
    
    func deleteAssignment(_ assignment: Assignment) {
        delete(assignment)
    }
}

// MARK: - Offline Calendar Events Repository
class OfflineCalendarEventsRepository: BaseOfflineRepository<CalendarEvent> {
    
    init() {
        super.init(dataType: .calendarEvent)
    }
    
    override func syncWithFirebase() async throws {
        // Placeholder for Firebase sync implementation
        lastSyncDate = Date()
    }
    
    var events: [CalendarEvent] {
        return localData
    }
    
    func addEvent(_ event: CalendarEvent) {
        create(event)
    }
    
    func updateEvent(_ event: CalendarEvent) {
        update(event)
    }
    
    func deleteEvent(_ event: CalendarEvent) {
        delete(event)
    }
}

// MARK: - Offline User Availability Repository
class OfflineUserAvailabilityRepository: BaseOfflineRepository<AvailabilitySlot> {
    
    init() {
        super.init(dataType: .userAvailability)
    }
    
    override func syncWithFirebase() async throws {
        // Placeholder for Firebase sync implementation
        lastSyncDate = Date()
    }
    
    var availabilitySlots: [AvailabilitySlot] {
        return localData
    }
    
    func addAvailabilitySlot(_ slot: AvailabilitySlot) {
        create(slot)
    }
    
    func updateAvailabilitySlot(_ slot: AvailabilitySlot) {
        update(slot)
    }
    
    func deleteAvailabilitySlot(_ slot: AvailabilitySlot) {
        delete(slot)
    }
}

// MARK: - Offline Workload Analysis Repository
class OfflineWorkloadAnalysisRepository: BaseOfflineRepository<WorkloadAnalysis> {
    private let assignmentRepository = OfflineAssignmentRepository()
    
    init() {
        super.init(dataType: .workloadAnalysis)
    }
    
    override func syncWithFirebase() async throws {
        // Placeholder for Firebase sync implementation
        lastSyncDate = Date()
    }
    
    var analyses: [WorkloadAnalysis] {
        return localData
    }
    
    func generateAnalysis() async throws -> WorkloadAnalysis {
        let assignments = assignmentRepository.assignments
        
        // Generate analysis locally
        let analysis = generateLocalAnalysis(assignments: assignments)
        create(analysis)
        return analysis
    }
    
    private func generateLocalAnalysis(assignments: [Assignment]) -> WorkloadAnalysis {
        // Local analysis generation logic
        let analysisId = UUID().uuidString
        let userId = self.userId
        let analysisDate = Date()
        
        // Calculate basic metrics
        let totalAssignments = assignments.count
        let calendar = Calendar.current
        let now = Date()
        let weekFromNow = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        
        let upcomingAssignments = assignments.filter { assignment in
            assignment.dueDate >= now && assignment.dueDate <= weekFromNow
        }
        
        let dailyWorkload = Dictionary(grouping: upcomingAssignments) { assignment in
            calendar.startOfDay(for: assignment.dueDate)
        }.mapValues { assignments in
            Double(assignments.count)
        }
        
        let averageDaily = dailyWorkload.values.reduce(0, +) / max(1, Double(dailyWorkload.count))
        
        let overloadDays = dailyWorkload.filter { $0.value > 3 }.map { $0.key }
        
        let workloadBalance: AnalysisWorkloadBalance
        if overloadDays.isEmpty && averageDaily <= 2 {
            workloadBalance = AnalysisWorkloadBalance.excellent
        } else if overloadDays.count <= 1 && averageDaily <= 3 {
            workloadBalance = AnalysisWorkloadBalance.good
        } else if overloadDays.count <= 2 && averageDaily <= 4 {
            workloadBalance = AnalysisWorkloadBalance.fair
        } else {
            workloadBalance = AnalysisWorkloadBalance.poor
        }
        
        let recommendations = generateLocalRecommendations(
            overloadDays: overloadDays,
            averageDaily: averageDaily,
            workloadBalance: workloadBalance
        )
        
        return WorkloadAnalysis(
            id: analysisId,
            userId: userId,
            analysisDate: analysisDate,
            totalAssignments: totalAssignments,
            averageDaily: averageDaily,
            workloadBalance: workloadBalance,
            overloadDays: overloadDays,
            lightDays: [], // Calculate light days (days with < 2 assignments)
            recommendations: recommendations,
            dailyWorkload: dailyWorkload,
            createdAt: analysisDate
        )
    }
    
    private func generateLocalRecommendations(
        overloadDays: [Date],
        averageDaily: Double,
        workloadBalance: AnalysisWorkloadBalance
    ) -> [String] {
        var recommendations: [String] = []
        
        if !overloadDays.isEmpty {
            recommendations.append("Consider redistributing assignments from overloaded days")
        }
        
        if averageDaily > 4 {
            recommendations.append("Your daily workload is high - consider breaking down large assignments")
        }
        
        if workloadBalance == AnalysisWorkloadBalance.poor {
            recommendations.append("Schedule dedicated study time for better workload management")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Great job maintaining a balanced workload!")
        }
        
        return recommendations
    }
}