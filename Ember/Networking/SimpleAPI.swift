//
//  SimpleAPI.swift
//  Ember
//
//  Minimal, no-dependency REST helpers using URLSession.
//  Targets http://localhost:8080 and adds Authorization if present.
//

import Foundation

enum SimpleAPI {
    static let base: URL = {
        let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        return URL(string: configured ?? "http://localhost:8080")!
    }()
    static var token: String? {
        get { UserDefaults.standard.string(forKey: "auth_token") }
        set { UserDefaults.standard.set(newValue, forKey: "auth_token") }
    }

    // GET /path?query=...
    static func get<T: Decodable>(
        _ path: String,
        query: [String: CustomStringConvertible] = [:]
    ) async throws -> T {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            comps.queryItems = query.map { .init(name: $0.key, value: String(describing: $0.value)) }
        }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }

        let (data, resp) = try await URLSession.shared.data(for: req)
        try ensureOK(resp, data: data)
        return try decoder.decode(T.self, from: data)
    }

    // GET /path with JSON body (unconventional, but supported here for compatibility)
    static func getWithBody<T: Decodable, B: Encodable>(
        _ path: String,
        body: B
    ) async throws -> T {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try encoder.encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        try ensureOK(resp, data: data)
        return try decoder.decode(T.self, from: data)
    }

    // POST /path with JSON body
    static func post<T: Decodable, B: Encodable>(
        _ path: String,
        body: B
    ) async throws -> T {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try encoder.encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        try ensureOK(resp, data: data)
        return try decoder.decode(T.self, from: data)
    }

    // No-content helper
    static func postVoid<B: Encodable>(_ path: String, body: B) async throws {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try encoder.encode(body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        try ensureOK(resp, data: nil)
    }

    // POST with method override header to simulate GET on servers that accept it
    static func postOverrideGet<T: Decodable, B: Encodable>(
        _ path: String,
        body: B
    ) async throws -> T {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("GET", forHTTPHeaderField: "X-HTTP-Method-Override")
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try encoder.encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        try ensureOK(resp, data: data)
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Private

private let decoder: JSONDecoder = {
    let d = JSONDecoder()
    if #available(iOS 15.0, *) { d.dateDecodingStrategy = .iso8601 }
    return d
}()

private let encoder: JSONEncoder = {
    let e = JSONEncoder()
    if #available(iOS 15.0, *) { e.dateEncodingStrategy = .iso8601 }
    return e
}()

private func ensureOK(_ response: URLResponse, data: Data?) throws {
    guard let http = response as? HTTPURLResponse else { return }
    guard (200..<300).contains(http.statusCode) else {
        let message = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        throw NSError(domain: "SimpleAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
