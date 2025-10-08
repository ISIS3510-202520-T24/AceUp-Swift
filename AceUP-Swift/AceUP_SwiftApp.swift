//
//  AceUP_SwiftApp.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 19/09/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

// Import Analytics (our custom implementation)

@main
struct AceUP_SwiftApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared
    
    //Configuración de firebase 
    init(){
        FirebaseConfig.shared.configure()
        
        // Initialize analytics with current user if logged in
        if let currentUser = Auth.auth().currentUser {
            Analytics.shared.identify(userId: currentUser.uid)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .environmentObject(UserPreferencesManager.shared)
        }
    }
}


struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var isInitializing = true
    @State private var needsMigration = false
    @StateObject private var migrationService = DataMigrationService.shared
    @StateObject private var offlineManager = OfflineManager.shared
    
    var body: some View {
        Group {
            if isInitializing {
                LoadingView()
                    .task {
                        await initializeApp()
                    }
            } else if needsMigration && migrationService.isMigrating {
                MigrationView()
            } else if isLoggedIn {
                VStack(spacing: 0) {
                    // Offline banner
                    OfflineBannerView()
                    
                    AppNavigationView(onLogout: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isLoggedIn = false
                        }
                    })
                }
            } else {
                LoginView(onLoginSuccess: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isLoggedIn = true
                    }
                })
            }
        }
        .onChange(of: migrationService.isMigrating) { _, isMigrating in
            if !isMigrating && needsMigration {
                needsMigration = false
            }
        }
    }
    
    private func initializeApp() async {
        // Check for existing authentication
        if Auth.auth().currentUser != nil {
            isLoggedIn = true
            
            // Initialize analytics for authenticated user
            Analytics.shared.identify(userId: Auth.auth().currentUser!.uid)
        }
        
        // Check and perform migration if needed
        await migrationService.checkAndPerformMigration()
        needsMigration = migrationService.isMigrating
        
        // Prepare offline data if user is logged in
        if isLoggedIn && offlineManager.isOnline {
            await offlineManager.prepareForOffline()
        }
        
        // Start background sync setup
        DataSynchronizationManager.shared.setupBackgroundSync()
        
        isInitializing = false
    }
}

// MARK: - Loading View

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image("Blue")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            
            Text("AceUp")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(UI.navy)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: UI.primary))
                .scaleEffect(1.2)
            
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UI.bg)
        .onAppear {
            isAnimating = true
        }
    }
}
