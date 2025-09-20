//
//  ViewController.swift
//  AceUp-Swift
//
//  Created by Ana M. Sánchez on 19/09/25.
//

import UIKit
import SwiftUI

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1.0) // UI.neutralLight
        
        setupSwiftUIIntegration()
    }
    
    private func setupSwiftUIIntegration() {
       
    }
    
    
    func navigateToLogin() {
        let loginView = LoginView(onLoginSuccess: {
            self.navigateToMainApp()
        })
        let hostingController = UIHostingController(rootView: loginView)
        present(hostingController, animated: true)
    }
    
    func navigateToMainApp() {
        let mainAppView = SharedCalendarsView()
        let hostingController = UIHostingController(rootView: mainAppView)
        present(hostingController, animated: true)
    }
    
    static func aceUpNavyColor() -> UIColor {
        return UIColor(red: 0.07, green: 0.17, blue: 0.29, alpha: 1.0) // #122C4A
    }
    
    static func aceUpPrimaryColor() -> UIColor {
        return UIColor(red: 0.31, green: 0.89, blue: 0.76, alpha: 1.0) // #50E3C2
    }
    
    static func aceUpNeutralLightColor() -> UIColor {
        return UIColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1.0) // #F8F6F0
    }
}

