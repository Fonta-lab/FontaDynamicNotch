import SwiftUI

struct NotchView: View {
    let model: NotchViewModel
    private var settings: AppSettings { SettingsStore.shared.settings }
    private var spotify: SpotifyService { .shared }

    var body: some View {
        let g = model.geometry
        let t = model.theme
        let open = model.isOpen
        let half = g.notchRect.width / 2
        let left = open ? g.openRect.width / 2 : half + model.leftWingWidth
        let right = open ? g.openRect.width / 2 : half + model.rightWingWidth
        let height = open ? g.openRect.height : g.closedHeight
        let topR = open ? min(t.topFilletRadius, NotchGeometry.margin) : 0
        let bottomR = open ? t.openBottomRadius : t.closedBottomRadius
        let visible = open || model.wingsVisible || model.showsClosedShape
        // The panel is centred on the notch, so the shape's centre line is the notch centre.
        let shape = NotchShape(left: left, right: right, height: height, topRadius: topR, bottomRadius: bottomR)

        ZStack(alignment: .topLeading) {
            shape
                .fill(Color.black)
                .shadow(color: .black.opacity(open && t.shadowEnabled ? t.shadowOpacity : 0),
                        radius: t.shadowRadius, y: t.shadowYOffset)

            ZStack(alignment: .topLeading) {
                NotchBackgroundView(theme: t, color: backgroundColor)
                    .opacity(open ? 1 : 0)   // closed is always pure black

                if open {
                    OpenContentView(model: model, settings: settings)
                        .frame(width: g.openRect.width, height: g.openRect.height)
                        .offset(x: g.openRect.minX)
                        .transition(.opacity)
                } else if model.wingsVisible {
                    ClosedWingsView(model: model, settings: settings)
                        .transition(.opacity)
                }
            }
            .frame(width: g.panelFrame.width, height: g.panelFrame.height, alignment: .topLeading)
            .clipShape(shape)
        }
        .opacity(visible ? 1 : 0)
        .animation(settings.animations.wings.animation, value: WingKey(left: model.leftWingWidth, right: model.rightWingWidth))
        .overlay(alignment: .topLeading) {
            if model.showDebugOverlay { DebugOverlayView(model: model) }
        }
        .frame(width: g.panelFrame.width, height: g.panelFrame.height, alignment: .topLeading)
        .environment(\.notchActions, NotchActions(
            setCloseBlocker: { [model] blocker, on in model.blockerHandler?(blocker, on) },
            dismissToken: model.dismissToken))
    }

    private struct WingKey: Equatable { let left: CGFloat; let right: CGFloat }

    private var backgroundColor: Color? {
        guard model.theme.useArtworkColor, spotify.isMusicActive, let c = spotify.artworkColor else { return nil }
        return c.scaled(model.theme.artworkIntensity).darkenedForWhiteText(contrast: model.theme.minTextContrast).color
    }
}

/// Everything inside the open notch: the top bar and the Home tab (or the alarm while ringing).
struct OpenContentView: View {
    let model: NotchViewModel
    let settings: AppSettings
    private var alarm: AlarmService { .shared }

    var body: some View {
        let theme = model.theme
        VStack(spacing: 0) {
            TopBarView(geometry: model.geometry.relativeToOpenRect, theme: theme, settings: settings,
                       showScreenBrightness: model.showsScreenBrightness,
                       showKeyboardBrightness: model.showsKeyboardBrightness)
            Group {
                if alarm.isRinging {
                    AlarmView(theme: theme)
                        .transition(.opacity)
                } else {
                    // Music block centred vertically against the (full-height) tool panel.
                    HStack(alignment: .center, spacing: 14) {
                        MediaPanelView(theme: theme, settings: settings)
                        ToolPanelView(theme: theme, spring: settings.animations.tabSwitch.animation)
                            .frame(width: 172)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }
}

/// Outlines of the computed rectangles (Settings › Advanced in M9; menu-bar Debug menu for now).
struct DebugOverlayView: View {
    let model: NotchViewModel

    var body: some View {
        let g = model.geometry
        ZStack(alignment: .topLeading) {
            outline(g.openRect, .blue)
            outline(model.hotZone, .red, fill: model.isMouseInside && !model.isOpen ? 0.35 : 0)
            outline(model.closedRect, .green)
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
