//
//  AppDelegate.swift
//  AceUp-Swift
//
//  Created by Ana M. Sánchez on 19/09/25.
//

import UIKit
import SwiftUI

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
       
        configureAppearance()
        
        return true
    }
    
    
    private func configureAppearance() {

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.07, green: 0.17, blue: 0.29, alpha: 1.0) // UI.navy
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        

        UINavigationBar.appearance().tintColor = UIColor(red: 0.31, green: 0.89, blue: 0.76, alpha: 1.0) // UI.primary
        

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1.0) // UI.neutralLight
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        

        UITabBar.appearance().tintColor = UIColor(red: 0.31, green: 0.89, blue: 0.76, alpha: 1.0) // UI.primary
        UITabBar.appearance().unselectedItemTintColor = UIColor(red: 0.55, green: 0.53, blue: 0.50, alpha: 1.0) // UI.muted
    }
}

