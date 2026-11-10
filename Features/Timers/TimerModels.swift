import Foundation

/// Run state of one timer (SPEC §7.1). `endDate` is wall-clock, so a timer keeps counting across reboots.
enum TimerRun: Codable, Equatable, Sendable {
    case idle
    case running(endDate: Date)
    case paused(remaining: TimeInterval)
    case ringing
}

/// One of the 5 preset slots.
struct TimerPreset: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var duration: TimeInterval
    var run: TimerRun = .idle

    init(id: UUID = UUID(), name: String, duration: TimeInterval, run: TimerRun = .idle) {
        self.id = id
        self.name = name
        self.duration = duration
        self.run = run
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? c.decode(String.self, forKey: .name)) ?? "Timer"
        duration = max(1, (try? c.decode(TimeInterval.self, forKey: .duration)) ?? 300)
        run = (try? c.decode(TimerRun.self, forKey: .run)) ?? .idle
    }

    var isRunning: Bool { if case .running = run { true } else { false } }
    var isRinging: Bool { run == .ringing }

    /// Starting values; names and durations become editable in Settings › Timers (M9). [Guess]
    static let defaults: [TimerPreset] = [
        TimerPreset(name: "1 min", duration: 60),
        TimerPreset(name: "5 min", duration: 5 * 60),
        TimerPreset(name: "10 min", duration: 10 * 60),
        TimerPreset(name: "Pomodoro", duration: 25 * 60),
        TimerPreset(name: "1 hour", duration: 60 * 60),
    ]
}

enum Tool: String, Codable, CaseIterable, Sendable {
    case timer, stopwatch, counter
}

/// Everything in state.json (SPEC §11). Every key decodes with a default.
struct PersistedState: Codable, Sendable {
    var schemaVersion = 1
    var timers: [TimerPreset] = TimerPreset.defaults
    var selectedTimerID: UUID?
    var stopwatch = StopwatchState()
    var counters: [CounterItem] = [CounterItem(name: "Counter")]
    var selectedCounterID: UUID?
    var lastTool: Tool = .timer

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PersistedState()
        schemaVersion = (try? c.decode(Int.self, forKey: .schemaVersion)) ?? d.schemaVersion
        var t = (try? c.decode([TimerPreset].self, forKey: .timers)) ?? d.timers
        // Always exactly 5 slots.
        if t.count < 5 { t += TimerPreset.defaults[t.count...] }
        timers = Array(t.prefix(5))
        selectedTimerID = try? c.decode(UUID.self, forKey: .selectedTimerID)
        stopwatch = (try? c.decode(StopwatchState.self, forKey: .stopwatch)) ?? d.stopwatch
        let cs = (try? c.decode([CounterItem].self, forKey: .counters)) ?? d.counters
        counters = cs.isEmpty ? d.counters : cs      // at least one counter always exists
        selectedCounterID = try? c.decode(UUID.self, forKey: .selectedCounterID)
        lastTool = (try? c.decode(Tool.self, forKey: .lastTool)) ?? d.lastTool
    }
}

enum TimeFormat {
    /// m:ss under an hour, h:mm:ss above.
    static func clock(_ seconds: TimeInterval) -> String {
        let t = Int(max(0, seconds))
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60)
                         : String(format: "%d:%02d", t / 60, t % 60)
    }

    /// Countdowns round up, so "0:01" shows until the very end.
    static func countdown(_ remaining: TimeInterval) -> String { clock(remaining.rounded(.up)) }
}
