import SwiftUI

/// Theme editor section for the notch surface: Solid or Liquid Glass, and the glass options.
struct SurfaceSettingsSection: View {
    @Binding var theme: Theme

    var body: some View {
        Section {
            Picker("Style", selection: $theme.surfaceStyle) {
                Text("Solid").tag(SurfaceStyle.solid)
                Text("Liquid Glass").tag(SurfaceStyle.liquidGlass)
            }
            .pickerStyle(.segmented)
            if theme.isGlass {
                Picker("Glass", selection: $theme.glassVariant) {
                    Text("Regular").tag(GlassVariant.regular)
                    Text("Clear").tag(GlassVariant.clear)
                }
                .pickerStyle(.segmented)
                // Same idea as macOS's own Liquid Glass slider: clear on the left, tinted on the right.
                LabeledContent("Transparency") {
                    Slider(value: $theme.glassOpacity, in: 0...1) {
                        Text("Transparency")
                    } minimumValueLabel: {
                        Image(systemName: "rectangle.on.rectangle").help("Clear")
                    } maximumValueLabel: {
                        Image(systemName: "rectangle.fill.on.rectangle.fill").help("Tinted")
                    }
                    .labelsHidden()
                }
                LabeledSlider(title: "Blur behind the notch", value: $theme.glassBlur, range: 0...1,
                              format: { $0 == 0 ? "Off" : "\(Int($0 * 100))%" })
                    .help("How much what's under the notch is blurred. Off = only the glass's own blur.")
                Toggle(isOn: $theme.glassTintEnabled) {
                    Text("Tint the glass")
                    if theme.useArtworkColor {
                        Text("Doesn't apply while music plays: “Use artwork colour for the background” (in Colours) is on, so the album cover's colour tints the glass instead. Your tint shows only when nothing is playing.")
                            .foregroundStyle(.orange)
                    } else {
                        Text("Your colour tints the glass all the time.")
                    }
                }
                ColorPicker("Tint colour", selection: Binding(get: { theme.glassTintColor.color },
                                                              set: { theme.glassTintColor = CodableColor($0) }),
                            supportsOpacity: false)
                    .disabled(!theme.glassTintEnabled)
                LabeledSlider(title: "Tint intensity", value: $theme.glassTintIntensity, range: 0...1,
                              format: { "\(Int($0 * 100))%" })
                LabeledSlider(title: "Darken for legibility", value: $theme.glassDimming, range: 0...0.7,
                              format: { "\(Int($0 * 100))%" })
                Toggle("Glass also when closed", isOn: $theme.glassWhenClosed)
            }
        } header: {
            Text("Surface")
        } footer: {
            if theme.isGlass { footer }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !GlassSupport.isFullGlassAvailable {
                Label("Full Liquid Glass requires macOS 26. This Mac uses a blurred material instead.",
                      systemImage: "info.circle")
            } else {
                Label("Full Liquid Glass requires macOS 26.", systemImage: "info.circle")
            }
            Text("Corner rounding and shadow below apply to the glass too. With “Use artwork colour” on, the cover colour tints the glass (at the tint intensity) while music plays. Off when closed: the closed notch stays black.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
