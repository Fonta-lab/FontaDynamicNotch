import SwiftUI

struct MusicSettingsView: View {
    @Bindable private var store = SettingsStore.shared
    @State private var permission: SystemStatus.SpotifyPermission = .unknown

    var body: some View {
        Form {
            Section("Spotify") {
                LabeledContent("Permission to control Spotify") {
                    HStack {
                        statusLabel
                        Button("Check again") { Task { permission = await SystemStatus.spotifyPermission() } }
                    }
                }
                Button("Open Automation settings…") { SpotifyService.shared.openAutomationSettings() }
            }
            Section("Bars beside the closed notch") {
                Stepper(value: $store.settings.musicBarCount, in: 3...8) {
                    LabeledContent("Number of bars", value: "\(store.settings.musicBarCount)")
                }
                LabeledSlider(title: "Speed", value: $store.settings.musicBarSpeed, range: 0.3...2.5,
                              format: { String(format: "%.1f×", $0) })
                Picker("Colour", selection: $store.settings.musicBarsUseArtworkColor) {
                    Text("From the album cover").tag(true)
                    Text("Theme accent").tag(false)
                }
            }
            Section("Song title") {
                Toggle("Scroll long titles on hover", isOn: $store.settings.marqueeEnabled)
            }
        }
        .task { permission = await SystemStatus.spotifyPermission() }
    }

    @ViewBuilder private var statusLabel: some View {
        switch permission {
        case .allowed: Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .denied: Label("Not allowed", systemImage: "xmark.circle.fill").foregroundStyle(.red)
        case .notAsked: Label("Not asked yet", systemImage: "questionmark.circle").foregroundStyle(.secondary)
        case .spotifyNotRunning: Label("Open Spotify to check", systemImage: "questionmark.circle").foregroundStyle(.secondary)
        case .unknown: Label("Unknown", systemImage: "questionmark.circle").foregroundStyle(.secondary)
        }
    }
}
