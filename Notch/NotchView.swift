import SwiftUI

struct NotchView: View {
    let model: NotchViewModel

    var body: some View {
        let g = model.geometry
        let t = model.theme
        let open = model.isOpen
        let size = open ? g.openRect.size : g.closedRect.size
        let topR = open ? min(t.topFilletRadius, NotchGeometry.margin) : 0
        let bottomR = open ? t.openBottomRadius : t.closedBottomRadius
        let visible = open || model.showsClosedShape

        ZStack(alignment: .topLeading) {
            NotchShape(width: size.width, height: size.height, topRadius: topR, bottomRadius: bottomR)
                .fill(Color.black)
                .shadow(color: .black.opacity(open && t.shadowEnabled ? t.shadowOpacity : 0),
                        radius: t.shadowRadius, y: t.shadowYOffset)
                .opacity(visible ? 1 : 0)

            if open {
                // Placeholder until the Home tab arrives in M3.
                Text("Fonta's Dynamic Notch")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: g.openRect.width, height: g.openRect.height - g.notchRect.height)
                    .offset(x: g.openRect.minX, y: g.notchRect.maxY)
                    .transition(.opacity)
            }

            if model.showDebugOverlay {
                DebugOverlayView(model: model)
            }
        }
        .frame(width: g.panelFrame.width, height: g.panelFrame.height, alignment: .topLeading)
    }
}

/// Outlines of the computed rectangles (Settings › Advanced in M9; menu-bar Debug menu for now).
struct DebugOverlayView: View {
    let model: NotchViewModel

    var body: some View {
        let g = model.geometry
        ZStack(alignment: .topLeading) {
            outline(g.openRect, .blue)
            outline(g.hotZone, .red, fill: model.isMouseInside && !model.isOpen ? 0.35 : 0)
            outline(g.closedRect, .green)
            outline(g.notchRect, .yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.screenName) · \(g.hasRealNotch ? "real notch" : "fake notch")\(model.isBuiltin ? " · built-in" : "")")
                Text("notch \(Int(g.notchSize.width))×\(Int(g.notchSize.height)) · open \(Int(g.openRect.width))×\(Int(g.openRect.height))")
                Text("open: \(model.isOpen ? "yes" : "no") · mouse inside: \(model.isMouseInside ? "yes" : "no") · full screen: \(model.isFullscreenHidden ? "yes" : "no")")
                Text("keeping open: \(model.closeBlockers.isEmpty ? "–" : model.closeBlockers.map(\.rawValue).sorted().joined(separator: ", "))")
                Text("yellow notch · green closed · red hot zone · blue open").foregroundStyle(.secondary)
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.white)
            .padding(6)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
            .offset(x: g.openRect.minX + 8, y: g.openRect.maxY + 6)
        }
        .allowsHitTesting(false)
    }

    private func outline(_ r: CGRect, _ c: Color, fill: Double = 0) -> some View {
        Rectangle()
            .fill(c.opacity(fill))
            .overlay(Rectangle().stroke(c, lineWidth: 1))
            .frame(width: r.width, height: r.height)
            .offset(x: r.minX, y: r.minY)
    }
}
