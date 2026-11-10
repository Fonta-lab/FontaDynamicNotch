import SwiftUI

/// Song progress: draggable, seeks when released. Times underneath.
/// Redraws at most 30×/s and only while playing (it only exists while the notch is open).
struct ProgressBar: View {
    let theme: Theme
    private var spotify: SpotifyService { .shared }

    @State private var dragFraction: Double?
    @State private var hovering = false

    var body: some View {
        let duration = spotify.track?.duration ?? 0
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !spotify.isPlaying || dragFraction != nil)) { ctx in
            let pos = dragFraction.map { $0 * duration } ?? spotify.currentPosition(at: ctx.date)
            let fraction = duration > 0 ? min(1, max(0, pos / duration)) : 0
            VStack(spacing: 3) {
                bar(fraction: fraction, duration: duration)
                HStack {
                    Text(Self.format(pos))
                    Spacer()
                    Text(Self.format(duration))
                }
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(theme.secondaryText)
            }
        }
        .onChange(of: spotify.track?.id) { dragFraction = nil }   // track changed mid-drag: drop the drag
    }

    private func bar(fraction: Double, duration: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let showKnob = hovering || dragFraction != nil
            ZStack(alignment: .leading) {
                Capsule().fill(theme.sliderTrack).frame(height: theme.sliderHeight)
                Capsule().fill(theme.sliderFill).frame(width: max(theme.sliderHeight, w * fraction), height: theme.sliderHeight)
                Circle()
                    .fill(theme.sliderKnob)
                    .frame(width: theme.knobSize, height: theme.knobSize)
                    .offset(x: w * fraction - theme.knobSize / 2)
                    .opacity(showKnob ? 1 : 0)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in dragFraction = min(1, max(0, v.location.x / max(1, w))) }
                    .onEnded { v in
                        let f = min(1, max(0, v.location.x / max(1, w)))
                        if duration > 0 { spotify.seek(to: f * duration) }
                        dragFraction = nil
                    }
            )
        }
        .frame(height: max(theme.knobSize, 12))
        .notchHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    static func format(_ s: Double) -> String {
        let t = Int(max(0, s).rounded(.down))
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60)
                         : String(format: "%d:%02d", t / 60, t % 60)
    }
}
