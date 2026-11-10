import SwiftUI

/// The notch outline, centred horizontally at the top of its rect.
/// Top corners are outward concave fillets that merge into the menu bar; bottom corners are rounded.
struct NotchShape: Shape {
    var width: CGFloat
    var height: CGFloat
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(width, height), AnimatablePair(topRadius, bottomRadius)) }
        set {
            width = newValue.first.first
            height = newValue.first.second
            topRadius = newValue.second.first
            bottomRadius = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let x0 = rect.midX - width / 2
        let x1 = rect.midX + width / 2
        let top = rect.minY
        let bottom = top + height
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
