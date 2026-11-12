import SwiftUI

/// Themed horizontal slider (0…1). Knob shape, knob-on-hover and fill colour come from the theme.
/// `onChange` fires continuously while dragging; `onEnd` once on release.
struct NotchSlider: View {
    let value: Double
    let theme: Theme
    /// What VoiceOver calls it ("Volume", "Song position"…).
    var label = ""
    var enabled = true
    var onChange: ((Double) -> Void)? = nil
    var onEnd: ((Double) -> Void)? = nil
    /// true when a drag starts, false when it ends.
    var onEditingChanged: ((Bool) -> Void)? = nil

    @State private var dragValue: Double?
    @State private var hovering = false

    /// How much bigger the knob gets on hover.
    static let hoverKnobScale: CGFloat = 1.25

    private var knobGrown: Bool {
        enabled && (hovering || dragValue != nil) && !Motion.reduceMotion
    }

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let v = min(1, max(0, dragValue ?? value))
            let showKnob = enabled && theme.knobShape != .none
                && (!theme.knobOnlyOnHover || hovering || dragValue != nil)
            let knobW = theme.knobShape == .capsule ? theme.knobSize * 1.7 : theme.knobSize
            // Fill and knob are drawn as shapes at their exact (fractional) position, not moved with
            // offset/frame: those snap to whole pixels, which made a slow knob hop pixel by pixel.
            ZStack {
                Capsule().fill(theme.sliderTrack).frame(height: theme.sliderHeight)
                SliderCapsule(x: 0, width: max(theme.sliderHeight, w * v), height: theme.sliderHeight)
                    .fill(fillColor.opacity(enabled ? 1 : 0.35))
                // Grows a little while the mouse is over the slider or dragging it (not with Reduce Motion).
                SliderKnob(color: theme.sliderKnob, shadow: theme.knob3D,
                           shape: SliderCapsule(x: min(w - knobW, max(0, w * v - knobW / 2)), width: knobW,
                                                height: theme.knobSize, scale: knobGrown ? Self.hoverKnobScale : 1))
                    .opacity(showKnob ? 1 : 0)
                    .animation(Motion.feedback, value: knobGrown)
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
        .notchHover { hovering = $0 }
        .animation(Motion.feedback, value: hovering)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int((min(1, max(0, value)) * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            guard enabled else { return }
            let step = direction == .increment ? 0.05 : direction == .decrement ? -0.05 : 0
            onEnd?(min(1, max(0, value + step)))
        }
    }

    private var fillColor: Color {
        if theme.sliderFillStyle == .artwork, let c = SpotifyService.shared.artworkColor { return c.lightenedForBars.color }
        return theme.sliderFill
    }
}

/// A capsule at an exact horizontal position inside the slider's full frame, vertically centred.
/// Drawing it as a path (instead of offset + frame) keeps fractional positions: the edge is
/// anti-aliased across pixels, so slow movement glides. `scale` (animatable) grows it about its centre.
struct SliderCapsule: InsettableShape {
    var x: CGFloat
    var width: CGFloat
    var height: CGFloat
    var scale: CGFloat = 1
    var insetAmount: CGFloat = 0

    var animatableData: CGFloat {
        get { scale }
        set { scale = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = width * scale, h = height * scale
        let cx = rect.minX + x + width / 2, cy = rect.midY
        let r = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h).insetBy(dx: insetAmount, dy: insetAmount)
        return Capsule().path(in: r)
    }

    func inset(by amount: CGFloat) -> SliderCapsule {
        var s = self
        s.insetAmount += amount
        return s
    }
}

/// The slider knob, in the theme's knob colour exactly (no shading). With "Knob shadow" on, a soft
/// shadow underneath separates it from a same-coloured fill and lifts it a little off the track.
private struct SliderKnob: View {
    let color: Color
    let shadow: Bool
    let shape: SliderCapsule

    var body: some View {
        if shadow {
            shape.fill(color)
                .shadow(color: .black.opacity(0.4), radius: 1.5, y: 0.5)   // a crisp edge against the fill
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1.5)     // and a soft lift
        } else {
            shape.fill(color)
        }
    }
}
