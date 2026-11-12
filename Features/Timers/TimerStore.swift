import AppKit
import Observation

/// The 5 timers. Several can run at once. One scheduled wake-up for the nearest end date —
/// no per-second ticking (SPEC §7.1, §12).
@MainActor @Observable
final class TimerStore {
    static let shared = TimerStore()

    private(set) var presets: [TimerPreset] = TimerPreset.defaults
    var selectedID: UUID? {
        didSet { if oldValue != selectedID { StateStore.shared.markDirty() } }
    }

    @ObservationIgnored private var dueWork: DispatchWorkItem?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private init() {}

    var selected: TimerPreset? { presets.first { $0.id == selectedID } ?? presets.first }
    var ringing: [TimerPreset] { presets.filter(\.isRinging) }
    var anyRunning: Bool { presets.contains(where: \.isRunning) }

    /// The running timer that ends first (shown in the closed notch and picked when opening).
    var soonestRunning: (preset: TimerPreset, endDate: Date)? {
        presets.compactMap { p -> (TimerPreset, Date)? in
            if case .running(let end) = p.run { return (p, end) }
            return nil
        }.min { $0.1 < $1.1 }
    }

    func remaining(_ p: TimerPreset, at date: Date = Date()) -> TimeInterval {
        switch p.run {
        case .idle: return p.duration
        case .running(let end): return max(0, end.timeIntervalSince(date))
        case .paused(let r): return r
        case .ringing: return 0
        }
    }

    // MARK: Launch / lifecycle

    /// Applies saved state. Timers that ended while the app wasn't running get a notification
    /// and go back to idle; they don't ring (SPEC §7.1).
    func restore(_ saved: [TimerPreset], selectedID: UUID?) {
        let now = Date()
        var missed: [(String, Date)] = []
        presets = saved.map { p in
            var p = p
            switch p.run {
            case .running(let end) where end <= now:
                missed.append((p.name, end))
                p.run = .idle
            case .ringing:
                p.run = .idle
            default: break
            }
            return p
        }
        self.selectedID = selectedID ?? presets.first?.id
        for (name, end) in missed {
            NotificationService.shared.post(title: "⏲ \(name) ended at \(end.formatted(date: .omitted, time: .shortened))",
                                            body: "It finished while Fonta's Dynamic Notch wasn't running.")
        }
        if !missed.isEmpty { StateStore.shared.markDirty() }
        reschedule()
        startObserving()
    }

    private func startObserving() {
        guard observers.isEmpty else { return }
        let ws = NSWorkspace.shared.notificationCenter
        // After sleep: anything that ended while asleep rings now.
        observers.append(ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { TimerStore.shared.reschedule() }
        })
        observers.append(ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { StateStore.shared.flush() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .NSSystemClockDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { TimerStore.shared.reschedule() }
        })
    }

    // MARK: Actions

    func select(_ id: UUID) { selectedID = id }

    /// Start / Pause / Resume.
    func toggle(_ id: UUID) {
        update(id) { p in
            switch p.run {
            case .idle: p.run = .running(endDate: Date().addingTimeInterval(p.duration))
            case .paused(let r): p.run = .running(endDate: Date().addingTimeInterval(r))
            case .running(let end): p.run = .paused(remaining: max(0, end.timeIntervalSinceNow))
            case .ringing: break
            }
        }
    }

    func reset(_ id: UUID) {
        update(id) { $0.run = .idle }
    }

    /// Settings › Timers. A running timer keeps its end time; the new length applies from the next start.
    func updatePreset(_ id: UUID, name: String? = nil, duration: TimeInterval? = nil) {
        update(id) { p in
            if let name { p.name = name }
            if let duration { p.duration = max(1, duration) }
        }
    }

    /// From the notch's time editor: the new length is saved into the chip (only while idle).
    /// A name that just described the old length ("5 min") follows the new one; custom names stay.
    func setDuration(_ id: UUID, _ duration: TimeInterval) {
        update(id) { p in
            guard p.run == .idle else { return }
            let new = min(TimerDurationEditor.maxDuration, max(1, duration.rounded()))
            if p.name == TimeFormat.label(p.duration) { p.name = TimeFormat.label(new) }
            p.duration = new
        }
    }

    /// Called by the alarm's Stop button: every ringing timer goes back to idle.
    func clearRinging() {
        var changed = false
        for i in presets.indices where presets[i].isRinging {
            presets[i].run = .idle
            changed = true
        }
        if changed { StateStore.shared.markDirty() }
    }

    private func update(_ id: UUID, _ change: (inout TimerPreset) -> Void) {
        guard let i = presets.firstIndex(where: { $0.id == id }) else { return }
        change(&presets[i])
        StateStore.shared.markDirty()
        reschedule()
    }

    // MARK: Scheduling

    /// One wake-up at the nearest end date; recomputed whenever something changes.
    func reschedule() {
        dueWork?.cancel()
        dueWork = nil
        fireDue()
        guard let next = soonestRunning?.endDate else { return }
        let work = DispatchWorkItem { MainActor.assumeIsolated { TimerStore.shared.reschedule() } }
        dueWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.05, next.timeIntervalSinceNow), execute: work)
    }

    private func fireDue() {
        let now = Date()
        var fired: [String] = []
        for i in presets.indices {
            if case .running(let end) = presets[i].run, end <= now.addingTimeInterval(0.02) {
                presets[i].run = .ringing
                fired.append(presets[i].name)
            }
        }
        guard !fired.isEmpty else { return }
        StateStore.shared.markDirty()
        AlarmService.shared.ring(names: fired)
    }
}

/// Which tool the right panel shows. Shared by all screens.
@MainActor @Observable
final class ToolState {
    static let shared = ToolState()

    private(set) var selected: Tool = .timer
    /// The last tool the user picked (saved; used when nothing is running).
    private(set) var lastUsed: Tool = .timer

    private init() {}

    func restore(_ tool: Tool) {
        lastUsed = tool
        selected = tool
    }

    func select(_ tool: Tool) {
        selected = tool
        if lastUsed != tool {
            lastUsed = tool
            StateStore.shared.markDirty()
        }
    }

    /// On open: a running timer wins (the one ending first), then a running stopwatch,
    /// otherwise the last tool used (SPEC §4.3).
    func prepareForOpen() {
        let visible = SettingsStore.shared.settings.visibleTools
        if visible.contains(.timer), let r = TimerStore.shared.soonestRunning {
            selected = .timer
            TimerStore.shared.selectedID = r.preset.id
        } else if visible.contains(.stopwatch), StopwatchStore.shared.isRunning {
            selected = .stopwatch
        } else {
            selected = lastUsed
        }
    }
}
