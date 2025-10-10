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
    @StateObject private var newsStore = MapNewsStore()

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
    @State private var showSettings: Bool = false
    @State private var showNewsDrawer: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            mapCanvas

            VStack(spacing: 18) {
                newsDrawer
                GlassSurface {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Label("Drop your vibe", systemImage: "sparkles")
                                .font(.callout.weight(.semibold))
                                .labelStyle(.titleAndIcon)
                                .foregroundStyle(.primary.opacity(0.85))
                            Spacer()
                            if let coord = locationManager.location?.coordinate {
                                Text(formatLocation(coord))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 14) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(allEmojis, id: \.self) { e in
                                        Button {
                                            selectedEmoji = e
                                        } label: {
                                            Text(e)
                                                .font(.system(size: 24))
                                                .frame(width: 48, height: 48)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .fill(emojiBackground(for: e))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .stroke(emojiStroke(for: e), lineWidth: selectedEmoji == e ? 1.6 : 1)
                                                )
                                                .shadow(color: selectedEmoji == e ? Color.accentColor.opacity(0.22) : Color.black.opacity(0.08), radius: selectedEmoji == e ? 12 : 6, x: 0, y: selectedEmoji == e ? 10 : 4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            Button(action: placeSelectedEmoji) {
                                HStack(spacing: 8) {
                                    Text(selectedEmoji)
                                        .font(.system(size: 24))
                                    Text("Drop")
                                        .font(.callout.weight(.semibold))
                                }
                                .padding(.vertical, 11)
                                .padding(.horizontal, 18)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.accentColor, Color.pink.opacity(0.85)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .foregroundStyle(Color.white)
                                .shadow(color: Color.accentColor.opacity(0.28), radius: 18, x: 0, y: 10)
                            }
                            .buttonStyle(.plain)
                            .disabled(locationManager.location == nil)
                            .opacity(locationManager.location == nil ? 0.45 : 1)
                            .accessibilityLabel("Drop selected emoji on your current location")
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Discovery radius")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Picker("Radius", selection: $radiusKm) {
                                ForEach(radiusOptions, id: \.self) { r in
                                    Text("\(Int(r)) km").tag(r)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
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
            if showNewsDrawer {
                refreshNewsForDrawer()
            }
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
        .onChange(of: radiusKm) { _, newRadius in
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
            if showNewsDrawer {
                refreshNewsForDrawer(force: true)
            }
            triggerPulse()
        }
        // Removed onChange(of: position) to avoid pattern matching on MapCameraPosition
        .onChange(of: pins) { _, newPins in
            PinsStore.save(newPins)
        }
        .onChange(of: showNewsDrawer) { _, isOpen in
            if isOpen {
                refreshNewsForDrawer(force: true)
            }
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
                .presentationDetents([.height(noteSheetHeight(for: pin))])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
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

    private var mapCanvas: some View {
        let baseMap = Map(position: $position) {
            // Emoji pins within selected radius
            ForEach(filteredPins) { pin in
                Annotation("", coordinate: pin.coordinate) {
                    EmojiBadge(emoji: pin.emoji)
                }
            }

            // Active fake-pin popouts (Everyone scope only)
            if scope == .everyone {
                ForEach(activeFakePins) { pin in
                    Annotation("", coordinate: pin.coordinate) {
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
                Annotation("Me", coordinate: userCoord) {
                    PreviewEmojiBadge(emoji: selectedEmoji)
                }
            }
        }

        let styledMap: AnyView
        if #available(iOS 17, *) {
            styledMap = AnyView(
                baseMap
                    .mapStyle(.standard(elevation: .realistic))
                    .mapControls {
                        MapCompass()
                        MapPitchToggle()
                    }
            )
        } else {
            styledMap = AnyView(baseMap)
        }

        return styledMap
            .ignoresSafeArea()
            .onMapCameraChange(frequency: .continuous) { context in
                currentRegion = context.region
                if showNewsDrawer {
                    refreshNewsForDrawer()
                }
            }
            .overlay(alignment: Alignment.top) { topGradientOverlay }
            .overlay(alignment: Alignment.bottom) { bottomGradientOverlay }
            .overlay { pulseOverlay }
            .overlay(alignment: Alignment.top) { topChrome }
    }

    @ViewBuilder
    private var topGradientOverlay: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.28), Color.black.opacity(0.0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 190)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }

    @ViewBuilder
    private var bottomGradientOverlay: some View {
        LinearGradient(
            colors: [Color.white.opacity(0.18), Color.white.opacity(0.0)],
            startPoint: .bottom,
            endPoint: .top
        )
        .frame(height: 220)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }

    @ViewBuilder
    private var pulseOverlay: some View {
        GeometryReader { geo in
            if scope == .everyone, let region = currentRegion, let userCoord = locationManager.location?.coordinate {
                let centerPoint = pointOnScreen(for: userCoord, in: region, size: geo.size)
                let currentMeters = max(50, pulseRadiusMeters)
                let rawPixelRadius = pixels(forMeters: currentMeters, atLatitude: userCoord.latitude, in: region, size: geo.size)
                let pixelRadius = min(rawPixelRadius, 600)
                let targetMeters = max(50, radiusKm * 1000.0)
                let progress = min(max(currentMeters / targetMeters, 0.0), 1.0)
                let fadeStart: CGFloat = 0.995
                let fade: CGFloat = progress < fadeStart ? 1.0 : max(0.0, 1.0 - (CGFloat(progress) - fadeStart) / (1.0 - fadeStart))

                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.22 * fade))
                        .frame(width: pixelRadius * 2, height: pixelRadius * 2)
                        .position(x: centerPoint.x, y: centerPoint.y)

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

    private var recenterButton: some View {
        FloatingMapButton(systemName: "location.fill", action: recenterOnUser)
    }

    private var scopePicker: some View {
        GlassSurface(style: .compact) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Now viewing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Picker("Scope", selection: $scope) {
                    ForEach(Scope.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
        }
    }

    private var settingsButton: some View {
        FloatingMapButton(systemName: "gearshape.fill") {
            showSettings = true
        }
    }

    private var topChrome: some View {
        HStack(alignment: .center, spacing: 16) {
            settingsButton
            Spacer(minLength: 0)
            scopePicker
                .padding(.horizontal, 4)
            Spacer(minLength: 0)
            recenterButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 5)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var newsDrawer: some View {
        if showNewsDrawer {
            MapNewsDeck(
                store: newsStore,
                openInMaps: openNewsItem,
                onClose: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showNewsDrawer = false
                    }
                },
                onRefresh: { refreshNewsForDrawer(force: true) }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            collapsedNewsHandle
                .transition(.opacity)
        }
    }

    private var collapsedNewsHandle: some View {
        GlassSurface(style: .compact) {
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.primary.opacity(0.22))
                    .frame(width: 40, height: 4)
                Text("Local pulse")
                    .font(.callout.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showNewsDrawer = true
            }
        }
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.height < -60 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showNewsDrawer = true
                    }
                }
            }
        )
    }

    private func refreshNewsForDrawer(force: Bool = false) {
        guard let anchor = currentRegion?.center ?? locationManager.location?.coordinate else { return }
        newsStore.refresh(around: anchor, force: force)
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

    private func recenterOnUser() {
        guard let c = locationManager.location?.coordinate else {
            showLocationAlert = true
            return
        }
        updateCamera(center: c, radiusKm: radiusKm, animated: true)
    }

    private func noteSheetHeight(for pin: EmojiPin) -> CGFloat {
        let base: CGFloat = 0
        let count = pin.note?.count ?? 0
        // Roughly add height per 60 chars, clamp to a sane range
        let extra = CGFloat(max(0, (count / 60))) * 22
        return min(max(base + extra, 160), 420)
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

    private func formatLocation(_ coordinate: CLLocationCoordinate2D) -> String {
        let lat = String(format: "%@%.3f°", coordinate.latitude >= 0 ? "N" : "S", abs(coordinate.latitude))
        let lon = String(format: "%@%.3f°", coordinate.longitude >= 0 ? "E" : "W", abs(coordinate.longitude))
        return "\(lat) · \(lon)"
    }

    private func emojiBackground(for emoji: String) -> AnyShapeStyle {
        if selectedEmoji == emoji {
            let gradient = LinearGradient(
                colors: [Color.accentColor.opacity(0.92), Color.pink.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            return AnyShapeStyle(gradient)
        } else {
            let base = Color(.systemBackground).opacity(0.92)
            return AnyShapeStyle(base)
        }
    }

    private func emojiStroke(for emoji: String) -> Color {
        selectedEmoji == emoji ? Color.white.opacity(0.65) : Color.gray.opacity(0.26)
    }

    private func openNewsItem(_ item: MapNewsItem) {
        var launchOptions: [String: Any] = [:]
        launchOptions[MKLaunchOptionsMapCenterKey] = NSValue(mkCoordinate: item.coordinate)
        launchOptions[MKLaunchOptionsMapSpanKey] = NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12))
        item.mapItem.openInMaps(launchOptions: launchOptions)
    }
}
