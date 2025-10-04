//
//  FakePins.swift
//  Ember
//
//  Temporary fake data generator for local development.
//  Delete this file when wiring real data.
//

import Foundation
import CoreLocation

#if DEBUG
enum FakePins {
    static let enabled: Bool = true

    // Seed points up to a selected radius. Points include:
    // - Always include 5km set when radius >= 5
    // - Add 10km set when radius >= 10
    // - Add 25km set when radius >= 25
    static func seed(around center: CLLocationCoordinate2D, forRadiusKm radiusKm: Double) -> [EmojiPin] {
        let emojis = EmojiPin.defaultEmojis
        var all: [(CLLocationDistance, Int)] = []

        // Within 5km
        if radiusKm >= 5 {
            let dists5: [CLLocationDistance] = [300, 800, 1600, 2500, 4200]
            for (i, d) in dists5.enumerated() { all.append((d, i)) }
        }

        // Within 10km (additional to 5km)
        if radiusKm >= 10 {
            let dists10: [CLLocationDistance] = [6000, 7200, 9000]
            for (i, d) in dists10.enumerated() { all.append((d, i + 5)) }
        }

        // Within 25km (additional to 10km)
        if radiusKm >= 25 {
            let dists25: [CLLocationDistance] = [12000, 16000, 20000, 24000]
            for (i, d) in dists25.enumerated() { all.append((d, i + 8)) }
        }

        // Place around the user at different bearings
        var pins: [EmojiPin] = []
        for (idx, (meters, seedIndex)) in all.enumerated() {
            let bearing = Double((seedIndex * 36) % 360) // spread bearings
            let coord = coordinate(from: center, bearingDegrees: bearing, distanceMeters: meters)
            let emoji = emojis[(seedIndex) % emojis.count]
            pins.append(EmojiPin(id: UUID(), emoji: emoji, latitude: coord.latitude, longitude: coord.longitude, timePlaced: Date(), visibility: nil, note: nil))
        }
        return pins
    }

    // Friends-only seed with notes attached
    static func seedFriends(around center: CLLocationCoordinate2D, forRadiusKm radiusKm: Double) -> [EmojiPin] {
        let base = seed(around: center, forRadiusKm: radiusKm)
        let notes = [
            "Coffee at Blue Bottle ☕️",
            "Pickup soccer 6pm ⚽️",
            "Concert tonight at the park 🎵",
            "New ramen spot is amazing 🍜",
            "Traffic on 3rd Ave, avoid! 🚧",
            "Gym session done 💪",
            "Beach day vibes 🏖️",
            "Study group here 📚"
        ]
        return base.enumerated().map { idx, pin in
            EmojiPin(
                id: pin.id,
                emoji: pin.emoji,
                latitude: pin.latitude,
                longitude: pin.longitude,
                timePlaced: pin.timePlaced,
                visibility: .friends,
                note: notes[idx % notes.count]
            )
        }
    }
}

private func coordinate(from start: CLLocationCoordinate2D, bearingDegrees: Double, distanceMeters: CLLocationDistance) -> CLLocationCoordinate2D {
    let R = 6_371_000.0 // meters
    let δ = distanceMeters / R
    let θ = bearingDegrees * .pi / 180.0

    let φ1 = start.latitude * .pi / 180.0
    let λ1 = start.longitude * .pi / 180.0

    let sinφ1 = sin(φ1)
    let cosφ1 = cos(φ1)
    let sinδ = sin(δ)
    let cosδ = cos(δ)

    let sinφ2 = sinφ1 * cosδ + cosφ1 * sinδ * cos(θ)
    let φ2 = asin(sinφ2)
    let y = sin(θ) * sinδ * cosφ1
    let x = cosδ - sinφ1 * sinφ2
    let λ2 = λ1 + atan2(y, x)

    let lat = φ2 * 180.0 / .pi
    var lon = λ2 * 180.0 / .pi
    // Normalize longitude to [-180, 180]
    lon = (lon + 540).truncatingRemainder(dividingBy: 360) - 180
    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
}
#endif
