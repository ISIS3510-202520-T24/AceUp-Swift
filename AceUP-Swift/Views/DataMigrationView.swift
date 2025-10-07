//
//  DataMigrationView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 6/10/25.
//

import SwiftUI

struct DataMigrationView: View {
    @StateObject private var migrationService = DataMigrationService()
    @State private var showingClearAlert = false
    @State private var hasExistingData = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    if migrationService.isMigrating {
                        migrationProgressSection
                    } else {
                        actionButtonsSection
                    }
                    
                    if let errorMessage = migrationService.migrationError {
                        errorSection(errorMessage)
                    }
                    
                    if migrationService.migrationCompleted {
                        successSection
                    }
                    
                    informationSection
                }
                .padding()
            }
            .navigationTitle("Data Migration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            hasExistingData = await migrationService.hasExistingData()
        }
        .alert("Clear All Data", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                Task {
                    await migrationService.clearAllData()
                    hasExistingData = await migrationService.hasExistingData()
                }
            }
        } message: {
            Text("This will permanently delete all your courses and assignments. This action cannot be undone.")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 60))
                .foregroundColor(UI.primary)
            
            Text("Firestore Migration")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            Text("Migrate your academic data to Firestore for real-time sync and better performance")
                .font(.body)
                .foregroundColor(UI.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var migrationProgressSection: some View {
        VStack(spacing: 16) {
            Text(migrationService.migrationMessage)
                .font(.headline)
                .foregroundColor(UI.navy)
                .multilineTextAlignment(.center)
            
            ProgressView(value: migrationService.migrationProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: UI.primary))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            Text("\(Int(migrationService.migrationProgress * 100))% Complete")
                .font(.caption)
                .foregroundColor(UI.muted)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            if hasExistingData {
                existingDataCard
            }
            
            Button(action: {
                Task {
                    await migrationService.migrateAllData()
                    hasExistingData = await migrationService.hasExistingData()
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(hasExistingData ? "Add Sample Data" : "Create Sample Data")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(UI.primary)
                .cornerRadius(12)
            }
            .disabled(migrationService.isMigrating)
            
            if hasExistingData {
                Button(action: {
                    showingClearAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                        Text("Clear All Data")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .disabled(migrationService.isMigrating)
            }
        }
    }
    
    private var existingDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Text("Existing Data Found")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
            }
            
            Text("You already have courses and assignments in Firestore. You can add more sample data or clear everything to start fresh.")
                .font(.body)
                .foregroundColor(UI.muted)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func errorSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text("Migration Error")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            
            Text(message)
                .font(.body)
                .foregroundColor(UI.muted)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var successSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Text("Migration Successful!")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            
            Text("Your academic data has been successfully migrated to Firestore. You can now enjoy real-time sync across all your devices!")
                .font(.body)
                .foregroundColor(UI.muted)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What gets migrated:")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)
            
            VStack(alignment: .leading, spacing: 8) {
                migrationFeatureRow(
                    icon: "book.closed",
                    title: "Courses",
                    description: "All your course information including grades and weights"
                )
                
                migrationFeatureRow(
                    icon: "doc.text",
                    title: "Assignments",
                    description: "Tasks, due dates, priorities, and progress tracking"
                )
                
                migrationFeatureRow(
                    icon: "list.bullet",
                    title: "Subtasks",
                    description: "Detailed breakdown of assignment components"
                )
                
                migrationFeatureRow(
                    icon: "cloud.fill",
                    title: "Real-time Sync",
                    description: "Automatic synchronization across all devices"
                )
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func migrationFeatureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(UI.primary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(UI.muted)
            }
            
            Spacer()
        }
    }
}

#if DEBUG
struct DataMigrationView_Previews: PreviewProvider {
    static var previews: some View {
        DataMigrationView()
    }
}
#endif