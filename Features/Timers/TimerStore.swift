import AppKit
import Observation

/// Timers (SPEC §7.1). Up to 3 chips — each one its own timer, starred (kept) or started — that
/// can all run at once, plus at most one "draft": the unstarred, not-started timer being set in
/// the panel. The panel always shows the selected timer. One scheduled wake-up for the soonest
/// end date — no per-second ticking (§12).
@MainActor @Observable
final class TimerStore {
    static let shared = TimerStore()
    nonisolated static let maxChips = 3
    static let maxDuration: TimeInterval = 24 * 3600 - 1

    private(set) var timers: [TimerItem] = [TimerItem()]
    private(set) var selectedID: UUID?
    /// Length a new timer (+) starts with: the last one set.
    @ObservationIgnored private var lastDraftDuration: TimeInterval = 5 * 60

    @ObservationIgnored private var dueWork: DispatchWorkItem?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private init() {
        selectedID = timers.first?.id
    }

    // MARK: Reading

    var selected: TimerItem { timers.first { $0.id == selectedID } ?? timers[0] }
    /// The chips, in the order they were added (so they don't jump around).
    var chips: [TimerItem] { timers.filter(\.isChip) }
    var canAddChip: Bool { chips.count < Self.maxChips }
    var isRunning: Bool { timers.contains(where: \.isRunning) }
    var ringing: [TimerItem] { timers.filter(\.isRinging) }

    /// The soonest end date among running timers (shown in the closed notch).
    var runningEndDate: Date? {
        timers.compactMap { t -> Date? in
            if case .running(let end) = t.run { return end }
            return nil
        }.min()
    }

    func remaining(_ t: TimerItem, at date: Date = Date()) -> TimeInterval {
        switch t.run {
        case .idle: return t.duration
        case .running(let end): return max(0, end.timeIntervalSince(date))
        case .paused(let r): return r
        case .ringing: return 0
        }
    }

    // MARK: Launch / lifecycle

    /// Applies saved state. Timers that ended while the app wasn't running get a notification and
    /// go back to idle; they don't ring (SPEC §7.1).
    func restore(_ saved: [TimerItem], selectedID: UUID?) {
        let now = Date()
        var missed: [(TimeInterval, Date)] = []
        timers = saved.map { t in
            var t = t
            switch t.run {
            case .running(let end) where end <= now:
                missed.append((t.duration, end))
                t.run = .idle
            case .ringing:
                t.run = .idle
            default: break
            }
            return t
        }
        self.selectedID = selectedID
        tidy()
        for (d, end) in missed {
            NotificationService.shared.post(
                title: "⏲ \(TimeFormat.label(d)) timer ended at \(end.formatted(date: .omitted, time: .shortened))",
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

    // MARK: Actions (on the selected timer unless said otherwise)

    /// Shows a chip's timer in the panel. An unsaved draft being set is let go (its length is
    /// remembered for the next +).
    func select(_ id: UUID) {
        guard id != selectedID, timers.contains(where: { $0.id == id }) else { return }
        selectedID = id
        tidy()
        StateStore.shared.markDirty()
    }

    /// The + chip: a new timer to set and start alongside the others.
    func addTimer() {
        guard canAddChip else { return }
        if !selected.isChip { return }   // already setting a new one
        let t = TimerItem(duration: lastDraftDuration)
        timers.append(t)
        selectedID = t.id
        StateStore.shared.markDirty()
    }

    enum ActionResult { case done, full }

    /// Start / Pause / Resume. Starting a new timer makes it a chip, so it needs a free slot.
    @discardableResult
    func toggle() -> ActionResult {
        let t = selected
        if t.isIdle && !t.isChip && !canAddChip { return .full }
        change(t.id) { t in
            switch t.run {
            case .idle: t.run = .running(endDate: Date().addingTimeInterval(t.duration))
            case .paused(let r): t.run = .running(endDate: Date().addingTimeInterval(r))
            case .running(let end): t.run = .paused(remaining: max(0, end.timeIntervalSinceNow))
            case .ringing: break
            }
        }
        return .done
    }

    func reset() {
        change(selected.id) { $0.run = .idle }
    }

    /// The time setter. Only before Start (or after Reset). On a starred timer it changes the
    /// saved length.
    func setDuration(_ duration: TimeInterval) {
        let d = min(Self.maxDuration, max(1, duration.rounded()))
        change(selected.id) { t in
            guard t.isIdle else { return }
            t.duration = d
        }
        if !selected.starred { lastDraftDuration = d }
    }

    /// Stars the selected timer (it stays as a chip), or un-stars it. A new timer needs a free slot.
    @discardableResult
    func toggleStar() -> ActionResult {
        let t = selected
        if !t.starred && !t.isChip && !canAddChip { return .full }
        change(t.id) { $0.starred.toggle() }
        if !selected.starred { lastDraftDuration = selected.duration }
        return .done
    }

    /// Settings › Timers: un-star one.
    func unstar(_ id: UUID) {
        change(id) { $0.starred = false }
    }

    /// Called by the alarm's Stop button: every ringing timer goes back to idle.
    func clearRinging() {
        guard timers.contains(where: \.isRinging) else { return }
        for i in timers.indices where timers[i].isRinging { timers[i].run = .idle }
        tidy()
        StateStore.shared.markDirty()
    }

    /// On open (SPEC §4.3): show the timer ending first if the selected one isn't counting.
    func selectSoonestRunningIfIdle() {
        guard selected.isIdle else { return }
        let soonest = timers.compactMap { t -> (UUID, Date)? in
            if case .running(let end) = t.run { return (t.id, end) }
            return nil
        }.min { $0.1 < $1.1 }
        if let soonest { select(soonest.0) }
    }

    private func change(_ id: UUID, _ body: (inout TimerItem) -> Void) {
        guard let i = timers.firstIndex(where: { $0.id == id }) else { return }
        var t = timers[i]
        body(&t)
        guard t != timers[i] else { return }
        timers[i] = t
        tidy()
        StateStore.shared.markDirty()
        reschedule()
    }

    /// Keeps the rules: timers that aren't chips only exist while selected (the draft); there's
    /// always a selected timer; never more than `maxChips` chips.
    private func tidy() {
        timers.removeAll { !$0.isChip && $0.id != selectedID }
        while timers.filter(\.isChip).count > Self.maxChips,
              let i = timers.lastIndex(where: { $0.isChip && $0.isIdle }) {
            timers[i].starred = false
            if timers[i].id != selectedID { timers.remove(at: i) }
        }
        if !timers.contains(where: { $0.id == selectedID }) {
            if let draft = timers.first(where: { !$0.isChip }) {
                selectedID = draft.id
            } else {
                let t = TimerItem(duration: lastDraftDuration)
                timers.append(t)
                selectedID = t.id
            }
        }
    }

    // MARK: Scheduling

    /// One wake-up at the soonest end date; recomputed whenever something changes.
    func reschedule() {
        dueWork?.cancel()
        dueWork = nil
        fireDue()
        guard let next = runningEndDate else { return }
        let work = DispatchWorkItem { MainActor.assumeIsolated { TimerStore.shared.reschedule() } }
        dueWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.05, next.timeIntervalSinceNow), execute: work)
    }

    private func fireDue() {
        let now = Date().addingTimeInterval(0.02)
        var fired: [String] = []
        for i in timers.indices {
            if case .running(let end) = timers[i].run, end <= now {
                timers[i].run = .ringing
                fired.append(TimeFormat.label(timers[i].duration))
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

    /// On open: a running timer wins, then a running stopwatch,
    /// otherwise the last tool used (SPEC §4.3).
    func prepareForOpen() {
        let visible = SettingsStore.shared.settings.visibleTools
        if visible.contains(.timer), TimerStore.shared.isRunning {
            selected = .timer
            TimerStore.shared.selectSoonestRunningIfIdle()
        } else if visible.contains(.stopwatch), StopwatchStore.shared.isRunning {
            selected = .stopwatch
        } else {
            selected = lastUsed
        }
    }
}
