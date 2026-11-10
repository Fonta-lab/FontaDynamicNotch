import SwiftUI

/// Themed horizontal slider (0…1). The knob shows on hover or while dragging.
/// `onChange` fires continuously while dragging; `onEnd` once on release.
struct NotchSlider: View {
    let value: Double
    let theme: Theme
    var enabled = true
    var onChange: ((Double) -> Void)? = nil
    var onEnd: ((Double) -> Void)? = nil

    @State private var dragValue: Double?
    @State private var hovering = false

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let v = min(1, max(0, dragValue ?? value))
            let showKnob = enabled && (hovering || dragValue != nil)
            ZStack(alignment: .leading) {
                Capsule().fill(theme.sliderTrack).frame(height: theme.sliderHeight)
                Capsule().fill(theme.sliderFill.opacity(enabled ? 1 : 0.35))
                    .frame(width: max(theme.sliderHeight, w * v), height: theme.sliderHeight)
                Circle()
                    .fill(theme.sliderKnob)
                    .frame(width: theme.knobSize, height: theme.knobSize)
                    .offset(x: w * v - theme.knobSize / 2)
                    .opacity(showKnob ? 1 : 0)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        guard enabled else { return }
                        let f = min(1, max(0, g.location.x / w))
                        dragValue = f
                        onChange?(f)
                    }
                    .onEnded { g in
                        guard enabled else { return }
                        let f = min(1, max(0, g.location.x / w))
                        onEnd?(f)
                        dragValue = nil
                    }
            )
        }
        .frame(height: max(theme.knobSize, 12))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}
