//
//  OfflineRepository.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import Foundation
import FirebaseFirestore
import Combine

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
                await syncWithFirebase()
            }
        }
    }
    
    // MARK: - Local Storage
    private func saveLocally(_ items: [T]) {
        localData = items
        offlineManager.storeOfflineData(items, for: dataType, userId: userId)
    }
    
    private func loadFromLocal() {
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
                await syncWithFirebase()
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
    private let firebaseRepository = FirebaseAssignmentRepository()
    
    override init() {
        super.init(dataType: .assignment)
        setupFirebaseSync()
    }
    
    private func setupFirebaseSync() {
        // Monitor Firebase repository changes
        firebaseRepository.$assignments
            .receive(on: DispatchQueue.main)
            .sink { [weak self] firebaseAssignments in
                if !self?.isOfflineMode ?? false && self?.offlineManager.isOnline ?? false {
                    // Merge with local data and resolve conflicts
                    let merged = self?.resolveConflicts(self?.localData ?? [], firebaseAssignments) ?? firebaseAssignments
                    self?.localData = merged
                    self?.saveLocally(merged)
                }
            }
            .store(in: &cancellables)
    }
    
    override func syncWithFirebase() async throws {
        // Start Firebase listener
        firebaseRepository.startRealtimeListener()
        
        // Load assignments from Firebase
        try await firebaseRepository.loadAssignments()
        
        // Update local data with Firebase data
        await MainActor.run {
            let merged = resolveConflicts(localData, firebaseRepository.assignments)
            localData = merged
            saveLocally(merged)
            lastSyncDate = Date()
        }
    }
    
    // MARK: - Assignment-specific methods
    var assignments: [Assignment] {
        return localData
    }
    
    func addAssignment(_ assignment: Assignment) {
        create(assignment)
        
        // Also update Firebase repository if online
        if offlineManager.isOnline {
            Task {
                try await firebaseRepository.addAssignment(assignment)
            }
        }
    }
    
    func updateAssignment(_ assignment: Assignment) {
        update(assignment)
        
        if offlineManager.isOnline {
            Task {
                try await firebaseRepository.updateAssignment(assignment)
            }
        }
    }
    
    func deleteAssignment(_ assignment: Assignment) {
        delete(assignment)
        
        if offlineManager.isOnline {
            Task {
                try await firebaseRepository.deleteAssignment(assignment.id)
            }
        }
    }
}

// MARK: - Offline Calendar Events Repository
class OfflineCalendarEventsRepository: BaseOfflineRepository<CalendarEvent> {
    private let firebaseRepository = FirebaseCalendarEventsRepository()
    
    override init() {
        super.init(dataType: .calendarEvent)
        setupFirebaseSync()
    }
    
    private func setupFirebaseSync() {
        firebaseRepository.$events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] firebaseEvents in
                if !self?.isOfflineMode ?? false && self?.offlineManager.isOnline ?? false {
                    let merged = self?.resolveConflicts(self?.localData ?? [], firebaseEvents) ?? firebaseEvents
                    self?.localData = merged
                    self?.saveLocally(merged)
                }
            }
            .store(in: &cancellables)
    }
    
    override func syncWithFirebase() async throws {
        firebaseRepository.startRealtimeListener()
        try await firebaseRepository.loadEvents()
        
        await MainActor.run {
            let merged = resolveConflicts(localData, firebaseRepository.events)
            localData = merged
            saveLocally(merged)
            lastSyncDate = Date()
        }
    }
    
    var events: [CalendarEvent] {
        return localData
    }
    
    func addEvent(_ event: CalendarEvent) {
        create(event)
        
        if offlineManager.isOnline {
            Task {
                try await firebaseRepository.createEvent(event)
            }
        }
    }
    
    func updateEvent(_ event: CalendarEvent) {
        update(event)
        
        if offlineManager.isOnline {
            Task {
                try await firebaseRepository.updateEvent(event)
            }
        }
    }
    
    func deleteEvent(_ event: CalendarEvent) {
        delete(event)
        
        if offlineManager.isOnline {
            Task {
                try await firebaseRepository.deleteEvent(event.id)
            }
        }
    }
}

// MARK: - Offline User Availability Repository
class OfflineUserAvailabilityRepository: BaseOfflineRepository<AvailabilitySlot> {
    private let firebaseRepository = FirebaseUserAvailabilityRepository()
    
    override init() {
        super.init(dataType: .userAvailability)
        setupFirebaseSync()
    }
    
    private func setupFirebaseSync() {
        firebaseRepository.$availabilitySlots
            .receive(on: DispatchQueue.main)
            .sink { [weak self] firebaseSlots in
                if !self?.isOfflineMode ?? false && self?.offlineManager.isOnline ?? false {
                    let merged = self?.resolveConflicts(self?.localData ?? [], firebaseSlots) ?? firebaseSlots
                    self?.localData = merged
                    self?.saveLocally(merged)
                }
            }
            .store(in: &cancellables)
    }
    
    override func syncWithFirebase() async throws {
        firebaseRepository.startRealtimeListener()
        try await firebaseRepository.loadAvailability()
        
        await MainActor.run {
            let merged = resolveConflicts(localData, firebaseRepository.availabilitySlots)
            localData = merged
            saveLocally(merged)
            lastSyncDate = Date()
        }
    }
    
    var availabilitySlots: [AvailabilitySlot] {
        return localData
    }
    
    func addAvailabilitySlot(_ slot: AvailabilitySlot) {
        create(slot)
        
        if offlineManager.isOnline {
            Task {
                try await firebaseRepository.addAvailabilitySlot(slot)
            }
        }
    }
    
    func updateAvailabilitySlot(_ slot: AvailabilitySlot) {
        update(slot)
        
        if offlineManager.isOnline {
            Task {
                try await firebaseRepository.updateAvailabilitySlot(slot)
            }
        }
    }
    
    func deleteAvailabilitySlot(_ slot: AvailabilitySlot) {
        delete(slot)
        
        if offlineManager.isOnline {
            Task {
                try await firebaseRepository.deleteAvailabilitySlot(slot.id)
            }
        }
    }
}

// MARK: - Offline Workload Analysis Repository
class OfflineWorkloadAnalysisRepository: BaseOfflineRepository<WorkloadAnalysis> {
    private let firebaseRepository = FirebaseWorkloadAnalysisRepository()
    private let assignmentRepository = OfflineAssignmentRepository()
    
    override init() {
        super.init(dataType: .workloadAnalysis)
        setupFirebaseSync()
    }
    
    private func setupFirebaseSync() {
        firebaseRepository.$analyses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] firebaseAnalyses in
                if !self?.isOfflineMode ?? false && self?.offlineManager.isOnline ?? false {
                    let merged = self?.resolveConflicts(self?.localData ?? [], firebaseAnalyses) ?? firebaseAnalyses
                    self?.localData = merged
                    self?.saveLocally(merged)
                }
            }
            .store(in: &cancellables)
    }
    
    override func syncWithFirebase() async throws {
        firebaseRepository.startRealtimeListener()
        try await firebaseRepository.loadAnalysis()
        
        await MainActor.run {
            let merged = resolveConflicts(localData, firebaseRepository.analyses)
            localData = merged
            saveLocally(merged)
            lastSyncDate = Date()
        }
    }
    
    var analyses: [WorkloadAnalysis] {
        return localData
    }
    
    func generateAnalysis() async throws -> WorkloadAnalysis {
        let assignments = assignmentRepository.assignments
        
        if offlineManager.isOnline {
            // Generate analysis using Firebase
            let analysis = try await firebaseRepository.generateAnalysis(assignments: assignments)
            create(analysis)
            return analysis
        } else {
            // Generate analysis locally
            let analysis = generateLocalAnalysis(assignments: assignments)
            create(analysis)
            return analysis
        }
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
        
        let workloadBalance: WorkloadBalance
        if overloadDays.isEmpty && averageDaily <= 2 {
            workloadBalance = .excellent
        } else if overloadDays.count <= 1 && averageDaily <= 3 {
            workloadBalance = .good
        } else if overloadDays.count <= 2 && averageDaily <= 4 {
            workloadBalance = .fair
        } else {
            workloadBalance = .poor
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
            dailyWorkload: dailyWorkload,
            averageDaily: averageDaily,
            overloadDays: overloadDays,
            workloadBalance: workloadBalance,
            recommendations: recommendations
        )
    }
    
    private func generateLocalRecommendations(
        overloadDays: [Date],
        averageDaily: Double,
        workloadBalance: WorkloadBalance
    ) -> [String] {
        var recommendations: [String] = []
        
        if !overloadDays.isEmpty {
            recommendations.append("Consider redistributing assignments from overloaded days")
        }
        
        if averageDaily > 4 {
            recommendations.append("Your daily workload is high - consider breaking down large assignments")
        }
        
        if workloadBalance == .poor {
            recommendations.append("Schedule dedicated study time for better workload management")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Great job maintaining a balanced workload!")
        }
        
        return recommendations
    }
}