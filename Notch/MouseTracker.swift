import AppKit

/// Watches mouse movement everywhere (no permission needed, verified in M0) and reports the position.
/// Event-driven only: nothing runs while the mouse is still.
@MainActor
final class MouseTracker {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    enum Kind { case moved, down, up }

    func start(onEvent: @escaping @MainActor (Kind, NSPoint) -> Void) {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        let handle: (NSEvent) -> Void = { event in
            let kind: Kind = switch event.type {
            case .leftMouseDown: .down
            case .leftMouseUp: .up
            default: .moved
            }
            MainActor.assumeIsolated { onEvent(kind, NSEvent.mouseLocation) }
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handle)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            handle(event)
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
