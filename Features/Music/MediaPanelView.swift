import SwiftUI

/// The music part of the Home tab: cover, (volume row in M4), title, artist, progress, controls.
struct MediaPanelView: View {
    let theme: Theme
    let settings: AppSettings
    private var spotify: SpotifyService { .shared }

    var body: some View {
        Group {
            if !spotify.isRunning {
                placeholder(icon: "music.note", text: "Spotify isn't open", button: "Open Spotify") { spotify.openSpotify() }
            } else if spotify.permissionDenied {
                placeholder(icon: "lock", text: "Spotify control isn't allowed", button: "Allow Spotify control") { spotify.openAutomationSettings() }
            } else if let track = spotify.track {
                nowPlaying(track)
            } else {
                placeholder(icon: "music.note", text: "Nothing playing", button: nil) {}
            }
        }
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

    private func nowPlaying(_ track: SpotifyTrack) -> some View {
        HStack(alignment: .top, spacing: 14) {
            CoverImage(image: spotify.artwork, radius: theme.coverRadiusOpen)
                .frame(width: 108, height: 108)

            VStack(alignment: .leading, spacing: 0) {
                // Reserved for the volume row (M4), directly under the notch.
                Color.clear.frame(height: 18)
                Spacer(minLength: 4)
                MarqueeText(text: track.name.isEmpty ? "Unknown" : track.name,
                            font: .system(size: 13, weight: .semibold), color: theme.primaryText,
                            enabled: settings.marqueeEnabled)
                MarqueeText(text: track.artist, font: .system(size: 12), color: theme.secondaryText,
                            enabled: settings.marqueeEnabled)
                Spacer(minLength: 6)
                ProgressBar(theme: theme)
                Spacer(minLength: 4)
                controls
            }
            .frame(height: 108)
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
                .frame(maxWidth: .infinity, minHeight: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius))
    }

    private func placeholder(icon: String, text: String, button: String?, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 22)).foregroundStyle(theme.secondaryText)
            Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.secondaryText)
            if let button {
                Button(button, action: action)
                    .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius, filled: true))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Plain button with a soft highlight on hover and press.
struct NotchButtonStyle: ButtonStyle {
    let radius: CGFloat
    var filled = false
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, filled ? 12 : 0)
            .padding(.vertical, filled ? 5 : 0)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.2 : (hovering || filled) ? 0.1 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
