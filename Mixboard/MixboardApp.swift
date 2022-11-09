//
//  MixboardApp.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        return true
    }
}

@main
struct MixboardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject var mashupVM = MashupViewModel()

    var body: some Scene {
        WindowGroup {
            ZStack {
                MashupView()
                    .blur(radius: mashupVM.loggedIn ? 0 : 64)
                    .environmentObject(mashupVM)
                
                if !mashupVM.loggedIn {
                    LoginView()
                        .environmentObject(mashupVM)
                        .animation(.spring(), value: mashupVM.loggedIn)
                        .transition(.move(edge: .bottom))
                }
            }
        }
    }
}
