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

    private let menuProvider: @MainActor () -> NSMenu

    init(settingsStore: SettingsStore, menuProvider: @escaping @MainActor () -> NSMenu) {
        self.settingsStore = settingsStore
        self.menuProvider = menuProvider
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
        mouse.start { [weak self] kind, p in
            guard let self else { return }
            for c in self.controllers.values {
                switch kind {
                case .moved: c.mouseMoved(to: p)
                case .down: c.mouseDown(at: p)
                case .up: c.mouseUp()
                }
            }
        }
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
                controllers[id] = NotchController(displayID: id, screen: screen, geometry: g, settings: settings, menuProvider: menuProvider)
            }
        }
        mouseMoved(to: NSEvent.mouseLocation)
    }

    /// Click-through and hover: each panel decides from the cursor position.
    private func mouseMoved(to p: NSPoint) {
        for c in controllers.values { c.mouseMoved(to: p) }
    }
}
