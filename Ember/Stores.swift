//
//  Stores.swift
//  Ember
//
//  Local persistence for pins.
//

import Foundation

enum PinsStore {
    private static let key = "emojiPins"

    static func load() -> [EmojiPin] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([EmojiPin].self, from: data)) ?? []
    }

    static func save(_ pins: [EmojiPin]) {
        if let data = try? JSONEncoder().encode(pins) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

