//
//  EmberApp.swift
//  Ember
//
//  Created by Edward Liang on 2025-10-04.
//

import SwiftUI

@main
struct EmberApp: App {
    @StateObject private var auth = AuthStore()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
    }
}
