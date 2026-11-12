import SwiftUI

/// Speaker (click = mute), system volume slider, output-device button (SPEC §5.2, §6).
struct VolumeRow: View {
    let theme: Theme
    @Binding var showDevices: Bool
    private var audio: AudioService { .shared }

    var body: some View {
        let s = audio.state
        HStack(spacing: Spacing.s) {
            Button { audio.toggleMute() } label: {
                Image(systemName: speakerSymbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.iconColor.opacity(audio.isEffectivelyMuted ? 0.5 : 0.9))
                    .frame(width: 20, height: 18)
            }
            .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius(height: 18), tint: theme.primaryText))

            NotchSlider(value: Double(s.isMuted ? 0 : s.volume), theme: theme, enabled: s.hasVolumeControl,
                        onChange: { audio.setVolume($0) }, onEnd: { audio.setVolume($0) })
                .help(s.hasVolumeControl ? "" : "This device has no volume control")

            Button { showDevices.toggle() } label: {
                Image(systemName: audio.currentDevice?.symbol ?? "hifispeaker")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.iconColor.opacity(showDevices ? 1 : 0.8))
                    .frame(width: 22, height: 18)
            }
            .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius(height: 18), tint: theme.primaryText))
            .help(audio.currentDevice?.name ?? "Output")
        }
    }

    private var speakerSymbol: String {
        if audio.isEffectivelyMuted { return "speaker.slash.fill" }
        let v = audio.state.volume
        return v < 0.34 ? "speaker.wave.1.fill" : v < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
    }
}

/// Inline list of output devices, shown under the volume row. The notch stays open while it's shown.
struct OutputDeviceList: View {
    let theme: Theme
    let onPick: () -> Void
    private var audio: AudioService { .shared }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(audio.state.devices) { device in
                    Button {
                        audio.selectDevice(device.id)
                        onPick()
                    } label: {
                        HStack(spacing: Spacing.s) {
                            Image(systemName: device.symbol).frame(width: 16)
                            Text(device.name).lineLimit(1).truncationMode(.tail)
                            Spacer(minLength: Spacing.xs)
                            if device.id == audio.state.defaultDeviceID {
                                Image(systemName: "checkmark").font(.caption.weight(.bold))
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.primaryText)
                        .padding(.horizontal, Spacing.s)
                        .frame(height: 24)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius(height: 24), tint: theme.primaryText))
                }
            }
            .padding(Spacing.xs)
        }
        .frame(maxHeight: 88)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            // Rows sit Spacing.xs in, so the list's corner is the rows' corner plus that gap.
            RoundedRectangle(cornerRadius: theme.buttonRadius(height: 24) + Spacing.xs, style: .continuous)
                .fill(Color.black.opacity(0.88))
                .overlay(RoundedRectangle(cornerRadius: theme.buttonRadius(height: 24) + Spacing.xs, style: .continuous)
                    .stroke(theme.primaryText.opacity(Highlight.hover), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
    }
}
