import SwiftUI

/// Open-state background (SPEC §4.4): black base, the cover's dominant colour on top, faded to pure
/// black right around the real notch, as if the notch cast a short shadow.
struct NotchBackgroundView: View {
    let geometry: NotchGeometry
    let theme: Theme
    let color: Color?

    var body: some View {
        ZStack(alignment: .topLeading) {
            theme.fallbackBackground
            if let color {
                color.mask {
                    NotchShadowMask(notch: geometry.closedRect(wings: false),
                                    bottomRadius: theme.closedBottomRadius,
                                    fade: theme.notchBlendRadius)
                }
            }
        }
    }
}

/// White = colour visible, black = black shows. Black over the notch, then a short fade that follows
/// the notch's rectangular shape (rounded bottom corners) and reaches full colour after `fade` points.
struct NotchShadowMask: View {
    let notch: CGRect
    let bottomRadius: CGFloat
    let fade: CGFloat

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            let steps = 16
            // Outermost ring first; each smaller ring paints over the previous one.
            for k in 0...steps {
                let t = 1 - Double(k) / Double(steps)          // 1 = outer edge, 0 = notch
                let d = fade * t
                let rect = CGRect(x: notch.minX - d, y: -1,
                                  width: notch.width + 2 * d, height: notch.height + 1 + d)
                let r = bottomRadius + d
                let path = Path(roundedRect: rect, cornerRadii: RectangleCornerRadii(
                    topLeading: 0, bottomLeading: r, bottomTrailing: r, topTrailing: 0))
                let level = t * t * (3 - 2 * t)                // smooth ease
                ctx.fill(path, with: .color(white: level))
            }
        }
        .luminanceToAlpha()
    }
}
