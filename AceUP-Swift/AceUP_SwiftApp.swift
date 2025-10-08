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
        
        // Verify Firebase configuration
        if !FirebaseConfig.shared.verifyConfiguration() {
            print("⚠️ Firebase configuration verification failed")
        }
        
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
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
        }
        .handlesExternalEvents(matching: ["aceup"])
    }
    
    // MARK: - Deep Link Handling
    private func handleDeepLink(url: URL) {
        print("📱 Deep link received: \(url)")
        
        // Handle aceup://join/inviteCode URLs
        if url.scheme == "aceup" && url.host == "join" {
            let inviteCode = String(url.path.dropFirst()) // Remove leading "/"
            if !inviteCode.isEmpty {
                print("🔗 Processing group invitation with code: \(inviteCode)")
                // Post notification to handle the invite code
                NotificationCenter.default.post(
                    name: NSNotification.Name("HandleGroupInviteCode"),
                    object: inviteCode
                )
            }
        }
    }
}


struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var isInitializing = true
    @State private var needsMigration = false
    @StateObject private var migrationService = DataMigrationService.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var authService = AuthService()
    
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
                        Task {
                            await handleLogout()
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
    
    @MainActor
    private func handleLogout() async {
        print("🔥 Starting logout process")
        
        do {
            try authService.signOut()
            print("🔥 Firebase sign-out successful")
            
            // Clear any cached data
            await offlineManager.clearOfflineData()
            print("🔥 Offline data cleared")
            
            // Update UI state
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoggedIn = false
            }
            print("🔥 Logout completed successfully")
            
        } catch {
            print("🔥 Logout failed with error: \(error)")
            // Even if Firebase signout fails, update UI state
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoggedIn = false
            }
        }
    }
    
    private func initializeApp() async {
        print("🔥 App: Starting app initialization")
        
        // Monitor memory warnings during initialization
        let memoryTask = Task {
            let notifications = NotificationCenter.default.notifications(named: UIApplication.didReceiveMemoryWarningNotification)
            
            for await _ in notifications {
                print("App: Memory warning during initialization")
            }
        }
        
        defer {
            memoryTask.cancel()
        }
        
        do {
            // Check for existing authentication with timeout
            let authTask = Task {
                return Auth.auth().currentUser
            }
            
            let currentUser = try await withTimeout(seconds: 10) {
                await authTask.value
            }
            
            if let user = currentUser {
                print("🔥 App: Found existing user: \(user.uid)")
                await MainActor.run {
                    isLoggedIn = true
                }
                
                // Initialize analytics for authenticated user
                Analytics.shared.identify(userId: user.uid)
            } else {
                print("App: No existing user found")
            }
            
            // Check and perform migration if needed
            print("App: Checking for data migration")
            await migrationService.checkAndPerformMigration()
            await MainActor.run {
                needsMigration = migrationService.isMigrating
            }
            
            // Prepare offline data if user is logged in
            if isLoggedIn && offlineManager.isOnline {
                print("🔥 App: Preparing offline data")
                await offlineManager.prepareForOffline()
            }
            
            // Start background sync setup
            DataSynchronizationManager.shared.setupBackgroundSync()
            
            print("App: Initialization completed successfully")
            
        } catch {
            print("App: Initialization failed with error: \(error)")
            // Continue with app launch even if some initialization fails
        }
        
        await MainActor.run {
            isInitializing = false
        }
    }
    
    // Timeout helper for initialization
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
        }
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
