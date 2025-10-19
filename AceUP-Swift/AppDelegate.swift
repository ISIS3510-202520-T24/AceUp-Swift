//
//  AppDelegate.swift
//  AceUp-Swift
//
//  Created by Ana M. Sánchez on 19/09/25.
//

import UIKit
import SwiftUI
import FirebaseCore
import FirebaseAnalytics
import FirebaseAuth

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                       didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        // Configure Firebase using the FirebaseConfig class
        FirebaseConfig.shared.configure()
        
        // Verify configuration
        if FirebaseConfig.shared.verifyConfiguration() {
            print("Firebase configured successfully in AppDelegate")
        } else {
            print("Firebase configuration failed in AppDelegate")
        }
        
        return true
      }
    
    
    private func configureAppearance() {

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.07, green: 0.17, blue: 0.29, alpha: 1.0) 
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        

        UINavigationBar.appearance().tintColor = UIColor(red: 0.31, green: 0.89, blue: 0.76, alpha: 1.0) 
        

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1.0) 
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        

        UITabBar.appearance().tintColor = UIColor(red: 0.31, green: 0.89, blue: 0.76, alpha: 1.0) 
        UITabBar.appearance().unselectedItemTintColor = UIColor(red: 0.55, green: 0.53, blue: 0.50, alpha: 1.0) 
    }
}

