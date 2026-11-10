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
        // Each item sits as far from the wing's outer side as from the bottom edge.
        ZStack(alignment: .topLeading) {
            if model.leftWingWidth > 0 {
                let side = max(12, h - 10)
                let inset = (h - side) / 2
                CoverImage(image: spotify.artwork, radius: theme.coverRadiusClosed)
                    .frame(width: side, height: side)
                    .position(x: left.minX + inset + side / 2, y: h / 2)
                    .transition(.opacity)
            }
            switch model.rightWingContent {
            case .bars:
                let count = min(8, max(3, settings.musicBarCount))
                let barsW = CGFloat(count) * 5 - 2
                let barsH = max(8, h - 16)
                let inset = (h - barsH) / 2
                MusicBarsView(count: count, speed: settings.musicBarSpeed, color: barColor(theme), playing: spotify.isPlaying)
                    .frame(width: barsW, height: barsH)
                    .position(x: right.maxX - inset - barsW / 2, y: h / 2)
                    .transition(.opacity)
            case .time:
                // The digits' visible height is the font's cap height, so that's what we measure from.
                let inset = (h - ClosedTimeView.capHeight) / 2
                ClosedTimeView(theme: theme)
                    .frame(width: max(10, right.width - inset), height: h, alignment: .trailing)
                    .position(x: right.maxX - inset - (right.width - inset) / 2, y: h / 2)
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

/// The running time in the closed right wing: the timer ending first, otherwise the running
/// stopwatch (without centiseconds). Updates once a second, only while visible.
struct ClosedTimeView: View {
    let theme: Theme
    static let fontSize: CGFloat = 14
    static let capHeight = NSFont.systemFont(ofSize: fontSize, weight: .semibold).capHeight
    private var timers: TimerStore { .shared }
    private var stopwatch: StopwatchStore { .shared }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            if let text = text(at: ctx.date) {
                Text(text)
                    .font(.system(size: Self.fontSize, weight: .semibold).monospacedDigit())
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private func text(at date: Date) -> String? {
        if let r = timers.soonestRunning { return TimeFormat.countdown(r.endDate.timeIntervalSince(date)) }
        if stopwatch.isRunning { return StopwatchFormat.coarse(stopwatch.elapsed(at: date)) }
        return nil
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
