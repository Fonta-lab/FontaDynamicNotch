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
    var onLog: ((String) -> Void)?
    private var observers: [NSObjectProtocol] = []

    /// Fallback detection: is a normal (layer 0) window covering the whole screen?
    static func screenHasFullscreenWindow(_ screen: NSScreen) -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }
        let mine = ProcessInfo.processInfo.processIdentifier
        // CG coordinates: origin top-left of the primary display.
        let primaryH = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let cgFrame = CGRect(x: screen.frame.minX, y: primaryH - screen.frame.maxY, width: screen.frame.width, height: screen.frame.height)
        for w in list {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerPID as String] as? Int32) != mine,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let r = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
            if r.width >= cgFrame.width - 1 && r.height >= cgFrame.height - 1 && abs(r.minX - cgFrame.minX) < 2 && abs(r.minY - cgFrame.minY) < 2 { return true }
        }
        return false
    }

    private func startFallback() {
        guard observers.isEmpty else { return }
        let check: @Sendable (Notification) -> Void = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                MainActor.assumeIsolated { self?.evaluate() }
            }
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: check))
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main, using: check))
    }

    private func evaluate() {
        guard let panel, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let fs = Self.screenHasFullscreenWindow(screen)
        let menuBarGone = (screen.frame.maxY - screen.visibleFrame.maxY) < 1
        onLog?("(e) Fallback check: full-screen window detected = \(fs); menu bar hidden by visibleFrame = \(menuBarGone). Bar \(fs ? "hidden" : "shown").")
        if fs { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
    }

    func toggle() -> Bool {
        if let p = panel { p.orderOut(nil); panel = nil; observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }; observers = []; return false }
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
        startFallback()
        return true
    }
}
