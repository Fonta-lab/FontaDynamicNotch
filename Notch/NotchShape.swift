import SwiftUI

/// The notch outline. It hangs from the top of its rect; `left` and `right` are how far it reaches
/// from the centre line (the notch centre) on each side, so the closed wings can be uneven.
/// Top corners are outward concave fillets that merge into the menu bar; bottom corners are rounded.
struct NotchShape: Shape {
    var left: CGFloat
    var right: CGFloat
    var height: CGFloat
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>> {
        get { AnimatablePair(AnimatablePair(left, right), AnimatablePair(height, AnimatablePair(topRadius, bottomRadius))) }
        set {
            left = newValue.first.first
            right = newValue.first.second
            height = newValue.second.first
            topRadius = newValue.second.second.first
            bottomRadius = newValue.second.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let x0 = rect.midX - left
        let x1 = rect.midX + right
        let top = rect.minY
        let bottom = top + height
        let width = x1 - x0
        let tr = max(0, min(topRadius, height / 2))
        let br = max(0, min(bottomRadius, width / 2, height - tr))

        var p = Path()
        p.move(to: CGPoint(x: x0 - tr, y: top))
        p.addQuadCurve(to: CGPoint(x: x0, y: top + tr), control: CGPoint(x: x0, y: top))
        p.addLine(to: CGPoint(x: x0, y: bottom - br))
        p.addQuadCurve(to: CGPoint(x: x0 + br, y: bottom), control: CGPoint(x: x0, y: bottom))
        p.addLine(to: CGPoint(x: x1 - br, y: bottom))
        p.addQuadCurve(to: CGPoint(x: x1, y: bottom - br), control: CGPoint(x: x1, y: bottom))
        p.addLine(to: CGPoint(x: x1, y: top + tr))
        p.addQuadCurve(to: CGPoint(x: x1 + tr, y: top), control: CGPoint(x: x1, y: top))
        p.closeSubpath()
        return p
    }
}
