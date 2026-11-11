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
        mouse.start { [weak self] kind, p in self?.handleMouse(kind, at: p) }
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
        for c in controllers.values {
            c.model.builtinScreenPresent = builtinScreenPresent
            c.setBlocker(.alarm, AlarmService.shared.isRinging)
        }
        // A screen went away while the alarm rang (e.g. lid closed): show it on a remaining screen.
        if AlarmService.shared.isRinging, !controllers.values.contains(where: { $0.model.isOpen }) {
            alarmChanged(ringing: true)
        }
        mouseMoved(to: NSEvent.mouseLocation)
    }

    /// Alarm (SPEC §7.4): open the notch on the screen with the mouse, keep every notch from closing
    /// while it rings, release them when it stops.
    func alarmChanged(ringing: Bool) {
        for c in controllers.values { c.setBlocker(.alarm, ringing) }
        guard ringing else { return }
        let mouse = NSEvent.mouseLocation
        let visible = controllers.values.filter { !$0.isFullscreenHidden }
        let target = visible.first { $0.containsMouse(mouse) } ?? visible.first
        if let target {
            target.open(animation: settingsStore.settings.animations.alarmOpen.animation)
        } else {
            // Every notch is hidden (full screen): make sure the user still hears about it.
            NotificationService.shared.post(title: "⏲ Timer ended", body: TimerStore.shared.ringing.map(\.name).joined(separator: ", "))
        }
    }

    // MARK: Mouse and file drags

    /// Drag pasteboard change count when the button went down: a new value during the drag means
    /// something is being dragged (not just a window or a selection).
    private var dragChangeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
    private var fileDragActive = false

    private func handleMouse(_ kind: MouseTracker.Kind, at p: NSPoint) {
        switch kind {
        case .down:
            dragChangeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
            for c in controllers.values { c.mouseDown(at: p) }
        case .up:
            endFileDrag()
            for c in controllers.values { c.mouseUp() }
        case .dragged:
            if !fileDragActive { fileDragActive = isDraggingFiles() }
            for c in controllers.values {
                if fileDragActive { c.fileDragMoved(to: p) } else { c.mouseMoved(to: p) }
            }
        case .moved:
            // Safety net: a drag can end without us seeing the mouse-up (e.g. dropped in another app).
            if NSEvent.pressedMouseButtons & 1 == 0 {
                endFileDrag()
                for c in controllers.values { c.mouseUp() }
            }
            mouseMoved(to: p)
        }
    }

    private func isDraggingFiles() -> Bool {
        let pb = NSPasteboard(name: .drag)
        guard pb.changeCount != dragChangeCountAtMouseDown else { return false }
        return pb.types?.contains(.fileURL) ?? false
    }

    private func endFileDrag() {
        guard fileDragActive else { return }
        fileDragActive = false
        for c in controllers.values { c.fileDragEnded() }
    }

    /// Click-through and hover: each panel decides from the cursor position.
    private func mouseMoved(to p: NSPoint) {
        for c in controllers.values { c.mouseMoved(to: p) }
    }
}
