import AppKit

@MainActor
final class MouseProbe {
    private var global: Any?
    private(set) var count = 0
    var onCount: ((Int) -> Void)?

    func start() {
        guard global == nil else { return }
        count = 0
        global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.count += 1
                if self.count % 10 == 0 { self.onCount?(self.count) }
            }
        }
    }
    var installed: Bool { global != nil }
}

/// A thin red bar at the top-centre of the main screen using the spec's intended window settings
/// (no .fullScreenAuxiliary). Used to see whether it disappears in a full-screen Space.
@MainActor
final class FullscreenProbePanel {
    private var panel: NSPanel?

    func toggle() -> Bool {
        if let p = panel { p.orderOut(nil); panel = nil; return false }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return false }
        let size = NSSize(width: 300, height: 24)
        let origin = NSPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height)
        let p = NSPanel(contentRect: NSRect(origin: origin, size: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .red
        p.hasShadow = false
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.ignoresMouseEvents = true
        p.orderFrontRegardless()
        panel = p
        return true
    }
}
