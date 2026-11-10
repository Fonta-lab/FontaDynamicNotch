import AppKit
import Observation

/// One NotchController per connected screen. Rebuilds on hot-plug, resolution change and settings change.
@MainActor
final class ScreenManager {
    private let settingsStore: SettingsStore
    private(set) var controllers: [CGDirectDisplayID: NotchController] = [:]
    private let fullscreen = FullscreenDetector()
    private let mouse = MouseTracker()
    private var screenObserver: NSObjectProtocol?

    /// False when the lid is closed (no built-in display connected). Used in M5 for brightness buttons.
    private(set) var builtinScreenPresent = true

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func start() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuild()
                self?.fullscreen.scheduleChecks()
            }
        }
        fullscreen.onResult = { [weak self] result in
            guard let self else { return }
            for (id, isFull) in result { self.controllers[id]?.setFullscreenHidden(isFull) }
            self.mouseMoved(to: NSEvent.mouseLocation)
        }
        mouse.start { [weak self] p in self?.mouseMoved(to: p) }
        rebuild()
        fullscreen.start()
        observeSettings()
    }

    private func observeSettings() {
        withObservationTracking {
            _ = settingsStore.settings
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.rebuild()
                self?.observeSettings()
            }
        }
    }

    func rebuild() {
        let settings = settingsStore.settings
        let all = NSScreen.screens.compactMap { s -> (CGDirectDisplayID, NSScreen)? in
            guard let id = s.displayID else { return nil }
            // Mirrored displays: keep only the one being mirrored.
            if CGDisplayMirrorsDisplay(id) != kCGNullDirectDisplay { return nil }
            return (id, s)
        }
        builtinScreenPresent = all.contains { CGDisplayIsBuiltin($0.0) != 0 }

        let mainID = CGMainDisplayID()
        let wanted = settings.notchOnAllScreens ? all : all.filter { $0.0 == mainID }

        // Width of the real notch, reused for fake notches on other screens.
        let knownNotchWidth: CGFloat? = all.lazy.compactMap { _, s -> CGFloat? in
            guard s.safeAreaInsets.top > 0, let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea else { return nil }
            return s.frame.width - l.width - r.width
        }.first

        let wantedIDs = Set(wanted.map(\.0))
        for (id, c) in controllers where !wantedIDs.contains(id) {
            c.tearDown()
            controllers[id] = nil
        }
        for (id, screen) in wanted {
            let g = NotchGeometry.compute(screen: screen, settings: settings, knownNotchWidth: knownNotchWidth)
            if let c = controllers[id] {
                c.update(screen: screen, geometry: g, settings: settings)
            } else {
                controllers[id] = NotchController(displayID: id, screen: screen, geometry: g, settings: settings)
            }
        }
        mouseMoved(to: NSEvent.mouseLocation)
    }

    /// Click-through: a panel takes the mouse only while the cursor is inside its visible notch.
    private func mouseMoved(to p: NSPoint) {
        for c in controllers.values {
            // Expand by 1 pt so the very top pixel row of the screen counts as inside.
            let inside = c.globalHotZone.map { $0.insetBy(dx: 0, dy: -1).contains(p) } ?? false
            c.setMouseInside(inside)
        }
    }
}
