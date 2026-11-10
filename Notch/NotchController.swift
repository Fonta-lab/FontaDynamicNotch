import AppKit
import SwiftUI

/// Owns the panel and view model for one screen.
@MainActor
final class NotchController {
    let displayID: CGDirectDisplayID
    let model: NotchViewModel
    private let panel: NotchPanel

    init(displayID: CGDirectDisplayID, screen: NSScreen, geometry: NotchGeometry, settings: AppSettings) {
        self.displayID = displayID
        model = NotchViewModel(geometry: geometry, screenName: screen.localizedName,
                               isBuiltin: CGDisplayIsBuiltin(displayID) != 0, settings: settings)
        panel = NotchPanel(frame: geometry.panelFrame)
        let host = NSHostingView(rootView: NotchView(model: model))
        host.sizingOptions = []
        panel.contentView = host
        panel.orderFrontRegardless()
    }

    func update(screen: NSScreen, geometry: NotchGeometry, settings: AppSettings) {
        model.screenName = screen.localizedName
        model.showFakeNotchWhenIdle = settings.showFakeNotchWhenIdle
        model.showDebugOverlay = settings.showDebugOverlay
        if model.geometry != geometry {
            model.geometry = geometry
            panel.setFrame(geometry.panelFrame, display: true)
        }
    }

    /// The area where the notch takes the mouse, in global coordinates; nil when hidden.
    var globalHotZone: CGRect? {
        model.isFullscreenHidden ? nil : model.geometry.toGlobal(model.geometry.hotZone)
    }

    func setMouseInside(_ inside: Bool) {
        guard model.isMouseInside != inside else { return }
        model.isMouseInside = inside
        panel.ignoresMouseEvents = !inside
    }

    func setFullscreenHidden(_ hidden: Bool) {
        guard model.isFullscreenHidden != hidden else { return }
        model.isFullscreenHidden = hidden
        if hidden { setMouseInside(false) }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = hidden ? 0 : 1
        }
    }

    func tearDown() {
        panel.orderOut(nil)
        panel.contentView = nil
    }
}
