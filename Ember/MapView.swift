//
//  MapView.swift
//  Ember
//
//  Created by Edward Liang on 2025-10-04.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine
import UIKit

// Explicit map accent to avoid Map overlay defaulting to black
private let mapAccent: Color = Color(.systemBlue)

// Show the map view with emoji pinning
struct MapView: View {
    // Camera + location
    @State private var position: MapCameraPosition = .automatic
    @StateObject private var locationManager = LocationManager()

    // Pins state
    @State private var pins: [EmojiPin] = []
    @State private var selectedEmoji: String = EmojiPin.defaultEmojis.first ?? "🙂"
    @State private var fakePins: [EmojiPin] = []
    @State private var fakePinsGenerated = false
    @State private var activePopups: Set<UUID> = []
    @State private var poppedThisPulse: Set<UUID> = []

    // Radius filtering (km)
    @State private var radiusKm: Double = 5
    private let radiusOptions: [Double] = [5, 10, 25]

    // Alert when location is missing
    @State private var showLocationAlert = false

    // Pulse animation state (true geodesic circle)
    @State private var pulseRadiusMeters: CLLocationDistance = 0
    private let pulseTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @State private var currentRegion: MKCoordinateRegion?
    @State private var pulseId: Int = 0
    private let pulseDuration: Double = 1.8

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position) {
                // Custom overlays only; hide system user annotation to avoid dark fill artifacts

                // Emoji pins within selected radius
                ForEach(filteredPins) { pin in
                    Annotation("", coordinate: pin.coordinate) {
                        EmojiBadge(emoji: pin.emoji)
                    }
                }

                // Active fake-pin popouts
                ForEach(activeFakePins) { pin in
                    Annotation("popup-\(pin.id)", coordinate: pin.coordinate) {
                        PopEmojiBadge(emoji: pin.emoji) {
                            activePopups.remove(pin.id)
                        }
                    }
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                currentRegion = context.region
            }
            // Custom SwiftUI overlay that draws a red filled pulse in screen space
            .overlay {
                GeometryReader { geo in
                    if let region = currentRegion, let userCoord = locationManager.location?.coordinate {
                        let centerPoint = pointOnScreen(for: userCoord, in: region, size: geo.size)
                        let currentMeters = max(50, pulseRadiusMeters)
                        let pixelRadius = pixels(forMeters: currentMeters, atLatitude: userCoord.latitude, in: region, size: geo.size)
                        let targetMeters = max(50, radiusKm * 1000.0)
                        let progress = min(max(currentMeters / targetMeters, 0.0), 1.0)
                        let fadeStart: CGFloat = 0.995 // fade only when extremely close to the edge
                        let fade: CGFloat = progress < fadeStart ? 1.0 : max(0.0, 1.0 - (CGFloat(progress) - fadeStart) / (1.0 - fadeStart))

                        ZStack {
                            // Base translucent red fill to avoid dark/black appearance
                            Circle()
                                .fill(Color.red.opacity(0.22 * fade))
                                .frame(width: pixelRadius * 2, height: pixelRadius * 2)
                                .position(x: centerPoint.x, y: centerPoint.y)

                            // Radial gradient on top to create a soft sonar effect
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.red.opacity(0.45 * fade), Color.red.opacity(0.05 * fade)],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: max(120, pixelRadius)
                                    )
                                )
                                .blendMode(.screen)
                                .frame(width: pixelRadius * 2, height: pixelRadius * 2)
                                .position(x: centerPoint.x, y: centerPoint.y)

                            Circle()
                                .stroke(Color.red.opacity(0.9 * fade), lineWidth: 3)
                                .frame(width: pixelRadius * 2, height: pixelRadius * 2)
                                .position(x: centerPoint.x, y: centerPoint.y)
                        }
                        .compositingGroup()
                        .opacity(Double(fade))
                        .allowsHitTesting(false)
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }

            // Controls overlay
            VStack(spacing: 12) {
                // One-tap pinning with big emoji buttons
                HStack(spacing: 10) {
                    ForEach(EmojiPin.defaultEmojis, id: \.self) { e in
                        Button {
                            selectedEmoji = e
                            pinCurrentLocation(emoji: e)
                        } label: {
                            Text(e)
                                .font(.system(size: 22))
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selectedEmoji == e ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(selectedEmoji == e ? Color.accentColor : Color.gray.opacity(0.25), lineWidth: selectedEmoji == e ? 1.5 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Radius selection
                Picker("Radius", selection: $radiusKm) {
                    ForEach(radiusOptions, id: \.self) { r in
                        Text("\(Int(r)) km").tag(r)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
            .padding()
        }
        .onAppear {
            // Request location authorization and load any saved pins
            locationManager.requestWhenInUseAuthorization()
            pins = PinsStore.load()
            // Start with a subtle pulse
            triggerPulse()
        }
        .onReceive(locationManager.$location) { newValue in
            // Center/adjust camera when we get a fix
            guard let c = newValue?.coordinate else { return }
            updateCamera(center: c, radiusKm: radiusKm, animated: true)
            #if DEBUG
            if FakePins.enabled {
                fakePins = FakePins.seed(around: c, forRadiusKm: radiusKm)
                fakePinsGenerated = true
            }
            #endif
        }
        .onChange(of: radiusKm) { newRadius in
            if let c = locationManager.location?.coordinate {
                updateCamera(center: c, radiusKm: newRadius, animated: true)
            }
            #if DEBUG
            if FakePins.enabled, let c = locationManager.location?.coordinate {
                fakePins = FakePins.seed(around: c, forRadiusKm: newRadius)
                // Keep active popups that still exist
                let valid = Set(fakePins.map { $0.id })
                activePopups = activePopups.intersection(valid)
            }
            #endif
            triggerPulse()
        }
        // Removed onChange(of: position) to avoid pattern matching on MapCameraPosition
        .onChange(of: pins) { newPins in
            PinsStore.save(newPins)
        }
        .alert("Location Unavailable", isPresented: $showLocationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn't access your location. Please enable location permissions in Settings.")
        }
        .onReceive(pulseTimer) { _ in
            triggerPulse()
        }
    }

    // Pins filtered by selected radius from current location (defaults to all if no fix)
    private var filteredPins: [EmojiPin] {
        guard let userCoord = locationManager.location?.coordinate else { return pins }
        let limitMeters = radiusKm * 1000
        return pins.filter { pin in
            distanceMeters(userCoord, pin.coordinate) <= limitMeters
        }
    }

    private func pinCurrentLocation(emoji: String) {
        guard let loc = locationManager.location?.coordinate else {
            showLocationAlert = true
            return
        }
        let new = EmojiPin(
            id: UUID(),
            emoji: emoji,
            latitude: loc.latitude,
            longitude: loc.longitude,
            timePlaced: Date()
        )
        pins.append(new)
    }

    private func triggerPulse() {
        // Reset then animate outward and fade to selected radius
        pulseId &+= 1
        pulseRadiusMeters = 0
        poppedThisPulse.removeAll()
        let target = max(100.0, radiusKm * 1000.0)
        // Animate the visual pulse
        withAnimation(.easeOut(duration: pulseDuration)) {
            pulseRadiusMeters = target
        }
        // Pop out all eligible pins roughly at the same time (slight uniform delay)
        guard let center = locationManager.location?.coordinate else { return }
        let thisPulse = pulseId
        let popDelay = 0.30
        DispatchQueue.main.asyncAfter(deadline: .now() + popDelay) {
            guard thisPulse == pulseId else { return }
            for pin in fakePins {
                let d = distanceMeters(center, pin.coordinate)
                guard d <= target else { continue }
                if !poppedThisPulse.contains(pin.id) {
                    poppedThisPulse.insert(pin.id)
                    activePopups.insert(pin.id)
                }
            }
        }
    }

    private func updateCamera(center: CLLocationCoordinate2D, radiusKm: Double, animated: Bool) {
        let span = spanFor(radiusKm: radiusKm, atLatitude: center.latitude)
        let region = MKCoordinateRegion(center: center, span: span)
        currentRegion = region
        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                position = .region(region)
            }
        } else {
            position = .region(region)
        }
    }

    private var activeFakePins: [EmojiPin] {
        fakePins.filter { activePopups.contains($0.id) }
    }
}

#Preview {
    MapView()
}

// MARK: - Models & Utilities (kept in-file to avoid project changes)

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
}

struct EmojiPin: Identifiable, Codable, Hashable {
    let id: UUID
    let emoji: String
    let latitude: Double
    let longitude: Double
    let timePlaced: Date

    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }

    static let defaultEmojis: [String] = ["🙂", "😂", "😍", "😢", "😡"]
}

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

@inline(__always)
private func distanceMeters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
    let la = CLLocation(latitude: a.latitude, longitude: a.longitude)
    let lb = CLLocation(latitude: b.latitude, longitude: b.longitude)
    return la.distance(from: lb)
}

@inline(__always)
private func spanFor(radiusKm: Double, atLatitude lat: Double) -> MKCoordinateSpan {
    // Convert target radius (km) to a region span (degrees) that roughly frames a diameter = 2 * radius
    let radiusMeters = max(100.0, radiusKm * 1000.0)
    let degPerMeterLat = 1.0 / 111_000.0
    let latDelta = (radiusMeters * degPerMeterLat) * 2.2 // padding factor

    let latRad = abs(lat) * .pi / 180.0
    let metersPerDegLon = 111_320.0 * max(0.1, cos(latRad))
    let degPerMeterLon = 1.0 / metersPerDegLon
    let lonDelta = (radiusMeters * degPerMeterLon) * 2.2

    // Clamp deltas to reasonable bounds
    let clampedLat = min(max(latDelta, 0.005), 60)
    let clampedLon = min(max(lonDelta, 0.005), 60)
    return MKCoordinateSpan(latitudeDelta: clampedLat, longitudeDelta: clampedLon)
}

// Convert a meters distance to screen pixels for the current region and view size
@inline(__always)
private func pixels(forMeters meters: CLLocationDistance, atLatitude lat: Double, in region: MKCoordinateRegion, size: CGSize) -> CGFloat {
    // Degrees corresponding to the distance
    let degPerMeterLat = 1.0 / 111_000.0
    let latDelta = meters * degPerMeterLat

    let latRad = abs(lat) * .pi / 180.0
    let metersPerDegLon = 111_320.0 * max(0.1, cos(latRad))
    let degPerMeterLon = 1.0 / metersPerDegLon
    let lonDelta = meters * degPerMeterLon

    let pxX = CGFloat(lonDelta / max(region.span.longitudeDelta, 1e-6)) * size.width
    let pxY = CGFloat(latDelta / max(region.span.latitudeDelta, 1e-6)) * size.height
    return max(1, min(pxX, pxY))
}

// Convert a coordinate to a point in the map's local view coordinates given the current region
@inline(__always)
private func pointOnScreen(for coord: CLLocationCoordinate2D, in region: MKCoordinateRegion, size: CGSize) -> CGPoint {
    let dx = coord.longitude - region.center.longitude
    let dy = coord.latitude - region.center.latitude
    let x = size.width * 0.5 + CGFloat(dx / max(region.span.longitudeDelta, 1e-6)) * size.width
    let y = size.height * 0.5 - CGFloat(dy / max(region.span.latitudeDelta, 1e-6)) * size.height
    return CGPoint(x: x, y: y)
}

// Stylized emoji marker
private struct EmojiBadge: View {
    let emoji: String
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            Text(emoji)
                .font(.system(size: 20))
        }
    }
}

// Animated pop-out badge used when a fake pin is hit by the pulse
private struct PopEmojiBadge: View {
    let emoji: String
    var onDone: () -> Void
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0.0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            Text(emoji)
                .font(.system(size: 26))
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0)) {
                scale = 1.2
                opacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.25).delay(0.35)) {
                scale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.9)) {
                opacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                onDone()
            }
        }
    }
}
