import AppKit

/// Finds screens that show a full-screen app. Event-driven: it only checks after a Space change,
/// an app switch, or a screen change — never on a timer while idle.
@MainActor
final class FullscreenDetector {
    struct Target: Sendable {
        let id: CGDirectDisplayID
        let bounds: CGRect      // CG global coordinates (top-left origin)
        let safeTop: CGFloat
    }

    var onResult: (([CGDirectDisplayID: Bool]) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var pending: [DispatchWorkItem] = []

    func start() {
        let nc = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [NSWorkspace.activeSpaceDidChangeNotification,
                                          NSWorkspace.didActivateApplicationNotification,
                                          NSWorkspace.didTerminateApplicationNotification]
        for name in names {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleChecks() }
            })
        }
        scheduleChecks()
    }

    /// The full-screen animation takes a moment, so check a few times shortly after an event.
    func scheduleChecks() {
        pending.forEach { $0.cancel() }
        pending = [0.05, 0.4, 1.0].map { delay in
            let item = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.check() } }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item
        }
    }

    private func check() {
        let targets: [Target] = NSScreen.screens.compactMap { s in
            guard let id = s.displayID else { return nil }
            return Target(id: id, bounds: CGDisplayBounds(id), safeTop: s.safeAreaInsets.top)
        }
        let pid = ProcessInfo.processInfo.processIdentifier
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Self.detect(targets: targets, myPID: pid)
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.onResult?(result) } }
        }
    }

    /// A screen is "full screen" when a normal window (layer 0) of another app covers it,
    /// allowing for the notch-height gap at the top (seen in M0 on this Mac).
    nonisolated static func detect(targets: [Target], myPID: Int32) -> [CGDirectDisplayID: Bool] {
        var result: [CGDirectDisplayID: Bool] = [:]
        targets.forEach { result[$0.id] = false }
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return result }
        for w in list {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerPID as String] as? Int32) != myPID,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let r = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
            for t in targets where result[t.id] == false {
                let slack = t.safeTop + 2
                if r.width >= t.bounds.width - 1,
                   abs(r.minX - t.bounds.minX) < 2,
                   r.minY >= t.bounds.minY - 1, r.minY - t.bounds.minY <= slack,
                   r.height >= t.bounds.height - slack {
                    result[t.id] = true
                }
            }
        }
        return result
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
