//
//  MapNewsViews.swift
//  Ember
//
//  Presentation layer for the Apple Maps powered local news deck.
//

import SwiftUI
import MapKit

struct MapNewsDeck: View {
    @ObservedObject var store: MapNewsStore
    var openInMaps: (MapNewsItem) -> Void
    var onClose: () -> Void
    var onRefresh: () -> Void

    var body: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 8) {
                    Capsule()
                        .fill(Color.primary.opacity(0.18))
                        .frame(width: 44, height: 4)
                        .frame(maxWidth: .infinity)

                    HStack {
                        Label("Local pulse", systemImage: "newspaper")
                            .font(.callout.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                        Spacer()
                        Button(action: onRefresh) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(.borderless)
                        .opacity(store.isLoading ? 0.4 : 1)
                        .disabled(store.isLoading)

                        Button(action: onClose) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .buttonStyle(.borderless)
                    }
                }

                content
            }
        }
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.height > 70 {
                    onClose()
                }
            }
        )
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.items.isEmpty {
            HStack(spacing: 12) {
                ProgressView()
                Text("Scanning for nearby stories…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else if let error = store.lastError, store.items.isEmpty {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if store.items.isEmpty {
            Text("Zoom or pan the map to surface headlines around you.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            TabView {
                ForEach(store.items) { item in
                    MapNewsSlide(
                        item: item,
                        scene: store.scene(for: item),
                        openInMaps: { openInMaps(item) }
                    )
                    .padding(.vertical, 2)
                }
            }
            .frame(height: 210)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
    }
}

private struct MapNewsSlide: View {
    let item: MapNewsItem
    let scene: MKLookAroundScene?
    var openInMaps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            preview

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let distance = item.distanceText {
                        Text("·")
                            .font(.footnote)
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text(distance)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button(action: openInMaps) {
                    Label("Open in Maps", systemImage: "arrow.up.right.square")
                        .font(.footnote.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)

                if let url = item.url {
                    Link(destination: url) {
                        Label("Website", systemImage: "safari")
                            .font(.footnote.weight(.semibold))
                            .labelStyle(.iconOnly)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var preview: some View {
        if let scene {
            LookAroundPreview(scene: .constant(scene))
                .cornerRadius(16)
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.5), Color.clear],
                        startPoint: .bottom,
                        endPoint: .center
                    )
                    .cornerRadius(16)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.18), Color.pink.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "map")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
