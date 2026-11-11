import SwiftUI

/// Themed horizontal slider (0…1). Knob shape, knob-on-hover and fill colour come from the theme.
/// `onChange` fires continuously while dragging; `onEnd` once on release.
struct NotchSlider: View {
    let value: Double
    let theme: Theme
    var enabled = true
    var onChange: ((Double) -> Void)? = nil
    var onEnd: ((Double) -> Void)? = nil
    /// true when a drag starts, false when it ends.
    var onEditingChanged: ((Bool) -> Void)? = nil

    @State private var dragValue: Double?
    @State private var hovering = false

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let v = min(1, max(0, dragValue ?? value))
            let showKnob = enabled && theme.knobShape != .none
                && (!theme.knobOnlyOnHover || hovering || dragValue != nil)
            let knobW = theme.knobShape == .capsule ? theme.knobSize * 1.7 : theme.knobSize
            ZStack(alignment: .leading) {
                Capsule().fill(theme.sliderTrack).frame(height: theme.sliderHeight)
                Capsule().fill(fillColor.opacity(enabled ? 1 : 0.35))
                    .frame(width: max(theme.sliderHeight, w * v), height: theme.sliderHeight)
                Capsule()
                    .fill(theme.sliderKnob)
                    .frame(width: knobW, height: theme.knobSize)
                    .offset(x: min(w - knobW, max(0, w * v - knobW / 2)))
                    .opacity(showKnob ? 1 : 0)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        guard enabled else { return }
                        let f = min(1, max(0, g.location.x / w))
                        if dragValue == nil { onEditingChanged?(true) }
                        dragValue = f
                        onChange?(f)
                    }
                    .onEnded { g in
                        guard enabled else { return }
                        let f = min(1, max(0, g.location.x / w))
                        onEnd?(f)
                        dragValue = nil
                        onEditingChanged?(false)
                    }
            )
        }
        .frame(height: max(theme.knobSize, 12))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    private var fillColor: Color {
        if theme.sliderFillStyle == .artwork, let c = SpotifyService.shared.artworkColor { return c.lightenedForBars.color }
        return theme.sliderFill
    }
}
