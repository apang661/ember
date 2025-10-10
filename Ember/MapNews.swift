//
//  MapNews.swift
//  Ember
//
//  Lightweight Apple Maps powered news search for the current area.
//

import Foundation
import MapKit
import CoreLocation
import Combine

struct MapNewsItem: Identifiable {
    let id: UUID
    let name: String
    let subtitle: String?
    let url: URL?
    let mapItem: MKMapItem
    let distance: CLLocationDistance?
    let coordinate: CLLocationCoordinate2D

    init(mapItem: MKMapItem, origin: CLLocationCoordinate2D?) {
        self.id = UUID()
        self.name = mapItem.name ?? "Local Story"
        self.url = mapItem.url
        self.mapItem = mapItem
        self.coordinate = mapItem.placemark.coordinate

        if let origin = origin {
            self.distance = distanceMeters(origin, mapItem.placemark.coordinate)
        } else {
            self.distance = nil
        }

        if let customSubtitle = mapItem.placemark.title {
            let pieces = customSubtitle.components(separatedBy: "\u{B7}").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if let first = pieces.first, !first.isEmpty {
                self.subtitle = first
            } else {
                self.subtitle = mapItem.pointOfInterestCategory?.rawValue
            }
        } else if let locality = mapItem.placemark.locality {
            self.subtitle = locality
        } else {
            self.subtitle = mapItem.pointOfInterestCategory?.rawValue
        }
    }

    var distanceText: String? {
        guard let distance else { return nil }
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }
}

@MainActor
final class MapNewsStore: ObservableObject {
    @Published private(set) var items: [MapNewsItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var scenes: [UUID: MKLookAroundScene] = [:]

    private var lastQueryCoordinate: CLLocationCoordinate2D?
    private var lastQueryDate: Date?
    private var refreshTask: Task<Void, Never>?
    private let searchRadiusMeters: CLLocationDistance = 9_000
    private let primaryCategories: [MKPointOfInterestCategory] = [
        .library,
        .museum,
        .stadium,
        .university,
        .school,
        .park,
        .theater
    ]
    private let fallbackQuery = "news"

    func refresh(around coordinate: CLLocationCoordinate2D, force: Bool = false) {
        if !force && !shouldFetch(for: coordinate) { return }
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.performFetch(around: coordinate)
        }
    }

    func scene(for item: MapNewsItem) -> MKLookAroundScene? {
        scenes[item.id]
    }

    private func shouldFetch(for coordinate: CLLocationCoordinate2D) -> Bool {
        if let lastCoord = lastQueryCoordinate, let lastDate = lastQueryDate {
            let elapsed = Date().timeIntervalSince(lastDate)
            let distance = distanceMeters(lastCoord, coordinate)
            if elapsed < 45 && distance < 800 {
                return false
            }
        }
        return true
    }

    private func performFetch(around coordinate: CLLocationCoordinate2D) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            var primaryItems = try await searchNews(around: coordinate, fallback: false)
            if Task.isCancelled { return }

            if primaryItems.isEmpty {
                primaryItems = try await searchNews(around: coordinate, fallback: true)
                if Task.isCancelled { return }
            }

            let trimmed = primaryItems.prefix(8)
            let mapped = trimmed.map { MapNewsItem(mapItem: $0, origin: coordinate) }
            self.items = mapped
            self.scenes = [:]
            self.lastQueryCoordinate = coordinate
            self.lastQueryDate = Date()
            self.lastError = mapped.isEmpty ? "No local stories surfaced for this area yet. Try zooming out or refreshing later." : nil

            for item in mapped {
                if Task.isCancelled { return }
                await fetchLookAroundScene(for: item)
            }
        } catch {
            if (error as NSError).code == NSUserCancelledError { return }
            self.items = []

            if let mkError = error as? MKError {
                switch mkError.code {
                case .serverFailure:
                    self.lastError = "Apple Maps couldn't load local news right now. Try again shortly."
                case .loadingThrottled:
                    self.lastError = "Apple Maps is rate-limiting requests. Please wait a moment and retry."
                case .placemarkNotFound:
                    self.lastError = "No local stories surfaced for this area yet. Try zooming out or refreshing later."
                default:
                    self.lastError = mkError.localizedDescription
                }
            } else {
                self.lastError = error.localizedDescription
            }
        }
    }

    private func searchNews(around coordinate: CLLocationCoordinate2D, fallback: Bool) async throws -> [MKMapItem] {
        if fallback {
            var request = MKLocalSearch.Request()
            request.naturalLanguageQuery = fallbackQuery
            request.resultTypes = [.pointOfInterest, .address]
            request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: searchRadiusMeters * 1.5, longitudinalMeters: searchRadiusMeters * 1.5)
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            return response.mapItems
        } else if #available(iOS 13.0, *) {
            let poiRequest = MKLocalPointsOfInterestRequest(center: coordinate, radius: searchRadiusMeters)
            poiRequest.pointOfInterestFilter = MKPointOfInterestFilter(including: primaryCategories)
            let search = MKLocalSearch(request: poiRequest)
            let response = try await search.start()
            return response.mapItems
        } else {
            // Legacy fallback for older OS versions
            var request = MKLocalSearch.Request()
            request.naturalLanguageQuery = fallbackQuery
            request.resultTypes = [.pointOfInterest]
            request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: searchRadiusMeters * 1.5, longitudinalMeters: searchRadiusMeters * 1.5)
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            return response.mapItems
        }
    }

    private func fetchLookAroundScene(for item: MapNewsItem) async {
        guard scenes[item.id] == nil else { return }
        if Task.isCancelled { return }
        let request = MKLookAroundSceneRequest(mapItem: item.mapItem)
        if let scene = try? await request.scene, !Task.isCancelled {
            scenes[item.id] = scene
        }
    }
}
