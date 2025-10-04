//
//  SettingsView.swift
//  Ember
//
//  Simple settings pane with logout and about details.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    HStack {
                        Text("Signed in as")
                        Spacer()
                        Text(auth.username ?? "Unknown")
                            .foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) {
                        auth.logout()
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section("About") {
                    LabeledContent("App") { Text("Ember") }
                    LabeledContent("Build") { Text(versionString) }
                    Text("Ember lets you pin how you feel on a map and see nearby vibes from friends and everyone around you.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Made with ❤️, support our [GitHub](https://github.com/apang661/ember/tree/main)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

