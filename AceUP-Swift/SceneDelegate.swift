//
//  SceneDelegate.swift
//  AceUp-Swift
//
//  Created by Ángel Farfán Arcila on 19/09/25.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        if let window = windowScene.windows.first {
            window.backgroundColor = UIColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1.0) // UI.neutralLight
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        
    }

    func sceneWillResignActive(_ scene: UIScene) {
        
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
       
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        
    }
}

