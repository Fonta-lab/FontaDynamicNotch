import AppKit
import SwiftUI

/// Owns the panel and view model for one screen, and runs that screen's open/close logic.
@MainActor
final class NotchController {
    let displayID: CGDirectDisplayID
    let model: NotchViewModel
    private let panel: NotchPanel
    private var settings: AppSettings
    private let menuProvider: @MainActor () -> NSMenu
    private var openWork: DispatchWorkItem?
    private var closeWork: DispatchWorkItem?

    init(displayID: CGDirectDisplayID, screen: NSScreen, geometry: NotchGeometry, settings: AppSettings,
         menuProvider: @escaping @MainActor () -> NSMenu) {
        self.displayID = displayID
        self.settings = settings
        self.menuProvider = menuProvider
        model = NotchViewModel(geometry: geometry, screenName: screen.localizedName,
                               isBuiltin: CGDisplayIsBuiltin(displayID) != 0, settings: settings)
        panel = NotchPanel(frame: geometry.panelFrame)
        let host = NotchHostingView(rootView: NotchView(model: model))
        host.sizingOptions = []
        panel.contentView = host
        panel.onRightMouseDown = { [weak self] event in self?.showContextMenu(event) }
        model.blockerHandler = { [weak self] blocker, on in self?.setBlocker(blocker, on) }
        panel.orderFrontRegardless()
    }

    func update(screen: NSScreen, geometry: NotchGeometry, settings: AppSettings) {
        self.settings = settings
        model.screenName = screen.localizedName
        model.showFakeNotchWhenIdle = settings.showFakeNotchWhenIdle
        model.showDebugOverlay = settings.showDebugOverlay
        if model.geometry != geometry {
            model.geometry = geometry
            panel.setFrame(geometry.panelFrame, display: true)
        }
    }

    // MARK: Mouse

    /// The region that currently takes the mouse, in global coordinates (nil when hidden).
    private var globalActiveRect: CGRect? {
        guard !model.isFullscreenHidden else { return nil }
        let g = model.geometry
        // Expand by 1 pt upward so the very top pixel row of the screen counts as inside.
        return g.toGlobal(model.isOpen ? g.openRect : model.hotZone).insetBy(dx: 0, dy: -1)
    }

    func mouseMoved(to p: NSPoint) {
        let inside = globalActiveRect?.contains(p) ?? false
        setAcceptsMouse(inside || model.closeBlockers.contains(.mouseDown))

        if model.isOpen {
            if inside { cancelClose() } else if model.closeBlockers.isEmpty { scheduleClose() }
        } else {
            if inside { scheduleOpen() } else { cancelOpen() }
        }
    }

    func mouseDown(at p: NSPoint) {
        guard model.isOpen else { return }
        if globalActiveRect?.contains(p) == true {
            setBlocker(.mouseDown, true)
        } else if model.closeBlockers.contains(.outputList) {
            model.dismissToken += 1     // click outside: close the output list (then the notch closes)
        }
    }

    func mouseUp() {
        setBlocker(.mouseDown, false)
    }

    private func setAcceptsMouse(_ accepts: Bool) {
        guard model.isMouseInside != accepts else { return }
        model.isMouseInside = accepts
        panel.ignoresMouseEvents = !accepts
    }

    // MARK: Open / close

    private func scheduleOpen() {
        guard openWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.open() } }
        openWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, settings.hoverOpenDelay), execute: work)
    }

    private func cancelOpen() {
        openWork?.cancel()
        openWork = nil
    }

    private func scheduleClose() {
        if settings.closeDelay <= 0 { close(); return }
        guard closeWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.close() } }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.closeDelay, execute: work)
    }

    private func cancelClose() {
        closeWork?.cancel()
        closeWork = nil
    }

    func open(animation: Animation? = nil) {
        cancelOpen()
        guard !model.isOpen, !model.isFullscreenHidden else { return }
        ToolState.shared.prepareForOpen()
        withAnimation(animation ?? settings.animations.open.animation) { model.isOpen = true }
        mouseMoved(to: NSEvent.mouseLocation)
    }

    func close() {
        cancelClose()
        guard model.isOpen, model.closeBlockers.isEmpty || model.isFullscreenHidden else { return }
        withAnimation(settings.animations.close.animation) { model.isOpen = false }
        mouseMoved(to: NSEvent.mouseLocation)
    }

    /// Adds or removes a reason to stay open. When the last one goes away and the mouse is outside, it closes.
    func setBlocker(_ blocker: CloseBlocker, _ on: Bool) {
        if on {
            model.closeBlockers.insert(blocker)
            cancelClose()
        } else if model.closeBlockers.remove(blocker) != nil {
            mouseMoved(to: NSEvent.mouseLocation)
        }
    }

    var isFullscreenHidden: Bool { model.isFullscreenHidden }

    /// True if the cursor is on this controller's screen.
    func containsMouse(_ p: NSPoint) -> Bool {
        NSScreen.screens.contains { $0.displayID == displayID && $0.frame.contains(p) }
    }

    // MARK: Right-click menu

    private func showContextMenu(_ event: NSEvent) {
        guard model.isOpen, let view = panel.contentView else { return }
        setBlocker(.contextMenu, true)
        NSMenu.popUpContextMenu(menuProvider(), with: event, for: view)   // returns when the menu closes
        setBlocker(.contextMenu, false)
    }

    // MARK: Full screen

    func setFullscreenHidden(_ hidden: Bool) {
        guard model.isFullscreenHidden != hidden else { return }
        model.isFullscreenHidden = hidden
        if hidden {
            cancelOpen()
            model.closeBlockers.remove(.mouseDown)
            model.dismissToken += 1
            model.isOpen = false
            setAcceptsMouse(false)
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = hidden ? 0 : 1
        }
    }

    func tearDown() {
        cancelOpen()
        cancelClose()
        panel.orderOut(nil)
        panel.contentView = nil
    }
}

/// Clicks work on the first press even though the panel never becomes the key window.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
