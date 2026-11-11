import SwiftUI

/// Animations (SPEC §9): one spring per animation, simple (duration, bounce) or advanced
/// (response, damping, blend), each with a live preview and a reset.
struct AnimationSettingsView: View {
    @Bindable private var store = SettingsStore.shared

    private let rows: [(String, WritableKeyPath<AnimationSettings, SpringSetting>)] = [
        ("Open", \.open),
        ("Close", \.close),
        ("Closed wings appear / disappear", \.wings),
        ("Brightness slider expand / collapse", \.brightness),
        ("Tab switch (Home ↔ Files, tools)", \.tabSwitch),
        ("Alarm auto-open", \.alarmOpen),
    ]

    var body: some View {
        Form {
            Section {
                Picker("Editor", selection: $store.settings.springEditorAdvanced) {
                    Text("Simple (duration, bounce)").tag(false)
                    Text("Advanced (response, damping, blend)").tag(true)
                }
                .pickerStyle(.segmented)
            }
            ForEach(rows, id: \.0) { title, key in
                Section(title) {
                    SpringEditor(spring: Binding(get: { store.settings.animations[keyPath: key] },
                                                 set: { store.settings.animations[keyPath: key] = $0 }),
                                 defaultValue: AnimationSettings()[keyPath: key],
                                 advanced: store.settings.springEditorAdvanced)
                }
            }
        }
    }
}

struct SpringEditor: View {
    @Binding var spring: SpringSetting
    let defaultValue: SpringSetting
    let advanced: Bool
    @State private var previewOn = false

    var body: some View {
        if advanced {
            LabeledSlider(title: "Response", value: $spring.response, range: 0.05...1.5, format: { String(format: "%.2f s", $0) })
            LabeledSlider(title: "Damping", value: $spring.dampingFraction, range: 0.1...1.5)
            LabeledSlider(title: "Blend duration", value: $spring.blendDuration, range: 0...1, format: { String(format: "%.2f s", $0) })
        } else {
            LabeledSlider(title: "Duration", value: simple(\.duration), range: 0.05...1.5, format: { String(format: "%.2f s", $0) })
            LabeledSlider(title: "Bounce", value: simple(\.bounce), range: -0.5...0.9)
        }
        HStack {
            // A little bar that grows and shrinks with this spring.
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 14)
                Capsule().fill(Color.accentColor).frame(width: previewOn ? 220 : 40, height: 14)
            }
            .frame(width: 230, alignment: .leading)
            Spacer()
            Button("Preview") { withAnimation(spring.animation) { previewOn.toggle() } }
            Button("Reset to default") { spring = defaultValue }
                .disabled(spring == defaultValue)
        }
    }

    /// Simple-mode values, converted to and from the stored response / damping.
    private func simple(_ key: KeyPath<Spring, TimeInterval>) -> Binding<Double> {
        Binding(
            get: { Spring(response: spring.response, dampingRatio: spring.dampingFraction)[keyPath: key] },
            set: { newValue in
                let current = Spring(response: spring.response, dampingRatio: spring.dampingFraction)
                let duration = key == \Spring.duration ? newValue : current.duration
                let bounce = key == \Spring.bounce ? newValue : current.bounce
                let s = Spring(duration: max(0.05, duration), bounce: bounce)
                spring.response = s.response
                spring.dampingFraction = s.dampingRatio
            })
    }
}
