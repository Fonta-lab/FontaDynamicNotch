import SwiftUI
import UniformTypeIdentifiers

/// Timers (SPEC §10.6): starred times, alarm sound (pick, import, preview) and volume.
struct TimerSettingsView: View {
    @Bindable private var store = SettingsStore.shared
    private var timers: TimerStore { .shared }
    @State private var sounds: [AlarmSoundRef] = []
    @State private var importFailed = false

    var body: some View {
        Form {
            Section {
                let starred = timers.timers.filter(\.starred)
                if starred.isEmpty {
                    Text("No starred times yet").foregroundStyle(.secondary)
                }
                ForEach(starred) { t in
                    HStack {
                        Label(TimeFormat.clock(t.duration), systemImage: "star.fill")
                            .monospacedDigit()
                        Text(TimeFormat.label(t.duration)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Remove") { timers.unstar(t.id) }
                    }
                }
            } header: {
                Text("Starred times")
            } footer: {
                Text("In the notch's timer, press the star to keep a time as a chip, or + to add a timer that runs alongside the others (up to \(TimerStore.maxChips) in all).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Alarm") {
                Picker("Sound", selection: $store.settings.alarmSound) {
                    ForEach(sounds, id: \.self) { s in
                        Text(s.isCustom ? "\(s.displayName) (imported)" : s.displayName).tag(s)
                    }
                    if !sounds.contains(store.settings.alarmSound) {
                        Text(store.settings.alarmSound.displayName).tag(store.settings.alarmSound)
                    }
                }
                HStack {
                    Button("Preview") { SoundPreview.shared.play(store.settings.alarmSound, volume: store.settings.alarmVolume) }
                    Button("Stop") { SoundPreview.shared.stop() }
                    Spacer()
                    Button("Import sound…", action: importSound)
                }
                LabeledSlider(title: "Volume", value: $store.settings.alarmVolume, range: 0...1,
                              format: { "\(Int($0 * 100))%" })
            }
        }
        .task { await reloadSounds() }
        .onDisappear { SoundPreview.shared.stop() }
        .alert("Couldn't import that sound", isPresented: $importFailed) {}
    }

    private func reloadSounds() async {
        sounds = await Task.detached(priority: .utility) { SoundLibrary.list() }.value
    }

    private func importSound() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                let ref = await Task.detached(priority: .userInitiated) { SoundLibrary.importSound(from: url) }.value
                if let ref {
                    await reloadSounds()
                    SettingsStore.shared.settings.alarmSound = ref
                } else {
                    importFailed = true
                }
            }
        }
    }
}
