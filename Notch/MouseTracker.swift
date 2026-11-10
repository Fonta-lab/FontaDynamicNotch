import AppKit

/// Watches mouse movement everywhere (no permission needed, verified in M0) and reports the position.
/// Event-driven only: nothing runs while the mouse is still.
@MainActor
final class MouseTracker {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start(onMove: @escaping @MainActor (NSPoint) -> Void) {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { _ in
            MainActor.assumeIsolated { onMove(NSEvent.mouseLocation) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            MainActor.assumeIsolated { onMove(NSEvent.mouseLocation) }
            return event
        }
    }

    func stop() {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor { NSEvent.removeMonitor(l) }
        globalMonitor = nil
        localMonitor = nil
    }
}
