//
//  Endpoints.swift
//  Ember
//
//  Typed wrappers around SimpleAPI for your REST endpoints.
//  Targets http://localhost:8080
//

import Foundation

// MARK: - Auth

enum AuthAPI {
    struct RegisterRequest: Encodable { let email: String; let password: String }
    struct LoginRequest: Encodable { let email: String; let password: String }
    struct LoginResponse: Decodable { let token: String }

    @discardableResult
    static func register(email: String, password: String) async throws -> Void {
        let _ : EmptyDecodable = try await SimpleAPI.post("/register", body: RegisterRequest(email: email, password: password))
    }

    static func login(email: String, password: String) async throws -> LoginResponse {
        return try await SimpleAPI.postOverrideGet("/auth/login", body: LoginRequest(email: email, password: password))
    }
}

// MARK: - Users

enum FriendsStatus: String, CaseIterable { case accepted, blocked, pending }

struct APIUser: Decodable, Identifiable {
    let id: Int
    let username: String
    let displayName: String?
}

enum UsersAPI {
    static func listUsers() async throws -> [APIUser] {
        try await SimpleAPI.get("/users")
    }

    static func listFriends(status: FriendsStatus? = nil) async throws -> [APIUser] {
        var q: [String: CustomStringConvertible] = [:]
        if let status { q["status"] = status.rawValue }
        return try await SimpleAPI.get("/users/friends", query: q)
    }

    struct UpdateUserRequest: Encodable { let displayName: String? }

    static func updateUser(displayName: String?) async throws -> APIUser {
        try await SimpleAPI.post("/users", body: UpdateUserRequest(displayName: displayName))
    }
}

// MARK: - Pins

enum PinsAPI {
    static func listPins(lat: Double, lng: Double, radiusKm: Double, includeFriends: Bool = false) async throws -> [EmojiPin] {
        try await SimpleAPI.get("/pins", query: [
            "lat": lat,
            "lng": lng,
            "radius_km": radiusKm,
            "include_friends": includeFriends ? 1 : 0
        ])
    }

    struct CreatePinRequest: Encodable {
        let emoji: String
        let latitude: Double
        let longitude: Double
        let visibility: String?
        let note: String?
    }

    static func createPin(emoji: String, latitude: Double, longitude: Double, visibility: Visibility?, note: String?) async throws -> EmojiPin {
        let body = CreatePinRequest(emoji: emoji, latitude: latitude, longitude: longitude, visibility: visibility?.rawValue, note: note)
        return try await SimpleAPI.post("/pins", body: body)
    }
}

// MARK: - Internals

private struct EmptyDecodable: Decodable {}
