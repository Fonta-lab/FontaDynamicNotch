import Foundation

/// Run state of one timer (SPEC §7.1). `endDate` is wall-clock, so a timer keeps counting across reboots.
enum TimerRun: Codable, Equatable, Sendable {
    case idle
    case running(endDate: Date)
    case paused(remaining: TimeInterval)
    case ringing
}

/// One timer (SPEC §7.1). Up to 3 can exist as chips (starred, or started); one more can be the
/// "draft" being set in the panel.
struct TimerItem: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var duration: TimeInterval = 5 * 60
    var run: TimerRun = .idle
    /// Starred = kept as a chip even when idle.
    var starred = false

    init(id: UUID = UUID(), duration: TimeInterval = 5 * 60, run: TimerRun = .idle, starred: Bool = false) {
        self.id = id
        self.duration = duration
        self.run = run
        self.starred = starred
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        duration = max(1, (try? c.decode(TimeInterval.self, forKey: .duration)) ?? 5 * 60)
        run = (try? c.decode(TimerRun.self, forKey: .run)) ?? .idle
        starred = (try? c.decode(Bool.self, forKey: .starred)) ?? false
    }

    var isIdle: Bool { run == .idle }
    var isRunning: Bool { if case .running = run { true } else { false } }
    var isRinging: Bool { run == .ringing }
    /// Shown as a chip: starred, or started (running, paused or ringing).
    var isChip: Bool { starred || !isIdle }
}

/// A preset from versions before 0.4 (5 named slots). Only read, to carry the selected one's
/// length and run state over.
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
    /// All timers: the chips plus at most one draft.
    var timerList: [TimerItem] = []
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
        selectedTimerID = try? c.decode(UUID.self, forKey: .selectedTimerID)
        if let list = try? c.decode([TimerItem].self, forKey: .timerList) {
            timerList = list
        } else {
            timerList = Self.migratedTimers(c, selectedID: &selectedTimerID)
        }
        stopwatch = (try? c.decode(StopwatchState.self, forKey: .stopwatch)) ?? d.stopwatch
        let cs = (try? c.decode([CounterItem].self, forKey: .counters)) ?? d.counters
        counters = cs.isEmpty ? d.counters : cs      // at least one counter always exists
        selectedCounterID = try? c.decode(UUID.self, forKey: .selectedCounterID)
        lastTool = (try? c.decode(Tool.self, forKey: .lastTool)) ?? d.lastTool
    }

    /// Older state files: one timer + starred lengths (early 0.4), or 5 named presets (0.3).
    private static func migratedTimers(_ c: KeyedDecodingContainer<CodingKeys>, selectedID: inout UUID?) -> [TimerItem] {
        var current: TimerItem?
        if let t = try? c.decode(TimerItem.self, forKey: .timer) {
            current = t
        } else if let old = try? c.decode([LegacyTimerPreset].self, forKey: .timers), !old.isEmpty {
            let p = old.first { $0.id != nil && $0.id == selectedID } ?? old[0]
            current = TimerItem(duration: max(1, p.duration ?? 5 * 60), run: p.run ?? .idle)
        }
        let stars = (try? c.decode([TimeInterval].self, forKey: .starredTimers)) ?? []
        var list = Array(Set(stars.filter { $0 >= 1 })).sorted().prefix(TimerStore.maxChips)
            .map { TimerItem(duration: $0, starred: true) }
        if var t = current {
            if let i = list.firstIndex(where: { $0.duration == t.duration }) {
                list[i].run = t.run                // same length as a star: that chip carries its state
                t = list[i]
            } else if !t.isIdle && list.count >= TimerStore.maxChips {
                t.run = .idle                      // no room for another chip
                list.append(t)
            } else {
                list.append(t)
            }
            selectedID = t.id
        }
        return list
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, timerList, selectedTimerID, stopwatch, counters, selectedCounterID, lastTool
        case timer, starredTimers, timers   // older versions, read only
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(timerList, forKey: .timerList)
        try c.encodeIfPresent(selectedTimerID, forKey: .selectedTimerID)
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
