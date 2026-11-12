import AppKit
import Observation

/// The timer (SPEC §7.1): one timer whose length is set in the notch, plus up to 3 starred
/// lengths shown as chips. One scheduled wake-up for the end date — no per-second ticking (§12).
@MainActor @Observable
final class TimerStore {
    static let shared = TimerStore()
    nonisolated static let maxStars = 3
    static let maxDuration: TimeInterval = 24 * 3600 - 1

    private(set) var timer = TimerItem()
    /// Starred lengths, shortest first.
    private(set) var starred: [TimeInterval] = []

    @ObservationIgnored private var dueWork: DispatchWorkItem?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private init() {}

    var isRunning: Bool { timer.isRunning }
    var isRinging: Bool { timer.isRinging }
    var isCurrentStarred: Bool { starred.contains(timer.duration) }

    /// When the running timer ends (shown in the closed notch).
    var runningEndDate: Date? {
        if case .running(let end) = timer.run { return end }
        return nil
    }

    func remaining(at date: Date = Date()) -> TimeInterval {
        switch timer.run {
        case .idle: return timer.duration
        case .running(let end): return max(0, end.timeIntervalSince(date))
        case .paused(let r): return r
        case .ringing: return 0
        }
    }

    // MARK: Launch / lifecycle

    /// Applies saved state. If the timer ended while the app wasn't running it gets a notification
    /// and goes back to idle; it doesn't ring (SPEC §7.1).
    func restore(_ saved: TimerItem, starred: [TimeInterval]) {
        var t = saved
        self.starred = starred
        switch t.run {
        case .running(let end) where end <= Date():
            t.run = .idle
            timer = t
            NotificationService.shared.post(
                title: "⏲ \(TimeFormat.label(t.duration)) timer ended at \(end.formatted(date: .omitted, time: .shortened))",
                body: "It finished while Fonta's Dynamic Notch wasn't running.")
            StateStore.shared.markDirty()
        case .ringing:
            t.run = .idle
            timer = t
        default:
            timer = t
        }
        reschedule()
        startObserving()
    }

    private func startObserving() {
        guard observers.isEmpty else { return }
        let ws = NSWorkspace.shared.notificationCenter
        // After sleep: if it ended while asleep, it rings now.
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

    /// Start / Pause / Resume.
    func toggle() {
        change { t in
            switch t.run {
            case .idle: t.run = .running(endDate: Date().addingTimeInterval(t.duration))
            case .paused(let r): t.run = .running(endDate: Date().addingTimeInterval(r))
            case .running(let end): t.run = .paused(remaining: max(0, end.timeIntervalSinceNow))
            case .ringing: break
            }
        }
    }

    func reset() {
        change { $0.run = .idle }
    }

    /// The notch's time editor and the starred chips. Only while the timer isn't started.
    func setDuration(_ duration: TimeInterval) {
        change { t in
            guard t.isIdle else { return }
            t.duration = min(Self.maxDuration, max(1, duration.rounded()))
        }
    }

    enum StarResult { case added, removed, full }

    /// Stars the current length (a chip appears), or un-stars it if it's already starred.
    /// At most `maxStars`: a fourth isn't added and `.full` comes back.
    @discardableResult
    func toggleStar() -> StarResult {
        let d = timer.duration
        if let i = starred.firstIndex(of: d) {
            starred.remove(at: i)
            StateStore.shared.markDirty()
            return .removed
        }
        guard starred.count < Self.maxStars else { return .full }
        starred.append(d)
        starred.sort()
        StateStore.shared.markDirty()
        return .added
    }

    /// Settings › Timers: remove a starred length.
    func unstar(_ duration: TimeInterval) {
        guard let i = starred.firstIndex(of: duration) else { return }
        starred.remove(at: i)
        StateStore.shared.markDirty()
    }

    /// Called by the alarm's Stop button.
    func clearRinging() {
        guard timer.isRinging else { return }
        timer.run = .idle
        StateStore.shared.markDirty()
    }

    private func change(_ body: (inout TimerItem) -> Void) {
        var t = timer
        body(&t)
        guard t != timer else { return }
        timer = t
        StateStore.shared.markDirty()
        reschedule()
    }

    // MARK: Scheduling

    /// One wake-up at the end date; recomputed whenever something changes.
    func reschedule() {
        dueWork?.cancel()
        dueWork = nil
        guard let end = runningEndDate else { return }
        if end <= Date().addingTimeInterval(0.02) {
            timer.run = .ringing
            StateStore.shared.markDirty()
            AlarmService.shared.ring(names: [TimeFormat.label(timer.duration)])
            return
        }
        let work = DispatchWorkItem { MainActor.assumeIsolated { TimerStore.shared.reschedule() } }
        dueWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.05, end.timeIntervalSinceNow), execute: work)
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
        } else if visible.contains(.stopwatch), StopwatchStore.shared.isRunning {
            selected = .stopwatch
        } else {
            selected = lastUsed
        }
    }
}
