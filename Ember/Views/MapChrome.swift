//
//  MapChrome.swift
//  Ember
//
//  Shared map chrome styling helpers so the overlays feel cohesive.
//

import SwiftUI

/// Rounded glass surface with a subtle gradient and stroke.
struct GlassSurface<Content: View>: View {
    enum SizeStyle {
        case regular
        case compact

        var cornerRadius: CGFloat {
            switch self {
            case .regular: return 20
            case .compact: return 14
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .regular:
                return EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
            case .compact:
                return EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
            }
        }
    }

    let style: SizeStyle
    @ViewBuilder var content: Content

    init(style: SizeStyle = .regular, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .padding(style.padding)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                            .strokeBorder(borderGradient, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 12)
            )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.55), Color.white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Floating circular button used for map utilities.
struct FloatingMapButton: View {
    let systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial.opacity(0.96))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.45), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 8)
                )
        }
        .buttonStyle(.plain)
    }
}

