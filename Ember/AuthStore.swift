//
//  AuthStore.swift
//  Ember
//
//  Minimal fake-auth store for gating MapView behind a login.
//

import Foundation
import Combine

final class AuthStore: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var username: String? = nil

    private let tokenKey = "auth_token"
    private let userKey = "auth_user"

    init() {
        if let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty {
            self.isAuthenticated = true
            self.username = UserDefaults.standard.string(forKey: userKey)
        }
    }

    func login(username: String, password: String) -> Bool {
        // Fake credentials; adjust as needed
        let allowed: [String: String] = [
            "demo": "ember",
            "alice": "1234",
            "bob": "password"
        ]
        if allowed[username] == password {
            let token = "fake-token-\(UUID().uuidString)"
            UserDefaults.standard.set(token, forKey: tokenKey)
            UserDefaults.standard.set(username, forKey: userKey)
            self.username = username
            self.isAuthenticated = true
            return true
        }
        return false
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        self.username = nil
        self.isAuthenticated = false
    }
}
