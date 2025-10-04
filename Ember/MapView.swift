//
//  MapView.swift
//  Ember
//
//  Created by Edward Liang on 2025-10-04.
//

import SwiftUI
import MapKit

// Show the map view
struct MapView: View {
    @State private var position: MapCameraPosition = .automatic
    var body: some View {
        Map(position: $position) {
            // Optionally display a system-styled indicator for the user's location
            UserAnnotation()
        }
        .mapControls {
            // Add the button to recenter the map on the user's location
            MapUserLocationButton()
        }
        .onAppear {
            // Request location authorization when the view appears
            CLLocationManager().requestWhenInUseAuthorization()
        }
    }
}

#Preview {
    MapView()
}
