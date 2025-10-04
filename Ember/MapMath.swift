//
//  MapMath.swift
//  Ember
//
//  Geospatial helpers and conversions for map rendering.
//

import Foundation
import CoreLocation
import MapKit
import SwiftUI

@inline(__always)
func distanceMeters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
    let la = CLLocation(latitude: a.latitude, longitude: a.longitude)
    let lb = CLLocation(latitude: b.latitude, longitude: b.longitude)
    return la.distance(from: lb)
}

@inline(__always)
func spanFor(radiusKm: Double, atLatitude lat: Double) -> MKCoordinateSpan {
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
func pixels(forMeters meters: CLLocationDistance, atLatitude lat: Double, in region: MKCoordinateRegion, size: CGSize) -> CGFloat {
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
func pointOnScreen(for coord: CLLocationCoordinate2D, in region: MKCoordinateRegion, size: CGSize) -> CGPoint {
    let dx = coord.longitude - region.center.longitude
    let dy = coord.latitude - region.center.latitude
    let x = size.width * 0.5 + CGFloat(dx / max(region.span.longitudeDelta, 1e-6)) * size.width
    let y = size.height * 0.5 - CGFloat(dy / max(region.span.latitudeDelta, 1e-6)) * size.height
    return CGPoint(x: x, y: y)
}

