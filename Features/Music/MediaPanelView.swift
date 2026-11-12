import SwiftUI

/// The music part of the Home tab: cover on the left; volume row directly under the notch,
/// then title, artist, progress and controls (or a message when nothing can be shown).
struct MediaPanelView: View {
    let theme: Theme
    let settings: AppSettings
    /// Shared with the closed wing's cover, so the cover grows out of the wing when the notch opens.
    let coverNamespace: Namespace.ID
    private var spotify: SpotifyService { .shared }

    @Environment(\.notchActions) private var actions
    @State private var showDevices = false

    private let side: CGFloat = 112

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            CoverImage(image: spotify.track != nil && spotify.isRunning ? spotify.artwork : nil, radius: theme.coverRadiusOpen)
                .frame(width: side, height: side)
                .modifier(CoverMatch(namespace: coverNamespace))

            VStack(alignment: .leading, spacing: 0) {
                VolumeRow(theme: theme, showDevices: $showDevices)
                    .frame(height: 18)
                Spacer(minLength: 2)
                mainContent
            }
            .frame(height: side)
            .overlay(alignment: .top) {
                if showDevices {
                    ZStack(alignment: .top) {
                        // Clicking anywhere else in this column closes the list.
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .onTapGesture { showDevices = false }
                        OutputDeviceList(theme: theme) { showDevices = false }
                    }
                    .padding(.top, 22)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
            .animation(Motion.change, value: showDevices)
        }
        .onChange(of: showDevices) { _, open in actions.setCloseBlocker(.outputList, open) }
        .onChange(of: actions.dismissToken) { showDevices = false }
        .onDisappear { actions.setCloseBlocker(.outputList, false) }
        // Resync with Spotify every 5 s, only while open and playing (this view only exists while open).
        .task(id: spotify.isPlaying) {
            guard spotify.isPlaying else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if Task.isCancelled { break }
                spotify.refresh()
            }
        }
    }

    @ViewBuilder private var mainContent: some View {
        if !spotify.isRunning {
            message("Spotify isn't open", button: "Open Spotify") { spotify.openSpotify() }
        } else if spotify.permissionDenied {
            message("Spotify control isn't allowed", button: "Allow Spotify control") { spotify.openAutomationSettings() }
        } else if let track = spotify.track {
            nowPlaying(track)
        } else {
            message("Nothing playing", button: nil) {}
        }
    }

    private func nowPlaying(_ track: SpotifyTrack) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MarqueeText(text: track.name.isEmpty ? "Unknown" : track.name,
                        font: .body.weight(.semibold), color: theme.primaryText,
                        enabled: settings.marqueeEnabled)
            MarqueeText(text: track.artist, font: .callout, color: theme.secondaryText,
                        enabled: settings.marqueeEnabled)
            Spacer(minLength: 4)
            ProgressBar(theme: theme)
            Spacer(minLength: 2)
            controls
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            control("shuffle", "Shuffle", active: spotify.shuffling) { spotify.toggleShuffle() }
            control("backward.fill", "Previous track") { spotify.previousTrack() }
            control(spotify.isPlaying ? "pause.fill" : "play.fill", spotify.isPlaying ? "Pause" : "Play",
                    size: theme.controlIconSize + 4) { spotify.playPause() }
            control("forward.fill", "Next track") { spotify.nextTrack() }
            control("repeat", "Repeat", active: spotify.repeating) { spotify.toggleRepeat() }
        }
    }

    private func control(_ symbol: String, _ label: String, active: Bool? = nil, size: CGFloat? = nil,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size ?? theme.controlIconSize, weight: .semibold))
                .foregroundStyle(theme.iconColor.opacity(active == false ? 0.5 : 1))
                .frame(maxWidth: .infinity, minHeight: 22)
                // Shuffle / Repeat "on" is shown by a dot too, not only by brightness.
                .overlay(alignment: .bottom) {
                    if active == true {
                        Circle().fill(theme.accent).frame(width: 4, height: 4).offset(y: 4)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius, tint: theme.primaryText))
        .help(label)
        .accessibilityLabel(label)
        .accessibilityValue(active.map { $0 ? "On" : "Off" } ?? "")
    }

    private func message(_ text: String, button: String?, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Spacer(minLength: 0)
            Text(text).font(.body.weight(.semibold)).foregroundStyle(theme.secondaryText)
            if let button {
                Button(button, action: action)
                    .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius, filled: true, tint: theme.primaryText))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Plain button with a soft highlight on hover and press.
struct NotchButtonStyle: ButtonStyle {
    let radius: CGFloat
    var filled = false
    /// Extra inner padding for filled buttons. Off when the label sets its own size (tool panels).
    var padded = true
    /// Colour of the highlight: the theme's primary text colour, so it suits the theme.
    var tint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        NotchButtonBody(configuration: configuration, radius: radius, filled: filled, padded: padded, tint: tint)
    }
}

/// Holds the hover state in a real view (state stored on a ButtonStyle isn't reliably kept).
private struct NotchButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let radius: CGFloat
    let filled: Bool
    let padded: Bool
    let tint: Color
    @State private var hovering = false

    var body: some View {
        configuration.label
            .padding(.horizontal, filled && padded ? Spacing.m : 0)
            .padding(.vertical, filled && padded ? Spacing.xs : 0)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint.opacity(fill))
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .contentShape(Rectangle())
            .notchHover { hovering = $0 }
            .animation(Motion.feedback, value: hovering)
            .animation(Motion.feedback, value: configuration.isPressed)
    }

    private var fill: Double {
        if configuration.isPressed { return Highlight.pressed }
        if hovering { return filled ? Highlight.selected : Highlight.hover }
        return filled ? Highlight.filled : 0
    }
}
