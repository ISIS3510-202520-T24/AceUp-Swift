//
//  DataMigrationService.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 7/10/25.
//

import Foundation
import CoreData
import SwiftUI
import FirebaseAuth

/// Handles data migrations and app version upgrades
/// Ensures smooth transitions between app versions and data schema changes
@MainActor
class DataMigrationService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DataMigrationService()
    
    // MARK: - Published Properties
    
    @Published var isMigrating = false
    @Published var migrationProgress: Double = 0.0
    @Published var migrationStatus: String = ""
    
    // MARK: - Private Properties
    
    private let persistenceController = PersistenceController.shared
    private let userPreferences = UserPreferencesManager.shared
    
    // MARK: - Version Constants
    
    private struct AppVersions {
        static let v1_0 = "1.0"
        static let v1_1 = "1.1"
        static let v1_2 = "1.2"
        // Add new versions as they're released
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Check if migration is needed and perform it
    func checkAndPerformMigration() async {
        let currentVersion = userPreferences.currentAppVersion
        let lastVersion = userPreferences.lastAppVersion
        
        // If this is the first launch or app was updated
        if userPreferences.isFirstLaunch || userPreferences.wasAppUpdated {
            await performMigration(from: lastVersion, to: currentVersion)
            userPreferences.updateAppVersion()
        }
    }
    
    /// Perform migration from one version to another
    private func performMigration(from oldVersion: String?, to newVersion: String) async {
        guard !isMigrating else { return }
        
        isMigrating = true
        migrationProgress = 0.0
        migrationStatus = "Preparing migration..."
        
        do {
            // Determine migration path
            let migrations = getMigrationPath(from: oldVersion, to: newVersion)
            let totalSteps = Double(migrations.count)
            
            for (index, migration) in migrations.enumerated() {
                migrationStatus = "Migrating to \(migration.targetVersion)..."
                
                try await performSpecificMigration(migration)
                
                migrationProgress = Double(index + 1) / totalSteps
                
                // Small delay to show progress
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            migrationStatus = "Migration completed successfully"
            
            // Track migration completion
            AppAnalytics.shared.track("migration_completed", props: [
                "from_version": oldVersion ?? "new_install",
                "to_version": newVersion,
                "migration_count": migrations.count
            ])
            
        } catch {
            migrationStatus = "Migration failed: \(error.localizedDescription)"
            print("Migration failed: \(error)")
            
            // Track migration failure
            AppAnalytics.shared.track("migration_failed", props: [
                "from_version": oldVersion ?? "new_install",
                "to_version": newVersion,
                "error": error.localizedDescription
            ])
        }
        
        isMigrating = false
        
        // Reset status after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if !self.isMigrating {
                self.migrationStatus = ""
                self.migrationProgress = 0.0
            }
        }
    }
    
    // MARK: - Migration Path Planning
    
    private func getMigrationPath(from oldVersion: String?, to newVersion: String) -> [Migration] {
        var migrations: [Migration] = []
        
        // First launch - setup initial data
        if oldVersion == nil {
            migrations.append(Migration(
                targetVersion: newVersion,
                type: .initialSetup,
                description: "Setting up initial data"
            ))
            return migrations
        }
        
        // Version-specific migrations
        if compareVersions(oldVersion!, newVersion) < 0 {
            // Add migrations based on version jumps
            
            if compareVersions(oldVersion!, AppVersions.v1_1) < 0 && compareVersions(AppVersions.v1_1, newVersion) <= 0 {
                migrations.append(Migration(
                    targetVersion: AppVersions.v1_1,
                    type: .dataModelUpdate,
                    description: "Updating data model for enhanced features"
                ))
            }
            
            if compareVersions(oldVersion!, AppVersions.v1_2) < 0 && compareVersions(AppVersions.v1_2, newVersion) <= 0 {
                migrations.append(Migration(
                    targetVersion: AppVersions.v1_2,
                    type: .featureAddition,
                    description: "Adding new feature data structures"
                ))
            }
            
            // If no specific migrations are needed, add a general update
            if migrations.isEmpty {
                migrations.append(Migration(
                    targetVersion: newVersion,
                    type: .generalUpdate,
                    description: "Updating app configuration"
                ))
            }
        }
        
        return migrations
    }
    
    // MARK: - Specific Migrations
    
    private func performSpecificMigration(_ migration: Migration) async throws {
        switch migration.type {
        case .initialSetup:
            try await performInitialSetup()
            
        case .dataModelUpdate:
            try await performDataModelUpdate(to: migration.targetVersion)
            
        case .featureAddition:
            try await performFeatureAddition(to: migration.targetVersion)
            
        case .generalUpdate:
            try await performGeneralUpdate(to: migration.targetVersion)
            
        case .bugFix:
            try await performBugFixMigration(to: migration.targetVersion)
        }
    }
    
    private func performInitialSetup() async throws {
        // Set up default preferences
        userPreferences.completeFirstLaunch()
        
        // Create sample data if needed (for demo purposes)
        if ProcessInfo.processInfo.environment["DEMO_MODE"] == "true" {
            await createSampleData()
        }
        
        // Initialize analytics
        if let currentUser = FirebaseAuth.Auth.auth().currentUser {
            AppAnalytics.shared.identify(userId: currentUser.uid)
        }
    }
    
    private func performDataModelUpdate(to version: String) async throws {
        // Handle Core Data model changes
        // This is where you'd handle complex data transformations
        
        switch version {
        case AppVersions.v1_1:
            // Example: Add new fields to existing entities
            try await migrateToV1_1()
            
        case AppVersions.v1_2:
            // Example: Restructure data for new features
            try await migrateToV1_2()
            
        default:
            break
        }
    }
    
    private func performFeatureAddition(to version: String) async throws {
        // Add new features and their associated data
        
        switch version {
        case AppVersions.v1_1:
            // Enable new features introduced in v1.1
            userPreferences.enableSmartSuggestions = true
            
        case AppVersions.v1_2:
            // Enable new features introduced in v1.2
            userPreferences.workloadAnalysisEnabled = true
            
        default:
            break
        }
    }
    
    private func performGeneralUpdate(to version: String) async throws {
        // General app updates that don't require specific data changes
        
        // Update default settings if needed
        // Refresh cached data
        await DataSynchronizationManager.shared.performFullSync()
    }
    
    private func performBugFixMigration(to version: String) async throws {
        // Handle data inconsistencies or fixes
        
        // Clean up any corrupted data
        await cleanupCorruptedData()
        
        // Refresh caches
        await OfflineManager.shared.prepareForOffline()
    }
    
    // MARK: - Version-Specific Migrations
    
    private func migrateToV1_1() async throws {
        // Example migration for v1.1
        // Add courseColor field to assignments that don't have it
        
        let context = persistenceController.viewContext
        let request: NSFetchRequest<AssignmentEntity> = AssignmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "courseColor == nil OR courseColor == %@", "")
        
        do {
            let assignments = try context.fetch(request)
            for assignment in assignments {
                if assignment.courseColor?.isEmpty ?? true {
                    assignment.courseColor = userPreferences.defaultCourseColor
                }
            }
            
            try context.save()
        } catch {
            throw MigrationError.dataUpdateFailed(error)
        }
    }
    
    private func migrateToV1_2() async throws {
        // Example migration for v1.2
        // Update assignment priorities based on new algorithm
        
        let context = persistenceController.viewContext
        let request: NSFetchRequest<AssignmentEntity> = AssignmentEntity.fetchRequest()
        
        do {
            let assignments = try context.fetch(request)
            for assignment in assignments {
                // Recalculate priority based on new logic
                let assignmentModel = assignment.toAssignment()
                let newPriority = calculateUpdatedPriority(for: assignmentModel)
                assignment.priority = newPriority.rawValue
            }
            
            try context.save()
        } catch {
            throw MigrationError.dataUpdateFailed(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSampleData() async {
        // Create sample assignments for demo
        let sampleAssignments = [
            Assignment(
                title: "Welcome to AceUp!",
                description: "This is a sample assignment to get you started.",
                courseId: "demo_course",
                courseName: "Demo Course",
                dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                priority: .medium
            )
        ]
        
        for assignment in sampleAssignments {
            do {
                let provider = DataSynchronizationManager.shared.getAssignmentProvider()
                try await provider.save(assignment)
            } catch {
                print("Failed to create sample assignment: \(error)")
            }
        }
    }
    
    private func cleanupCorruptedData() async {
        // Clean up any data inconsistencies
        let context = persistenceController.viewContext
        
        // Remove orphaned subtasks
        let orphanedSubtasks = NSFetchRequest<SubtaskEntity>(entityName: "SubtaskEntity")
        orphanedSubtasks.predicate = NSPredicate(format: "assignment == nil")
        
        do {
            let subtasks = try context.fetch(orphanedSubtasks)
            for subtask in subtasks {
                context.delete(subtask)
            }
            
            try context.save()
        } catch {
            print("Failed to clean up corrupted data: \(error)")
        }
    }
    
    private func calculateUpdatedPriority(for assignment: Assignment) -> Priority {
        // Updated priority calculation logic
        let daysUntilDue = assignment.daysUntilDue
        let weight = assignment.weight
        
        if daysUntilDue <= 1 || weight >= 0.3 {
            return .critical
        } else if daysUntilDue <= 3 || weight >= 0.2 {
            return .high
        } else if daysUntilDue <= 7 || weight >= 0.1 {
            return .medium
        } else {
            return .low
        }
    }
    
    private func compareVersions(_ version1: String, _ version2: String) -> Int {
        let v1Components = version1.components(separatedBy: ".").compactMap { Int($0) }
        let v2Components = version2.components(separatedBy: ".").compactMap { Int($0) }
        
        let maxCount = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxCount {
            let v1Value = i < v1Components.count ? v1Components[i] : 0
            let v2Value = i < v2Components.count ? v2Components[i] : 0
            
            if v1Value < v2Value {
                return -1
            } else if v1Value > v2Value {
                return 1
            }
        }
        
        return 0
    }
}

// MARK: - Supporting Types

struct Migration {
    let targetVersion: String
    let type: MigrationType
    let description: String
}

enum MigrationType {
    case initialSetup
    case dataModelUpdate
    case featureAddition
    case generalUpdate
    case bugFix
}

enum MigrationError: LocalizedError {
    case dataUpdateFailed(Error)
    case invalidVersion
    case migrationInProgress
    
    var errorDescription: String? {
        switch self {
        case .dataUpdateFailed(let error):
            return "Data update failed: \(error.localizedDescription)"
        case .invalidVersion:
            return "Invalid version specified for migration"
        case .migrationInProgress:
            return "Migration is already in progress"
        }
    }
}

// MARK: - Migration View

struct MigrationView: View {
    @StateObject private var migrationService = DataMigrationService.shared
    
    var body: some View {
        VStack(spacing: 24) {
            Image("Blue")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
            
            Text("AceUp")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            VStack(spacing: 12) {
                Text("Updating App...")
                    .font(.headline)
                    .foregroundColor(UI.navy)
                
                if !migrationService.migrationStatus.isEmpty {
                    Text(migrationService.migrationStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                ProgressView(value: migrationService.migrationProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: UI.primary))
                    .frame(maxWidth: 200)
            }
            
            Text("Please wait while we update your data...")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UI.bg)
    }
}

#Preview {
    MigrationView()
}
