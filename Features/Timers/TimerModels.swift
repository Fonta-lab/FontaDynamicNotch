import Foundation

/// Run state of one timer (SPEC §7.1). `endDate` is wall-clock, so a timer keeps counting across reboots.
enum TimerRun: Codable, Equatable, Sendable {
    case idle
    case running(endDate: Date)
    case paused(remaining: TimeInterval)
    case ringing
}

/// The one timer (SPEC §7.1): its length and run state.
struct TimerItem: Codable, Equatable, Sendable {
    var duration: TimeInterval = 5 * 60
    var run: TimerRun = .idle

    init(duration: TimeInterval = 5 * 60, run: TimerRun = .idle) {
        self.duration = duration
        self.run = run
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        duration = max(1, (try? c.decode(TimeInterval.self, forKey: .duration)) ?? 5 * 60)
        run = (try? c.decode(TimerRun.self, forKey: .run)) ?? .idle
    }

    var isIdle: Bool { run == .idle }
    var isRunning: Bool { if case .running = run { true } else { false } }
    var isRinging: Bool { run == .ringing }
}

/// A preset from versions before 0.4 (5 named slots). Only read, to carry the selected one's
/// length and run state over to the single timer.
private struct LegacyTimerPreset: Decodable {
    var id: UUID?
    var duration: TimeInterval?
    var run: TimerRun?
}

enum Tool: String, Codable, CaseIterable, Sendable {
    case timer, stopwatch, counter
}

/// Everything in state.json (SPEC §11). Every key decodes with a default.
struct PersistedState: Codable, Sendable {
    var schemaVersion = 1
    var timer = TimerItem()
    /// Starred timer lengths shown as chips (at most TimerStore.maxStars), shortest first.
    var starredTimers: [TimeInterval] = []
    var stopwatch = StopwatchState()
    var counters: [CounterItem] = [CounterItem(name: "Counter")]
    var selectedCounterID: UUID?
    var lastTool: Tool = .timer

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PersistedState()
        schemaVersion = (try? c.decode(Int.self, forKey: .schemaVersion)) ?? d.schemaVersion
        if let t = try? c.decode(TimerItem.self, forKey: .timer) {
            timer = t
        } else if let old = try? c.decode([LegacyTimerPreset].self, forKey: .timers), !old.isEmpty {
            // Before 0.4: keep the selected preset's length (and its run state, if it was running).
            let selectedID = try? c.decode(UUID.self, forKey: .selectedTimerID)
            let p = old.first { $0.id != nil && $0.id == selectedID } ?? old[0]
            timer = TimerItem(duration: max(1, p.duration ?? 5 * 60), run: p.run ?? .idle)
        }
        let stars = (try? c.decode([TimeInterval].self, forKey: .starredTimers)) ?? []
        starredTimers = Array(Set(stars.filter { $0 >= 1 })).sorted().prefix(TimerStore.maxStars).map { $0 }
        stopwatch = (try? c.decode(StopwatchState.self, forKey: .stopwatch)) ?? d.stopwatch
        let cs = (try? c.decode([CounterItem].self, forKey: .counters)) ?? d.counters
        counters = cs.isEmpty ? d.counters : cs      // at least one counter always exists
        selectedCounterID = try? c.decode(UUID.self, forKey: .selectedCounterID)
        lastTool = (try? c.decode(Tool.self, forKey: .lastTool)) ?? d.lastTool
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, timer, starredTimers, stopwatch, counters, selectedCounterID, lastTool
        case timers, selectedTimerID   // before 0.4, read only
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(timer, forKey: .timer)
        try c.encode(starredTimers, forKey: .starredTimers)
        try c.encode(stopwatch, forKey: .stopwatch)
        try c.encode(counters, forKey: .counters)
        try c.encodeIfPresent(selectedCounterID, forKey: .selectedCounterID)
        try c.encode(lastTool, forKey: .lastTool)
    }
}

enum TimeFormat {
    /// m:ss under an hour, h:mm:ss above.
    static func clock(_ seconds: TimeInterval) -> String {
        let t = Int(max(0, seconds))
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60)
                         : String(format: "%d:%02d", t / 60, t % 60)
    }

    /// A length in words, as the default chip names are written: "1 min", "1 hour", "1 h 30 min",
    /// "12 min 30 s".
    static func label(_ seconds: TimeInterval) -> String {
        let t = Int(seconds.rounded())
        let h = t / 3600, m = t / 60 % 60, s = t % 60
        var parts: [String] = []
        if h > 0 { parts.append(m == 0 && s == 0 ? (h == 1 ? "1 hour" : "\(h) hours") : "\(h) h") }
        if m > 0 { parts.append("\(m) min") }
        if s > 0 { parts.append("\(s) s") }
        return parts.isEmpty ? "0 s" : parts.joined(separator: " ")
    }

    /// Countdowns round up, so "0:01" shows until the very end.
    static func countdown(_ remaining: TimeInterval) -> String { clock(remaining.rounded(.up)) }
}
