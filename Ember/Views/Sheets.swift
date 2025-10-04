//
//  Sheets.swift
//  Ember
//
//  Bottom sheets for placing pins and viewing friend notes.
//

import SwiftUI
import CoreLocation

struct PlacePinSheet: View {
    let selectedEmoji: String
    @Binding var visibility: Visibility
    @Binding var note: String
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Place Pin")
                    .font(.headline)
                Spacer()
                Text(selectedEmoji).font(.title2)
            }
            Picker("Visibility", selection: $visibility) {
                ForEach(Visibility.allCases) { v in
                    Text(v.label).tag(v)
                }
            }
            .pickerStyle(.segmented)
            TextField("Add a note (optional)", text: $note)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel", role: .cancel) { onCancel() }
                Spacer()
                Button("Confirm") { onConfirm() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding()
    }
}

struct FriendNoteSheet: View {
    let pin: EmojiPin
    let userLocation: CLLocation?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(pin.emoji).font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Friend's Pin").font(.headline)
                    if let d = distanceText { Text(d).foregroundStyle(.secondary).font(.subheadline) }
                }
                Spacer()
            }
            Divider()
            if let note = pin.note, !note.isEmpty {
                Text(note).font(.body)
            } else {
                Text("No note provided").foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private var distanceText: String? {
        guard let user = userLocation else { return nil }
        let dist = user.distance(from: CLLocation(latitude: pin.latitude, longitude: pin.longitude))
        if dist >= 1000 {
            return String(format: "%.1f km away", dist / 1000)
        } else {
            return String(format: "%.0f m away", dist)
        }
    }
}

