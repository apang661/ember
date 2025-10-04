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

    // Place flow
    @State private var showPlaceSheet: Bool = false
    @State private var placeVisibility: Visibility = .public
    @State private var placeNote: String = ""

    // Scope
    @State private var scope: Scope = .everyone
    @State private var friendPins: [EmojiPin] = []
    @State private var selectedFriendPin: EmojiPin?

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

                // Active fake-pin popouts (Everyone scope only)
                if scope == .everyone {
                    ForEach(activeFakePins) { pin in
                        Annotation("popup-\(pin.id)", coordinate: pin.coordinate) {
                            PopEmojiBadge(emoji: pin.emoji) {
                                activePopups.remove(pin.id)
                            }
                        }
                    }
                }

                // Static friends pins (Friends scope only)
                if scope == .friends {
                    ForEach(filteredFriendPins) { pin in
                        Annotation("friend-\(pin.id)", coordinate: pin.coordinate) {
                            Button {
                                selectedFriendPin = pin
                            } label: {
                                EmojiBadge(emoji: pin.emoji)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Preview of selected emoji at user location before placing
                if let userCoord = locationManager.location?.coordinate {
                    Annotation("preview", coordinate: userCoord) {
                        PreviewEmojiBadge(emoji: selectedEmoji)
                    }
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                currentRegion = context.region
            }
            // Custom SwiftUI overlay that draws a red filled pulse in screen space
            .overlay {
                GeometryReader { geo in
                    if scope == .everyone, let region = currentRegion, let userCoord = locationManager.location?.coordinate {
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

            // Scope picker overlay at top
            .overlay(alignment: .top) {
                HStack {
                    Picker("Scope", selection: $scope) {
                        ForEach(Scope.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }

            // Controls overlay
            VStack(spacing: 12) {
                // Emoji slider: scroll right to reveal more categories
                HStack(alignment: .center, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(allEmojis, id: \.self) { e in
                                Button {
                                    selectedEmoji = e
                                } label: {
                                    Text(e)
                                        .font(.system(size: 22))
                                        .frame(width: 44, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(selectedEmoji == e ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(selectedEmoji == e ? Color.accentColor : Color.gray.opacity(0.25), lineWidth: selectedEmoji == e ? 1.5 : 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    Button(action: placeSelectedEmoji) {
                        HStack(spacing: 6) {
                            Text(selectedEmoji)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(locationManager.location == nil)
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
            #if DEBUG
            if FakePins.enabled {
                friendPins = FakePins.seedFriends(around: c, forRadiusKm: radiusKm)
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
            #if DEBUG
            if FakePins.enabled, let c = locationManager.location?.coordinate {
                friendPins = FakePins.seedFriends(around: c, forRadiusKm: newRadius)
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
            if scope == .everyone { triggerPulse() }
        }
        .sheet(isPresented: $showPlaceSheet) {
            PlacePinSheet(selectedEmoji: selectedEmoji, visibility: $placeVisibility, note: $placeNote) {
                pinCurrentLocation(emoji: selectedEmoji, visibility: placeVisibility, note: placeNote)
                showPlaceSheet = false
            } onCancel: {
                showPlaceSheet = false
            }
            .presentationDetents([.height(250)])
        }
        .sheet(item: $selectedFriendPin) { pin in
            FriendNoteSheet(pin: pin, userLocation: locationManager.location)
                .presentationDetents([.height(240)])
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

    private var filteredFriendPins: [EmojiPin] {
        guard let userCoord = locationManager.location?.coordinate else { return friendPins }
        let limitMeters = radiusKm * 1000
        return friendPins.filter { pin in
            distanceMeters(userCoord, pin.coordinate) <= limitMeters
        }
    }

    private func pinCurrentLocation(emoji: String, visibility: Visibility? = nil, note: String? = nil) {
        guard let loc = locationManager.location?.coordinate else {
            showLocationAlert = true
            return
        }
        let new = EmojiPin(
            id: UUID(),
            emoji: emoji,
            latitude: loc.latitude,
            longitude: loc.longitude,
            timePlaced: Date(),
            visibility: visibility,
            note: (note?.isEmpty ?? true) ? nil : note
        )
        pins.append(new)
    }

    private func placeSelectedEmoji() {
        guard locationManager.location != nil else {
            showLocationAlert = true
            return
        }
        placeVisibility = .public
        placeNote = ""
        showPlaceSheet = true
    }

    private func triggerPulse() {
        guard scope == .everyone else { return }
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

    private var allEmojis: [String] {
        emojiCatalog.flatMap { $0 }
    }

    private var activeFakePins: [EmojiPin] {
        fakePins.filter { activePopups.contains($0.id) }
    }
}

#Preview { MapView() }
