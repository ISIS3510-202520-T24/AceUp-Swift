//
//  AceUP_SwiftApp.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 19/09/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseCore
import FirebaseAnalytics

@main
struct AceUP_SwiftApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared

    // Configuración de Firebase + sincronización de GA4 user_id
    init() {
        FirebaseConfig.shared.configure()
        NotificationService.requestAuthorization()

        // Verifica configuración
        if !FirebaseConfig.shared.verifyConfiguration() {
            print("Firebase configuration verification failed")
        }

        // Si ya hay usuario al abrir, sincroniza user_id de GA4
        if let currentUser = Auth.auth().currentUser {
            FirebaseAnalytics.Analytics.setUserID(currentUser.uid)
        } else {
            FirebaseAnalytics.Analytics.setUserID(nil)
        }

        // Mantener GA4 user_id sincronizado cuando cambie el estado de Auth
        _ = Auth.auth().addStateDidChangeListener { _, user in
            if let u = user {
                FirebaseAnalytics.Analytics.setUserID(u.uid)
            } else {
                FirebaseAnalytics.Analytics.setUserID(nil)
            }
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
        print("Deep link received: \(url)")

        // Handle aceup://join/inviteCode URLs
        if url.scheme == "aceup" && url.host == "join" {
            let inviteCode = String(url.path.dropFirst()) // Remove leading "/"
            if !inviteCode.isEmpty {
                print("Processing group invitation with code: \(inviteCode)")
                // Post notification to handle the invite code
                NotificationCenter.default.post(
                    name: NSNotification.Name("HandleGroupInviteCode"),
                    object: inviteCode
                )
            }
        }
    }
}


// MARK: - Root Content

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var isInitializing = true
    @State private var needsMigration = false
    @StateObject private var migrationService = DataMigrationService.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var authService = AuthService()

    #if DEBUG
    @State private var showLab = false
    #endif

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

                    #if DEBUG
                    Button("Abrir Analytics Lab (DEBUG)") {
                        showLab = true
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    #endif

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
                    // Por si el login ocurrió en caliente, refuerza GA4 user_id
                    if let uid = Auth.auth().currentUser?.uid {
                        FirebaseAnalytics.Analytics.setUserID(uid)
                    }
                })
            }
        }
        .onChange(of: migrationService.isMigrating) { _, isMigrating in
            if !isMigrating && needsMigration {
                needsMigration = false
            }
        }
        #if DEBUG
        .sheet(isPresented: $showLab) {
            NavigationView { AnalyticsDebugView() }
        }
        #endif
    }

    @MainActor
    private func handleLogout() async {
        do {
            try authService.signOut()

            // Limpia GA4 user_id en logout
            FirebaseAnalytics.Analytics.setUserID(nil)

            // Clear any cached data
            await offlineManager.clearOfflineData()

            // Update UI state
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoggedIn = false
            }

        } catch {
            // Incluso si falla el signOut de Firebase, limpia el estado de UI
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoggedIn = false
            }
            // Asegura limpieza de GA4 user_id
            FirebaseAnalytics.Analytics.setUserID(nil)
        }
    }

    private func initializeApp() async {
        // Monitor memory warnings during initialization
        let memoryTask = Task {
            let notifications = NotificationCenter.default.notifications(named: UIApplication.didReceiveMemoryWarningNotification)
            for await _ in notifications {
                // Handle memory warnings if needed
            }
        }

        defer { memoryTask.cancel() }

        do {
            // Check for existing authentication with timeout
            let authTask = Task {
                return Auth.auth().currentUser
            }

            let currentUser = try await withTimeout(seconds: 10) {
                await authTask.value
            }

            if let user = currentUser {
                await MainActor.run {
                    isLoggedIn = true
                }
                // Sincroniza GA4 user_id
                FirebaseAnalytics.Analytics.setUserID(user.uid)
            }

            // Check and perform migration if needed
            await migrationService.checkAndPerformMigration()
            await MainActor.run {
                needsMigration = migrationService.isMigrating
            }

            // Prepare offline data if user is logged in
            if isLoggedIn && offlineManager.isOnline {
                await offlineManager.prepareForOffline()
            }

            // Start background sync setup
            DataSynchronizationManager.shared.setupBackgroundSync()

        } catch {
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
