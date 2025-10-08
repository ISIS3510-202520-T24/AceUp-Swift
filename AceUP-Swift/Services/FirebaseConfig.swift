//
//  FirebaseConfig.swift
//  AceUP-Swift
//
//  Created for secure Firebase configuration
//

import Foundation
import Firebase

class FirebaseConfig {
    static let shared = FirebaseConfig()
    
    private init() {}
    
    func configure() {
        // Check if Firebase is already configured
        if FirebaseApp.app() != nil {
            print("Firebase already configured, skipping")
            return
        }
        
        do {
            if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
               FileManager.default.fileExists(atPath: path) {
                FirebaseApp.configure()
                print("Firebase configured with plist file")
                return
            }
            
            configureProgrammatically()
            
        } catch {
            print("🔥 Firebase configuration error: \(error)")
            // Attempt fallback configuration
            configureFallback()
        }
    }
    
    private func configureProgrammatically() {
        guard let filePath = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: filePath) else {
            print("Config.plist not found - using fallback configuration")
            configureFallback()
            return
        }
        
        guard let apiKey = config["FIREBASE_API_KEY"] as? String,
              let projectId = config["FIREBASE_PROJECT_ID"] as? String,
              let bundleId = config["BUNDLE_ID"] as? String,
              let gcmSenderId = config["GCM_SENDER_ID"] as? String,
              let googleAppId = config["GOOGLE_APP_ID"] as? String else {
            print("Missing required Firebase configuration values")
            configureFallback()
            return
        }
        
        let options = FirebaseOptions(googleAppID: googleAppId, gcmSenderID: gcmSenderId)
        options.apiKey = apiKey
        options.projectID = projectId
        options.bundleID = bundleId
        
        if let storageBucket = config["STORAGE_BUCKET"] as? String, !storageBucket.isEmpty {
            options.storageBucket = storageBucket
        }
        
        FirebaseApp.configure(options: options)
        print("Firebase configured programmatically")
    }
    
    private func configureFallback() {
        print("Using fallback Firebase configuration - NOT recommended for production")
        
        // Use environment variable if available, otherwise use default for development
        let apiKey = ProcessInfo.processInfo.environment["FIREBASE_API_KEY"] ?? "AIzaSyC8example_default_key_for_development"
        
        if apiKey == "AIzaSyC8example_default_key_for_development" {
            print("⚠️ WARNING: Using default development Firebase API key. This should not be used in production.")
        }
        
        let options = FirebaseOptions(googleAppID: "1:372482326957:ios:afd7d180c1dc65986d2124", 
                                    gcmSenderID: "372482326957")
        options.apiKey = apiKey
        options.projectID = "aceup-app-123"
        options.bundleID = "prueba.AceUP-Swift"
        options.storageBucket = "aceup-app-123.firebasestorage.app"
        
        do {
            FirebaseApp.configure(options: options)
            print("Firebase configured with fallback options")
        } catch {
            print("🔥 Firebase configuration failed: \(error)")
            // Don't crash the app, just log the error
        }
    }
    
    /// Verify that Firebase is properly configured
    func verifyConfiguration() -> Bool {
        guard let app = FirebaseApp.app() else {
            print("Firebase app not configured")
            return false
        }
        
        let options = app.options
        
        print("Firebase configured successfully")
        print("Bundle ID: \(String(describing: options.bundleID))")
        print("Project ID: \(String(describing: options.projectID))")
        print("App ID: \(String(describing: options.googleAppID))")
        
        return true
    }
}