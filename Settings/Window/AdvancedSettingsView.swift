import SwiftUI

/// Advanced (SPEC §10.8): feature report, debug overlay, fine-tune, reset, data folder.
struct AdvancedSettingsView: View {
    @Bindable private var store = SettingsStore.shared
    private var brightness: BrightnessService { .shared }
    @State private var spotify: SystemStatus.SpotifyPermission = .unknown
    @State private var notifications: Bool?
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("Feature availability on this Mac") {
                row("Screen brightness control", ok: brightness.screenAvailable)
                row("Keyboard brightness control", ok: brightness.keyboardAvailable)
                row("Spotify control", ok: spotify == .allowed ? true : spotify == .denied ? false : nil,
                    detail: spotify == .spotifyNotRunning ? "Open Spotify to check" : nil)
                HStack {
                    row("Notifications", ok: notifications, detail: notifications == nil ? "Not asked yet" : nil)
                    if notifications != true {
                        Button("Ask") { Task { _ = await SystemStatus.requestNotifications(); await refresh() } }
                    }
                }
            }
            Section("Debug") {
                Toggle("Show geometry overlay", isOn: $store.settings.showDebugOverlay)
                Stepper(value: $store.settings.closedHeightExtra, in: 0...10, step: 1) {
                    LabeledContent("Closed notch extra height", value: "\(Int(store.settings.closedHeightExtra)) pt")
                }
            }
            Section("Data") {
                Button("Open data folder") {
                    let url = JSONFile.folder
                    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(url)
                }
                Button("Reset all settings…", role: .destructive) { confirmReset = true }
                Text("Resets every setting to its default. Your themes, timers, counters and imported sounds are kept.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .task { await refresh() }
        .confirmationDialog("Reset all settings to their defaults?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { store.settings = AppSettings() }
        }
    }

    private func refresh() async {
        spotify = await SystemStatus.spotifyPermission()
        notifications = await SystemStatus.notificationsAllowed()
    }

    private func row(_ title: String, ok: Bool?, detail: String? = nil) -> some View {
        LabeledContent(title) {
            switch ok {
            case true?: Label("Available", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case false?: Label("Not available", systemImage: "xmark.circle.fill").foregroundStyle(.red)
            case nil: Label(detail ?? "Unknown", systemImage: "questionmark.circle").foregroundStyle(.secondary)
            }
        }
    }
}
