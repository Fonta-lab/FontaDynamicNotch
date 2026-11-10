import SwiftUI

/// What sits beside the closed notch: the album cover (left) and the bars (right).
struct ClosedWingsView: View {
    let geometry: NotchGeometry
    let theme: Theme
    let settings: AppSettings
    private var spotify: SpotifyService { .shared }

    var body: some View {
        let h = geometry.notchRect.height
        let coverSide = max(12, h - 10)
        ZStack(alignment: .topLeading) {
            CoverImage(image: spotify.artwork, radius: theme.coverRadiusClosed)
                .frame(width: coverSide, height: coverSide)
                .position(x: geometry.leftWing.midX, y: geometry.leftWing.midY)

            MusicBarsView(count: min(8, max(3, settings.musicBarCount)),
                          speed: settings.musicBarSpeed,
                          color: barColor,
                          playing: spotify.isPlaying)
                .frame(width: CGFloat(min(8, max(3, settings.musicBarCount))) * 5, height: max(8, h - 16))
                .position(x: geometry.rightWing.midX, y: geometry.rightWing.midY)
        }
    }

    private var barColor: Color {
        if settings.musicBarsUseArtworkColor, let c = spotify.artworkColor { return c.lightenedForBars.color }
        return theme.accent
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
