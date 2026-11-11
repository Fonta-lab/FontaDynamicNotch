import SwiftUI

struct GeneralSettingsView: View {
    @Bindable private var store = SettingsStore.shared
    @State private var launchAtLogin = SystemStatus.launchAtLogin
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        loginError = SystemStatus.setLaunchAtLogin(on)
                        launchAtLogin = SystemStatus.launchAtLogin
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Show icon in the menu bar", isOn: $store.settings.showMenuBarIcon)
                if !store.settings.showMenuBarIcon {
                    Text("Settings stay reachable by right-clicking the open notch.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Screens") {
                Picker("Show the notch on", selection: $store.settings.notchOnAllScreens) {
                    Text("All screens").tag(true)
                    Text("Main display only").tag(false)
                }
                Toggle("Show fake notch when idle", isOn: $store.settings.showFakeNotchWhenIdle)
                Text("On screens without a notch, a small black pill stays visible so there's something to hover.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Opening and closing") {
                LabeledSlider(title: "Hover delay before opening", value: $store.settings.hoverOpenDelay,
                              range: 0...0.6, format: { String(format: "%.2f s", $0) })
                LabeledSlider(title: "Delay before closing", value: $store.settings.closeDelay,
                              range: 0...1, format: { String(format: "%.2f s", $0) })
            }
            Section("Music") {
                Stepper(value: $store.settings.pausedMusicVisibleMinutes, in: 1...120, step: 1) {
                    LabeledContent("Paused music stays visible for",
                                   value: "\(Int(store.settings.pausedMusicVisibleMinutes)) min")
                }
            }
        }
    }
}
