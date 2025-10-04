//
//  Models.swift
//  Ember
//
//  App data models and enums.
//

import Foundation
import CoreLocation

enum Visibility: String, Codable, CaseIterable, Identifiable {
    case `public` = "public"
    case friends = "friends"
    case anonymous = "anonymous"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .public: return "Public"
        case .friends: return "Friends Only"
        case .anonymous: return "Anonymous to All"
        }
    }
}

enum Scope: String, CaseIterable, Identifiable {
    case everyone
    case friends
    var id: String { rawValue }
    var label: String {
        switch self {
        case .everyone: return "Everyone"
        case .friends: return "Friends"
        }
    }
}

struct EmojiPin: Identifiable, Codable, Hashable {
    let id: UUID
    let emoji: String
    let latitude: Double
    let longitude: Double
    let timePlaced: Date
    let visibility: Visibility?
    let note: String?

    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }

    static let defaultEmojis: [String] = ["🙂", "😂", "😍", "😢", "😡"]
}

