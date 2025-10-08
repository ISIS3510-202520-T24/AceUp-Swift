//
//  OfflineManager.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import Foundation
import Network
import Combine

// MARK: - Offline Operation Types
enum OfflineOperationType: String, CaseIterable, Codable {
    case create = "CREATE"
    case update = "UPDATE"
    case delete = "DELETE"
}

enum DataType: String, CaseIterable, Codable {
    case assignment = "Assignment"
    case course = "Course"
    case teacher = "Teacher"
    case calendarEvent = "CalendarEvent"
    case userAvailability = "UserAvailability"
    case workloadAnalysis = "WorkloadAnalysis"
    case sharedCalendar = "SharedCalendar"
}

// MARK: - Offline Operation Model
struct OfflineOperation: Codable, Identifiable {
    let id: String
    let type: OfflineOperationType
    let dataType: DataType
    let data: Data
    let timestamp: Date
    let userId: String
    var retryCount: Int
    var lastAttempt: Date?
    
    init(type: OfflineOperationType, dataType: DataType, data: Data, userId: String) {
        self.id = UUID().uuidString
        self.type = type
        self.dataType = dataType
        self.data = data
        self.timestamp = Date()
        self.userId = userId
        self.retryCount = 0
        self.lastAttempt = nil
    }
}

// MARK: - Sync Status
enum SyncStatus {
    case synced
    case pending
    case syncing
    case failed
    case offline
}

// MARK: - Network Monitor
class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var connectionType: NWInterface.InterfaceType?
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Offline Manager
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()
    
    @Published var syncStatus: SyncStatus = .synced
    @Published var pendingOperationsCount: Int = 0
    @Published var lastSyncDate: Date?
    
    private let networkMonitor = NetworkMonitor()
    private var cancellables = Set<AnyCancellable>()
    private let syncQueue = DispatchQueue(label: "OfflineSync", qos: .utility)
    private var syncTimer: Timer?
    
    // Local storage keys
    private let pendingOperationsKey = "PendingOfflineOperations"
    private let lastSyncKey = "LastSyncDate"
    private let offlineDataKey = "OfflineData_"
    
    private init() {
        setupNetworkMonitoring()
        let operations = loadPendingOperations()
        pendingOperationsCount = operations.count
        lastSyncDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        startPeriodicSync()
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                if isConnected {
                    self?.syncStatus = .pending
                    self?.processPendingOperations()
                } else {
                    self?.syncStatus = .offline
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Offline Data Storage
    func storeOfflineData<T: Codable>(_ data: [T], for dataType: DataType, userId: String) {
        let key = offlineDataKey + dataType.rawValue + "_" + userId
        
        do {
            let encodedData = try JSONEncoder().encode(data)
            UserDefaults.standard.set(encodedData, forKey: key)
        } catch {
            print("Failed to store offline data: \(error)")
        }
    }
    
    func loadOfflineData<T: Codable>(_ type: T.Type, for dataType: DataType, userId: String) -> [T] {
        let key = offlineDataKey + dataType.rawValue + "_" + userId
        
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            print("Failed to load offline data: \(error)")
            return []
        }
    }
    
    // MARK: - Operation Queue Management
    func queueOperation<T: Codable>(
        _ operation: OfflineOperationType,
        data: T,
        dataType: DataType,
        userId: String
    ) {
        do {
            let encodedData = try JSONEncoder().encode(data)
            let offlineOperation = OfflineOperation(
                type: operation,
                dataType: dataType,
                data: encodedData,
                userId: userId
            )
            
            addPendingOperation(offlineOperation)
            
            // Try immediate sync if online
            if networkMonitor.isConnected {
                processPendingOperations()
            }
        } catch {
            print("Failed to encode operation data: \(error)")
        }
    }
    
    private func addPendingOperation(_ operation: OfflineOperation) {
        var operations = loadPendingOperations()
        operations.append(operation)
        savePendingOperations(operations)
        
        DispatchQueue.main.async {
            self.pendingOperationsCount = operations.count
        }
    }
    
    private func loadPendingOperations() -> [OfflineOperation] {
        guard let data = UserDefaults.standard.data(forKey: pendingOperationsKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([OfflineOperation].self, from: data)
        } catch {
            print("Failed to load pending operations: \(error)")
            return []
        }
    }
    
    private func savePendingOperations(_ operations: [OfflineOperation]) {
        do {
            let data = try JSONEncoder().encode(operations)
            UserDefaults.standard.set(data, forKey: pendingOperationsKey)
        } catch {
            print("Failed to save pending operations: \(error)")
        }
    }
    
    // MARK: - Sync Processing
    private func processPendingOperations() {
        guard networkMonitor.isConnected else { return }
        
        syncQueue.async { [weak self] in
            self?.performSync()
        }
    }
    
    private func performSync() {
        DispatchQueue.main.async {
            self.syncStatus = .syncing
        }
        
        let operations = loadPendingOperations()
        var successfulOperations: [String] = []
        var failedOperations: [OfflineOperation] = []
        
        let group = DispatchGroup()
        
        for operation in operations {
            group.enter()
            
            processSingleOperation(operation) { success in
                if success {
                    successfulOperations.append(operation.id)
                } else {
                    var failedOp = operation
                    failedOp.retryCount += 1
                    failedOp.lastAttempt = Date()
                    
                    // Retry up to 3 times
                    if failedOp.retryCount < 3 {
                        failedOperations.append(failedOp)
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            // Remove successful operations
            let remainingOperations = operations.filter { op in
                !successfulOperations.contains(op.id)
            }
            
            // Add failed operations back to queue
            let finalOperations = remainingOperations + failedOperations
            self?.savePendingOperations(finalOperations)
            self?.pendingOperationsCount = finalOperations.count
            
            // Update sync status
            if finalOperations.isEmpty {
                self?.syncStatus = .synced
                self?.lastSyncDate = Date()
                UserDefaults.standard.set(Date(), forKey: self?.lastSyncKey ?? "LastSyncDate")
            } else {
                self?.syncStatus = .failed
            }
        }
    }
    
    private func processSingleOperation(_ operation: OfflineOperation, completion: @escaping (Bool) -> Void) {
        // This would integrate with your existing Firebase repositories
        // For now, simulate the process
        
        switch operation.dataType {
        case .assignment:
            processAssignmentOperation(operation, completion: completion)
        case .course:
            processCourseOperation(operation, completion: completion)
        case .teacher:
            processTeacherOperation(operation, completion: completion)
        case .calendarEvent:
            processCalendarEventOperation(operation, completion: completion)
        case .userAvailability:
            processUserAvailabilityOperation(operation, completion: completion)
        case .workloadAnalysis:
            processWorkloadAnalysisOperation(operation, completion: completion)
        case .sharedCalendar:
            processSharedCalendarOperation(operation, completion: completion)
        }
    }
    
    // MARK: - Individual Operation Processors
    private func processAssignmentOperation(_ operation: OfflineOperation, completion: @escaping (Bool) -> Void) {
        // Simulate async Firebase operation
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            // In real implementation, this would call the appropriate Firebase repository method
            completion(true)
        }
    }
    
    private func processCourseOperation(_ operation: OfflineOperation, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }
    
    private func processTeacherOperation(_ operation: OfflineOperation, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }
    
    private func processCalendarEventOperation(_ operation: OfflineOperation, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }
    
    private func processUserAvailabilityOperation(_ operation: OfflineOperation, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }
    
    private func processWorkloadAnalysisOperation(_ operation: OfflineOperation, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }
    
    private func processSharedCalendarOperation(_ operation: OfflineOperation, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }
    
    // MARK: - Manual Sync
    func forceSyncNow() {
        guard networkMonitor.isConnected else { return }
        processPendingOperations()
    }
    
    // MARK: - Periodic Sync
    private func startPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            if self?.networkMonitor.isConnected == true && self?.pendingOperationsCount ?? 0 > 0 {
                self?.processPendingOperations()
            }
        }
    }
    
    // MARK: - Clear Operations
    func clearAllPendingOperations() {
        UserDefaults.standard.removeObject(forKey: pendingOperationsKey)
        pendingOperationsCount = 0
    }
    
    // MARK: - Data Conflict Resolution
    func resolveConflict<T: Codable>(localData: T, serverData: T, lastModified: Date) -> T {
        // Simple last-write-wins strategy
        // In a more sophisticated app, you might want custom conflict resolution
        return serverData // Prefer server data
    }
}

// MARK: - Offline-Aware Protocol
protocol OfflineCapable {
    var isOfflineMode: Bool { get }
    func enableOfflineMode()
    func syncWhenOnline()
}

// MARK: - Extensions
extension OfflineManager {
    var isOnline: Bool {
        networkMonitor.isConnected
    }
    
    var connectionDescription: String {
        guard networkMonitor.isConnected else { return "Offline" }
        
        switch networkMonitor.connectionType {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        case .wiredEthernet:
            return "Ethernet"
        default:
            return "Connected"
        }
    }
}