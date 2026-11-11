import SwiftUI
import UniformTypeIdentifiers

/// Timers (SPEC §10.6): the 5 presets, alarm sound (pick, import, preview) and volume.
struct TimerSettingsView: View {
    @Bindable private var store = SettingsStore.shared
    private var timers: TimerStore { .shared }
    @State private var sounds: [AlarmSoundRef] = []
    @State private var importFailed = false

    var body: some View {
        Form {
            Section {
                ForEach(timers.presets) { p in
                    TimerPresetRow(preset: p)
                }
            } header: {
                Text("Presets")
            } footer: {
                Text("A running timer keeps its end time; a new length applies from its next start.")
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

/// Name + hours/minutes/seconds for one preset.
struct TimerPresetRow: View {
    let preset: TimerPreset
    @State private var name = ""

    var body: some View {
        let total = Int(preset.duration)
        HStack(spacing: 10) {
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 140)
                .onSubmit(commitName)
                .onChange(of: name) { commitName() }
            Spacer()
            field(total / 3600, "h", max: 23) { set(h: $0) }
            field(total / 60 % 60, "m", max: 59) { set(m: $0) }
            field(total % 60, "s", max: 59) { set(s: $0) }
        }
        .onAppear { name = preset.name }
    }

    private func field(_ value: Int, _ unit: String, max: Int, set: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 2) {
            TextField(unit, value: Binding(get: { value }, set: { set(Swift.min(max, Swift.max(0, $0))) }), format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 44)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func commitName() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed != preset.name { TimerStore.shared.updatePreset(preset.id, name: trimmed) }
    }

    private func set(h: Int? = nil, m: Int? = nil, s: Int? = nil) {
        let t = Int(preset.duration)
        let total = (h ?? t / 3600) * 3600 + (m ?? t / 60 % 60) * 60 + (s ?? t % 60)
        TimerStore.shared.updatePreset(preset.id, duration: TimeInterval(max(1, total)))
    }
}
