//
//  AceUP_SwiftApp.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 19/09/25.
//

import SwiftUI
import Firebase

@main
struct AceUP_SwiftApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    //Configuración de firebase 
    init(){
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView() 
        }
    }
}


struct ContentView: View {
    @State private var isLoggedIn = false
    
    var body: some View {
        if isLoggedIn {
            
            AppNavigationView(onLogout: {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isLoggedIn = false
                }
            })
        } else {

            LoginView(onLoginSuccess: {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isLoggedIn = true
                }
            })
        }
    }
}
