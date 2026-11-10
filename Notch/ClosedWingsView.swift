import SwiftUI

/// What sits beside the closed notch (SPEC §4.1): the album cover on the left; on the right the
/// running time (if a timer is running) or the music bars.
struct ClosedWingsView: View {
    let model: NotchViewModel
    let settings: AppSettings
    private var spotify: SpotifyService { .shared }

    var body: some View {
        let g = model.geometry
        let theme = model.theme
        let h = g.closedHeight
        let left = g.leftWing(model.leftWingWidth)
        let right = g.rightWing(model.rightWingWidth)
        ZStack(alignment: .topLeading) {
            if model.leftWingWidth > 0 {
                let side = max(12, h - 10)
                CoverImage(image: spotify.artwork, radius: theme.coverRadiusClosed)
                    .frame(width: side, height: side)
                    .position(x: left.midX, y: left.midY)
                    .transition(.opacity)
            }
            switch model.rightWingContent {
            case .bars:
                let count = min(8, max(3, settings.musicBarCount))
                MusicBarsView(count: count, speed: settings.musicBarSpeed, color: barColor(theme), playing: spotify.isPlaying)
                    .frame(width: CGFloat(count) * 5, height: max(8, h - 16))
                    .position(x: right.midX, y: right.midY)
                    .transition(.opacity)
            case .time:
                ClosedTimeView(theme: theme)
                    .frame(width: right.width, height: h)
                    .position(x: right.midX, y: right.midY)
                    .transition(.opacity)
            case .none:
                EmptyView()
            }
        }
    }

    private func barColor(_ theme: Theme) -> Color {
        if settings.musicBarsUseArtworkColor, let c = spotify.artworkColor { return c.lightenedForBars.color }
        return theme.accent
    }
}

/// The running time in the closed right wing. Updates once a second, only while visible.
struct ClosedTimeView: View {
    let theme: Theme
    private var timers: TimerStore { .shared }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            if let r = timers.soonestRunning {
                Text(TimeFormat.countdown(r.endDate.timeIntervalSince(ctx.date)))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

/// Album cover with a placeholder when there is no artwork.
struct CoverImage: View {
    let image: NSImage?
    let radius: CGFloat

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(Color.white.opacity(0.12))
                Image(systemName: "music.note").foregroundStyle(.white.opacity(0.5))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
