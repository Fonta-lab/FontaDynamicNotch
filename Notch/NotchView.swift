import SwiftUI

struct NotchView: View {
    let model: NotchViewModel

    var body: some View {
        let g = model.geometry
        ZStack(alignment: .topLeading) {
            if model.showsClosedShape {
                UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10, style: .continuous)
                    .fill(Color.black)
                    .frame(width: g.closedRect.width, height: g.closedRect.height)
                    .offset(x: g.closedRect.minX, y: g.closedRect.minY)
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
            outline(g.hotZone, .red, fill: model.isMouseInside ? 0.35 : 0)
            outline(g.closedRect, .green)
            outline(g.notchRect, .yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.screenName) · \(g.hasRealNotch ? "real notch" : "fake notch")\(model.isBuiltin ? " · built-in" : "")")
                Text("notch \(Int(g.notchSize.width))×\(Int(g.notchSize.height)) · open \(Int(g.openRect.width))×\(Int(g.openRect.height))")
                Text("mouse inside: \(model.isMouseInside ? "yes" : "no") · full screen: \(model.isFullscreenHidden ? "yes" : "no")")
                Text("yellow notch · green closed · red hot zone · blue open").foregroundStyle(.secondary)
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.white)
            .padding(6)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
            .offset(x: g.openRect.minX + 8, y: g.notchRect.maxY + 10)
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
