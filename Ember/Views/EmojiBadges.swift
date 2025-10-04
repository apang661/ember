//
//  EmojiBadges.swift
//  Ember
//
//  Reusable emoji badge views.
//

import SwiftUI

// Stylized emoji marker
struct EmojiBadge: View {
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

// Live preview marker at user location for the currently selected emoji
struct PreviewEmojiBadge: View {
    let emoji: String
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemBackground).opacity(0.85))
                .frame(width: 40, height: 40)
                .overlay(
                    Circle().stroke(Color.accentColor.opacity(0.6), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
            Text(emoji)
                .font(.system(size: 22))
        }
    }
}

// Animated pop-out badge used when a fake pin is hit by the pulse
struct PopEmojiBadge: View {
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

