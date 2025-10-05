//
//  ContentView.swift
//  Ember
//
//  Root switcher between Auth and Map.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MapView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: auth.isAuthenticated)
    }
}
