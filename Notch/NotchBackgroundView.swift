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
                color.mask {
                    let n = geometry.notchRect
                    let blend = theme.notchBlendRadius
                    ZStack(alignment: .topLeading) {
                        Color.white
                        // Black (= transparent after luminanceToAlpha) over the notch, feathered by the blur.
                        RoundedRectangle(cornerRadius: blend / 2, style: .continuous)
                            .fill(Color.black)
                            .frame(width: n.width + blend, height: n.height + blend * 1.5)
                            .offset(x: n.minX - blend / 2, y: -blend)
                            .blur(radius: blend / 2)
                    }
                    .compositingGroup()
                    .luminanceToAlpha()
                }
            }
        }
    }
}
