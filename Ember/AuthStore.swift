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
    @Published var email: String? = nil

    private let tokenKey = "auth_token"
    private let emailKey = "auth_email"

    init() {
        if let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty {
            self.isAuthenticated = true
            self.email = UserDefaults.standard.string(forKey: emailKey)
        }
    }

    func login(email: String, password: String) async throws -> Bool {
        let res = try await AuthAPI.login(email: email, password: password)
        // Persist token + email and mark session as authenticated
        UserDefaults.standard.set(res.token, forKey: tokenKey)
        UserDefaults.standard.set(email, forKey: emailKey)
        self.email = email
        self.isAuthenticated = true
        return true
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
        self.email = nil
        self.isAuthenticated = false
    }
}
