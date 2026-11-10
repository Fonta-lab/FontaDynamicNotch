import SwiftUI

/// The music part of the Home tab: cover on the left; volume row directly under the notch,
/// then title, artist, progress and controls (or a message when nothing can be shown).
struct MediaPanelView: View {
    let theme: Theme
    let settings: AppSettings
    private var spotify: SpotifyService { .shared }

    @Environment(\.notchActions) private var actions
    @State private var showDevices = false

    private let side: CGFloat = 112

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            CoverImage(image: spotify.track != nil && spotify.isRunning ? spotify.artwork : nil, radius: theme.coverRadiusOpen)
                .frame(width: side, height: side)

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
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeOut(duration: 0.15), value: showDevices)
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
                        font: .system(size: 13, weight: .semibold), color: theme.primaryText,
                        enabled: settings.marqueeEnabled)
            MarqueeText(text: track.artist, font: .system(size: 12), color: theme.secondaryText,
                        enabled: settings.marqueeEnabled)
            Spacer(minLength: 4)
            ProgressBar(theme: theme)
            Spacer(minLength: 2)
            controls
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            control("shuffle", active: spotify.shuffling) { spotify.toggleShuffle() }
            control("backward.fill") { spotify.previousTrack() }
            control(spotify.isPlaying ? "pause.fill" : "play.fill", size: theme.controlIconSize + 4) { spotify.playPause() }
            control("forward.fill") { spotify.nextTrack() }
            control("repeat", active: spotify.repeating) { spotify.toggleRepeat() }
        }
    }

    private func control(_ symbol: String, active: Bool? = nil, size: CGFloat? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size ?? theme.controlIconSize, weight: .semibold))
                .foregroundStyle(theme.iconColor.opacity(active == false ? 0.4 : 1))
                .frame(maxWidth: .infinity, minHeight: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius))
    }

    private func message(_ text: String, button: String?, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.secondaryText)
            if let button {
                Button(button, action: action)
                    .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius, filled: true))
                    .font(.system(size: 12, weight: .semibold))
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

    func makeBody(configuration: Configuration) -> some View {
        NotchButtonBody(configuration: configuration, radius: radius, filled: filled, padded: padded)
    }
}

/// Holds the hover state in a real view (state stored on a ButtonStyle isn't reliably kept).
private struct NotchButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let radius: CGFloat
    let filled: Bool
    let padded: Bool
    @State private var hovering = false

    var body: some View {
        configuration.label
            .padding(.horizontal, filled && padded ? 12 : 0)
            .padding(.vertical, filled && padded ? 5 : 0)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.22 : hovering ? (filled ? 0.18 : 0.12) : (filled ? 0.1 : 0)))
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
