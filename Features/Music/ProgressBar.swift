import SwiftUI

/// Song progress: draggable, seeks when released. Times underneath.
/// Redraws at most 30×/s and only while playing (it only exists while the notch is open).
struct ProgressBar: View {
    let theme: Theme
    private var spotify: SpotifyService { .shared }

    @State private var dragFraction: Double?

    var body: some View {
        let duration = spotify.track?.duration ?? 0
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !spotify.isPlaying || dragFraction != nil)) { ctx in
            let pos = dragFraction.map { $0 * duration } ?? spotify.currentPosition(at: ctx.date)
            let fraction = duration > 0 ? min(1, max(0, pos / duration)) : 0
            VStack(spacing: Spacing.xs) {
                NotchSlider(value: fraction, theme: theme, label: "Song position", enabled: duration > 0,
                            onChange: { dragFraction = $0 },
                            onEnd: { f in
                                if duration > 0 { spotify.seek(to: f * duration) }
                                dragFraction = nil
                            })
                HStack {
                    Text(Self.format(pos))
                    Spacer()
                    Text(Self.format(duration))
                }
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(theme.secondaryText)
            }
        }
        .onChange(of: spotify.track?.id) { dragFraction = nil }   // track changed mid-drag: drop the drag
    }

    static func format(_ s: Double) -> String { TimeFormat.clock(s.rounded(.down)) }
}
