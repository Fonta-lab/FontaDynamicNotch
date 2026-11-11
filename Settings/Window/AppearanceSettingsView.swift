import SwiftUI
import UniformTypeIdentifiers

/// Themes (SPEC §10.2): list, create, duplicate, rename, delete, import/export JSON, and the editor.
struct AppearanceSettingsView: View {
    @Bindable private var settings = SettingsStore.shared
    private var themes: ThemeStore { .shared }
    @State private var confirmDelete = false
    @State private var importError = false

    var body: some View {
        Form {
            Section("Themes") {
                Picker("Theme", selection: $settings.settings.selectedThemeID) {
                    ForEach(themes.all) { t in
                        Text(t.isBuiltIn ? "\(t.name) (built-in)" : t.name).tag(t.id)
                    }
                }
                HStack {
                    Button("New") { themes.duplicate(.default) }
                    Button("Duplicate") { themes.duplicate(themes.current) }
                    Button("Delete…") { confirmDelete = true }
                        .disabled(themes.current.isBuiltIn)
                    Spacer()
                    Button("Import…", action: importTheme)
                    Button("Export…", action: exportTheme)
                }
                if themes.current.isBuiltIn {
                    Text("The Default theme can't be changed. Click Duplicate to make an editable copy.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ThemeEditorSections(theme: Binding(get: { themes.current }, set: { themes.update($0) }))
                .disabled(themes.current.isBuiltIn)
        }
        .confirmationDialog("Delete the theme “\(themes.current.name)”?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { themes.delete(themes.current.id) }
        }
        .alert("That file isn't a theme", isPresented: $importError) {} message: {
            Text("Choose a .json file exported from Fonta's Dynamic Notch.")
        }
    }

    private func importTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                if !(await ThemeStore.shared.importTheme(from: url)) { importError = true }
            }
        }
    }

    private func exportTheme() {
        let theme = themes.current
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(theme.name).json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in ThemeStore.shared.export(theme, to: url) }
        }
    }
}

/// Every value in a theme.
struct ThemeEditorSections: View {
    @Binding var theme: Theme

    var body: some View {
        Section("Name") {
            TextField("Name", text: $theme.name)
        }
        Section("Colours") {
            color("Background (no artwork)", \.fallbackBackgroundColor)
            color("Primary text", \.primaryTextColor)
            color("Secondary text", \.secondaryTextColor)
            color("Accent", \.accentColor)
            color("Icons", \.iconTint)
            color("Slider track", \.sliderTrackColor)
            color("Slider fill", \.sliderFillColor)
            color("Slider knob", \.sliderKnobColor)
            Toggle("Use artwork colour for the background", isOn: $theme.useArtworkColor)
            LabeledSlider(title: "Artwork colour intensity", value: $theme.artworkIntensity, range: 0...1,
                          format: { "\(Int($0 * 100))%" })
            LabeledSlider(title: "Max background brightness", value: $theme.maxBackgroundLuminance, range: 0.03...0.6,
                          format: { "\(Int($0 * 100))%" })
        }
        Section("Corner rounding") {
            radius("Top corners (into the menu bar)", \.topFilletRadius, 0...24)
            radius("Open notch bottom corners", \.openBottomRadius, 0...48)
            radius("Closed notch bottom corners", \.closedBottomRadius, 0...16)
            radius("Album cover (open)", \.coverRadiusOpen, 0...40)
            radius("Album cover (closed)", \.coverRadiusClosed, 0...12)
            radius("Buttons", \.buttonRadius, 0...16)
        }
        Section("Shadow") {
            Toggle("Shadow under the open notch", isOn: $theme.shadowEnabled)
            color("Colour", \.shadowTint)
            LabeledSlider(title: "Opacity", value: $theme.shadowOpacity, range: 0...1, format: { "\(Int($0 * 100))%" })
            radius("Blur", \.shadowRadius, 0...40)
            radius("Vertical offset", \.shadowYOffset, -10...20)
        }
        Section("Icon size") {
            radius("Top bar icons", \.topBarIconSize, 9...18)
            radius("Music controls", \.controlIconSize, 11...24)
        }
        Section("Sliders") {
            radius("Height", \.sliderHeight, 2...10)
            radius("Knob size", \.knobSize, 6...18)
            Picker("Knob shape", selection: $theme.knobShape) {
                Text("Circle").tag(KnobShape.circle)
                Text("Capsule").tag(KnobShape.capsule)
                Text("None").tag(KnobShape.none)
            }
            Toggle("Show knob only on hover", isOn: $theme.knobOnlyOnHover)
            Picker("Fill", selection: $theme.sliderFillStyle) {
                Text("Solid colour").tag(SliderFillStyle.solid)
                Text("Artwork colour").tag(SliderFillStyle.artwork)
            }
        }
    }

    private func color(_ title: String, _ key: WritableKeyPath<Theme, CodableColor>) -> some View {
        ColorPicker(title, selection: Binding(get: { theme[keyPath: key].color },
                                              set: { theme[keyPath: key] = CodableColor($0) }),
                    supportsOpacity: true)
    }

    private func radius(_ title: String, _ key: WritableKeyPath<Theme, CGFloat>, _ range: ClosedRange<Double>) -> some View {
        LabeledSlider(title: title, value: $theme[dynamicMember: key].double, range: range, step: 1,
                      format: { "\(Int($0)) pt" })
    }
}
