import SwiftUI

/// Open-state background (SPEC §4.4): black base, the cover's dominant colour on top, faded to pure
/// black around the real notch as if the notch cast a shadow downward.
struct NotchBackgroundView: View {
    let geometry: NotchGeometry
    let theme: Theme
    let color: Color?

    var body: some View {
        ZStack(alignment: .topLeading) {
            theme.fallbackBackground
            if let color {
                color.mask { NotchShadowMask(notch: geometry.notchRect, blend: theme.notchBlendRadius) }
            }
        }
    }
}

/// White = colour visible, transparent = black shows. An oval gradient centred on the top of the notch:
/// fully transparent over the whole notch, then a smooth fade to opaque over `blend` points.
struct NotchShadowMask: View {
    let notch: CGRect
    let blend: CGFloat

    var body: some View {
        // Half-ellipse hanging from the top edge, reaching `blend` beyond the notch on each side and below.
        let a = notch.width / 2 + blend          // horizontal semi-axis
        let b = notch.height + blend             // vertical semi-axis
        // Where the notch's bottom corner sits inside the ellipse (0 = centre, 1 = edge).
        // Start fading a little before the notch corner, so the fade is long and soft (the corner stays ~95% dark).
        let inner = 0.8 * min(0.95, sqrt(pow(notch.width / 2 / a, 2) + pow(notch.height / b, 2)))
        // Smooth ease-out from solid to clear between `inner` and the edge.
        let fade: [Gradient.Stop] = (0...8).map { i in
            let t = Double(i) / 8
            let s = t * t * (3 - 2 * t)
            return .init(color: .black.opacity(1 - s), location: inner + (1 - inner) * t)
        }

        ZStack(alignment: .topLeading) {
            Color.white
            EllipticalGradient(stops: [.init(color: .black, location: 0)] + fade)
            .frame(width: a * 2, height: b * 2)
            .offset(x: notch.midX - a, y: -b)
            .blendMode(.destinationOut)   // where the gradient is solid, the white is removed
        }
        .compositingGroup()
    }
}
